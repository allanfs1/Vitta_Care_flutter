/**
 * vigiaCron — o ciclo diário do **Vigia** no servidor.
 *
 * Uma vez por dia lê a operação de cada clínica, escreve um relatório em
 * `tb_relatorio_ia` (tela /relatorios) e propõe rotinas de prevenção em
 * `tb_scheduled_tasks` com `status: "suggested"` (tela /tarefas-agendadas).
 *
 * **O Vigia nunca executa nada.** Uma rotina proposta nasce sem `nextRunAt` e
 * com status que nenhum runner aceita — nem este cron (`status === "active"`
 * em scheduledTasksCron), nem o cliente Dart (`getDue`/`claimDue`). Ligar uma
 * rotina exige uma pessoa aprovando na tela, e só a aprovação calcula o
 * primeiro horário de execução.
 *
 * Relação com o cliente: `lib/features/ia/vigia/` faz o mesmo ciclo quando
 * alguém abre o app. Os dois compartilham a trava diária em `tb_vigia_ciclos`
 * (doc `{clinicaId}_{YYYY-MM-DD}`), então rodam no máximo uma vez por dia por
 * clínica, não importa quem chegou primeiro.
 *
 * Deploy:
 *   firebase deploy --only functions:vigiaCron
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

const cron = require("./scheduledTasksCron");

const AZURE_AI_KEY = defineSecret("AZURE_AI_KEY");

if (!getApps().length) initializeApp();
const db = getFirestore();

/** Teto de rotinas propostas por ciclo — rotina demais vira ruído ignorado. */
const TETO_ROTINAS = 3;
/** Confiança mínima para uma proposta chegar ao gestor. */
const CONFIANCA_MINIMA = 0.6;
/** Clínicas processadas por execução, para caber no timeout. */
const MAX_CLINICAS = 8;

exports.vigiaCron = onSchedule(
  {
    // Uma vez por dia, cedo, antes do expediente começar.
    schedule: "0 6 * * *",
    timeZone: "America/Sao_Paulo",
    region: "us-central1",
    secrets: [AZURE_AI_KEY],
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const hoje = diaIso(new Date());
    const clinicas = await clinicasAtivas();
    let ok = 0;

    for (const clinicaId of clinicas.slice(0, MAX_CLINICAS)) {
      try {
        const r = await rodarCiclo(clinicaId, hoje);
        if (r.executou) ok++;
        console.log(`vigiaCron[${clinicaId}]: ${r.motivo}`);
      } catch (e) {
        console.error(`vigiaCron[${clinicaId}] falhou:`, e && e.message);
      }
    }
    console.log(`vigiaCron: ${ok}/${clinicas.length} clínica(s) analisada(s).`);
  }
);

// ─────────────────────── Ciclo ───────────────────────

async function rodarCiclo(clinicaId, hoje) {
  const refCiclo = db.collection("tb_vigia_ciclos").doc(`${clinicaId}_${hoje}`);

  // Trava compartilhada com o cliente: quem chegar primeiro faz o ciclo.
  const jaFoi = await db.runTransaction(async (tx) => {
    const snap = await tx.get(refCiclo);
    if (snap.exists && snap.data().executou === true) return true;
    tx.set(refCiclo, { iniciadoEm: FieldValue.serverTimestamp(), origem: "cron" },
      { merge: true });
    return false;
  });
  if (jaFoi) return { executou: false, motivo: "ciclo de hoje já rodou" };

  const inicio = Date.now();
  const vigentes = await tarefasDaClinica(clinicaId);

  const meter = cron._makeReadMeter();
  const cache = { agendamentos: new Map() };
  const { content } = await cron._runAgent({
    system: sistema(),
    prompt: contexto({
      hoje,
      clinicaId,
      cerebro: await resumoCerebro(clinicaId),
      vigentes,
    }),
    clinicaId,
    cache,
    meter,
    onTool: () => {},
  });

  const json = extrairJson(content);
  if (!json) throw new Error("o modelo não devolveu JSON utilizável");

  let relatorioId = null;
  if (json.relatorio && json.relatorio.titulo && json.relatorio.corpo) {
    const ref = await db.collection("tb_relatorio_ia").add({
      titulo: String(json.relatorio.titulo),
      markdown: String(json.relatorio.corpo),
      conteudo: String(json.relatorio.corpo),
      periodo: String(json.relatorio.periodo || "Últimas 24 horas"),
      metricas: normalizarMetricas(json.relatorio.metricas),
      tipoRelatorio: "ia",
      idclinica: clinicaId,
      origem: "vigia",
      createdAt: FieldValue.serverTimestamp(),
    });
    relatorioId = ref.id;
  }

  const { criadas, descartadas } = await gravarSugestoes({
    rotinas: json.rotinas,
    clinicaId,
    vigentes,
    relatorioId,
  });

  const resultado = {
    executou: true,
    motivo: `relatório=${relatorioId ? "sim" : "não"} · ` +
      `${criadas} sugerida(s) · ${descartadas} descartada(s)`,
    relatorioId,
    sugestoesCriadas: criadas,
    sugestoesDescartadas: descartadas,
    duracaoMs: Date.now() - inicio,
    origem: "cron",
    em: FieldValue.serverTimestamp(),
  };
  await refCiclo.set(resultado, { merge: true });
  return resultado;
}

