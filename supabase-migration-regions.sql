-- =====================================================================
--  Migração: novas regiões anatômicas para o Diário de Cefaleia
--  Data: 2026-05-04
--  Autor: Dr. Brendow Mártin
--
--  CONTEXTO
--  --------
--  A coluna `headache_entries.location_regions` é um text[] (array de
--  strings).  Antes, o front-end gravava 6 regiões antigas:
--      frontal, temporal, parietal, occipital, orbital, nuchal
--  Agora o seletor visual da cabeça grava 18 regiões com lateralidade:
--
--    Frente (12)
--      entre_os_olhos
--      fronte_direita,    fronte_esquerda
--      olho_direito,      olho_esquerdo
--      tempora_direita,   tempora_esquerda
--      maxilar_direito,   maxilar_esquerdo
--      mandibula_direita, mandibula_esquerda
--      dente
--    Atrás (6)
--      traseira_superior_direita, traseira_superior_esquerda
--      traseira_inferior_direita, traseira_inferior_esquerda
--      nuca_direita,              nuca_esquerda
--
--  Como `text[]` aceita qualquer string, NENHUMA alteração de tipo é
--  necessária — a coluna continua igual.  O que esta migração faz é:
--
--    1) Criar tabela de catálogo `body_regions` com as 18 regiões,
--       facilitando relatórios, traduções e validação opcional.
--    2) Criar uma view `headache_entries_with_regions` que devolve as
--       regiões já com label em pt-BR (útil para futuras consultas SQL).
--    3) (Opcional) função para converter entradas legadas das 6 regiões
--       antigas para o novo padrão.  Comentada por padrão — descomente
--       só depois de validar.
--
--  Rode este arquivo no SQL Editor do seu projeto Supabase.  É
--  idempotente (pode rodar mais de uma vez sem quebrar nada).
-- =====================================================================

-- 1) Catálogo de regiões -----------------------------------------------
create table if not exists public.body_regions (
  slug         text primary key,
  label_pt     text not null,
  view         text not null check (view in ('front', 'back')),
  side         text         check (side in ('left', 'right', 'center')),
  display_order int not null
);

-- Permite leitura pública (necessário para o front-end pegar a tabela
-- via PostgREST sem login).  Ajuste se quiser restringir.
alter table public.body_regions enable row level security;

drop policy if exists "body_regions_read" on public.body_regions;
create policy "body_regions_read"
  on public.body_regions for select
  using (true);

-- Popula/atualiza as 18 regiões
insert into public.body_regions (slug, label_pt, view, side, display_order) values
  ('entre_os_olhos',              'Entre os olhos',                'front', 'center',  1),
  ('fronte_direita',              'Fronte (direita)',              'front', 'right',   2),
  ('fronte_esquerda',             'Fronte (esquerda)',             'front', 'left',    3),
  ('olho_direito',                'Olho direito',                  'front', 'right',   4),
  ('olho_esquerdo',               'Olho esquerdo',                 'front', 'left',    5),
  ('tempora_direita',             'Têmpora direita',               'front', 'right',   6),
  ('tempora_esquerda',            'Têmpora esquerda',              'front', 'left',    7),
  ('maxilar_direito',             'Maxilar direito',               'front', 'right',   8),
  ('maxilar_esquerdo',            'Maxilar esquerdo',              'front', 'left',    9),
  ('mandibula_direita',           'Mandíbula direita',             'front', 'right',  10),
  ('mandibula_esquerda',          'Mandíbula esquerda',            'front', 'left',   11),
  ('dente',                       'Dente',                         'front', 'center', 12),
  ('traseira_superior_direita',   'Traseira superior (direita)',   'back',  'right',  13),
  ('traseira_superior_esquerda',  'Traseira superior (esquerda)',  'back',  'left',   14),
  ('traseira_inferior_direita',   'Traseira inferior (direita)',   'back',  'right',  15),
  ('traseira_inferior_esquerda',  'Traseira inferior (esquerda)',  'back',  'left',   16),
  ('nuca_direita',                'Nuca direita',                  'back',  'right',  17),
  ('nuca_esquerda',               'Nuca esquerda',                 'back',  'left',   18)
on conflict (slug) do update set
  label_pt      = excluded.label_pt,
  view          = excluded.view,
  side          = excluded.side,
  display_order = excluded.display_order;

-- 2) View opcional para relatórios -------------------------------------
-- Faz unnest do array e junta com o catálogo, devolvendo uma linha por
-- (entrada × região) com o label em pt-BR.  Útil para gráficos por
-- região, exportações, etc.
create or replace view public.headache_entries_with_regions as
select
  e.id           as entry_id,
  e.user_id,
  e.started_at,
  e.intensity,
  e.location_side,
  r_slug         as region_slug,
  br.label_pt    as region_label,
  br.view        as region_view,
  br.side        as region_side
from public.headache_entries e
left join lateral unnest(coalesce(e.location_regions, array[]::text[])) as r_slug on true
left join public.body_regions br on br.slug = r_slug;

-- A view herda RLS da tabela base — usuários só veem as próprias
-- entradas, exatamente como já acontece em headache_entries.

-- 3) (OPCIONAL) Converter entradas legadas -----------------------------
-- Os valores antigos não têm lateralidade; a conversão abaixo escolhe
-- equivalentes "centrais" ou bilaterais.  Descomente só se quiser
-- normalizar entradas anteriores ao seletor visual.
--
-- update public.headache_entries set location_regions = (
--   select array_agg(distinct case x
--     when 'frontal'   then 'entre_os_olhos'
--     when 'temporal'  then 'tempora_direita'   -- (sem como saber o lado)
--     when 'parietal'  then 'traseira_superior_direita'
--     when 'occipital' then 'traseira_inferior_direita'
--     when 'orbital'   then 'olho_direito'
--     when 'nuchal'    then 'nuca_direita'
--     else x
--   end)
--   from unnest(location_regions) as x
-- )
-- where exists (
--   select 1 from unnest(location_regions) as x
--   where x in ('frontal','temporal','parietal','occipital','orbital','nuchal')
-- );

-- =====================================================================
-- Pronto.  O front-end já estava gravando text[] em location_regions,
-- então passa a gravar os novos slugs sem nenhuma outra alteração no
-- esquema.  As entradas antigas continuam funcionando — o LABELS no
-- JS reconhece tanto os slugs antigos quanto os novos.
-- =====================================================================
