/**
 * Testes do Vigia no servidor.
 *
 * O ciclo roda dos dois lados — cliente (Dart) e cron (Node) — e os dois
 * precisam concordar em duas coisas para não brigarem entre si:
 *
 *   1. a **chave de deduplicação**, senão o cron repropõe o que o cliente já
 *      sugeriu (e vice-versa);
 *   2. o que conta como proposta **válida**, senão um lado aceita o que o outro
 *      recusa e o gestor vê cards inconsistentes.
 *
 * O espelho em Dart é `test/features/vigia_sugestoes_test.dart`.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  normalizarRotina, normalizarSchedule, normalizarMetricas,
  chaveDedupe, extrairJson,
} = require("../vigiaCron")._interno;

describe("deduplicação combina com o cliente Dart", () => {
  test("ignora prefixo de origem, caixa e pontuação", () => {
    const a = chaveDedupe("[Preventiva] Confirmação Ativa — Manhã", "action");
    const c = chaveDedupe("Confirmação Ativa   Manhã!!!", "action");
    assert.equal(a, c);
  });

  test("mesma rotina em kinds diferentes não colide", () => {
    assert.notEqual(
      chaveDedupe("Auditoria de faltas", "action"),
      chaveDedupe("Auditoria de faltas", "report")
    );
  });

  test("produz exatamente a mesma chave que o Dart", () => {
    // Valor conferido contra ScheduledTask.chaveDedupeDe. Se alguém mudar a
    // normalização de um lado, este teste quebra antes de a divergência virar
    // sugestão duplicada em produção.
    assert.equal(chaveDedupe("[IA] Auditoria de Faltas!", "action"),
      "action|auditoria de faltas");
  });
});

describe("proposta malformada é descartada, não exibida pela metade", () => {
  const sched = { type: "daily", time: "07:30" };

  test("sem título ou sem prompt", () => {
    assert.equal(normalizarRotina({ prompt: "x", schedule: sched }), null);
    assert.equal(normalizarRotina({ titulo: "x", schedule: sched }), null);
    assert.equal(normalizarRotina(null), null);
    assert.equal(normalizarRotina("texto solto"), null);
  });

  test("sem agendamento utilizável", () => {
    assert.equal(normalizarRotina({ titulo: "x", prompt: "y" }), null);
    assert.equal(
      normalizarRotina({ titulo: "x", prompt: "y", schedule: { type: "quando_der" } }),
      null
    );
  });

  test("aceita proposta completa e normaliza o que falta", () => {
    const p = normalizarRotina({
      titulo: "  Confirmação ativa  ",
      prompt: "Ligar para pacientes de risco",
      schedule: sched,
      evidencias: ["22% de falta", "   ", "nota: protocolos/x.md"],
      confianca: 0.83,
    });
    assert.equal(p.titulo, "Confirmação ativa");
    assert.equal(p.kind, "action", "kind ausente vira ação");
    assert.deepEqual(p.evidencias, ["22% de falta", "nota: protocolos/x.md"]);
    assert.equal(p.confianca, 0.83);
  });

  test("confiança fora da faixa é contida, não rejeitada", () => {
    const base = { titulo: "x", prompt: "y", schedule: sched };
    assert.equal(normalizarRotina({ ...base, confianca: 4.2 }).confianca, 1);
    assert.equal(normalizarRotina({ ...base, confianca: -1 }).confianca, 0);
    assert.equal(normalizarRotina(base).confianca, 0.5, "sem valor, meio-termo");
  });
});

describe("agendamento", () => {
  test("daily exige horário", () => {
    assert.equal(normalizarSchedule({ type: "daily" }), null);
    assert.deepEqual(normalizarSchedule({ type: "daily", time: "07:30" }),
      { type: "daily", time: "07:30" });
  });

  test("weekly filtra dias inválidos e exige ao menos um", () => {
    const s = normalizarSchedule({
      type: "weekly", time: "08:00", weekdays: [1, 9, -3, 5],
    });
    assert.deepEqual(s.weekdays, [1, 5]);
    assert.equal(
      normalizarSchedule({ type: "weekly", time: "08:00", weekdays: [9] }),
      null,
      "só dias inválidos não vira agendamento"
    );
  });

  test("monthly valida o dia do mês", () => {
    assert.equal(normalizarSchedule({ type: "monthly", time: "08:00", dayOfMonth: 45 }), null);
    assert.equal(
      normalizarSchedule({ type: "monthly", time: "08:00", dayOfMonth: 5 }).dayOfMonth,
      5
    );
  });

  test("interval recusa período curto demais", () => {
    assert.equal(normalizarSchedule({ type: "interval", intervalMinutes: 1 }), null);
    assert.equal(
      normalizarSchedule({ type: "interval", intervalMinutes: 60 }).intervalMinutes,
      60
    );
  });

  test("horário malformado é ignorado em vez de aceito", () => {
    assert.equal(normalizarSchedule({ type: "daily", time: "7h da manhã" }), null);
  });
});

describe("leitura da resposta do modelo", () => {
  test("aceita JSON puro", () => {
    assert.equal(extrairJson('{"a":1}').a, 1);
  });

  test("aceita JSON dentro de cerca de código", () => {
    assert.equal(extrairJson('```json\n{"a":2}\n```').a, 2);
  });

  test("aceita JSON com texto ao redor", () => {
    assert.equal(extrairJson('Segue a análise:\n{"a":3}\nEspero ter ajudado.').a, 3);
  });

  test("devolve null em vez de lançar quando não há JSON", () => {
    assert.equal(extrairJson("sem json aqui"), null);
    assert.equal(extrairJson('{"quebrado": '), null);
    assert.equal(extrairJson(""), null);
    assert.equal(extrairJson(null), null);
  });
});

describe("métricas do relatório", () => {
  test("lê os dois formatos e descarta incompletas", () => {
    const m = normalizarMetricas([
      { label: "Absenteísmo", valor: "18%" },
      { rotulo: "Ocupação", value: "78%" },
      { label: "", valor: "ignorado" },
      "lixo",
    ]);
    assert.equal(m.length, 2);
    assert.equal(m[0].label, "Absenteísmo");
    assert.equal(m[1].valor, "78%");
  });

  test("entrada não-lista vira lista vazia", () => {
    assert.deepEqual(normalizarMetricas(undefined), []);
    assert.deepEqual(normalizarMetricas("texto"), []);
  });
});
