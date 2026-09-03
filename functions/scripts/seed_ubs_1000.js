// Script de Seed: 1.000 Consultas UBS distribuídas em 30 dias (Simulação UBS)
// Popula tb_agendamentos, dashboard_risco e tb_faltas_data com casos clínicos realistas de Atenção Básica (SUS).

const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const {
  getFirestore,
  collection,
  doc,
  writeBatch,
  Timestamp
} = require('firebase/firestore');

const firebaseConfig = {
  apiKey: 'AIzaSyAbyyNeqQVvfJQfoig75f0Vbnz-w-6MxxE',
  authDomain: 'agendaclinica-457713.firebaseapp.com',
  projectId: 'agendaclinica-457713',
  storageBucket: 'agendaclinica-457713.firebasestorage.app',
  messagingSenderId: '401017379288',
  appId: '1:401017379288:web:67f28064e7c78fd2147aad'
};

const CLINIC_ID = 'JuhdNt7NG3GYOFKOKOXP';
const TOTAL_CONSULTAS = 1000;
const DIAS_PASSADOS = 25;
const DIAS_FUTUROS = 5;
const FAKE_BATCH_ID = 'ubs_seed_1000_' + Date.now();

// Equipe multiprofissional da UBS
const PROFISSIONAIS = [
  {
    id: 'FFBcGmjeuoJB27f8Q2t3',
    nome: 'Dra. Amarilia dos Santos Neves',
    crm: '12958/SP',
    especialidade: 'Clínica Geral',
    tipo: 'Médica de Família'
  },
  {
    id: 'perXKN9RfKJGqZHULp8a',
    nome: 'Dr. Renato Guimarães',
    crm: '345677/SP',
    especialidade: 'Clínica Geral',
    tipo: 'Acompanhamento de Crônicos'
  },
  {
    id: 'sET6RPGM0TEFDGIyxMWZ',
    nome: 'Dra. Mariana Castilho',
    crm: '122-SP',
    especialidade: 'Saúde Mental',
    tipo: 'Psicóloga / Saúde Mental'
  },
  {
    id: 'Xc7bTvyDQrSETcJQpsma',
    nome: 'Dr. Marcelo Fausto',
    crm: '122333-SP',
    especialidade: 'Geriatria',
    tipo: 'Atenção ao Idoso'
  },
  {
    id: '7TmpqDwmm7xZ3u2RnxRr',
    nome: 'Dra. Camila Rodrigues',
    crm: '334443/SP',
    especialidade: 'Pediatria',
    tipo: 'Puericultura & Saúde Infantil'
  },
  {
    id: 'atw3o9oMPxtWhTHZuWZc',
    nome: 'Dr. Lucas Vasconcelos',
    crm: '111114-SP',
    especialidade: 'Ginecologia e Obstetrícia',
    tipo: 'Pré-natal & Saúde da Mulher'
  },
  {
    id: '1U7uzL26dYhROXraqyql',
    nome: 'Enfª. Beatriz Alencar',
    crm: 'COREN 234512-SP',
    especialidade: 'Enfermagem',
    tipo: 'Acolhimento & Curativos'
  }
];

