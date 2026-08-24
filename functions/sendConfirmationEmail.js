/**
 * sendConfirmationEmail — Cloud Function (Gen 2, HTTPS) que envia o e-mail de
 * CONFIRMAÇÃO de uma consulta agendada ou remarcada (ex.: pelo totem de
 * autoatendimento), via SendGrid. A chave fica SOMENTE no servidor (secret).
 *
 * Contrato (POST, JSON):
 *   {
 *     to:          string,            // e-mail do paciente (obrigatório)
 *     mode?:       'agendar'|'remarcar', // padrão 'agendar'
 *     patientName?:string,
 *     doctorName?: string,
 *     specialty?:  string,
 *     date?:       string,            // ex.: "27/06/2026"
 *     time?:       string,            // ex.: "14:00"
 *     senha?:      string,            // senha/comprovante
 *     clinicName?: string,            // sobrescreve EMAIL_FROM_NAME no remetente
 *     footer?:     string,            // rodapé livre (ex.: instruções)
 *     idclinica?:  string             // apenas para log/rastreio
 *   }
 * Resposta: { ok: true } ou { error }.
 *
 * ─── Deploy ──────────────────────────────────────────────────────────────────
 *   firebase functions:secrets:set SENDGRID_API_KEY   // se ainda não houver
 *   firebase deploy --only functions:sendConfirmationEmail
 *
 * URL: https://us-central1-agendaclinica-457713.cloudfunctions.net/sendConfirmationEmail
 */

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const SENDGRID_API_KEY = defineSecret("SENDGRID_API_KEY");

const EMAIL_FROM = process.env.EMAIL_FROM || "time@agendaclinicas.com.br";
const EMAIL_FROM_NAME = process.env.EMAIL_FROM_NAME || "Agenda Clínica";

exports.sendConfirmationEmail = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [SENDGRID_API_KEY],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") return void res.status(204).send("");
    if (req.method !== "POST") return void res.status(405).json({ error: "Use POST." });

    try {
      const body = req.body || {};
      const to = (body.to || "").toString().trim();
      if (!to.includes("@")) return void res.status(400).json({ error: "Campo 'to' inválido." });

      const isReschedule = (body.mode || "agendar") === "remarcar";
      const clinicName = (body.clinicName || EMAIL_FROM_NAME).toString();
      const data = {
        patientName: (body.patientName || "Paciente").toString(),
        doctorName: (body.doctorName || "A definir").toString(),
        specialty: (body.specialty || "Consulta").toString(),
        date: (body.date || "").toString(),
        time: (body.time || "").toString(),
        senha: (body.senha || "").toString(),
        footer: (body.footer || "").toString(),
      };

      const subject = isReschedule
        ? `Consulta remarcada — ${clinicName}`
        : `Consulta confirmada — ${clinicName}`;
      const html = _buildHtml({ isReschedule, clinicName, ...data });
      const text = _buildText({ isReschedule, clinicName, ...data });

      const payload = {
        personalizations: [{ to: [{ email: to }] }],
        from: { email: EMAIL_FROM, name: clinicName },
        subject,
        content: [
          { type: "text/plain", value: text },
          { type: "text/html", value: html },
        ],
      };

      const sg = await fetch("https://api.sendgrid.com/v3/mail/send", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${SENDGRID_API_KEY.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      if (sg.status === 202) return void res.status(200).json({ ok: true });

      const errText = await sg.text();
      console.error("sendConfirmationEmail SendGrid error:", sg.status, errText);
      res.status(502).json({ error: `SendGrid HTTP ${sg.status}`, detail: errText.slice(0, 500) });
    } catch (err) {
      console.error("sendConfirmationEmail error:", err);
      res.status(500).json({ error: String(err && err.message ? err.message : err) });
    }
  }
);

function _esc(s) {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function _buildText(d) {
  const title = d.isReschedule ? "Sua consulta foi remarcada" : "Sua consulta foi confirmada";
  const lines = [
    `${title} — ${d.clinicName}`,
    "",
    `Paciente: ${d.patientName}`,
    `Profissional: ${d.doctorName}`,
    `Especialidade: ${d.specialty}`,
    d.date ? `Data: ${d.date}` : null,
    d.time ? `Horário: ${d.time}` : null,
    d.senha ? `Senha: ${d.senha}` : null,
    "",
    d.footer || "",
  ].filter((l) => l !== null);
  return lines.join("\n");
}

function _buildHtml(d) {
  const title = d.isReschedule ? "Consulta remarcada" : "Consulta confirmada";
  const accent = d.isReschedule ? "#23BAD4" : "#1FAA59";
  const row = (label, value) =>
    value
      ? `<tr>
           <td style="padding:6px 0;color:#6b7280;font-size:13px">${_esc(label)}</td>
           <td style="padding:6px 0;color:#11151c;font-size:14px;font-weight:600;text-align:right">${_esc(value)}</td>
         </tr>`
      : "";
  const senhaBlock = d.senha
    ? `<div style="margin:16px 0;padding:14px;background:#f6f8fb;border-radius:10px;text-align:center">
         <div style="font-size:11px;letter-spacing:2px;color:#6b7280;font-weight:700">SENHA</div>
         <div style="font-size:40px;font-weight:800;color:#11151c;line-height:1.1">${_esc(d.senha)}</div>
       </div>`
    : "";
  const footerBlock = d.footer
    ? `<p style="margin-top:16px;color:#6b7280;font-size:12px">${_esc(d.footer)}</p>`
    : "";

  return `<!DOCTYPE html><html><body style="margin:0;background:#eef3f7;padding:24px;font-family:Arial,Helvetica,sans-serif">
    <div style="max-width:480px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid #e5e7eb">
      <div style="background:${accent};padding:20px 24px">
        <div style="color:#fff;font-size:13px;font-weight:700;letter-spacing:1px;opacity:.9">${_esc(d.clinicName)}</div>
        <div style="color:#fff;font-size:22px;font-weight:800;margin-top:4px">${title}</div>
      </div>
      <div style="padding:24px">
        <p style="margin:0 0 12px;color:#11151c;font-size:15px">Olá, <strong>${_esc(d.patientName)}</strong>! ${
    d.isReschedule
      ? "Seu agendamento foi atualizado com sucesso."
      : "Seu agendamento foi confirmado com sucesso."
  }</p>
        ${senhaBlock}
        <table style="width:100%;border-collapse:collapse;border-top:1px solid #eee;border-bottom:1px solid #eee">
          ${row("Profissional", d.doctorName)}
          ${row("Especialidade", d.specialty)}
          ${row("Data", d.date)}
          ${row("Horário", d.time)}
        </table>
        ${footerBlock}
      </div>
    </div>
  </body></html>`;
}
