/**
 * publicAgenda.js — lógica de `publicAgendaProxy`/`publicAgendaSolicitar`,
 * isolada do HTTP (Fábrica que recebe `db`/`Timestamp` injetados) para ser
 * testável com um Firestore falso — mesmo padrão de `lib/dataAccess.js` (ver
 * `functions/test/fakeFirestore.js` e `functions/test/publicAgenda.test.js`).
 *
 * Por que isto existe: a agenda **pública** do médico (`/agenda-publica/:id`,
 * link/QR Code sem login) não pode ler `tb_agendamentos` direto pelo SDK do
 * cliente — o Firestore não filtra campos, e o documento tem `nomePaciente`,
 * `cpf`, `telefonePaciente`, `emailPaciente` e `motivoConsulta` de cada
 * paciente do médico. Foi exatamente isso que vazou por leitura anônima em
 * 2026-08-26 (ver `EMERGENCIA-firestore.rules` e `.specify/ATENCAO.md`).
 *
 * As duas funções aqui usam o Admin SDK (ignora as regras do Firestore de
 * propósito) e devolvem/persistem só o que a tela pública precisa:
 *
 *   getAgenda(...)   → perfil do médico + config de horário + `startMs` dos
 *                       horários ocupados — sem nome, CPF, telefone ou motivo.
 *   solicitar(...)   → cria a consulta como `pre-agendado`, validando tudo no
 *                       servidor (nome, telefone, vaga, duplicidade) —
 *                       validação só no cliente não impede quem chama a API
 *                       direto.
 */

/** Máximo de consultas futuras ativas por telefone, com o mesmo médico. */
const MAX_FUTURAS_POR_TELEFONE = 3;

function digits(s) {
  return (s || "").toString().replace(/\D/g, "");
}

function refId(v) {
  if (v == null) return "";
  if (typeof v === "string") return v.includes("/") ? v.split("/").pop() : v;
  if (typeof v.id === "string") return v.id; // DocumentReference
  return "";
}

/** Rótulos de "cancelado" gravados em `tb_agendamentos` (espelha `AppointmentStatus.fromString`). */
function isCancelado(status) {
  const s = (status || "").toString().trim().toLowerCase();
  return s === "cancelado" || s === "cancelled";
}

/** Assunto seguro do médico — só o que a página pública já mostra por design. */
function doctorPublico(id, d) {
  return {
    id,
    name: (d.nomeCompleto || d.nome || "Sem nome").toString(),
    crm: (d.crm || "").toString(),
    specialties: Array.isArray(d.especialidades)
      ? d.especialidades.map((e) => e.toString())
      : typeof d.especialidades === "string" && d.especialidades
        ? [d.especialidades]
        : [],
    clinicId: refId(d.idclinica || d.idClinica),
    photoUrl: (d.fotoPerfil || d.photoUrl || "").toString(),
    email: (d.email || "").toString(),
    phone: (d.telefone || "").toString(),
    address: (d.endereco || "").toString(),
    bio: (d.biografia || "").toString(),
    experience: (d.experiencia || "").toString(),
    active: typeof d.status === "boolean" ? d.status : true,
    slotLimit: 1, // `tb_medicos` não grava limite/overbook por slot hoje.
    maxOverbook: typeof d.maxOverbook === "number" ? d.maxOverbook : 0,
  };
}

