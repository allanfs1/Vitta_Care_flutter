/**
 * Testes de `lib/publicAgenda.js` — a lógica por trás de `publicAgendaProxy`/
 * `publicAgendaSolicitar` (agenda pública do médico, `/agenda-publica/:id`).
 * Usa o Firestore falso (`fakeFirestore.js`); roda com `node --test`.
 *
 * O que importa validar aqui, além do caminho feliz: `getAgenda` nunca
 * devolve nome/CPF/telefone/motivo (é o vazamento que este desenho evita — ver
 * `.specify/ATENCAO.md`), e `solicitar` refaz no servidor toda validação que o
 * cliente já faz (nome, telefone, vaga, duplicidade) — a garantia real está
 * aqui, não no app.
 */

const test = require("node:test");
const assert = require("node:assert/strict");

const { createFakeFirestore, ref } = require("./fakeFirestore");
const createPublicAgenda = require("../lib/publicAgenda");

const DAY = 86400000;
const HOUR = 3600000;

function seedDb(extra = {}) {
  const seed = {
    tb_medicos: [
      {
        id: "m1",
        nomeCompleto: "Dra. Helena Prado",
        crm: "CRM/SP 123456",
        especialidades: ["Cardiologia", "Clínico Geral"],
        idclinica: ref("tb_clinica", "c1"),
        telefone: "(11) 98888-7777",
        status: true,
        maxOverbook: 0,
      },
      {
        id: "m2-inativo",
        nomeCompleto: "Dr. Inativo",
        crm: "CRM/SP 999999",
        especialidades: ["Clínico Geral"],
        idclinica: ref("tb_clinica", "c1"),
        status: false,
      },
    ],
    tb_totem_config: [
      { id: "c1", config: { clinicName: "Clínica Teste", appointmentDuration: 30 } },
    ],
    tb_agendamentos: [],
    ...extra,
  };
  return { ...createFakeFirestore(seed), seed };
}

function agendaFor(fake) {
  return createPublicAgenda({ db: fake.db, Timestamp: fake.Timestamp });
}

// ───────── getAgenda: nunca vaza dado pessoal ─────────

test("getAgenda: médico inexistente devolve found:false", async () => {
  const fake = seedDb();
  const agenda = agendaFor(fake);
  const r = await agenda.getAgenda({ medicoId: "não-existe", inicioMs: 0, fimMs: DAY });
  assert.deepEqual(r, { found: false });
});

test("getAgenda: perfil público não inclui campos internos sensíveis", async () => {
  const fake = seedDb();
  const agenda = agendaFor(fake);
  const r = await agenda.getAgenda({ medicoId: "m1", inicioMs: 0, fimMs: DAY });
  assert.equal(r.found, true);
  assert.equal(r.doctor.name, "Dra. Helena Prado");
  assert.equal(r.doctor.crm, "CRM/SP 123456");
  assert.deepEqual(r.doctor.specialties, ["Cardiologia", "Clínico Geral"]);
  assert.equal(r.doctor.clinicId, "c1");
  assert.equal(r.totemConfig.clinicName, "Clínica Teste");
  assert.equal(r.totemConfig.appointmentDuration, 30);
});

test("getAgenda: appointments só tem startMs — nunca nome/telefone/motivo", async () => {
  const base = Date.UTC(2027, 0, 11, 12, 0, 0); // uma terça, meio-dia UTC
  const fake = seedDb({
    tb_agendamentos: [
      {
        id: "a1",
        idMedico: ref("tb_medicos", "m1"),
        dataConsulta: fake_ts(base),
        status: "confirmado",
        nomePaciente: "Fulano de Tal",
        cpf: "11122233344",
        telefonePaciente: "11999998888",
        motivo: "Motivo sigiloso",
      },
    ],
  });
  const agenda = agendaFor(fake);
  const r = await agenda.getAgenda({ medicoId: "m1", inicioMs: base - HOUR, fimMs: base + HOUR });
  assert.equal(r.appointments.length, 1);
  const keys = Object.keys(r.appointments[0]);
  assert.deepEqual(keys, ["startMs"]);
  assert.equal(r.appointments[0].startMs, base);
});

