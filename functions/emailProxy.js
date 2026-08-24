/**
 * emailProxy — Cloud Function (Gen 2, HTTPS) que envia e-mail DIRETO via SendGrid.
 *
 * O app/MCP chama esta função; ela envia pela API do SendGrid com a chave que
 * vive SOMENTE no servidor (secret). Complementa a fila `email_queue` (que é
 * processada de forma assíncrona por `ffProcessEmailQueue`): aqui o envio é
 * imediato e síncrono.
 *
 * Contrato (POST, JSON):
 *   {
 *     to:        string | string[],   // destinatário(s)
 *     subject:   string,
 *     html?:     string,              // corpo HTML (tem prioridade)
 *     text?:     string,              // corpo texto puro
 *     markdown?: string,              // alternativa: convertido p/ HTML simples
 *     fromName?: string,              // sobrescreve EMAIL_FROM_NAME
 *     idclinica?: string              // apenas para rastreio/log
 *   }
 * Resposta: { ok: true } ou { error }.
 *
 * ─── Deploy ──────────────────────────────────────────────────────────────────
 *   1. Copie para functions/.
 *   2. Secret com a chave (AI_chaves.md §1.6 SENDGRID_API_KEY):
 *        firebase functions:secrets:set SENDGRID_API_KEY
 *   3. (Opcional) env vars: EMAIL_FROM (padrão time@agendaclinicas.com.br) e
 *      EMAIL_FROM_NAME (padrão "Agenda Clínica").
 *   4. firebase deploy --only functions:emailProxy
 *
 * URL: https://us-central1-agendaclinica-457713.cloudfunctions.net/emailProxy
 * (igual ao default usado pela camada MCP em comunicacao_tools.dart).
 */

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const SENDGRID_API_KEY = defineSecret("SENDGRID_API_KEY");

const EMAIL_FROM = process.env.EMAIL_FROM || "time@agendaclinicas.com.br";
const EMAIL_FROM_NAME = process.env.EMAIL_FROM_NAME || "Agenda Clínica";
const ALLOWED_ORIGINS = "*";

exports.emailProxy = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [SENDGRID_API_KEY],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", ALLOWED_ORIGINS);
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") return void res.status(204).send("");
    if (req.method !== "POST") return void res.status(405).json({ error: "Use POST." });

    try {
      const body = req.body || {};
      const recipients = Array.isArray(body.to) ? body.to : [body.to];
      const tos = recipients.filter((e) => typeof e === "string" && e.includes("@"));
      if (tos.length === 0) return void res.status(400).json({ error: "Campo 'to' inválido." });

      const subject = (body.subject || "(sem assunto)").toString();
      let html = body.html;
      if (!html && body.markdown) html = _miniMarkdown(body.markdown.toString());
      const text = body.text || (body.markdown ? body.markdown.toString() : undefined);
      if (!html && !text) return void res.status(400).json({ error: "Forneça html, text ou markdown." });

      const content = [];
      if (text) content.push({ type: "text/plain", value: text });
      if (html) content.push({ type: "text/html", value: html });

      const payload = {
        personalizations: [{ to: tos.map((email) => ({ email })) }],
        from: { email: EMAIL_FROM, name: body.fromName || EMAIL_FROM_NAME },
        subject,
        content,
      };

      const sg = await fetch("https://api.sendgrid.com/v3/mail/send", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${SENDGRID_API_KEY.value()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      if (sg.status === 202) return void res.status(200).json({ ok: true, sent: tos.length });

      const errText = await sg.text();
      console.error("emailProxy SendGrid error:", sg.status, errText);
      res.status(502).json({ error: `SendGrid HTTP ${sg.status}`, detail: errText.slice(0, 500) });
    } catch (err) {
      console.error("emailProxy error:", err);
      res.status(500).json({ error: String(err && err.message ? err.message : err) });
    }
  }
);

/** Conversão mínima de Markdown → HTML (negrito, itálico, quebras de linha). */
function _miniMarkdown(md) {
  const esc = md
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
  const inline = esc
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/\*(.+?)\*/g, "<em>$1</em>");
  const paragraphs = inline
    .split(/\n{2,}/)
    .map((p) => `<p>${p.replace(/\n/g, "<br>")}</p>`)
    .join("");
  return `<div style="font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#1a1d29">${paragraphs}</div>`;
}
