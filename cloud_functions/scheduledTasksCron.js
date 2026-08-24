/**
 * scheduledTasksCron — Cloud Function AGENDADA (Gen 2) que executa as Tarefas
 * Agendadas no servidor, mesmo com o app fechado.
 * (`.specify/TAREFAS_AGENDADAS.md` §6/§8 — equivalente ao cron do Vercel.)
 *
 * Otimização de custo: este arquivo segue os SOPs de `.specify/CUSTO.md`.
 * A lógica sensível a custo vive em módulos PUROS/INJETÁVEIS, com testes
 * automatizados (`functions/test/`):
 *   - `lib/costGuards.js`  → read meter/circuit breaker (§6.8), recalibração
 *      temporal anti catch-up (§6.4), parse/score (puro, sem Firestore).
 *   - `lib/dataAccess.js`  → leitura escopada por tenant (§6.1), cache por
 *      execução (§6.2), time-bounding (§6.3), campo canônico (§6.6).
 *
 * Deploy:
 *   firebase deploy --only firestore:indexes        # ÍNDICES PRIMEIRO (§7/§11)
 *   firebase deploy --only functions:scheduledTasksCron
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } =
  require("firebase-admin/firestore");

const guards = require("./lib/costGuards");
const createDataAccess = require("./lib/dataAccess");

const {
  BRT_MS, makeReadMeter, advanceNextRun, parseDate, apptDate,
  quickScore, faltaRatios, belongsToClinic,
} = guards;

const AZURE_AI_KEY = defineSecret("AZURE_AI_KEY");
const SENDGRID_API_KEY = defineSecret("SENDGRID_API_KEY");

const AZURE_ENDPOINT =
  process.env.AZURE_AI_ENDPOINT ||
  "https://micro-mrfgtgfz-eastus2.services.ai.azure.com/models/chat/completions?api-version=2024-05-01-preview";
const MODEL = process.env.AZURE_AI_MODEL || "DeepSeek-V4-Flash";
const EMAIL_FROM = process.env.EMAIL_FROM || "time@agendaclinicas.com.br";
const EMAIL_FROM_NAME = process.env.EMAIL_FROM_NAME || "Agenda Clínica";

const LOCK_TTL_MS = 10 * 60 * 1000;
const HISTORY_LIMIT = 20;
const MAX_TASKS_PER_RUN = 10;

// ── Custo (CUSTO.md) ──
// §6.6 Campo de tenant: a base de PRODUÇÃO usa predominantemente `idclinica`
// (minúsculo, como reference) — confirmado pela auditoria dos índices existentes
// (49× idclinica vs 2× idClinica). Consultamos os dois (idclinica primeiro);
// `idClinica` cobre os poucos docs novos. A unificação num único campo (§6.6) é
// pré-requisito para QUALQUER agregação por campo único (ver taxa_absenteismo).
const TENANT_FIELDS = ["idclinica", "idClinica"];
// §6.8 teto de leituras por execução de agente (circuit breaker).
const READ_BUDGET = 1500;
// §6.2 paginação legítima das queries de agendamentos.
const AGENDAMENTOS_QUERY_LIMIT = 500;
// Janela de histórico (dias) usada para calcular ratios de falta no risco.
const HISTORY_WINDOW_DAYS = 180;

if (!getApps().length) initializeApp();
const db = getFirestore();

// Camada de acesso a dados escopada por tenant (injeção de db/Timestamp).
const {
  clinicRef, meteredGet, tenantFetch, listScoped, fetchAgendamentos,
} = createDataAccess({
  db, Timestamp,
  tenantFields: TENANT_FIELDS,
  agendamentosLimit: AGENDAMENTOS_QUERY_LIMIT,
});

exports.scheduledTasksCron = onSchedule(
  {
    // §11 hotfix: frequência reduzida de */5 → */15 (corta o multiplicador do
    // cron de 288 para 96 execuções/dia sem mudar a lógica das tarefas).
    schedule: "*/15 * * * *",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
    secrets: [AZURE_AI_KEY, SENDGRID_API_KEY],
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    await recoverStale();
    const due = await getDue(MAX_TASKS_PER_RUN);
    for (const task of due) {
      const claimed = await claimDue(task.id);
      if (!claimed) continue; // outro disparador ganhou o lock
      try {
        const record = await executeTask(claimed);
        await finishRun(claimed.id, record);
      } catch (e) {
        await finishRun(claimed.id, {
          runAt: Timestamp.now(),
          ok: false,
          summary: "Erro: " + (e && e.message ? e.message : e),
          toolsUsed: 0,
          durationMs: 0,
        });
      }
    }
    console.log(`scheduledTasksCron: ${due.length} candidata(s) avaliada(s).`);
  }
);