// Casos clínicos estruturados por ambiente de UBS
const CASOS_CLINICOS = [
  // Clínica Geral & Crônicos
  { esp: 'Clínica Geral', motivo: 'Acompanhamento de Hipertensão Arterial (HAS)', tipo: 'Retorno', dur: 20, pFaixa: 'baixo' },
  { esp: 'Clínica Geral', motivo: 'Controle de Diabetes Mellitus Tipo 2 com exames', tipo: 'Retorno', dur: 25, pFaixa: 'baixo' },
  { esp: 'Clínica Geral', motivo: 'Renovação de receituário de uso contínuo', tipo: 'Consulta Rápida', dur: 15, pFaixa: 'baixo' },
  { esp: 'Clínica Geral', motivo: 'Sintomas respiratórios agudos (febre e tosse)', tipo: 'Demanda Espontânea', dur: 20, pFaixa: 'medio' },
  { esp: 'Clínica Geral', motivo: 'Dor lombar mecânica pós-esforço', tipo: 'Consulta', dur: 20, pFaixa: 'medio' },
  { esp: 'Clínica Geral', motivo: 'Suspeita de Dengue / Síndrome Febril Aguda', tipo: 'Acolhimento', dur: 20, pFaixa: 'alto' },
  { esp: 'Clínica Geral', motivo: 'Atestado de aptidão física escolar / trabalho', tipo: 'Consulta de Rotina', dur: 15, pFaixa: 'baixo' },
  
  // Pediatria / Puericultura
  { esp: 'Pediatria', motivo: 'Puericultura 2 meses — Crescimento e desenvolvimento', tipo: 'Puericultura', dur: 30, pFaixa: 'baixo' },
  { esp: 'Pediatria', motivo: 'Puericultura 6 meses — Introdução alimentar e vacinas', tipo: 'Puericultura', dur: 30, pFaixa: 'baixo' },
  { esp: 'Pediatria', motivo: 'Puericultura 1 ano — Marcos motores e cognitivos', tipo: 'Puericultura', dur: 30, pFaixa: 'baixo' },
  { esp: 'Pediatria', motivo: 'Quadro de bronquiolite viral / sibilância', tipo: 'Demanda Espontânea', dur: 25, pFaixa: 'medio' },
  { esp: 'Pediatria', motivo: 'Otite média aguda e coriza hialina', tipo: 'Consulta', dur: 20, pFaixa: 'medio' },
  { esp: 'Pediatria', motivo: 'Avaliação de atraso vacinal infantil', tipo: 'Busca Ativa', dur: 20, pFaixa: 'alto' },

  // Ginecologia & Obstetrícia / Saúde da Mulher
  { esp: 'Ginecologia e Obstetrícia', motivo: 'Consulta Pré-natal 1º Trimestre (abertura de cartão)', tipo: 'Pré-natal', dur: 30, pFaixa: 'baixo' },
  { esp: 'Ginecologia e Obstetrícia', motivo: 'Consulta Pré-natal 2º Trimestre — USG morfológica', tipo: 'Pré-natal', dur: 25, pFaixa: 'baixo' },
  { esp: 'Ginecologia e Obstetrícia', motivo: 'Consulta Pré-natal 3º Trimestre — Rastreio EGB', tipo: 'Pré-natal', dur: 25, pFaixa: 'baixo' },
  { esp: 'Ginecologia e Obstetrícia', motivo: 'Coleta de preventivo citopatológico (Papanicolau)', tipo: 'Prevenção', dur: 20, pFaixa: 'medio' },
  { esp: 'Ginecologia e Obstetrícia', motivo: 'Planejamento familiar e aconselhamento contraceptivo', tipo: 'Consulta', dur: 20, pFaixa: 'baixo' },
  { esp: 'Ginecologia e Obstetrícia', motivo: 'Consulta de Puerpério (revisão de parto)', tipo: 'Pós-parto', dur: 25, pFaixa: 'alto' },

  // Geriatria / Idoso
  { esp: 'Geriatria', motivo: 'Avaliação multidimensional do idoso frágil', tipo: 'Consulta', dur: 30, pFaixa: 'medio' },
  { esp: 'Geriatria', motivo: 'Revisão de polifarmácia e interações medicamentosas', tipo: 'Retorno', dur: 25, pFaixa: 'baixo' },
  { esp: 'Geriatria', motivo: 'Queixa de tontura e histórico de quedas frequentes', tipo: 'Consulta', dur: 25, pFaixa: 'alto' },

  // Saúde Mental
  { esp: 'Saúde Mental', motivo: 'Acompanhamento de Transtorno de Ansiedade Generalizada', tipo: 'Acompanhamento', dur: 30, pFaixa: 'medio' },
  { esp: 'Saúde Mental', motivo: 'Episódio depressivo reativo / Suporte psicossocial', tipo: 'Acolhimento', dur: 30, pFaixa: 'alto' },
  { esp: 'Saúde Mental', motivo: 'Grupo de cessação de tabagismo — 3ª sessão', tipo: 'Grupo Terapêutico', dur: 45, pFaixa: 'alto' },

  // Enfermagem
  { esp: 'Enfermagem', motivo: 'Curativo especial de úlcera venosa crônica em MID', tipo: 'Procedimento', dur: 30, pFaixa: 'baixo' },
  { esp: 'Enfermagem', motivo: 'Avaliação de lesão trófica em pé diabético', tipo: 'Curativo / Cuidado', dur: 25, pFaixa: 'medio' },
  { esp: 'Enfermagem', motivo: 'Acolhimento com classificação de risco / Triagem', tipo: 'Acolhimento', dur: 15, pFaixa: 'alto' },
  { esp: 'Enfermagem', motivo: 'Testagem rápida IST (HIV, Sífilis e Hepatites B/C)', tipo: 'Rastreio', dur: 20, pFaixa: 'medio' }
];

