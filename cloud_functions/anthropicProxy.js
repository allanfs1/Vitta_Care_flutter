/**
 * anthropicProxy — Cloud Function (Gen 2, HTTPS) alternativa ao DeepSeek.
 *
 * Aceita o MESMO contrato OpenAI usado por `ai_agent_service.dart`
 * ({ messages, tools, tool_choice }) e TRADUZ para a API Messages da Anthropic
 * (Claude), devolvendo a resposta de volta no formato OpenAI
 * (`choices[0].message` com `tool_calls`). Assim o app pode trocar de provedor
 * apenas apontando `AiAgentService(proxyUrl: ...anthropicProxy)`.
 *
 * A chave fica SOMENTE no servidor (secret ANTHROPIC_API_KEY).
 *
 * ─── Deploy ──────────────────────────────────────────────────────────────────
 *   1. Copie para functions/.
 *   2. Secret com a chave da Anthropic (AI_chaves.md §1.3):
 *        firebase functions:secrets:set ANTHROPIC_API_KEY
 *   3. (Opcional) env ANTHROPIC_MODEL (padrão claude-sonnet-4-6) e
 *      ANTHROPIC_MAX_TOKENS (padrão 2048).
 *   4. firebase deploy --only functions:anthropicProxy
 *
 * URL: https://us-central1-agendaclinica-457713.cloudfunctions.net/anthropicProxy
 */

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL || "claude-sonnet-4-6";
const ANTHROPIC_MAX_TOKENS = parseInt(process.env.ANTHROPIC_MAX_TOKENS || "2048", 10);
const ALLOWED_ORIGINS = "*";

exports.anthropicProxy = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 120,
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
      const { system, messages } = _toAnthropicMessages(body.messages || []);
      const tools = _toAnthropicTools(body.tools);

      const anthropicReq = {
        model: ANTHROPIC_MODEL,
        max_tokens: ANTHROPIC_MAX_TOKENS,
        messages,
        ...(system ? { system } : {}),
        ...(tools ? { tools, tool_choice: { type: "auto" } } : {}),
        ...(typeof body.temperature === "number" ? { temperature: body.temperature } : {}),
      };

      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": ANTHROPIC_API_KEY.value(),
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify(anthropicReq),
      });

      const data = await r.json();
      if (r.status !== 200) {
        console.error("anthropicProxy error:", r.status, JSON.stringify(data));
        return void res.status(r.status).json({ error: data });
      }

      res.status(200).json(_toOpenAiResponse(data));
    } catch (err) {
      console.error("anthropicProxy error:", err);
      res.status(500).json({ error: String(err && err.message ? err.message : err) });
    }
  }
);

/** OpenAI messages → { system, messages } da Anthropic. Agrupa tool_results. */
function _toAnthropicMessages(openaiMessages) {
  const systemParts = [];
  const out = [];

  for (const m of openaiMessages) {
    const role = m.role;
    if (role === "system") {
      if (m.content) systemParts.push(String(m.content));
      continue;
    }
    if (role === "tool") {
      // tool_result deve ir num turno 'user'. Agrupa com o anterior se possível.
      const block = {
        type: "tool_result",
        tool_use_id: m.tool_call_id,
        content: String(m.content ?? ""),
      };
      const last = out[out.length - 1];
      if (last && last.role === "user" && Array.isArray(last.content) &&
          last.content.every((b) => b.type === "tool_result")) {
        last.content.push(block);
      } else {
        out.push({ role: "user", content: [block] });
      }
      continue;
    }
    if (role === "assistant") {
      const content = [];
      if (m.content) content.push({ type: "text", text: String(m.content) });
      for (const tc of m.tool_calls || []) {
        let input = {};
        try {
          input = JSON.parse(tc.function?.arguments || "{}");
        } catch (_) {
          input = {};
        }
        content.push({ type: "tool_use", id: tc.id, name: tc.function?.name, input });
      }
      out.push({ role: "assistant", content: content.length ? content : [{ type: "text", text: "" }] });
      continue;
    }
    // user
    out.push({ role: "user", content: [{ type: "text", text: String(m.content ?? "") }] });
  }

  return { system: systemParts.join("\n\n"), messages: out };
}

/** OpenAI tools → tools da Anthropic. */
function _toAnthropicTools(openaiTools) {
  if (!Array.isArray(openaiTools) || openaiTools.length === 0) return null;
  return openaiTools.map((t) => ({
    name: t.function?.name,
    description: t.function?.description || "",
    input_schema: t.function?.parameters || { type: "object", properties: {} },
  }));
}

/** Resposta Anthropic → formato OpenAI (choices[0].message + tool_calls). */
function _toOpenAiResponse(data) {
  const blocks = data.content || [];
  let text = "";
  const toolCalls = [];
  for (const b of blocks) {
    if (b.type === "text") text += b.text;
    else if (b.type === "tool_use") {
      toolCalls.push({
        id: b.id,
        type: "function",
        function: { name: b.name, arguments: JSON.stringify(b.input || {}) },
      });
    }
  }
  const message = { role: "assistant", content: text || null };
  if (toolCalls.length) message.tool_calls = toolCalls;
  return {
    choices: [
      {
        message,
        finish_reason: data.stop_reason === "tool_use" ? "tool_calls" : "stop",
      },
    ],
    usage: data.usage,
  };
}
