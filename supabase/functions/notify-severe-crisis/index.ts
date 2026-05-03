// Supabase Edge Function: notify-severe-crisis
// Dispara um e-mail ao médico quando um paciente registra uma crise com intensidade >= 8.
//
// Variáveis de ambiente necessárias (configure em Project Settings → Edge Functions → Secrets):
//   RESEND_API_KEY  → chave da API do Resend (https://resend.com/api-keys)
//   DOCTOR_EMAIL    → e-mail destino (ex.: neuro.brendow@gmail.com)
//   FROM_EMAIL      → remetente (ex.: "Diário de Cefaleia <noreply@neurobrendow.com.br>")
//                     Use o domínio que você verificou no Resend, ou "onboarding@resend.dev" para teste.
//
// Acionado por: Database Webhook (Database → Webhooks no painel) ou pelo trigger
// `notify_severe_crisis` definido no schema SQL.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SEVERE_THRESHOLD = 8;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const DOCTOR_EMAIL = Deno.env.get("DOCTOR_EMAIL")!;
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") || "onboarding@resend.dev";

const LABELS_SIDE: Record<string, string> = {
  left: "Esquerdo", right: "Direito", bilateral: "Bilateral",
  alternating: "Alternou", none: "Sem lado"
};
const LABELS_SYMPTOM: Record<string, string> = {
  nausea: "Náusea", vomiting: "Vômito", photophobia: "Fotofobia",
  phonophobia: "Fonofobia", osmophobia: "Osmofobia",
  visual_aura: "Aura visual", sensory_aura: "Aura sensitiva",
  dizziness: "Tontura", allodynia: "Alodinia"
};
const LABELS_TRIGGER: Record<string, string> = {
  stress: "Estresse", sleep_lack: "Pouco sono", sleep_excess: "Sono excessivo",
  hunger: "Jejum", alcohol: "Álcool", hormonal: "Hormonal",
  weather: "Clima", screen: "Telas", smell: "Cheiro",
  exertion: "Esforço", dehydration: "Desidratação", food: "Alimento"
};

function fmtList(arr: string[] | null | undefined, dict: Record<string, string>): string {
  if (!arr || !arr.length) return "—";
  return arr.map(v => dict[v] ?? v).join(", ");
}

function fmtDateBR(iso: string): string {
  return new Date(iso).toLocaleString("pt-BR", {
    timeZone: "America/Fortaleza",
    dateStyle: "short",
    timeStyle: "short",
  });
}

serve(async (req) => {
  try {
    const payload = await req.json().catch(() => ({}));
    // Aceita formato do Supabase Database Webhook OU do trigger pg_net (ambos com `record`)
    const record = payload?.record ?? payload?.new ?? payload;
    if (!record?.intensity || record.intensity < SEVERE_THRESHOLD) {
      return new Response(JSON.stringify({ skipped: true, reason: "below threshold" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Busca dados do paciente
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, phone")
      .eq("id", record.user_id)
      .maybeSingle();

    const patientName = profile?.full_name || "Paciente desconhecido";
    const phone = profile?.phone || "—";

    const subject = `🚨 Crise grave registrada — ${patientName} (${record.intensity}/10)`;

    const html = `
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; color: #0d1b2a;">
        <div style="background: #0d1b2a; color: #f5f2ee; padding: 24px; border-top: 3px solid #b89a5e;">
          <p style="margin: 0; font-size: 12px; letter-spacing: 0.15em; text-transform: uppercase; color: #b89a5e;">Diário de Cefaleia · Alerta</p>
          <h1 style="margin: 8px 0 0; font-size: 22px; font-weight: 400;">Crise de alta intensidade</h1>
        </div>

        <div style="background: #fff; padding: 24px; border: 1px solid #d8e4f0; border-top: none;">
          <p style="font-size: 16px; margin: 0 0 16px;">
            O paciente <strong>${patientName}</strong> registrou uma crise com intensidade
            <strong style="color: #c44;">${record.intensity}/10</strong>.
          </p>

          <table style="width: 100%; border-collapse: collapse; font-size: 14px; margin: 16px 0;">
            <tr><td style="padding: 6px 0; color: #5a6f85; width: 140px;">Data/hora</td><td style="padding: 6px 0;"><strong>${fmtDateBR(record.started_at)}</strong></td></tr>
            <tr><td style="padding: 6px 0; color: #5a6f85;">Duração</td><td style="padding: 6px 0;">${record.duration_minutes ? record.duration_minutes + " min" : "—"}</td></tr>
            <tr><td style="padding: 6px 0; color: #5a6f85;">Lado</td><td style="padding: 6px 0;">${LABELS_SIDE[record.location_side] || "—"}</td></tr>
            <tr><td style="padding: 6px 0; color: #5a6f85;">Sintomas</td><td style="padding: 6px 0;">${fmtList(record.symptoms, LABELS_SYMPTOM)}</td></tr>
            <tr><td style="padding: 6px 0; color: #5a6f85;">Gatilhos</td><td style="padding: 6px 0;">${fmtList(record.triggers, LABELS_TRIGGER)}${record.triggers_other ? " · " + record.triggers_other : ""}</td></tr>
            <tr><td style="padding: 6px 0; color: #5a6f85;">Telefone</td><td style="padding: 6px 0;">${phone}</td></tr>
          </table>

          ${record.notes ? `
            <div style="background: #eef2f7; padding: 14px; border-left: 3px solid #b89a5e; margin: 16px 0;">
              <p style="margin: 0; font-size: 12px; color: #5a6f85; text-transform: uppercase; letter-spacing: 0.08em;">Observações do paciente</p>
              <p style="margin: 6px 0 0; font-size: 14px;">${record.notes.replace(/\n/g, "<br>")}</p>
            </div>` : ""}

          <p style="margin: 24px 0 0;">
            <a href="https://neurobrendow.com.br/medico/"
               style="background: #b89a5e; color: #0d1b2a; padding: 12px 24px; text-decoration: none; font-size: 13px; letter-spacing: 0.1em; text-transform: uppercase; font-weight: 500; display: inline-block;">
              Abrir o dashboard
            </a>
          </p>
        </div>

        <p style="font-size: 11px; color: #8a9bb0; margin-top: 16px; text-align: center;">
          Você está recebendo este e-mail porque está cadastrado como médico no Diário de Cefaleia.
        </p>
      </div>
    `;

    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [DOCTOR_EMAIL],
        subject,
        html,
      }),
    });

    const resendBody = await resendRes.text();
    if (!resendRes.ok) {
      console.error("Resend error:", resendRes.status, resendBody);
      return new Response(JSON.stringify({ ok: false, error: resendBody }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ok: true, resend: resendBody }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Function error:", err);
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
