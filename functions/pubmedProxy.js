/**
 * pubmedProxy — Cloud Function (Gen 2, HTTPS) que faz proxy do NCBI E-utilities.
 *
 * O app Flutter chama ESTA função; ela repassa ao PubMed com a API key (quando
 * houver) que vive somente no servidor, aplica o limitador de taxa global e
 * bloqueia dado pessoal antes de qualquer saída de rede.
 *
 * Toda a lógica está em `lib/pubmed.js` (fábrica testável); aqui fica só a
 * camada HTTP: autenticação, parse, CORS e status code.
 *
 * ─── POR QUE ESTA FUNÇÃO EXIGE LOGIN (e as outras cinco não) ─────────────────
 * `chatProxy`, `emailProxy`, `whatsappProxy`, `analyzeDocument` e
 * `anthropicProxy` aceitam qualquer chamador — isso está registrado como risco
 * aberto em `.specify/ATENCAO.md`, e não se repete aqui.
 *
 * No caso do NCBI há um agravante que não existe nas outras: **o limite do NCBI
 * é por IP**, e o IP de saída é compartilhado por todo o projeto. Um proxy
 * aberto não custaria só cota — um único abusador faria o NCBI barrar o
 * tráfego, e a pesquisa de evidências pararia para **todas** as clínicas ao
 * mesmo tempo. Autenticar aqui é requisito de funcionamento, não só de higiene.
 *
 * Deploy:
 *   firebase functions:secrets:set NCBI_API_KEY      # opcional (10 req/s)
 *   firebase deploy --only functions:pubmedProxy
 *
 * Configuração obrigatória (variáveis de ambiente da function):
 *   NCBI_TOOL   — nome do software, sem espaços (ex.: vitta_app)
 *   NCBI_EMAIL  — e-mail do responsável técnico
 * Sem as duas a função responde 503: o NCBI exige ambas em toda chamada.
 */

const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

const createPubmed = require("./lib/pubmed");

const NCBI_API_KEY = defineSecret("NCBI_API_KEY");

if (!getApps().length) initializeApp();

/** Ações expostas. Allow-list: o cliente não escolhe endpoint arbitrário. */
const ACOES = new Set(["buscar", "resumos", "abstracts", "relacionados", "corrigir"]);

exports.pubmedProxy = onRequest(
  {
    region: "us-central1",
    cors: true,
    secrets: [NCBI_API_KEY],
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    if (req.method === "OPTIONS") return void res.status(204).send("");
    if (req.method !== "POST") return void res.status(405).json({ error: "Use POST." });

    // ── Autenticação ────────────────────────────────────────────────────
    const header = req.get("Authorization") || "";
    const token = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
    if (!token) {
      return void res.status(401).json({
        error: "Autenticação obrigatória.",
        codigo: "UNAUTHENTICATED",
      });
    }
    try {
      await getAuth().verifyIdToken(token);
    } catch (_) {
      // A causa exata (expirado, malformado, revogado) não volta ao cliente:
      // distinguir os casos ajuda mais quem sonda do que quem depura.
      return void res.status(401).json({
        error: "Sessão inválida ou expirada.",
        codigo: "UNAUTHENTICATED",
      });
    }

    const body = req.body || {};
    const acao = String(body.acao || "").trim();
    if (!ACOES.has(acao)) {
      return void res.status(400).json({
        error: `Ação inválida. Use uma de: ${[...ACOES].join(", ")}.`,
        codigo: "INVALID_QUERY",
      });
    }

    const api = createPubmed({
      db: getFirestore(),
      Timestamp,
      config: {
        baseUrl: process.env.NCBI_BASE_URL,
        tool: process.env.NCBI_TOOL,
        email: process.env.NCBI_EMAIL,
        apiKey: NCBI_API_KEY.value() || "",
      },
    });

    try {
      let dados;
      switch (acao) {
        case "buscar":
          dados = await api.esearch({
            term: body.termo,
            retmax: body.limite,
            retstart: body.offset,
            sort: body.ordem === "data" ? "pub_date" : "relevance",
          });
          break;
        case "resumos":
          dados = await api.esummary({ pmids: body.pmids });
          break;
        case "abstracts":
          dados = await api.efetchAbstracts({ pmids: body.pmids });
          break;
        case "relacionados":
          dados = await api.elink({ pmid: body.pmid, retmax: body.limite });
          break;
        case "corrigir":
          dados = await api.espell({ term: body.termo });
          break;
      }
      res.status(200).json({ ok: true, acao, ...dados });
    } catch (e) {
      const status = Number(e && e.status) || 502;
      const codigo = (e && e.codigo) || "UPSTREAM_ERROR";
      // PHI bloqueado não é falha do sistema — é a guarda funcionando. Fica em
      // `warn` para não poluir o alerta de erro com comportamento esperado.
      const nivel = codigo === "PHI_BLOCKED" ? console.warn : console.error;
      nivel(`pubmedProxy[${acao}] ${codigo}:`, e && e.message);
      res.status(status).json({
        error: (e && e.message) || "Falha ao consultar o PubMed.",
        codigo,
      });
    }
  },
);
