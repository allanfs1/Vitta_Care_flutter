/**
 * analyzeDocument — Cloud Function (Gen 2, HTTPS) para OCR via Azure Document Intelligence.
 *
 * Recebe um arquivo em base64 do app Flutter e chama o modelo `prebuilt-read`
 * do Azure Document Intelligence. A chave fica SOMENTE no servidor (secret do
 * Firebase); nunca é exposta ao cliente.
 *
 * Contrato de entrada (POST, JSON):
 *   {
 *     filename:      string,   // ex.: "laudo.pdf"
 *     mime:          string,   // ex.: "application/pdf"
 *     contentBase64: string    // bytes do arquivo em base64
 *   }
 *
 * Contrato de saída (200 OK, JSON):
 *   { text: string }           // texto extraído pelo OCR
 *
 * ─── Instruções de deploy ───────────────────────────────────────────────────
 *
 * Pré-requisitos:
 *   - Firebase CLI instalado: npm i -g firebase-tools
 *   - Projeto Firebase: agendaclinica-457713
 *   - Recurso Azure Document Intelligence criado (prebuilt-read disponível)
 *
 * 1. Copie este arquivo para a pasta `functions/` do seu projeto Firebase
 *    (ou importe-o no index.js com `require('./analyzeDocument')`).
 *
 * 2. Configure o secret com a chave do Azure Document Intelligence:
 *      firebase functions:secrets:set AZURE_DOCINTEL_KEY
 *      # Cole a chave quando solicitado (disponível no portal Azure →
 *      # Document Intelligence → Keys and Endpoint).
 *
 * 3. (Opcional) Endpoint do recurso Azure — o default já aponta para o do
 *    projeto (AI_chaves.md §1.5):
 *      https://micro-mpfiisv0-eastus2.cognitiveservices.azure.com
 *    Para outro recurso, defina a env var AZURE_DOCINTEL_ENDPOINT na função.
 *
 * 4. Faça o deploy:
 *      firebase deploy --only functions:analyzeDocument
 *
 * A URL pública ficará:
 *   https://us-central1-agendaclinica-457713.cloudfunctions.net/analyzeDocument
 * (mesma URL usada por DocumentService.defaultProxyUrl no Flutter).
 * ────────────────────────────────────────────────────────────────────────────
 */

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");

// Secret que contém a chave do Azure Document Intelligence.
// Nunca aparece em logs, variáveis de ambiente públicas ou no cliente.
const AZURE_DOCINTEL_KEY = defineSecret("AZURE_DOCINTEL_KEY");

// Origens permitidas para CORS. Em produção, restrinja ao seu domínio.
const ALLOWED_ORIGINS = "*";

// Intervalo entre tentativas de polling do resultado assíncrono (ms).
const POLL_INTERVAL_MS = 1000;

// Máximo de tentativas de polling (~15 s de espera total).
const MAX_POLL_ATTEMPTS = 15;

exports.analyzeDocument = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [AZURE_DOCINTEL_KEY],
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (req, res) => {
    // ── CORS manual (reforço além do cors:true) ─────────────────────────────
    res.set("Access-Control-Allow-Origin", ALLOWED_ORIGINS);
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ error: "Método não permitido. Use POST." });
      return;
    }

    // ── Validação do body ───────────────────────────────────────────────────
    const body = req.body || {};
    const { filename, mime, contentBase64 } = body;

    if (!filename || typeof filename !== "string") {
      res.status(400).json({ error: "Campo 'filename' é obrigatório." });
      return;
    }
    if (!contentBase64 || typeof contentBase64 !== "string") {
      res.status(400).json({ error: "Campo 'contentBase64' é obrigatório." });
      return;
    }

    // ── Configuração do endpoint Azure ──────────────────────────────────────
    const endpoint =
      process.env.AZURE_DOCINTEL_ENDPOINT ||
      // AI_chaves.md §1.5 (AZURE_COGNITIVE_ENDPOINT).
      "https://micro-mpfiisv0-eastus2.cognitiveservices.azure.com";

    // API assíncrona do Azure Document Intelligence 2024-11-30.
    const analyzeUrl = `${endpoint}/documentintelligence/documentModels/prebuilt-read:analyze?api-version=2024-11-30`;

    const apiKey = AZURE_DOCINTEL_KEY.value();

    try {
      // ── 1. Inicia a análise (POST assíncrono) ───────────────────────────────
      const analyzeResponse = await fetch(analyzeUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Ocp-Apim-Subscription-Key": apiKey,
        },
        body: JSON.stringify({ base64Source: contentBase64 }),
      });

      if (!analyzeResponse.ok) {
        const errText = await analyzeResponse.text();
        console.error("analyzeDocument: Azure analyze error", analyzeResponse.status, errText);

        if (analyzeResponse.status === 401 || analyzeResponse.status === 403) {
          res.status(502).json({
            error: "Chave do Azure Document Intelligence inválida ou expirada.",
          });
          return;
        }
        if (analyzeResponse.status === 429) {
          res.status(429).json({
            error: "Limite de requisições do Azure Document Intelligence atingido.",
          });
          return;
        }
        res.status(502).json({
          error: `Azure Document Intelligence retornou HTTP ${analyzeResponse.status}.`,
        });
        return;
      }

      // O header Operation-Location contém a URL de polling do resultado.
      const operationLocation = analyzeResponse.headers.get("Operation-Location");
      if (!operationLocation) {
        res.status(502).json({
          error: "Azure não retornou 'Operation-Location'. Verifique o endpoint.",
        });
        return;
      }

      // ── 2. Polling até o resultado ficar disponível ─────────────────────────
      let attempts = 0;
      let resultContent = null;

      while (attempts < MAX_POLL_ATTEMPTS) {
        // Aguarda antes da próxima tentativa.
        await _sleep(POLL_INTERVAL_MS);
        attempts++;

        const pollResponse = await fetch(operationLocation, {
          headers: { "Ocp-Apim-Subscription-Key": apiKey },
        });

        if (!pollResponse.ok) {
          console.error(
            "analyzeDocument: polling error",
            pollResponse.status,
            await pollResponse.text()
          );
          res.status(502).json({
            error: `Erro ao verificar resultado do OCR (HTTP ${pollResponse.status}).`,
          });
          return;
        }

        const pollData = await pollResponse.json();
        const status = pollData.status;

        if (status === "succeeded") {
          // Extrai o texto completo do resultado.
          resultContent =
            pollData.analyzeResult?.content ??
            pollData.analyzeResult?.pages
              ?.flatMap((p) => p.lines?.map((l) => l.content) ?? [])
              .join("\n") ??
            "";
          break;
        }

        if (status === "failed") {
          const errMsg =
            pollData.error?.message || "Falha no processamento do documento.";
          console.error("analyzeDocument: Azure analysis failed:", errMsg);
          res.status(502).json({ error: errMsg });
          return;
        }

        // status === "running" | "notStarted" → continua polling
      }

      // Esgotou as tentativas sem resultado.
      if (resultContent === null) {
        res.status(504).json({
          error:
            "Tempo de espera pelo OCR excedido. O arquivo pode ser muito grande ou complexo.",
        });
        return;
      }

      // ── 3. Retorna o texto extraído ─────────────────────────────────────────
      res.status(200).json({ text: resultContent });
    } catch (err) {
      console.error("analyzeDocument: unexpected error:", err);
      res.status(500).json({
        error: "Erro interno no serviço de OCR. Tente novamente mais tarde.",
      });
    }
  }
);

// ── Utilitário ────────────────────────────────────────────────────────────────
function _sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