function fake_ts(ms) {
  // Mesmo formato que `fakeFirestore.js` usa para campos Timestamp no seed.
  return { _ts: true, ms, toDate: () => new Date(ms), toMillis: () => ms };
}

test("getAgenda: ignora cancelados e agendamentos fora do intervalo", async () => {
  const base = Date.UTC(2027, 0, 11, 9, 0, 0);
  const fake = seedDb({
    tb_agendamentos: [
      { id: "cancelado", idMedico: ref("tb_medicos", "m1"), dataConsulta: fake_ts(base), status: "cancelado" },
      { id: "fora", idMedico: ref("tb_medicos", "m1"), dataConsulta: fake_ts(base + 2 * DAY), status: "confirmado" },
      { id: "outro-medico", idMedico: ref("tb_medicos", "m2-inativo"), dataConsulta: fake_ts(base), status: "confirmado" },
    ],
  });
  const agenda = agendaFor(fake);
  const r = await agenda.getAgenda({ medicoId: "m1", inicioMs: base - HOUR, fimMs: base + DAY });
  assert.deepEqual(r.appointments, []);
});

test("getAgenda: combina idMedico como ref, id cru e caminho, sem duplicar", async () => {
  const base = Date.UTC(2027, 0, 11, 9, 0, 0);
  const fake = seedDb({
    tb_agendamentos: [
      { id: "a-ref", idMedico: ref("tb_medicos", "m1"), dataConsulta: fake_ts(base), status: "confirmado" },
      { id: "a-id", idMedico: "m1", dataConsulta: fake_ts(base + HOUR), status: "confirmado" },
      { id: "a-path", idMedico: "tb_medicos/m1", dataConsulta: fake_ts(base + 2 * HOUR), status: "confirmado" },
    ],
  });
  const agenda = agendaFor(fake);
  const r = await agenda.getAgenda({ medicoId: "m1", inicioMs: base - HOUR, fimMs: base + DAY });
  assert.equal(r.appointments.length, 3);
});

// ───────── solicitar: validação refeita no servidor ─────────

function solicitacaoValida(overrides = {}) {
  // Ancorado ao MEIO-DIA UTC de amanhã, não a `Date.now() + DAY`.
  //
  // Com a hora corrente, o horário do pedido herdava a hora do relógio: rodar
  // o teste depois das 21:00 UTC fazia o `+3h` de "outro horário no mesmo dia"
  // atravessar a meia-noite e cair fora da janela do dia — e o teste de
  // duplicidade falhava por hora do dia, não por bug. Meio-dia deixa 12 h de
  // folga para cada lado.
  const diaInicio = new Date(Date.now() + DAY);
  diaInicio.setUTCHours(0, 0, 0, 0);
  const amanha = diaInicio.getTime() + 12 * HOUR;
  return {
    medicoId: "m1",
    startMs: amanha,
    diaInicioMs: diaInicio.getTime(),
    diaFimMs: diaInicio.getTime() + DAY,
    duracao: 30,
    nome: "Joana Ribeiro",
    telefone: "(11) 98765-4321",
    ...overrides,
  };
}

test("solicitar: recusa nome curto, telefone incompleto, e-mail inválido, horário passado", async () => {
  const fake = seedDb();
  const agenda = agendaFor(fake);

  assert.equal((await agenda.solicitar(solicitacaoValida({ nome: "Jo" }))).error, "nome_invalido");
  assert.equal((await agenda.solicitar(solicitacaoValida({ telefone: "1198" }))).error, "telefone_invalido");
  assert.equal(
    (await agenda.solicitar(solicitacaoValida({ email: "não-é-email" }))).error,
    "email_invalido"
  );
  assert.equal(
    (await agenda.solicitar(solicitacaoValida({ startMs: Date.now() - HOUR }))).error,
    "horario_passado"
  );
});

test("solicitar: médico inexistente ou inativo", async () => {
  const fake = seedDb();
  const agenda = agendaFor(fake);

  assert.equal(
    (await agenda.solicitar(solicitacaoValida({ medicoId: "não-existe" }))).error,
    "medico_nao_encontrado"
  );
  assert.equal(
    (await agenda.solicitar(solicitacaoValida({ medicoId: "m2-inativo" }))).error,
    "medico_inativo"
  );
});