/** Subconjunto do `TotemConfig` da clínica — só grade de horário, nada sensível. */
function totemConfigPublico(cfg) {
  const c = cfg || {};
  return {
    clinicName: (c.clinicName || "Agenda Clínica").toString(),
    accent: typeof c.accent === "number" ? c.accent : 0xFFFF3B30,
    showClock: c.showClock !== false,
    showOccupancy: c.showOccupancy !== false,
    scale: typeof c.scale === "number" ? c.scale : 1.0,
    showCalendarButton: c.showCalendarButton !== false,
    appointmentDuration:
      typeof c.appointmentDuration === "number" ? c.appointmentDuration : 30,
    maxDaysAhead: typeof c.maxDaysAhead === "number" ? c.maxDaysAhead : 365,
    openHour: typeof c.openHour === "number" ? c.openHour : 8,
    closeHour: typeof c.closeHour === "number" ? c.closeHour : 17,
    openSaturday: c.openSaturday !== false,
    saturdayCloseHour:
      typeof c.saturdayCloseHour === "number" ? c.saturdayCloseHour : 12,
    openSunday: c.openSunday === true,
    lunchBreakEnabled: c.lunchBreakEnabled === true,
    lunchStartHour: typeof c.lunchStartHour === "number" ? c.lunchStartHour : 12,
    lunchEndHour: typeof c.lunchEndHour === "number" ? c.lunchEndHour : 13,
  };
}