async function gravarSugestoes({ rotinas, clinicaId, vigentes, relatorioId }) {
  let criadas = 0;
  let descartadas = 0;
  if (!Array.isArray(rotinas)) return { criadas, descartadas };

  const jaExistem = new Set(
    vigentes.filter((t) => t.status !== "rejected").map((t) => chaveDedupe(t.titulo, t.kind))
  );
  const recusadas = new Set(
    vigentes.filter((t) => t.status === "rejected").map((t) => chaveDedupe(t.titulo, t.kind))
  );

  for (const bruta of rotinas) {
    if (criadas >= TETO_ROTINAS) { descartadas++; continue; }
    const p = normalizarRotina(bruta);
    if (!p) { descartadas++; continue; }

    const chave = chaveDedupe(p.titulo, p.kind);
    if (p.confianca < CONFIANCA_MINIMA || jaExistem.has(chave) || recusadas.has(chave)) {
      descartadas++;
      continue;
    }

    await db.collection("tb_scheduled_tasks").add({
      titulo: p.titulo,
      descricao: p.descricao,
      prompt: p.prompt,
      kind: p.kind,
      schedule: p.schedule,
      status: "suggested",
      // Sem nextRunAt: segunda trava, independente do filtro de status.
      nextRunAt: null,
      runCount: 0,
      errorCount: 0,
      history: [],
      clinicaId,
      origem: "ia",
      problemaDetectado: p.problemaDetectado,
      impactoEstimado: p.impactoEstimado,
      evidencias: p.evidencias,
      confianca: p.confianca,
      relatorioId: relatorioId || null,
      sugeridaEm: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
      createdBy: "ia",
    });
    jaExistem.add(chave);
    criadas++;
  }
  return { criadas, descartadas };
}

// ─────────────────────── Normalização defensiva ───────────────────────
//
// Mesma postura do cliente: proposta incompleta é descartada, não exibida pela
// metade. O gestor precisa poder confiar que todo card tem o que decidir.

const TIPOS_SCHEDULE = new Set(["once", "interval", "daily", "weekly", "monthly"]);

function normalizarRotina(b) {
  if (!b || typeof b !== "object") return null;
  const titulo = String(b.titulo || "").trim();
  const prompt = String(b.prompt || "").trim();
  if (!titulo || !prompt) return null;

  const sched = normalizarSchedule(b.schedule);
  if (!sched) return null;

  const conf = typeof b.confianca === "number" ? b.confianca : 0.5;
  return {
    titulo,
    prompt,
    descricao: String(b.descricao || "").trim(),
    kind: b.kind === "report" ? "report" : "action",
    schedule: sched,
    problemaDetectado: String(b.problemaDetectado || "").trim(),
    impactoEstimado: String(b.impactoEstimado || "").trim(),
    evidencias: Array.isArray(b.evidencias)
      ? b.evidencias.map((e) => String(e).trim()).filter(Boolean)
      : [],
    confianca: Math.max(0, Math.min(1, conf)),
  };
}

function normalizarSchedule(raw) {
  if (!raw || typeof raw !== "object") return null;
  const type = String(raw.type || "");
  if (!TIPOS_SCHEDULE.has(type)) return null;

  const out = { type };
  const time = String(raw.time || "");
  if (/^\d{2}:\d{2}$/.test(time)) out.time = time;

  if (type === "daily" && !out.time) return null;
  if (type === "weekly") {
    const dias = Array.isArray(raw.weekdays)
      ? raw.weekdays.filter((d) => Number.isInteger(d) && d >= 0 && d <= 6)
      : [];
    if (!dias.length || !out.time) return null;
    out.weekdays = dias;
  }
  if (type === "monthly") {
    const dia = Number(raw.dayOfMonth);
    if (!Number.isInteger(dia) || dia < 1 || dia > 31 || !out.time) return null;
    out.dayOfMonth = dia;
  }
  if (type === "interval") {
    const min = Number(raw.intervalMinutes);
    if (!Number.isInteger(min) || min < 5) return null;
    out.intervalMinutes = min;
  }
  return out;
}

function normalizarMetricas(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((m) => ({
      label: String((m && (m.label || m.rotulo)) || "").trim(),
      valor: String((m && (m.valor || m.value)) || "").trim(),
    }))
    .filter((m) => m.label && m.valor);
}

/** Mesma normalização do cliente (`ScheduledTask.chaveDedupeDe`). */
function chaveDedupe(titulo, kind) {
  const base = String(titulo || "")
    .toLowerCase()
    .replace(/^\[[^\]]*\]\s*/, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return `${kind}|${base}`;
}