const NOMES_PRIMEIROS_M = [
  'João', 'Lucas', 'Gabriel', 'Matheus', 'Pedro', 'Guilherme', 'Gustavo', 'Rafael',
  'Felipe', 'Leonardo', 'Rodrigo', 'Bruno', 'Tiago', 'Fernando', 'Carlos', 'Eduardo',
  'Marcos', 'Vinicius', 'Alexandre', 'Daniel', 'Marcelo', 'Henrique', 'Antônio', 'José',
  'Francisco', 'Manoel', 'Sebastião', 'Geraldo', 'Jorge', 'Paulo', 'Renato', 'Samuel'
];

const NOMES_PRIMEIROS_F = [
  'Maria', 'Ana', 'Juliana', 'Camila', 'Beatriz', 'Larissa', 'Mariana', 'Fernanda',
  'Aline', 'Letícia', 'Bruna', 'Amanda', 'Patrícia', 'Renata', 'Vanessa', 'Jéssica',
  'Carla', 'Natália', 'Carolina', 'Daniela', 'Tatiane', 'Priscila', 'Flávia', 'Roberta',
  'Francisca', 'Antônia', 'Lourdes', 'Aparecida', 'Tereza', 'Clara', 'Helena', 'Alice'
];

const SOBRENOMES = [
  'Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves', 'Pereira',
  'Lima', 'Gomes', 'Costa', 'Ribeiro', 'Martins', 'Carvalho', 'Almeida', 'Lopes',
  'Soares', 'Fernandes', 'Vieira', 'Barbosa', 'Rocha', 'Dias', 'Nascimento', 'Andrade',
  'Moreira', 'Nunes', 'Marques', 'Machado', 'Mendes', 'Freitas', 'Cardoso', 'Ramos'
];

function gerarNome(rng) {
  const fem = rng() > 0.5;
  const prim = fem
    ? NOMES_PRIMEIROS_F[Math.floor(rng() * NOMES_PRIMEIROS_F.length)]
    : NOMES_PRIMEIROS_M[Math.floor(rng() * NOMES_PRIMEIROS_M.length)];
  const sob1 = SOBRENOMES[Math.floor(rng() * SOBRENOMES.length)];
  const sob2 = SOBRENOMES[Math.floor(rng() * SOBRENOMES.length)];
  return `${prim} ${sob1} ${sob2}`;
}

function gerarCpf(rng) {
  const n = () => Math.floor(rng() * 10);
  return `${n()}${n()}${n()}.${n()}${n()}${n()}.${n()}${n()}${n()}-${n()}${n()}`;
}

function gerarTelefone(rng) {
  const n = () => Math.floor(rng() * 10);
  const ddd = ['11', '12', '19', '13'][Math.floor(rng() * 4)];
  return `(${ddd}) 9${n()}${n()}${n()}${n()}-${n()}${n()}${n()}${n()}`;
}

