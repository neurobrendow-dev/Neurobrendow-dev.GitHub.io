-- =============================================================
-- Diário de Cefaleia — Schema completo para Supabase
-- Dr. Brendow Mártin — neurobrendow.com.br
--
-- COMO USAR:
--   1. No painel do Supabase, abra "SQL Editor"
--   2. Cole TODO este arquivo e clique em "Run"
--   3. Aguarde a confirmação de sucesso
-- =============================================================

-- Extensões necessárias --------------------------------------------------
create extension if not exists "uuid-ossp";

-- ============================================================
-- 1) TABELA: profiles
--    Estende auth.users com nome, papel (paciente/médico), consentimento LGPD
-- ============================================================
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  full_name    text not null,
  birth_date   date,
  phone        text,
  role         text not null default 'patient'
                check (role in ('patient', 'doctor')),
  consent_lgpd boolean not null default false,
  consent_lgpd_at timestamptz,
  created_at   timestamptz default now(),
  updated_at   timestamptz default now()
);

-- ============================================================
-- 2) TABELA: headache_entries
--    Cada crise é um registro do paciente
-- ============================================================
create table if not exists public.headache_entries (
  id                uuid primary key default uuid_generate_v4(),
  user_id           uuid not null references auth.users(id) on delete cascade,

  -- Dados da crise
  started_at        timestamptz not null,
  duration_minutes  integer check (duration_minutes >= 0),
  intensity         smallint not null check (intensity between 0 and 10),

  -- Localização da dor
  location_side     text check (location_side in ('left','right','bilateral','alternating','none')),
  location_regions  text[] default '{}',  -- frontal, temporal, parietal, occipital, orbital, nuchal

  -- Qualidade
  pain_qualities    text[] default '{}',  -- throbbing, pressure, stabbing, burning, electric, in_band

  -- Sintomas associados
  symptoms          text[] default '{}',  -- nausea, vomiting, photophobia, phonophobia, osmophobia, visual_aura, sensory_aura, dizziness, allodynia

  -- Possíveis gatilhos
  triggers          text[] default '{}',  -- stress, sleep_lack, sleep_excess, hunger, alcohol, hormonal, weather, screen, smell, exertion, dehydration, food
  triggers_other    text,

  -- Medicações utilizadas (lista de objetos)
  -- Cada item: {"name": "...", "dose": "...", "time": "...", "effective": "yes|no|partial"}
  medications       jsonb default '[]'::jsonb,

  -- Observações livres
  notes             text,

  -- Metadados
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);

create index if not exists idx_headache_entries_user_started
  on public.headache_entries (user_id, started_at desc);

-- ============================================================
-- 3) Função trigger: criar perfil automaticamente quando usuário se cadastra
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, birth_date, consent_lgpd, consent_lgpd_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.raw_user_meta_data->>'phone',
    nullif(new.raw_user_meta_data->>'birth_date','')::date,
    coalesce((new.raw_user_meta_data->>'consent_lgpd')::boolean, false),
    case when (new.raw_user_meta_data->>'consent_lgpd')::boolean then now() else null end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- 4) Função trigger: atualizar updated_at automaticamente
-- ============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_entries_updated on public.headache_entries;
create trigger trg_entries_updated
  before update on public.headache_entries
  for each row execute procedure public.set_updated_at();

-- ============================================================
-- 5) Função auxiliar: verifica se um usuário é médico
--    (security definer evita recursão infinita nas policies)
-- ============================================================
create or replace function public.is_doctor(uid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists(
    select 1 from public.profiles
    where id = uid and role = 'doctor'
  );
$$;

-- ============================================================
-- 6) ROW LEVEL SECURITY — política de acesso por linha
-- ============================================================
alter table public.profiles enable row level security;
alter table public.headache_entries enable row level security;

-- ---- profiles --------------------------------------------------
drop policy if exists "self_select" on public.profiles;
create policy "self_select" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "self_update" on public.profiles;
create policy "self_update" on public.profiles
  for update using (auth.uid() = id);

-- Médico vê todos os perfis (papel = patient)
drop policy if exists "doctor_select_all" on public.profiles;
create policy "doctor_select_all" on public.profiles
  for select using ( public.is_doctor(auth.uid()) );

-- ---- headache_entries -----------------------------------------
-- Paciente: faz tudo nas próprias entradas
drop policy if exists "patient_all_own" on public.headache_entries;
create policy "patient_all_own" on public.headache_entries
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Médico: leitura de todas as entradas (somente leitura)
drop policy if exists "doctor_select_all_entries" on public.headache_entries;
create policy "doctor_select_all_entries" on public.headache_entries
  for select using ( public.is_doctor(auth.uid()) );

-- ============================================================
-- 7) View útil: estatísticas resumidas por paciente (para o painel do médico)
-- ============================================================
create or replace view public.patient_summary as
  select
    p.id,
    p.full_name,
    p.birth_date,
    p.phone,
    p.created_at as registered_at,
    count(h.id) as total_entries,
    max(h.started_at) as last_entry_at,
    round(avg(h.intensity)::numeric, 1) as avg_intensity_30d
  from public.profiles p
  left join public.headache_entries h
    on h.user_id = p.id and h.started_at >= now() - interval '30 days'
  where p.role = 'patient'
  group by p.id;

-- ============================================================
-- FIM. Após rodar este script:
--   1. Crie sua conta no app (qualquer cadastro normal)
--   2. No SQL Editor, execute:
--        update public.profiles set role = 'doctor' where id =
--          (select id from auth.users where email = 'seu-email@dominio.com');
--   3. Teste o login na área do médico.
-- ============================================================
