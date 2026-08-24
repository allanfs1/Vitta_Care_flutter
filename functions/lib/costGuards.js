/**
 * costGuards.js — Núcleo PURO das proteções de custo (CUSTO.md), sem dependência
 * de firebase-admin. Extraído para ser testável de forma determinística
 * (`functions/test/costGuards.test.js`). Consumido por `scheduledTasksCron.js`.
 */

const BRT_MS = -3 * 60 * 60 * 1000;

// §6.8 Read meter + circuit breaker: estoura ao passar do teto de leituras.
function makeReadMeter(limit) {
  let reads = 0;
  return {
    add(n) {
      reads += n || 0;
      if (reads > limit) throw new Error(`READ_BUDGET_EXCEEDED: ${reads}/${limit}`);
    },
    get total() {
      return reads;
    },
  };
}

function readSchedule(t) {
  const s = t.schedule || {};
  const typeMap = {
    acao: "once", once: "once", interval: "interval", intervalo: "interval",
    daily: "daily", diario: "daily", weekly: "weekly", semanal: "weekly",
    monthly: "monthly", mensal: "monthly",
  };
  const type = typeMap[String(s.type || s.recorrencia || "once").toLowerCase()] || "once";
  const time = s.time || s.horario || "08:00";
  const intervalMinutes = Number(s.intervalMinutes || s.intervaloMinutos || 0);
  const dayOfMonth = Number(s.dayOfMonth || s.diaDoMes || 1);
  let weekdays = [];
  const wd = s.weekdays || s.diasSemana;
  if (Array.isArray(wd)) {
    const names = { domingo: 0, segunda: 1, terca: 2, "terça": 2, quarta: 3, quinta: 4, sexta: 5, sabado: 6, "sábado": 6 };
    weekdays = wd.map((x) => (typeof x === "number" ? x : names[String(x).toLowerCase()])).filter((x) => x != null);
  }
  return { type, time, intervalMinutes, dayOfMonth, weekdays };
}

function computeNextRun(s, from) {
  const fromMs = from.getTime();
  if (s.type === "interval") {
    const m = s.intervalMinutes < 1 ? 1 : s.intervalMinutes;
    return new Date(fromMs + m * 60000);
  }
  const [h, mi] = String(s.time).split(":").map((x) => parseInt(x, 10) || 0);
  const brtFrom = new Date(fromMs + BRT_MS);
  for (let i = 0; i <= 370; i++) {
    const day = new Date(Date.UTC(brtFrom.getUTCFullYear(), brtFrom.getUTCMonth(), brtFrom.getUTCDate()) + i * 86400000);
    if (s.type === "weekly" && s.weekdays.length) {
      if (!s.weekdays.includes(day.getUTCDay())) continue;
    }
    if (s.type === "monthly") {
      const last = new Date(Date.UTC(day.getUTCFullYear(), day.getUTCMonth() + 1, 0)).getUTCDate();
      const target = s.dayOfMonth > last ? last : s.dayOfMonth;
      if (day.getUTCDate() !== target) continue;
    }
    const candUtc = Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate(), h, mi) - BRT_MS;
    if (candUtc > fromMs) return new Date(candUtc);
  }
  return null;
}

/// §6.4 Recalibração temporal segura: ancora em [now] (presente real), nunca em
/// `t.nextRunAt`. [now] é injetável para testes determinísticos.
function advanceNextRun(t, now = new Date()) {
  const s = readSchedule(t);
  if (s.type === "once") return null;
  if (t.maxRuns != null && (t.runCount || 0) + 1 >= t.maxRuns) return null;
  const next = computeNextRun(s, now);
  if (!next) return null;
  if (t.endAt && next.getTime() > t.endAt.toDate().getTime()) return null;
  return next;
}

function parseDate(input) {
  const s = String(input || "").trim();
  const br = s.match(/^(\d{2})\/(\d{2})\/(\d{4})(?:[ T](\d{1,2}):(\d{2}))?$/);
  if (br) {
    const [, d, mo, y, h, mi] = br;
    const utc = Date.UTC(+y, +mo - 1, +d, h ? +h : 0, mi ? +mi : 0) - BRT_MS;
    return new Date(utc);
  }
  const iso = Date.parse(s);
  if (isNaN(iso)) return null;
  if (!/[zZ]|[+-]\d{2}:?\d{2}$/.test(s)) {
    const d = new Date(iso);
    return new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes()) - BRT_MS);
  }
  return new Date(iso);
}

function apptDate(a) {
  return a.dataConsulta && a.dataConsulta.toDate ? a.dataConsulta.toDate() : null;
}

function quickScore(a, faltaRatio) {
  let score = 18 + faltaRatio * 55;
  const d = apptDate(a);
  if (d) {
    if (d.getUTCDay() === 1) score += 10;
    const h = d.getUTCHours();
    if (h < 8 || h >= 17) score += 10;
  }
  if (a.modalidade === "Telemedicina") score += 8;
  return Math.max(0, Math.min(100, Math.round(score)));
}

function faltaRatios(all) {
  const map = {};
  for (const a of all) {
    const cpf = a.cpf || "";
    if (!cpf) continue;
    map[cpf] = map[cpf] || { total: 0, faltas: 0 };
    map[cpf].total++;
    if (a.status === "faltou") map[cpf].faltas++;
  }
  return map;
}

function belongsToClinic(data, clinicaId) {
  for (const f of ["idClinica", "idclinica", "clinicaId"]) {
    const v = data[f];
    if (!v) continue;
    const id = v.id || (typeof v === "string" ? v.split("/").pop() : null);
    if (id === clinicaId) return true;
  }
  return false;
}

module.exports = {
  BRT_MS,
  makeReadMeter,
  readSchedule,
  computeNextRun,
  advanceNextRun,
  parseDate,
  apptDate,
  quickScore,
  faltaRatios,
  belongsToClinic,
};