// Pseudo-RNG determinístico para reprodutibilidade
function createRng(seed) {
  let s = seed % 2147483647;
  if (s <= 0) s += 2147483646;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

async function runSeed() {
  console.log('Iniciando Seed de 1.000 consultas UBS em 30 dias...');
  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  const db = getFirestore(app);

  await signInWithEmailAndPassword(auth, 'admin.seed@vitta.app', 'SeedPassword123!');
  console.log('Autenticado com sucesso no Firebase.');

  const rng = createRng(425713);
  const agora = new Date(2026, 8, 2, 17, 30); // 2026-09-02 17:30
  const clinicRef = doc(db, 'tb_clinica', CLINIC_ID);

  // Distribuir 1000 consultas em 30 dias (de 25 dias atrás até 5 dias à frente)
  // Dias úteis recebem mais consultas (~35 a 45/dia), sábados menos (~15 a 20), domingos nenhum.
  const diasLista = [];
  for (let d = -DIAS_PASSADOS; d <= DIAS_FUTUROS; d++) {
    const dataDia = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate() + d);
    if (dataDia.getDay() === 0) continue; // Pula domingos (UBS fechada)
    diasLista.push({
      data: dataDia,
      offset: d,
      sabado: dataDia.getDay() === 6
    });
  }

  // Aloca consultas proporcionalmente aos dias
  const consultasPorDia = [];
  let totalAlocado = 0;
  for (const diaInfo of diasLista) {
    const peso = diaInfo.sabado ? 1 : 2.5;
    consultasPorDia.push({ ...diaInfo, peso, count: 0 });
  }
  const pesoTotal = consultasPorDia.reduce((acc, x) => acc + x.peso, 0);
  for (const diaInfo of consultasPorDia) {
    diaInfo.count = Math.round((diaInfo.peso / pesoTotal) * TOTAL_CONSULTAS);
    totalAlocado += diaInfo.count;
  }
  // Ajusta diferença de arredondamento
  consultasPorDia[0].count += (TOTAL_CONSULTAS - totalAlocado);

  console.log(`Dias de atendimento calculados: ${consultasPorDia.length} dias para ${TOTAL_CONSULTAS} consultas.`);

  const agendamentos = [];
  let globalIndex = 0;

  for (const diaInfo of consultasPorDia) {
    const dia = diaInfo.data;
    const isPassado = diaInfo.offset < 0;
    const isHoje = diaInfo.offset === 0;
    const isFuturo = diaInfo.offset > 0;

    for (let k = 0; k < diaInfo.count; k++) {
      globalIndex++;
      const id = `ubs_${String(globalIndex).padStart(4, '0')}`;
      
      // Sorteia caso clínico
      const caso = CASOS_CLINICOS[Math.floor(rng() * CASOS_CLINICOS.length)];
      
      // Seleciona profissional correspondente ou mais próximo
      const profCompativeis = PROFISSIONAIS.filter(p => p.especialidade === caso.esp);
      const prof = profCompativeis.length > 0
        ? profCompativeis[Math.floor(rng() * profCompativeis.length)]
        : PROFISSIONAIS[Math.floor(rng() * PROFISSIONAIS.length)];

      // Horário da consulta (07:30 às 17:00 em dias de semana, 08:00 às 12:00 aos sábados)
      const horaMin = diaInfo.sabado ? 8 : 7;
      const horaMax = diaInfo.sabado ? 12 : 17;
      const hora = horaMin + Math.floor(rng() * (horaMax - horaMin));
      const minuto = [0, 15, 30, 45][Math.floor(rng() * 4)];
      const dataConsulta = new Date(dia.getFullYear(), dia.getMonth(), dia.getDate(), hora, minuto);

      // Probabilidade e Faixa de Risco com dispersão natural
      let prob, riscoLabel;
      const uRisco = rng();
      if (caso.pFaixa === 'baixo') {
        prob = 0.05 + rng() * 0.12; // 0.05 a 0.17
      } else if (caso.pFaixa === 'alto') {
        prob = 0.36 + rng() * 0.40; // 0.36 a 0.76
      } else {
        prob = 0.16 + rng() * 0.19; // 0.16 a 0.35
      }
      
      // Classifica em rótulo padrão
      if (prob >= 0.35) riscoLabel = 'alto';
      else if (prob >= 0.16) riscoLabel = 'médio';
      else riscoLabel = 'baixo';

      // Determina desfecho / status
      let status;
      if (isPassado) {
        const roll = rng();
        if (roll < prob) {
          // Faltou
          status = 'faltou';
        } else if (roll < prob + 0.08) {
          // Cancelou com aviso prévio
          status = 'cancelado';
        } else {
          // Compareceu / atendido
          status = rng() > 0.3 ? 'realizado' : 'atendido';
        }
      } else if (isHoje) {
        // Hoje: consultas de manhã já realizadas, da tarde confirmadas
        if (hora < 13) {
          status = rng() < prob ? 'faltou' : 'realizado';
        } else {
          status = 'confirmado';
        }
      } else {
        // Futuro: confirmados e pré-agendados
        status = rng() > 0.25 ? 'confirmado' : 'pre-agendado';
      }

      const nomePaciente = gerarNome(rng);
      const cpf = gerarCpf(rng);
      const tel = gerarTelefone(rng);
      const medRef = doc(db, 'tb_medicos', prof.id);
      const pacId = `pac_ubs_${(globalIndex % 400) + 1}`;

      agendamentos.push({
        id,
        idClinica: clinicRef,
        idclinica: clinicRef,
        idMedico: medRef,
        idPaciente: pacId,
        nomePaciente,
        cpf,
        telefonePaciente: tel,
        nomeMedico: prof.nome,
        especialidade: caso.esp,
        dataConsulta,
        duracao: caso.dur,
        status,
        tipoConsulta: caso.tipo,
        modalidade: 'Presencial',
        localConsulta: `UBS Centro — Consultório ${(globalIndex % 6) + 1}`,
        motivoConsulta: caso.motivo,
        probabilidade_falta: parseFloat(prob.toFixed(4)),
        risco_falta: riscoLabel,
        isFake: true,
        fakeBatchId: FAKE_BATCH_ID
      });
    }
  }

  console.log(`Gerados ${agendamentos.length} agendamentos. Iniciando persistência em lotes (batch)...`);

  // Grava em lotes de 400 (limite Firestore é 500)
  const BATCH_SIZE = 400;

  for (let i = 0; i < agendamentos.length; i += BATCH_SIZE) {
    const chunk = agendamentos.slice(i, i + BATCH_SIZE);
    
    // Batch 1: tb_agendamentos
    const batchAg = writeBatch(db);
    for (const a of chunk) {
      const ref = doc(db, 'tb_agendamentos', a.id);
      batchAg.set(ref, {
        idClinica: a.idClinica,
        idclinica: a.idclinica,
        idMedico: a.idMedico,
        idPaciente: a.idPaciente,
        nomePaciente: a.nomePaciente,
        cpf: a.cpf,
        telefonePaciente: a.telefonePaciente,
        nomeMedico: a.nomeMedico,
        especialidade: a.especialidade,
        dataConsulta: Timestamp.fromDate(a.dataConsulta),
        duracao: a.duracao,
        status: a.status,
        tipoConsulta: a.tipoConsulta,
        modalidade: a.modalidade,
        localConsulta: a.localConsulta,
        motivoConsulta: a.motivoConsulta,
        probabilidade_falta: a.probabilidade_falta,
        risco_falta: a.risco_falta,
        isFake: a.isFake,
        fakeBatchId: a.fakeBatchId,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now()
      });
    }
    await batchAg.commit();
    console.log(`Gravados ${i + chunk.length} de ${agendamentos.length} em tb_agendamentos.`);

    // Batch 2: dashboard_risco
    const batchDash = writeBatch(db);
    for (const a of chunk) {
      const ref = doc(db, 'dashboard_risco', `dash_${a.id}`);
      batchDash.set(ref, {
        appointmentId: a.id,
        clinica: CLINIC_ID,
        paciente: a.nomePaciente,
        medico: a.nomeMedico,
        risco: a.probabilidade_falta,
        riscoPercent: Math.round(a.probabilidade_falta * 100),
        riscoLabel: a.risco_falta,
        statusConsulta: a.status,
        dataConsulta: a.dataConsulta.toISOString(),
        timestampConsulta: Timestamp.fromDate(a.dataConsulta),
        createdAt: Timestamp.now()
      });
    }
    await batchDash.commit();
    console.log(`Gravados ${i + chunk.length} de ${agendamentos.length} em dashboard_risco.`);

    // Batch 3: tb_faltas_data
    const batchFaltas = writeBatch(db);
    for (const a of chunk) {
      const ref = doc(db, 'tb_faltas_data', `falta_${a.id}`);
      batchFaltas.set(ref, {
        _debug_agendamentoId: a.id,
        _debug_clinicId: CLINIC_ID,
        idConsulta: doc(db, 'tb_agendamentos', a.id),
        idclinica: clinicRef,
        data_consulta: Timestamp.fromDate(a.dataConsulta),
        probabilidade_falta: a.probabilidade_falta,
        risco_falta: a.risco_falta,
        valor_predicao: a.probabilidade_falta,
        processado: true,
        createdAt: Timestamp.now()
      });
    }
    await batchFaltas.commit();
    console.log(`Gravados ${i + chunk.length} de ${agendamentos.length} em tb_faltas_data.`);
  }

  console.log('\n========================================================');
  console.log(`SUCESSO! 1.000 consultas de UBS inseridas com sucesso!`);
  console.log(`Período coberto: 30 dias (25 dias históricos + hoje + 5 dias futuros)`);
  console.log(`Batch ID: ${FAKE_BATCH_ID}`);
  console.log('========================================================\n');
  process.exit(0);
}

runSeed().catch(err => {
  console.error('Falha na execução do seed:', err);
  process.exit(1);
});