// ─────────────────────── Data + lock ───────────────────────

async function getDue(limit) {
  const now = Timestamp.now();
  const snap = await db
    .collection("tb_scheduled_tasks")
    .where("nextRunAt", "<=", now)
    .limit(50)
    .get();
  return snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((t) => t.status === "active")
    .slice(0, limit);
}

async function claimDue(id) {
  return db.runTransaction(async (tx) => {
    const ref = db.collection("tb_scheduled_tasks").doc(id);
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const t = snap.data();
    const now = Date.now();
    const lockedMs = t.lockedAt ? t.lockedAt.toDate().getTime() : 0;
    const lockAlive = lockedMs && now - lockedMs < LOCK_TTL_MS;
    const due = t.nextRunAt && t.nextRunAt.toDate().getTime() <= now;
    if (t.status !== "active" || lockAlive || !due) return null;

    const advanced = advanceNextRun(t);
    tx.update(ref, {
      status: "running",
      lockedAt: Timestamp.now(),
      nextRunAt: advanced ? Timestamp.fromDate(advanced) : null,
    });
    return { id, ...t };
  });
}

async function finishRun(id, record) {
  const ref = db.collection("tb_scheduled_tasks").doc(id);
  const snap = await ref.get();
  if (!snap.exists) return;
  const t = snap.data();
  const history = [record, ...(t.history || [])].slice(0, HISTORY_LIMIT);
  await ref.update({
    status: t.nextRunAt ? "active" : "completed",
    lockedAt: null,
    lastRunAt: record.runAt || Timestamp.now(),
    runCount: (t.runCount || 0) + 1,
    errorCount: (t.errorCount || 0) + (record.ok ? 0 : 1),
    history,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

async function recoverStale() {
  const snap = await db
    .collection("tb_scheduled_tasks")
    .where("status", "==", "running")
    .limit(50)
    .get();
  const now = Date.now();
  for (const d of snap.docs) {
    const t = d.data();
    const lockedMs = t.lockedAt ? t.lockedAt.toDate().getTime() : 0;
    if (lockedMs && now - lockedMs > LOCK_TTL_MS) {
      await d.ref.update({
        status: t.nextRunAt ? "active" : "completed",
        lockedAt: null,
        errorCount: (t.errorCount || 0) + 1,
      });
    }
  }
}

// ─────────────────────── Execução do agente ───────────────────────

const ACTION_SYSTEM =
  "Você é um executor autônomo de tarefas clínicas. Execute a instrução de ponta " +
  "a ponta usando as ferramentas, NUNCA peça confirmação, e ao final RESUMA os " +
  "números/resultados. Use nomes legíveis (nunca IDs).";
const REPORT_SYSTEM =
  "Você é um gerador de relatórios clínicos. Produza Markdown (Resumo Executivo, " +
  "tabelas, Recomendações) com 1 a 4 gráficos ```json-chart``` (bar/line/pie). " +
  "Use as ferramentas para dados reais e nomes legíveis.";

async function executeTask(task) {
  const started = Date.now();
  const clinicaId = task.clinicaId || task.idclinica || "";
  const isReport = task.kind === "report";
  const system = isReport ? REPORT_SYSTEM : ACTION_SYSTEM;
  let toolsUsed = 0;

  // §6.2 cache por execução + §6.8 read meter por execução.
  const cache = { agendamentos: new Map() };
  const meter = makeReadMeter(READ_BUDGET);

  const { content } = await runAgent({
    system: `${system}\nClínica do contexto (clinicaId): ${clinicaId}.`,
    prompt: task.prompt || task.titulo,
    clinicaId,
    cache,
    meter,
    onTool: () => { toolsUsed++; },
  });

  let reportId = null;
  if (isReport) {
    const ref = await db.collection("tb_scheduled_reports").add({
      titulo: task.titulo, markdown: content, conteudo: content,
      tipoRelatorio: "agendado", taskId: task.id, idclinica: clinicaId,
      origem: "cron", createdAt: FieldValue.serverTimestamp(),
    });
    reportId = ref.id;
  } else if (task.notifyEmail && String(task.notifyEmail).includes("@")) {
    await sendEmail(task.notifyEmail, `Tarefa agendada: ${task.titulo}`, content);
  }

  const ok = !content.startsWith("Erro");
  // §10 log estruturado por execução (alimenta a métrica firestore_reads_per_run).
  console.log(JSON.stringify({
    evt: "task_run", taskId: task.id, clinicaId, kind: task.kind || "action",
    reads: meter.total, toolsUsed, durationMs: Date.now() - started, ok,
  }));

  const summary = content.length > 600 ? content.slice(0, 600) + "…" : content;
  return {
    runAt: Timestamp.now(),
    ok,
    summary: summary || "Sem retorno do agente.",
    toolsUsed,
    reads: meter.total,
    durationMs: Date.now() - started,
    ...(reportId ? { reportId } : {}),
  };
}

async function runAgent({ system, prompt, clinicaId, onTool, cache, meter }) {
  const messages = [
    { role: "system", content: system },
    { role: "user", content: prompt },
  ];
  for (let round = 0; round < 6; round++) {
    const resp = await azureChat(messages, TOOLS);
    const msg = resp.choices && resp.choices[0] && resp.choices[0].message;
    if (!msg) return { content: "Erro: resposta vazia do modelo." };
    const calls = msg.tool_calls || [];
    if (calls.length === 0) return { content: msg.content || "" };

    messages.push({ role: "assistant", content: msg.content || null, tool_calls: calls });
    for (const c of calls) {
      onTool();
      let args = {};
      try { args = JSON.parse(c.function.arguments || "{}"); } catch (_) {}
      let result;
      try {
        result = await executeTool(c.function.name, args, clinicaId, cache, meter);
      } catch (e) {
        // READ_BUDGET_EXCEEDED (circuit breaker) propaga: aborta a execução.
        if (e && /READ_BUDGET_EXCEEDED/.test(e.message)) throw e;
        result = "Erro: " + (e && e.message ? e.message : e);
      }
      messages.push({ role: "tool", tool_call_id: c.id, content: result });
    }
  }
  return { content: "Erro: limite de rodadas atingido." };
}

async function azureChat(messages, tools) {
  const key = AZURE_AI_KEY.value();
  const r = await fetch(AZURE_ENDPOINT, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": key,
      Authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      model: MODEL, messages, tools, tool_choice: "auto", temperature: 0.4,
    }),
  });
  if (!r.ok) throw new Error(`Azure HTTP ${r.status}: ${(await r.text()).slice(0, 300)}`);
  return r.json();
}