function extrairJson(bruto) {
  let t = String(bruto || "").trim();
  const cerca = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (cerca) t = cerca[1].trim();
  const i = t.indexOf("{");
  const f = t.lastIndexOf("}");
  if (i < 0 || f <= i) return null;
  try {
    const o = JSON.parse(t.slice(i, f + 1));
    return o && typeof o === "object" ? o : null;
  } catch (_) {
    return null;
  }
}

// ─────────────────────── Leituras de contexto ───────────────────────

async function clinicasAtivas() {
  const snap = await db.collection("tb_clinica").limit(50).get();
  return snap.docs.filter((d) => d.data().deleted !== true).map((d) => d.id);
}

async function tarefasDaClinica(clinicaId) {
  const snap = await db.collection("tb_scheduled_tasks")
    .where("clinicaId", "==", clinicaId).limit(200).get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/** Retrato do Cérebro: contagens e as notas mais referenciadas. */
async function resumoCerebro(clinicaId) {
  const snap = await db.collection("tb_cerebro_notas")
    .where("clinicaId", "==", clinicaId).limit(400).get();
  const notas = snap.docs.map((d) => d.data()).filter((n) => !n.deletedAt);
  if (!notas.length) return "Cérebro vazio — nenhuma nota registrada.";

  const hubs = notas
    .filter((n) => n.metrics && n.metrics.inDegree > 0)
    .sort((a, b) => (b.metrics.inDegree || 0) - (a.metrics.inDegree || 0))
    .slice(0, 8)
    .map((n) => `${n.path} (${n.metrics.inDegree} links)`);

  return [
    `${notas.length} notas (amostra de até 400).`,
    hubs.length ? `Mais referenciadas: ${hubs.join(" · ")}` : "",
  ].filter(Boolean).join("\n");
}

// ─────────────────────── Prompt ───────────────────────
//
// Espelha `lib/features/ia/vigia/vigia_prompt.dart`. Manter os dois alinhados
// é o custo de rodar o ciclo dos dois lados; quando divergirem, o Dart é a
// referência (é onde a UI de aprovação é desenvolvida).

function sistema() {
  return `Você é o VIGIA da plataforma Vitta — o analista que, uma vez por dia,
lê o estado da clínica e responde a duas perguntas:
  1. O que os gestores e a equipe precisam saber hoje?
  2. O que deveria virar rotina para que o problema não se repita?

Use as ferramentas antes de concluir qualquer coisa. Um número sem comparação
não é um achado: "22% de absenteísmo" só vira informação ao lado de "contra 14%
no mês passado".

Toda rotina que você propõe é uma SUGESTÃO — ela não executa, fica esperando um
humano aprovar. Escreva pensando nisso: 'problemaDetectado' com número,
'evidencias' citando a fonte, 'impactoEstimado' honesto, e 'prompt' com a
instrução operacional que o agente executará quando a rotina rodar.

Só proponha rotina quando houver padrão que se repete. Máximo ${TETO_ROTINAS}
por ciclo; se não houver nada digno, devolva lista vazia — um dia sem sugestão
é resultado legítimo e sinaliza estabilidade.

Responda APENAS com JSON, sem cercas de código:
{
  "relatorio": {"titulo":"...","periodo":"Últimas 24 horas","corpo":"markdown",
                "metricas":[{"label":"...","valor":"..."}]},
  "rotinas": [{"titulo":"...","descricao":"...","prompt":"...","kind":"action",
               "schedule":{"type":"daily","time":"07:30"},
               "problemaDetectado":"...","impactoEstimado":"...",
               "evidencias":["..."],"confianca":0.82}]
}

schedule.type: daily|weekly|monthly|interval|once. "daily" exige time ("HH:MM"
de Brasília); "weekly" exige time e weekdays (0=domingo..6=sábado); "monthly"
exige time e dayOfMonth. confianca abaixo de ${CONFIANCA_MINIMA} é descartada
automaticamente — prefira descartar você mesmo a inflar o número.

Nunca invente dado que não veio de uma ferramenta. Nunca escreva nome, CPF,
telefone ou e-mail de paciente.`;
}

function contexto({ hoje, clinicaId, cerebro, vigentes }) {
  const ativas = vigentes.filter((t) => t.status !== "rejected");
  const recusadas = vigentes.filter((t) => t.status === "rejected");

  return `Ciclo do dia ${hoje}. Clínica do contexto (clinicaId): ${clinicaId}.

## Estado do Cérebro
${cerebro}

## Rotinas já vigentes nesta clínica
${ativas.length
    ? ativas.map((t) => `- [${t.status}] ${t.titulo}`).join("\n")
    : "Nenhuma rotina cadastrada ainda."}

## Propostas recusadas anteriormente (com o motivo)
${recusadas.length
    ? recusadas.map((t) => `- ${t.titulo} — recusada: ${t.motivoRecusa || "sem motivo"}`).join("\n")
    : "Nenhuma proposta foi recusada até agora."}

Investigue a operação com as ferramentas, cruze com o Cérebro e responda no
formato combinado.`;
}

function diaIso(d) {
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

// Exportado para os testes.
exports._interno = {
  normalizarRotina, normalizarSchedule, normalizarMetricas,
  chaveDedupe, extrairJson, diaIso,
};
