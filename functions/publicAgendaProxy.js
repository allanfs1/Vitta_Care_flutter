/**
 * publicAgendaProxy / publicAgendaSolicitar — backend da agenda **pública** do
 * médico (`/agenda-publica/:id`, link/QR Code compartilhado sem login).
 *
 * ─── Por que isto existe ─────────────────────────────────────────────────────
 * A tela pública não pode ler `tb_agendamentos` direto pelo SDK do cliente: o
 * Firestore não filtra campos — ou o documento é legível, ou não é — e o
 * documento tem `nomePaciente`, `cpf`, `telefonePaciente`, `emailPaciente` e
 * `motivoConsulta` de cada paciente do médico. Foi exatamente isso que vazou
 * por leitura anônima em 2026-08-26 (ver `EMERGENCIA-firestore.rules` e
 * `.specify/ATENCAO.md`, 🔴 Crítico).
 *
 * Este arquivo só cuida da camada HTTP (parse de query/body, status code,
 * CORS). A lógica de verdade — o que cada função lê/valida/grava — mora em
 * `lib/publicAgenda.js`, isolada do HTTP de propósito: é o que permite testar
 * as regras (vaga, duplicidade, nome/telefone) com um Firestore falso, sem
 * subir uma função HTTP de verdade (ver `test/publicAgenda.test.js`).
 *
 *   publicAgendaProxy (GET)       → perfil do médico + config de horário +
 *                                    lista de `startMs` ocupados (sem nome,
 *                                    CPF, telefone ou motivo de ninguém).
 *   publicAgendaSolicitar (POST)  → cria a consulta como PRÉ-agendada
 *                                    (`status: 'pre-agendado'`), validando no
 *                                    servidor.
 *
 * Com isto, `tb_agendamentos` pode continuar **fechado** (leitura e escrita)
 * para quem não está logado no `firestore.rules` — nada aqui depende de abrir
 * uma exceção nas regras.
 *
 * ─── Deploy ──────────────────────────────────────────────────────────────────
 *   firebase deploy --only functions:publicAgendaProxy,functions:publicAgendaSolicitar
 *
 * URLs:
 *   https://us-central1-agendaclinica-457713.cloudfunctions.net/publicAgendaProxy
 *   https://us-central1-agendaclinica-457713.cloudfunctions.net/publicAgendaSolicitar
 */

const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

const createPublicAgenda = require("./lib/publicAgenda");

if (!getApps().length) initializeApp();
const db = getFirestore();
const agenda = createPublicAgenda({ db, Timestamp });

const ALLOWED_ORIGINS = "*";

/** Status HTTP por código de erro de `solicitar` — ver `lib/publicAgenda.js`. */
const STATUS_POR_ERRO = {
  parametros_invalidos: 400,
  horario_passado: 400,
  nome_invalido: 400,
  telefone_invalido: 400,
  email_invalido: 400,
  medico_nao_encontrado: 404,
  medico_inativo: 409,
  sem_vaga: 409,
  duplicado_no_dia: 409,
  limite_futuras: 409,
};

function cors(res, methods) {
  res.set("Access-Control-Allow-Origin", ALLOWED_ORIGINS);
  res.set("Access-Control-Allow-Methods", methods);
  res.set("Access-Control-Allow-Headers", "Content-Type");
}

/**
 * GET /publicAgendaProxy?medicoId=...&inicioMs=...&fimMs=...
 *
 * [inicioMs, fimMs) é o dia local do visitante, em epoch ms — o mesmo cálculo
 * que o cliente já faz para o próprio `_buildSlots` (`_startOfDay(_date)` até
 * `_startOfDay(_date) + 1 dia`), garantindo que "o mesmo dia" aqui e lá seja
 * exatamente o mesmo instante, sem depender de qual fuso o servidor roda.
 */
exports.publicAgendaProxy = onRequest(
  { region: "us-central1", cors: true, timeoutSeconds: 30, memory: "256MiB" },
  async (req, res) => {
    cors(res, "GET, OPTIONS");
    if (req.method === "OPTIONS") return void res.status(204).send("");
    if (req.method !== "GET") return void res.status(405).json({ error: "Use GET." });

    const medicoId = (req.query.medicoId || "").toString().trim();
    const inicioMs = Number(req.query.inicioMs);
    const fimMs = Number(req.query.fimMs);
    if (!medicoId || !Number.isFinite(inicioMs) || !Number.isFinite(fimMs) || fimMs <= inicioMs) {
      return void res.status(400).json({ error: "Parâmetros inválidos." });
    }

    try {
      const result = await agenda.getAgenda({ medicoId, inicioMs, fimMs });
      res.status(200).json(result);
    } catch (err) {
      console.error("publicAgendaProxy", err);
      res.status(500).json({ error: "Falha ao carregar a agenda." });
    }
  }
);

/**
 * POST /publicAgendaSolicitar
 * Body: { medicoId, startMs, diaInicioMs, diaFimMs, duracao, nome, telefone, email? }
 *
 * Sempre grava como `pre-agendado` — a clínica confirma depois. Todas as
 * validações são refeitas em `lib/publicAgenda.js`: o que o app já valida no
 * cliente é só UX, não a garantia — quem chamar esta rota direto tem que
 * passar pelas mesmas regras.
 */
exports.publicAgendaSolicitar = onRequest(
  { region: "us-central1", cors: true, timeoutSeconds: 30, memory: "256MiB" },
  async (req, res) => {
    cors(res, "POST, OPTIONS");
    if (req.method === "OPTIONS") return void res.status(204).send("");
    if (req.method !== "POST") return void res.status(405).json({ ok: false, error: "method_not_allowed" });

    const body = req.body || {};
    try {
      const result = await agenda.solicitar({
        medicoId: (body.medicoId || "").toString().trim(),
        startMs: Number(body.startMs),
        diaInicioMs: Number(body.diaInicioMs),
        diaFimMs: Number(body.diaFimMs),
        duracao: body.duracao,
        nome: body.nome,
        telefone: body.telefone,
        email: body.email,
      });
      const status = result.ok ? 200 : (STATUS_POR_ERRO[result.error] || 400);
      res.status(status).json(result);
    } catch (err) {
      console.error("publicAgendaSolicitar", err);
      res.status(500).json({ ok: false, error: "falha_interna" });
    }
  }
);