// ─────────────────────── Ferramentas (Node, escopo de clínica) ───────────────────────

const TOOLS = [
  fn("consultar_colecao", "Consulta genérica de uma coleção Firestore (somente documentos da clínica do contexto).", {
    colecao: { type: "string" }, campo: { type: "string" }, valor: { type: "string" }, limite: { type: "integer" },
  }, ["colecao"]),
  fn("listar_agendamentos", "Lista agendamentos da clínica. Filtros opcionais por status e intervalo (yyyy-MM-dd).", {
    status: { type: "string" }, dataInicio: { type: "string" }, dataFim: { type: "string" }, limite: { type: "integer" },
  }),
  fn("listar_medicos", "Lista médicos da clínica (apenasAtivos opcional).", {
    apenasAtivos: { type: "boolean" },
  }),
  fn("enviar_email", "Envia um e-mail (SendGrid).", {
    para: { type: "string" }, assunto: { type: "string" }, corpo: { type: "string" },
  }, ["para", "assunto", "corpo"]),
  fn("enviar_whatsapp", "Envia WhatsApp (Z-API) usando a config da clínica.", {
    telefone: { type: "string" }, mensagem: { type: "string" },
  }, ["telefone", "mensagem"]),
  fn("listar_agendamentos_hoje", "Lista os agendamentos de hoje da clínica.", {
    medicoId: { type: "string" },
  }),
  fn("buscar_paciente", "Busca paciente na coleção users por cpf, uid ou nome.", {
    cpf: { type: "string" }, uid: { type: "string" }, nome: { type: "string" },
  }),
  fn("listar_usuarios", "Lista usuários (users) da clínica.", {
    apenasAtivos: { type: "boolean" }, limite: { type: "integer" },
  }),
  fn("taxa_absenteismo", "Taxa de absenteísmo da clínica por período (semanal/mensal/trimestral) com comparação ao período anterior.", {
    periodo: { type: "string", enum: ["semanal", "mensal", "trimestral"] },
  }),
  fn("listar_agendamentos_risco_alto", "Agendamentos futuros (próximos N dias) com risco de falta >= 50, ordenados por risco.", {
    dias: { type: "integer" },
  }),
  fn("historico_absenteismo_paciente", "Estatísticas de faltas de um paciente (por cpf).", {
    pacienteId: { type: "string" },
  }, ["pacienteId"]),
  fn("listar_eventos_overbooking", "Eventos de overbooking recentes da clínica.", {
    decisao: { type: "string" }, limite: { type: "integer" },
  }),
  fn("listar_realocacoes", "Realocações (queue_realoc) da clínica.", {
    status: { type: "string" }, limite: { type: "integer" },
  }),
  fn("listar_tickets", "Tickets de suporte da clínica.", {
    status: { type: "string" }, prioridade: { type: "string" }, limite: { type: "integer" },
  }),
  fn("listar_relatorios_ia", "Relatórios de IA (tb_relatorio_ia) da clínica.", {
    tipoRelatorio: { type: "string" }, limite: { type: "integer" },
  }),
  fn("listar_email_logs", "Log de e-mails enviados (email_logs) da clínica.", {
    tipo: { type: "string" }, limite: { type: "integer" },
  }),
  fn("listar_email_queue", "Fila de e-mails (email_queue) da clínica.", {
    status: { type: "string" }, limite: { type: "integer" },
  }),
  fn("atualizar_status_agendamento", "Atualiza o status de um agendamento da clínica.", {
    id: { type: "string" },
    status: { type: "string", enum: ["confirmado", "cancelado", "faltou", "realizado", "reagendado"] },
  }, ["id", "status"]),
  fn("criar_agendamento", "Cria um agendamento (status inicial confirmado) na clínica do contexto.", {
    medicoId: { type: "string" }, nomeMedico: { type: "string" },
    pacienteId: { type: "string" }, nomePaciente: { type: "string" },
    cpf: { type: "string" }, telefonePaciente: { type: "string" }, emailPaciente: { type: "string" },
    especialidade: { type: "string" }, modalidade: { type: "string" }, tipoConsulta: { type: "string" },
    dataConsulta: { type: "string", description: "ISO 8601 ou DD/MM/AAAA HH:MM (BRT)" },
  }, ["medicoId", "nomePaciente", "dataConsulta"]),
];