module.exports = function createPublicAgenda({ db, Timestamp }) {
  /**
   * Busca os agendamentos de um médico com `dataConsulta` em
   * [inicioMs, fimMs), combinando as três formas como `idMedico` aparece no
   * documento (DocumentReference, id cru, caminho `tb_medicos/<id>`) — mesma
   * estratégia de `FirestoreAppointmentService.watchForDoctor` no app.
   */
  async function agendamentosNoIntervalo(doctorId, inicioMs, fimMs) {
    const col = db.collection("tb_agendamentos");
    const doctorRef = db.collection("tb_medicos").doc(doctorId);
    const inicio = Timestamp.fromDate(new Date(inicioMs));
    const fim = Timestamp.fromDate(new Date(fimMs));

    const variantes = [doctorRef, doctorId, `tb_medicos/${doctorId}`];
    const snaps = await Promise.all(
      variantes.map((v) =>
        col
          .where("idMedico", "==", v)
          .where("dataConsulta", ">=", inicio)
          .where("dataConsulta", "<", fim)
          .get()
      )
    );

    const byId = new Map();
    for (const snap of snaps) {
      for (const doc of snap.docs) byId.set(doc.id, doc.data());
    }
    return [...byId.values()];
  }

  /**
   * Perfil do médico + config de horário + horários ocupados no dia
   * [inicioMs, fimMs) — sem nome, CPF, telefone ou motivo de ninguém.
   */
  async function getAgenda({ medicoId, inicioMs, fimMs }) {
    const doc = await db.collection("tb_medicos").doc(medicoId).get();
    if (!doc.exists) return { found: false };

    const d = doc.data() || {};
    const doctor = doctorPublico(doc.id, d);

    let totemConfig = totemConfigPublico(null);
    if (doctor.clinicId) {
      const cfgDoc = await db.collection("tb_totem_config").doc(doctor.clinicId).get();
      totemConfig = totemConfigPublico(cfgDoc.data && cfgDoc.data() && cfgDoc.data().config);
    }

    const agendamentos = await agendamentosNoIntervalo(medicoId, inicioMs, fimMs);
    const appointments = agendamentos
      .filter((a) => !isCancelado(a.status))
      .map((a) => ({ startMs: (a.dataConsulta && a.dataConsulta.toMillis()) || 0 }))
      .filter((a) => a.startMs > 0);

    return { found: true, doctor, totemConfig, appointments };
  }

  /**
   * Solicita um horário — sempre grava como `pre-agendado`; a clínica
   * confirma depois. Todas as validações (nome, telefone, vaga, duplicidade)
   * são refeitas aqui: o que o app já valida no cliente é só UX.
   */
  async function solicitar({
    medicoId,
    startMs,
    diaInicioMs,
    diaFimMs,
    duracao,
    nome,
    telefone,
    email,
  }) {
    const nomeTrim = (nome || "").toString().trim();
    const telefoneDigits = digits(telefone);
    const telefoneFmt = (telefone || "").toString().trim();
    const emailTrim = (email || "").toString().trim();
    const dur = Number(duracao) || 30;

    if (!medicoId || !Number.isFinite(startMs)) {
      return { ok: false, error: "parametros_invalidos" };
    }
    if (startMs <= Date.now()) {
      return { ok: false, error: "horario_passado" };
    }
    if (nomeTrim.length < 3) {
      return { ok: false, error: "nome_invalido" };
    }
    if (telefoneDigits.length < 10) {
      return { ok: false, error: "telefone_invalido" };
    }
    if (emailTrim && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(emailTrim)) {
      return { ok: false, error: "email_invalido" };
    }

    const doctorSnap = await db.collection("tb_medicos").doc(medicoId).get();
    if (!doctorSnap.exists) {
      return { ok: false, error: "medico_nao_encontrado" };
    }
    const d = doctorSnap.data() || {};
    if (d.status === false) {
      return { ok: false, error: "medico_inativo" };
    }
    const doctor = doctorPublico(doctorSnap.id, d);

    // Vaga no slot exato: mesma janela [startMs, startMs+duracao) usada pela
    // grade do cliente para ancorar consultas fora de hora na grade.
    const doSlot = await agendamentosNoIntervalo(medicoId, startMs, startMs + dur * 60000);
    const ocupados = doSlot.filter((a) => !isCancelado(a.status)).length;
    const capacidade = Math.max(1, (doctor.slotLimit || 1) + Math.max(0, doctor.maxOverbook || 0));
    if (ocupados >= capacidade) {
      return { ok: false, error: "sem_vaga" };
    }

    // Anti-abuso pelo mesmo telefone, só na agenda deste médico (sem varrer
    // a clínica): nada no mesmo dia, no máximo N consultas futuras ativas.
    if (Number.isFinite(diaInicioMs) && Number.isFinite(diaFimMs) && diaFimMs > diaInicioMs) {
      const doDia = await agendamentosNoIntervalo(medicoId, diaInicioMs, diaFimMs);
      const mesmoTelefoneNoDia = doDia.some(
        (a) => !isCancelado(a.status) && digits(a.telefonePaciente) === telefoneDigits
      );
      if (mesmoTelefoneNoDia) {
        return { ok: false, error: "duplicado_no_dia" };
      }
    }
    const futSnap = await db
      .collection("tb_agendamentos")
      .where("idMedico", "==", db.collection("tb_medicos").doc(medicoId))
      .where("dataConsulta", ">=", Timestamp.now())
      .get();
    const futuras = futSnap.docs.filter((doc) => {
      const a = doc.data();
      return (
        !isCancelado(a.status) &&
        (a.status || "").toString().toLowerCase() !== "realizado" &&
        digits(a.telefonePaciente) === telefoneDigits
      );
    }).length;
    if (futuras >= MAX_FUTURAS_POR_TELEFONE) {
      return { ok: false, error: "limite_futuras" };
    }

    const ref = db.collection("tb_agendamentos").doc();
    await ref.set({
      idClinica: doctor.clinicId ? db.collection("tb_clinica").doc(doctor.clinicId) : null,
      idMedico: db.collection("tb_medicos").doc(medicoId),
      idPaciente: `publica-${ref.id}`,
      nomePaciente: nomeTrim,
      nomeMedico: doctor.name,
      especialidade: doctor.specialties[0] || "Clínico Geral",
      dataConsulta: Timestamp.fromDate(new Date(startMs)),
      duracao: dur,
      status: "pre-agendado",
      tipoConsulta: "Consulta",
      modalidade: "Presencial",
      local: "",
      motivo: "Solicitado pela agenda pública",
      observacoes: emailTrim ? `E-mail informado: ${emailTrim}` : "",
      crm: doctor.crm,
      telefonePaciente: telefoneFmt,
      createdAt: Timestamp.now(),
    });

    const protocolo = `AP-${ref.id.slice(-6).toUpperCase()}`;
    return { ok: true, id: ref.id, protocolo };
  }

  return { getAgenda, solicitar };
};
