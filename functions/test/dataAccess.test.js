/**
 * Testes da camada de acesso a dados escopada por tenant (CUSTO.md §6.1/§6.2/
 * §6.3/§6.6/§6.8). Usa um Firestore falso que conta leituras. `node --test`.
 */

const test = require("node:test");
const assert = require("node:assert/strict");

const { createFakeFirestore, ref, ts } = require("./fakeFirestore");
const createDataAccess = require("../lib/dataAccess");
const { makeReadMeter } = require("../lib/costGuards");

const NOW = Date.UTC(2026, 5, 30, 12, 0, 0); // 30/06/2026 12:00 UTC
const DAY = 86400000;

function seedDb(extraOpts = {}) {
  const seed = {
    users: [
      // c1 legado (idclinica). c2 vizinha (não pode vazar).
      { id: "u1", idclinica: ref("tb_clinica", "c1"), display_name: "Ana Lima", status: true },
      { id: "u2", idclinica: ref("tb_clinica", "c1"), display_name: "Bruno Sá", status: false },
      { id: "u3", idclinica: ref("tb_clinica", "c1"), display_name: "Carla Reis", status: true },
      { id: "x1", idclinica: ref("tb_clinica", "c2"), display_name: "Outro", status: true },
      // c3 canônico (idClinica) — testa early-break sem 2ª query.
      { id: "w1", idClinica: ref("tb_clinica", "c3"), display_name: "W1" },
      { id: "w2", idClinica: ref("tb_clinica", "c3"), display_name: "W2" },
      { id: "w3", idClinica: ref("tb_clinica", "c3"), display_name: "W3" },
    ],
    tb_agendamentos: [
      { id: "a1", idClinica: ref("tb_clinica", "c1"), cpf: "p1", status: "faltou", dataConsulta: ts(NOW - 1 * DAY) },
      { id: "a2", idClinica: ref("tb_clinica", "c1"), cpf: "p2", status: "confirmado", dataConsulta: ts(NOW + 1 * DAY) },
      { id: "a3", idClinica: ref("tb_clinica", "c1"), cpf: "p1", status: "realizado", dataConsulta: ts(NOW - 30 * DAY) },
      { id: "z1", idClinica: ref("tb_clinica", "c2"), cpf: "q1", status: "faltou", dataConsulta: ts(NOW) },
    ],
    tickets: [
      { id: "t1", idClinica: ref("tb_clinica", "c1"), status: "open" },
      { id: "t2", idClinica: ref("tb_clinica", "c1"), status: "open" },
      { id: "t3", idClinica: ref("tb_clinica", "c1"), status: "closed" },
      { id: "t9", idClinica: ref("tb_clinica", "c2"), status: "open" },
    ],
    // Coleção com tenant heterogêneo: reference, string e campo clinicaId.
    mixed: [
      { id: "m1", idclinica: ref("tb_clinica", "c1") },   // reference
      { id: "m2", idclinica: "c1" },                       // string
      { id: "m3", clinicaId: "c1" },                       // campo clinicaId
      { id: "m9", idclinica: ref("tb_clinica", "c2") },   // outra clínica
    ],
  };
  return createFakeFirestore(seed, extraOpts);
}

function makeAccess(fake) {
  return createDataAccess({
    db: fake.db,
    Timestamp: fake.Timestamp,
    tenantFields: ["idClinica", "idclinica"],
    agendamentosLimit: 500,
  });
}

const TENANT_FILTER_FIELDS = ["idClinica", "idclinica", "clinicaId"];
const everyQueryTenantScoped = (reads) =>
  reads.queries.every((q) => q.doc || q.fields.some((f) => TENANT_FILTER_FIELDS.includes(f)));

// ───────── §6.1/§6.6 server-side filtering + isolamento ─────────

test("tenantFetch retorna só a clínica do contexto (sem vazamento, sem full scan)", async () => {
  const fake = seedDb();
  const { tenantFetch } = makeAccess(fake);
  const meter = makeReadMeter(1e9);
  const list = await tenantFetch("users", "c1", { limit: 50 }, meter);

  assert.equal(list.length, 3, "apenas os 3 usuários de c1");
  assert.ok(list.every((u) => u.idclinica.id === "c1"), "nenhum doc de outra clínica");
  assert.ok(everyQueryTenantScoped(fake.reads), "toda query tem filtro de tenant (não é full scan)");
  // Lê os 3 docs da clínica + algumas leituras mínimas dos probes vazios das
  // variantes de campo de tenant (ref/string × idClinica/idclinica/clinicaId) —
  // overhead da heterogeneidade (§6.6), eliminado após a migração. Em todo caso,
  // MUITO abaixo de um full scan (que custaria centenas).
  assert.equal(list.length, 3);
  assert.ok(meter.total < 15, `leituras (${meter.total}) muito abaixo de um full scan`);
});

test("early-break: campo canônico supre o limite e evita a 2ª query (legado)", async () => {
  const fake = seedDb();
  const { tenantFetch } = makeAccess(fake);
  const meter = makeReadMeter(1e9);
  const list = await tenantFetch("users", "c3", { limit: 2 }, meter);

  assert.equal(list.length, 2, "limite respeitado");
  const userQueries = fake.reads.queries.filter((q) => q.coll === "users" && !q.doc);
  assert.equal(userQueries.length, 1, "só a query canônica (idClinica) rodou");
  assert.ok(userQueries[0].fields.includes("idClinica"));
});

