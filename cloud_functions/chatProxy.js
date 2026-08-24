/**
 * chatProxy — Cloud Function (Gen 2, HTTPS) que faz proxy seguro do chat de IA.
 *
 * O app Flutter (web/mobile/desktop) chama ESTA função; ela repassa para o
 * Azure AI Foundry (DeepSeek V4) com a chave que vive SOMENTE no servidor.
 * Assim a chave nunca vai para o cliente e o CORS é resolvido aqui.
 *
 * Contrato (POST, JSON):
 *   { model, messages, tools?, tool_choice?, temperature? }
 * Resposta: o JSON de chat-completions da Azure (choices[0].message, etc.),
 * inclusive `tool_calls` — o loop de ferramentas roda no app (ai_agent_service.dart).
 *
 * Deploy (na pasta `functions/` do projeto agendaclinica-457713):
 *   1. Copie este arquivo para functions/ (ou cole a função no seu index.js).
 *   2. Configure os segredos:
 *        firebase functions:secrets:set AZURE_AI_KEY
 *        # (cole a chave do .specify/AI_chaves.md)
 *   3. (Opcional) ajuste AZURE_AI_ENDPOINT / AZURE_AI_MODEL abaixo.
 *   4. firebase deploy --only functions:chatProxy
 *
 * A URL pública ficará:
 *   https://us-central1-agendaclinica-457713.cloudfunctions.net/chatProxy
 * (mesma URL usada por AiAgentService.defaultProxyUrl no Flutter).
 */

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const AZURE_AI_KEY = defineSecret("AZURE_AI_KEY");

// Endpoint OpenAI-compatível do Azure AI Foundry / DeepSeek (.specify/AI_chaves.md §1.4).
// Base AZURE_DEEPSEEK_ENDPOINT = https://micro-mrfgtgfz-eastus2.services.ai.azure.com/models/
const AZURE_AI_ENDPOINT =
  process.env.AZURE_AI_ENDPOINT ||
  "https://micro-mrfgtgfz-eastus2.services.ai.azure.com/models/chat/completions?api-version=2024-05-01-preview";

const DEFAULT_MODEL = process.env.AZURE_AI_MODEL || "DeepSeek-V4-Flash";

// Origens permitidas (CORS). Em produção, restrinja ao seu domínio.
const ALLOWED_ORIGINS = "*";

exports.chatProxy = onRequest(
  {
    region: "us-central1",
    cors: true, // habilita CORS automaticamente
    secrets: [AZURE_AI_KEY],
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (req, res) => {
    // Preflight / CORS manual (reforço além do cors:true).
    res.set("Access-Control-Allow-Origin", ALLOWED_ORIGINS);
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    if (req.method !== "POST") {
      res.status(405).json({ error: "Use POST." });
      return;
    }

    try {
      const body = req.body || {};
      const payload = {
        model: body.model || DEFAULT_MODEL,
        messages: body.messages || [],
        temperature: typeof body.temperature === "number" ? body.temperature : 0.4,
      };
      if (Array.isArray(body.tools) && body.tools.length > 0) {
        payload.tools = body.tools;
        payload.tool_choice = body.tool_choice || "auto";
      }

      const key = AZURE_AI_KEY.value();
      const upstream = await fetch(AZURE_AI_ENDPOINT, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          // Azure AI Inference aceita `api-key`; mantemos Bearer como fallback.
          "api-key": key,
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify(payload),
      });

      const text = await upstream.text();
      res.status(upstream.status);
      res.set("Content-Type", "application/json");
      res.send(text);
    } catch (err) {
      console.error("chatProxy error:", err);
      res.status(500).json({ error: String(err && err.message ? err.message : err) });
    }
  }
);
