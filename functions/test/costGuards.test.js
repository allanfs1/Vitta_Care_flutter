/**
 * Testes do núcleo puro de proteções de custo (CUSTO.md §6.4/§6.8 e helpers).
 * Roda com: `node --test` (sem dependências externas).
 */

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  BRT_MS, makeReadMeter, advanceNextRun, computeNextRun, readSchedule,
  parseDate, quickScore, faltaRatios, belongsToClinic,
} = require("../lib/costGuards");

const tsLike = (date) => ({ toDate: () => date });

// ───────── §6.8 Read meter + circuit breaker ─────────

test("read meter acumula e estoura no teto (circuit breaker)", () => {
  const m = makeReadMeter(100);
  m.add(40);
  m.add(50);
  assert.equal(m.total, 90);
  assert.throws(() => m.add(20), /READ_BUDGET_EXCEEDED: 110\/100/);
});

test("read meter trata add(0)/undefined sem quebrar", () => {
  const m = makeReadMeter(10);
  m.add(0); m.add(); m.add(5);
  assert.equal(m.total, 5);
});

// ───────── §6.4 Recalibração temporal anti catch-up ─────────

test("advanceNextRun (diário) ancora no PRESENTE, não em nextRunAt passado", () => {
  const now = new Date(Date.UTC(2026, 5, 30, 18, 0, 0)); // 30/06 15:00 BRT
  // nextRunAt 5 dias no passado: não deve influenciar o resultado.
  const task = {
    schedule: { type: "daily", time: "08:00" },
    nextRunAt: tsLike(new Date(Date.UTC(2026, 5, 25, 11, 0, 0))),
  };
  const next = advanceNextRun(task, now);
  assert.ok(next instanceof Date);
  assert.ok(next.getTime() > now.getTime(), "próxima execução deve ser futura");
  // Independência de nextRunAt: mesmo resultado sem o campo passado.
  const next2 = advanceNextRun({ schedule: task.schedule }, now);
  assert.equal(next.getTime(), next2.getTime());
  // É o próximo 08:00 BRT (11:00 UTC) após `now` → 01/07 11:00 UTC.
  assert.equal(next.getTime(), Date.UTC(2026, 6, 1, 11, 0, 0));
});

test("advanceNextRun (intervalo) salta a partir de agora (sem backfill)", () => {
  const now = new Date(Date.UTC(2026, 5, 30, 12, 0, 0));
  const task = {
    schedule: { type: "interval", intervalMinutes: 60 },
    nextRunAt: tsLike(new Date(Date.UTC(2026, 5, 20, 0, 0, 0))), // 10 dias atrás
  };
  const next = advanceNextRun(task, now);
  assert.equal(next.getTime(), now.getTime() + 60 * 60000, "deve ser now+60min, não old+60min");
});

test("advanceNextRun respeita maxRuns e once/endAt", () => {
  const now = new Date();
  assert.equal(advanceNextRun({ schedule: { type: "once" } }, now), null);
  assert.equal(
    advanceNextRun({ schedule: { type: "daily", time: "08:00" }, maxRuns: 3, runCount: 2 }, now),
    null, "para quando runCount+1 >= maxRuns");
  const past = tsLike(new Date(now.getTime() - 86400000));
  assert.equal(
    advanceNextRun({ schedule: { type: "interval", intervalMinutes: 5 }, endAt: past }, now),
    null, "não agenda além de endAt");
});

test("computeNextRun (semanal) cai num dia da semana permitido", () => {
  const s = readSchedule({ schedule: { type: "weekly", time: "09:00", weekdays: ["segunda"] } });
  const from = new Date(Date.UTC(2026, 5, 30, 12, 0, 0)); // terça
  const next = computeNextRun(s, from);
  const brt = new Date(next.getTime() + BRT_MS);
  assert.equal(brt.getUTCDay(), 1, "deve cair numa segunda (1) em BRT");
});

// ───────── Helpers de domínio ─────────

test("parseDate aceita BR (DD/MM/AAAA HH:MM) e ISO", () => {
  const br = parseDate("30/06/2026 08:30");
  assert.equal(br.getTime(), Date.UTC(2026, 5, 30, 8, 30) - BRT_MS);
  const iso = parseDate("2026-06-30T11:30:00Z");
  assert.equal(iso.getTime(), Date.UTC(2026, 5, 30, 11, 30));
  assert.equal(parseDate("xxx"), null);
});

test("quickScore aplica bumps e satura em [0,100]", () => {
  const seg8h = { dataConsulta: { toDate: () => new Date(Date.UTC(2026, 5, 29, 6, 0)) } }; // segunda 06h
  const s = quickScore(seg8h, 1); // ratio máximo
  assert.ok(s <= 100 && s >= 0);
  assert.ok(s > quickScore({ dataConsulta: { toDate: () => new Date(Date.UTC(2026, 5, 30, 12, 0)) } }, 0));
});

test("faltaRatios conta total e faltas por cpf", () => {
  const r = faltaRatios([
    { cpf: "1", status: "faltou" }, { cpf: "1", status: "realizado" },
    { cpf: "2", status: "realizado" }, { cpf: "", status: "faltou" },
  ]);
  assert.deepEqual(r["1"], { total: 2, faltas: 1 });
  assert.deepEqual(r["2"], { total: 1, faltas: 0 });
  assert.equal(r[""], undefined);
});

test("belongsToClinic reconhece ref, string e path", () => {
  assert.equal(belongsToClinic({ idClinica: { id: "c1" } }, "c1"), true);
  assert.equal(belongsToClinic({ idclinica: "tb_clinica/c1" }, "c1"), true);
  assert.equal(belongsToClinic({ clinicaId: "c2" }, "c1"), false);
});