test("tenantFetch cobre tenant como reference, string e campo clinicaId (sem full scan)", async () => {
  const fake = seedDb();
  const { tenantFetch } = makeAccess(fake);
  const meter = makeReadMeter(1e9);
  const list = await tenantFetch("mixed", "c1", { limit: 50 }, meter);
  const ids = list.map((d) => d.id).sort();
  assert.deepEqual(ids, ["m1", "m2", "m3"], "acha as 3 representações de c1");
  assert.ok(!ids.includes("m9"), "não vaza a clínica c2");
  assert.ok(everyQueryTenantScoped(fake.reads), "todas as queries são escopadas (não full scan)");
});

test("listScoped aplica filtro server-side e isola tenant", async () => {
  const fake = seedDb();
  const { listScoped } = makeAccess(fake);
  const meter = makeReadMeter(1e9);
  const open = await listScoped("tickets", "c1", { filters: { status: "open" }, limit: 50 }, meter);
  assert.equal(open.length, 2);
  assert.ok(open.every((t) => t.status === "open" && t.idClinica.id === "c1"));
});

// ───────── §6.3 time-bounding ─────────

test("fetchAgendamentos aplica a janela e exclui fora do intervalo", async () => {
  const fake = seedDb();
  const { fetchAgendamentos } = makeAccess(fake);
  const meter = makeReadMeter(1e9);
  const since = new Date(NOW - 7 * DAY), until = new Date(NOW + 7 * DAY);
  const list = await fetchAgendamentos("c1", { agendamentos: new Map() }, meter, { since, until });

  const ids = list.map((a) => a.id).sort();
  assert.deepEqual(ids, ["a1", "a2"], "a3 (30d atrás) fica fora; z1 (c2) não vaza");
});

// ───────── §6.2 cache por execução ─────────

test("fetchAgendamentos usa cache: 2ª chamada não gera novas leituras", async () => {
  const fake = seedDb();
  const { fetchAgendamentos } = makeAccess(fake);
  const meter = makeReadMeter(1e9);
  const cache = { agendamentos: new Map() };
  const since = new Date(NOW - 7 * DAY), until = new Date(NOW + 7 * DAY);

  const first = await fetchAgendamentos("c1", cache, meter, { since, until });
  const afterFirst = fake.reads.total;
  assert.ok(afterFirst > 0, "1ª chamada lê do banco");

  const second = await fetchAgendamentos("c1", cache, meter, { since, until });
  assert.equal(fake.reads.total, afterFirst, "2ª chamada NÃO lê de novo (cache)");
  assert.deepEqual(second.map((a) => a.id), first.map((a) => a.id));
});

// ───────── Fallback de índice composto (ainda tenant-scoped) ─────────

test("fallback de índice ausente mantém tenant-scope e resultado correto", async () => {
  // Simula FAILED_PRECONDITION em qualquer query composta (>1 filtro).
  const fake = seedDb({ failOn: ({ filters }) => filters.length > 1 });
  const { fetchAgendamentos, listScoped } = makeAccess(fake);
  const meter = makeReadMeter(1e9);

  const since = new Date(NOW - 7 * DAY), until = new Date(NOW + 7 * DAY);
  const appts = await fetchAgendamentos("c1", { agendamentos: new Map() }, meter, { since, until });
  assert.deepEqual(appts.map((a) => a.id).sort(), ["a1", "a2"], "janela aplicada em memória no fallback");
  assert.ok(everyQueryTenantScoped(fake.reads), "fallback continua escopado ao tenant (não vira full scan)");

  const open = await listScoped("tickets", "c1", { filters: { status: "open" }, limit: 50 }, meter);
  assert.equal(open.length, 2, "filtro aplicado em memória no fallback");
  assert.ok(open.every((t) => t.idClinica.id === "c1"));
});

// ───────── §6.5 agregação count() ─────────

test("meteredCount conta no servidor e cobra ~1 leitura", async () => {
  const fake = seedDb();
  const { meteredCount, clinicRef } = makeAccess(fake);
  const meter = makeReadMeter(1e9);
  const before = fake.reads.total;
  const q = fake.db.collection("tb_agendamentos").where("idClinica", "==", clinicRef("c1"));
  const total = await meteredCount(q, meter);

  assert.equal(total, 3, "conta os 3 agendamentos de c1");
  assert.equal(fake.reads.total - before, 1, "agregação custa 1 leitura, não 3");
});

// ───────── §6.8 circuit breaker (teto por execução) ─────────

test("circuit breaker aborta ao estourar o orçamento (não é engolido pelo fallback)", async () => {
  const fake = seedDb();
  const { tenantFetch } = makeAccess(fake);
  const meter = makeReadMeter(1); // teto baixíssimo
  await assert.rejects(
    () => tenantFetch("users", "c1", { limit: 50 }, meter),
    /READ_BUDGET_EXCEEDED/);
});