test("solicitar: sem vaga quando o slot já está na capacidade", async () => {
  const pedido = solicitacaoValida();
  const fake = seedDb({
    tb_agendamentos: [
      // Capacidade padrão é 1 (slotLimit 1 + maxOverbook 0) — já ocupado.
      { id: "ja-tem", idMedico: ref("tb_medicos", "m1"), dataConsulta: fake_ts(pedido.startMs), status: "confirmado" },
    ],
  });
  const agenda = agendaFor(fake);
  const r = await agenda.solicitar(pedido);
  assert.deepEqual(r, { ok: false, error: "sem_vaga" });
});

test("solicitar: duas solicitações seguidas no mesmo slot — a 2ª esbarra na 1ª", async () => {
  const fake = seedDb();
  const agenda = agendaFor(fake);
  const pedido = solicitacaoValida();

  const primeira = await agenda.solicitar(pedido);
  assert.equal(primeira.ok, true);

  // Telefone diferente — não é duplicidade, é a vaga que já foi ocupada pela
  // 1ª solicitação (o fake persiste o `set()` de verdade).
  const segunda = await agenda.solicitar(
    solicitacaoValida({ ...pedido, telefone: "(21) 91111-2222", nome: "Outra Pessoa" })
  );
  assert.deepEqual(segunda, { ok: false, error: "sem_vaga" });
});

test("solicitar: mesmo telefone não solicita duas vezes no mesmo dia", async () => {
  const pedido = solicitacaoValida();
  const outroHorarioMesmoDia = pedido.startMs + 3 * HOUR;
  const fake = seedDb({
    tb_agendamentos: [
      {
        id: "existente",
        idMedico: ref("tb_medicos", "m1"),
        dataConsulta: fake_ts(outroHorarioMesmoDia),
        status: "pre-agendado",
        telefonePaciente: pedido.telefone,
      },
    ],
  });
  const agenda = agendaFor(fake);
  const r = await agenda.solicitar(pedido);
  assert.deepEqual(r, { ok: false, error: "duplicado_no_dia" });
});

test("solicitar: limite de consultas futuras ativas por telefone", async () => {
  const pedido = solicitacaoValida();
  const telefoneDigits = "11987654321";
  const futuras = [1, 2, 3].map((n) => ({
    id: `futura-${n}`,
    idMedico: ref("tb_medicos", "m1"),
    // Dias bem depois do dia do pedido — não colide com duplicado_no_dia.
    dataConsulta: fake_ts(pedido.startMs + n * 10 * DAY),
    status: "confirmado",
    telefonePaciente: telefoneDigits,
  }));
  const fake = seedDb({ tb_agendamentos: futuras });
  const agenda = agendaFor(fake);
  const r = await agenda.solicitar(pedido);
  assert.deepEqual(r, { ok: false, error: "limite_futuras" });
});

test("solicitar: sucesso grava pré-agendado com os campos esperados", async () => {
  const fake = seedDb();
  const agenda = agendaFor(fake);
  const pedido = solicitacaoValida({ email: "joana@example.com" });

  const r = await agenda.solicitar(pedido);
  assert.equal(r.ok, true);
  assert.ok(r.id);
  assert.match(r.protocolo, /^AP-[0-9A-Z]{6}$/);

  const gravado = fake.seed.tb_agendamentos.find((a) => a.id === r.id);
  assert.ok(gravado, "documento deveria estar no seed após o set()");
  assert.equal(gravado.status, "pre-agendado");
  assert.equal(gravado.nomePaciente, "Joana Ribeiro");
  assert.equal(gravado.motivo, "Solicitado pela agenda pública");
  assert.equal(gravado.observacoes, "E-mail informado: joana@example.com");
  assert.equal(gravado.duracao, 30);
  assert.equal(gravado.crm, "CRM/SP 123456");
  assert.equal(gravado.idMedico.id, "m1");
  assert.equal(gravado.idClinica.id, "c1");
});