function fn(name, description, props, required = []) {
  return { type: "function", function: { name, description, parameters: { type: "object", properties: props, required } } };
}

function jsonSafe(v) {
  if (v == null) return v;
  if (v.toDate) return v.toDate().toISOString();
  if (v.path) return v.path;
  if (Array.isArray(v)) return v.map(jsonSafe);
  if (typeof v === "object") {
    const o = {}; for (const k of Object.keys(v)) o[k] = jsonSafe(v[k]); return o;
  }
  return v;
}

async function executeTool(name, args, clinicaId, cache, meter) {
  switch (name) {
    case "consultar_colecao": {
      // §6.1 escopado ao tenant na query (não full scan). Filtro campo/valor
      // entra na query quando indexável; senão cai p/ filtro em memória tenant-bound.
      const list = await tenantFetch(args.colecao, clinicaId, {
        limit: args.limite || 50,
        build: (q) =>
          args.campo && args.valor != null ? q.where(args.campo, "==", args.valor) : q,
        memFilter: (d) =>
          !args.campo || args.valor == null || String(d[args.campo]) === String(args.valor),
      }, meter);
      return JSON.stringify(list.slice(0, args.limite || 50).map(jsonSafe));
    }

    case "listar_agendamentos": {
      const di = args.dataInicio ? new Date(Date.parse(args.dataInicio)) : null;
      const dfim = args.dataFim ? new Date(Date.parse(args.dataFim) + 86400000) : null;
      // §6.3 janela vai para a query quando há intervalo.
      let list = await fetchAgendamentos(clinicaId, cache, meter, { since: di, until: dfim });
      if (args.status) list = list.filter((a) => a.status === args.status);
      list.sort((a, b) => ((apptDate(a) || 0) - (apptDate(b) || 0)));
      return JSON.stringify(list.slice(0, args.limite || 50).map(jsonSafe));
    }

    case "listar_medicos": {
      const list = await tenantFetch("tb_medicos", clinicaId, {
        limit: 200,
        build: (q) => (args.apenasAtivos ? q.where("status", "==", true) : q),
        memFilter: (m) => !args.apenasAtivos || m.status === true,
      }, meter);
      return JSON.stringify(list.map(jsonSafe));
    }

    case "enviar_email":
      await sendEmail(args.para, args.assunto, args.corpo, clinicaId);
      return JSON.stringify({ ok: true, para: args.para });
    case "enviar_whatsapp":
      return JSON.stringify(await sendWhatsapp(args.telefone, args.mensagem, clinicaId, meter));

    case "listar_agendamentos_hoje": {
      const now = new Date(Date.now() + BRT_MS);
      const y = now.getUTCFullYear(), mo = now.getUTCMonth(), d = now.getUTCDate();
      const start = new Date(Date.UTC(y, mo, d) - BRT_MS);
      const end = new Date(start.getTime() + 86400000);
      let list = await fetchAgendamentos(clinicaId, cache, meter, { since: start, until: end });
      if (args.medicoId) {
        list = list.filter((a) => (a.idMedico && a.idMedico.id) === args.medicoId);
      }
      list.sort((a, b) => (apptDate(a) || 0) - (apptDate(b) || 0));
      return JSON.stringify(list.map(jsonSafe));
    }

    case "buscar_paciente": {
      if (args.uid) {
        const s = await meteredGet(db.collection("users").doc(args.uid), meter);
        return JSON.stringify(s.exists ? [{ id: s.id, ...jsonSafe(s.data()) }] : []);
      }
      if (args.cpf) {
        const s = await meteredGet(db.collection("users").where("cpf", "==", args.cpf).limit(5), meter);
        return JSON.stringify(s.docs.map((d) => ({ id: d.id, ...jsonSafe(d.data()) })));
      }
      if (args.nome) {
        // §6.7 sem full scan global: busca por nome escopada ao tenant.
        const q = String(args.nome).toLowerCase();
        const list = await tenantFetch("users", clinicaId, {
          limit: 200,
          memFilter: (u) => String(u.display_name || "").toLowerCase().includes(q),
        }, meter);
        return JSON.stringify(
          list.filter((u) => String(u.display_name || "").toLowerCase().includes(q))
            .slice(0, 10).map(jsonSafe));
      }
      return "Erro: informe cpf, uid ou nome.";
    }

    case "listar_usuarios": {
      const list = await listScoped("users", clinicaId, { limit: args.limite || 50 }, meter);
      const filtered = args.apenasAtivos ? list.filter((u) => u.status === true) : list;
      return JSON.stringify(filtered.map(jsonSafe));
    }

    case "taxa_absenteismo": {
      const days = { semanal: 7, mensal: 30, trimestral: 90 }[args.periodo || "mensal"] || 30;
      const now = new Date();
      const winStart = new Date(now.getTime() - days * 86400000);
      const prevStart = new Date(now.getTime() - 2 * days * 86400000);
      // §6.3/§6.5: leitura ÚNICA da janela [prevStart, now] (deduplicada entre os
      // campos de tenant, limitada e cacheada) e contagem em memória. A agregação
      // count() por campo único fica ADIADA até a unificação do tenant (§6.6) —
      // com campos heterogêneos (idclinica/idClinica/clinicaId) ela
      // subcontaria silenciosamente.
      const all = await fetchAgendamentos(clinicaId, cache, meter, { since: prevStart, until: now });
      const inWin = (a, s, e) => {
        const t = apptDate(a) ? apptDate(a).getTime() : null;
        return t != null && t >= s.getTime() && t < e.getTime();
      };
      const cur = all.filter((a) => inWin(a, winStart, now));
      const prev = all.filter((a) => inWin(a, prevStart, winStart));
      const rate = (arr) => (arr.length === 0 ? 0 : (arr.filter((a) => a.status === "faltou").length / arr.length) * 100);
      const curRate = rate(cur), prevRate = rate(prev);
      return JSON.stringify({
        periodo: args.periodo || "mensal",
        total: cur.length,
        faltas: cur.filter((a) => a.status === "faltou").length,
        taxa: +curRate.toFixed(1),
        taxaPeriodoAnterior: +prevRate.toFixed(1),
        variacao: +(curRate - prevRate).toFixed(1),
        economiaEstimada: cur.filter((a) => a.status === "faltou").length * 150,
      });
    }

    case "listar_agendamentos_risco_alto": {
      const dias = args.dias || 7;
      const now = Date.now();
      // §6.3 uma única janela cobre histórico (p/ ratios) + futuro (candidatos).
      const since = new Date(now - HISTORY_WINDOW_DAYS * 86400000);
      const until = new Date(now + dias * 86400000);
      const all = await fetchAgendamentos(clinicaId, cache, meter, { since, until });
      const ratios = faltaRatios(all);
      const limit = now + dias * 86400000;
      const fut = all.filter((a) => {
        const t = apptDate(a) ? apptDate(a).getTime() : null;
        return t != null && t >= now && t <= limit;
      });
      const scored = fut.map((a) => {
        const r = ratios[a.cpf || ""];
        const ratio = r && r.total > 0 ? r.faltas / r.total : 0;
        return {
          agendamentoId: a.id, nomePaciente: a.nomePaciente, nomeMedico: a.nomeMedico,
          dataConsulta: apptDate(a) ? apptDate(a).toISOString() : null,
          riskScore: quickScore(a, ratio),
        };
      }).filter((x) => x.riskScore >= 50);
      scored.sort((a, b) => b.riskScore - a.riskScore);
      return JSON.stringify(scored.slice(0, 50));
    }

    case "historico_absenteismo_paciente": {
      const pid = String(args.pacienteId);
      // §6.1 query escopada ao tenant + cpf (não lê toda a coleção). Fallback
      // em memória cobre idPaciente quando o índice (idClinica,cpf) não existe.
      const hist = await tenantFetch("tb_agendamentos", clinicaId, {
        limit: 200,
        build: (q) => q.where("cpf", "==", pid),
        memFilter: (a) => a.cpf === pid || (a.idPaciente && a.idPaciente.id === pid),
      }, meter);
      const faltas = hist.filter((a) => a.status === "faltou").length;
      const realizados = hist.filter((a) => a.status === "realizado").length;
      const cancelados = hist.filter((a) => a.status === "cancelado").length;
      return JSON.stringify({
        pacienteId: pid, total: hist.length, faltas, realizados, cancelados,
        taxaFalta: hist.length ? +((faltas / hist.length) * 100).toFixed(1) : 0,
      });
    }

    case "listar_eventos_overbooking":
      return JSON.stringify((await listScoped("tb_overbooking_events", clinicaId, {
        filters: { decisao: args.decisao }, limit: args.limite || 50,
      }, meter)).map(jsonSafe));
    case "listar_realocacoes":
      return JSON.stringify((await listScoped("queue_realoc", clinicaId, {
        filters: { status: args.status }, limit: args.limite || 50,
      }, meter)).map(jsonSafe));
    case "listar_tickets":
      return JSON.stringify((await listScoped("tickets", clinicaId, {
        filters: { status: args.status, prioridade: args.prioridade }, limit: args.limite || 50,
      }, meter)).map(jsonSafe));
    case "listar_relatorios_ia":
      return JSON.stringify((await listScoped("tb_relatorio_ia", clinicaId, {
        filters: { tipoRelatorio: args.tipoRelatorio }, limit: args.limite || 50,
      }, meter)).map(jsonSafe));
    case "listar_email_logs":
      return JSON.stringify((await listScoped("email_logs", clinicaId, {
        filters: { tipo: args.tipo }, limit: args.limite || 50,
      }, meter)).map(jsonSafe));
    case "listar_email_queue":
      return JSON.stringify((await listScoped("email_queue", clinicaId, {
        filters: { status: args.status }, limit: args.limite || 50,
      }, meter)).map(jsonSafe));

    case "atualizar_status_agendamento": {
      const valid = ["confirmado", "cancelado", "faltou", "realizado", "reagendado"];
      if (!valid.includes(args.status)) return "Erro: status inválido.";
      const ref = db.collection("tb_agendamentos").doc(args.id);
      const snap = await meteredGet(ref, meter);
      if (!snap.exists) return "Erro: agendamento não encontrado.";
      // Trava multi-tenant: só altera se pertencer à clínica do contexto.
      if (!belongsToClinic(snap.data(), clinicaId)) {
        return "Erro: agendamento fora do escopo da clínica.";
      }
      await ref.update({ status: args.status, updatedAt: FieldValue.serverTimestamp() });
      return JSON.stringify({ ok: true, id: args.id, status: args.status });
    }

    case "criar_agendamento": {
      const when = parseDate(args.dataConsulta);
      if (!when) return "Erro: dataConsulta inválida (use ISO ou DD/MM/AAAA HH:MM).";
      const data = {
        status: "confirmado",
        idMedico: db.collection("tb_medicos").doc(String(args.medicoId)),
        // §6.6 grava AMBOS os campos de tenant (idclinica dominante + idClinica)
        // para que o doc seja visível a todas as queries/índices existentes
        // enquanto a base não está unificada. Após a migração, manter só um.
        idClinica: clinicRef(clinicaId),
        idclinica: clinicRef(clinicaId),
        nomeMedico: args.nomeMedico || "",
        nomePaciente: args.nomePaciente,
        cpf: args.cpf || "",
        telefonePaciente: args.telefonePaciente || "",
        emailPaciente: args.emailPaciente || "",
        especialidade: args.especialidade || "",
        modalidade: args.modalidade || "Presencial",
        tipoConsulta: args.tipoConsulta || "Consulta",
        dataConsulta: Timestamp.fromDate(when),
        origem: "cron",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (args.pacienteId) data.idPaciente = db.collection("users").doc(String(args.pacienteId));
      const ref = await db.collection("tb_agendamentos").add(data);
      return JSON.stringify({ ok: true, id: ref.id, status: "confirmado" });
    }

    default:
      return "Erro: ferramenta desconhecida: " + name;
  }
}

async function sendEmail(to, subject, body, clinicaId) {
  const html = `<div style="font-family:Arial,sans-serif;font-size:14px">${String(body || "").replace(/\n/g, "<br>")}</div>`;
  const r = await fetch("https://api.sendgrid.com/v3/mail/send", {
    method: "POST",
    headers: { Authorization: `Bearer ${SENDGRID_API_KEY.value()}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      personalizations: [{ to: [{ email: to }] }],
      from: { email: EMAIL_FROM, name: EMAIL_FROM_NAME },
      subject: subject || "Mensagem da clínica",
      content: [{ type: "text/html", value: html }],
    }),
  });
  await db.collection("email_logs").add({
    para: to, assunto: subject, tipo: "tarefa", status: r.status === 202 ? "sent" : "failed",
    idclinica: clinicaId || null, origem: "cron", createdAt: FieldValue.serverTimestamp(),
  });
  if (r.status !== 202) throw new Error(`SendGrid HTTP ${r.status}`);
}

async function sendWhatsapp(phone, message, clinicaId, meter) {
  let cfgSnap = await meteredGet(db.collection("tb_config_whatsapp").where("idclinica", "==", clinicRef(clinicaId)).limit(5), meter);
  if (cfgSnap.empty) cfgSnap = await meteredGet(db.collection("tb_config_whatsapp").where("idclinica", "==", clinicaId).limit(5), meter);
  if (cfgSnap.empty) return { ok: false, erro: "Sem config de WhatsApp para a clínica." };
  const cfg = (cfgSnap.docs.find((d) => d.data().active === 1) || cfgSnap.docs[0]).data();
  const url = `https://api.z-api.io/instances/${cfg.intanceId}/token/${cfg.token}/send-text`;
  const r = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Client-Token": cfg.tokenCliente || "" },
    body: JSON.stringify({ phone: String(phone).replace(/\D/g, ""), message }),
  });
  await db.collection("tb_conversas").add({
    telefone: phone, mensagem: message, tipo: "texto", status: r.ok ? "enviado" : "falhou",
    idclinica: clinicaId, origem: "cron", createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: r.ok };
}
