/**
 * whatsappProxy — Cloud Function (Gen 2, HTTPS) que envia WhatsApp via Z-API.
 *
 * As credenciais Z-API são **por clínica** e ficam no Firestore
 * (`tb_config_whatsapp`): `intanceId`, `token`, `tokenCliente`, `idclinica`.
 * A função lê a config da clínica (Admin SDK) e chama a Z-API — nada de
 * credencial no cliente. Ver `.specify/ZAPI.md`.
 *
 * Contrato (POST, JSON):
 *   {
 *     clinicaId: string,                       // obrigatório (escopo multi-tenant)
 *     action:    'send-text' | 'send-button-list',
 *     phone:     string,                        // DDI+DDD+número
 *     message:   string,
 *     buttons?:  string[],                      // p/ send-button-list
 *     delayMessage?: number
 *   }
 * Resposta: repassa o JSON da Z-API ou { error }.
 *
 * ─── Deploy ──────────────────────────────────────────────────────────────────
 *   1. Copie para functions/ (usa firebase-admin já disponível nas funções).
 *   2. firebase deploy --only functions:whatsappProxy
 *   (Sem secrets: as credenciais vêm de tb_config_whatsapp por clínica.)
 *
 * URL: https://us-central1-agendaclinica-457713.cloudfunctions.net/whatsappProxy
 */

const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

if (!getApps().length) initializeApp();
const db = getFirestore();

const ZAPI_BASE = "https://api.z-api.io";
const ALLOWED_ORIGINS = "*";

exports.whatsappProxy = onRequest(
  { region: "us-central1", cors: true, timeoutSeconds: 60, memory: "256MiB" },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", ALLOWED_ORIGINS);
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") return void res.status(204).send("");
    if (req.method !== "POST") return void res.status(405).json({ error: "Use POST." });

    try {
      const { clinicaId, action = "send-text", phone, message, buttons, delayMessage } =
        req.body || {};
      if (!clinicaId) return void res.status(400).json({ error: "clinicaId obrigatório." });
      if (!phone) return void res.status(400).json({ error: "phone obrigatório." });

      const cfg = await _getWhatsappConfig(clinicaId);
      if (!cfg) {
        return void res.status(404).json({
          error: "Configuração de WhatsApp (tb_config_whatsapp) não encontrada para a clínica.",
        });
      }

      const url = `${ZAPI_BASE}/instances/${cfg.intanceId}/token/${cfg.token}/${action}`;
      const payload =
        action === "send-button-list"
          ? {
              phone,
              message: message || "",
              buttonList: {
                buttons: (buttons || []).map((label, i) => ({ id: String(i + 1), label })),
              },
            }
          : { phone, message: message || "", ...(delayMessage ? { delayMessage } : {}) };

      const z = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Client-Token": cfg.tokenCliente || "",
        },
        body: JSON.stringify(payload),
      });

      const text = await z.text();
      res.status(z.status);
      res.set("Content-Type", "application/json");
      res.send(text);
    } catch (err) {
      console.error("whatsappProxy error:", err);
      res.status(500).json({ error: String(err && err.message ? err.message : err) });
    }
  }
);

/** Busca a config Z-API da clínica (idclinica como reference ou string). */
async function _getWhatsappConfig(clinicaId) {
  const col = db.collection("tb_config_whatsapp");
  // 1) idclinica como referência de documento.
  let snap = await col
    .where("idclinica", "==", db.doc(`tb_clinica/${clinicaId}`))
    .limit(5)
    .get();
  // 2) fallback: idclinica como string.
  if (snap.empty) {
    snap = await col.where("idclinica", "==", clinicaId).limit(5).get();
  }
  if (snap.empty) return null;
  // Prefere uma config ativa (active === 1) se houver várias.
  const docs = snap.docs.map((d) => d.data());
  const active = docs.find((d) => d.active === 1 || d.active === true);
  const cfg = active || docs[0];
  if (!cfg || !cfg.intanceId || !cfg.token) return null;
  return cfg;
}
