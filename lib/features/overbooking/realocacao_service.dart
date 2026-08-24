import 'package:cloud_firestore/cloud_firestore.dart';

import 'overbooking_models.dart';

/// Persistência da realocação de overbooking no servidor (AGENTS.md OVB-05.6):
/// fila `queue_realoc`, auditoria `tb_overbooking_events` e Tarefas Agendadas
/// `tb_scheduled_tasks` (executadas pelo `scheduledTasksCron`, com o app fechado).
///
/// Todas as operações são **best-effort**: em offline/mock nada é persistido e a
/// UI segue funcionando com o estado local.
abstract class RealocacaoService {
  /// Cria/atualiza a proposta na fila `queue_realoc` (id = agendamento origem).
  Future<void> upsertProposta(String clinicId, RealocacaoProposta p);

  /// Registra uma decisão na auditoria `tb_overbooking_events`.
  Future<void> logEvento(String clinicId, DecisaoOverbooking d);

  /// Enfileira uma Tarefa Agendada (`tb_scheduled_tasks`) para o cron efetivar a
  /// realocação no servidor e notificar o paciente com o novo horário.
  Future<void> enqueueTask(String clinicId, RealocacaoProposta p);
}

/// Implementação offline/testes — não persiste nada.
class MockRealocacaoService implements RealocacaoService {
  const MockRealocacaoService();

  @override
  Future<void> upsertProposta(String clinicId, RealocacaoProposta p) async {}

  @override
  Future<void> logEvento(String clinicId, DecisaoOverbooking d) async {}

  @override
  Future<void> enqueueTask(String clinicId, RealocacaoProposta p) async {}
}

// ─────────────────────── Mapeamento (puro, testável) ───────────────────────
//
// As funções abaixo montam o payload SEM depender de `Timestamp`: datas ficam
// como `DateTime` e a camada Firestore as converte na escrita. Assim o mapa é
// testável sem inicializar o Firebase.

/// Documento da fila `queue_realoc` para uma proposta.
Map<String, dynamic> realocQueueDoc(String clinicId, RealocacaoProposta p) => {
      'idclinica': clinicId,
      'agendamentoOrigemId': p.appointmentId,
      'pacienteNome': p.patientName,
      'risco': p.patientRisk.name,
      'medicoDestinoId': p.doctorId,
      'medicoDestinoNome': p.doctorName,
      'especialidade': p.specialty,
      'slotOrigem': p.slotOrigem,
      'slotDestino': p.slotDestino,
      'motivo': p.motivoDestino,
      'canal': p.canal.name,
      'status': p.status.name,
      'emailStatus': p.emailStatus.name,
      if (p.emailEnviadoEm != null) 'emailEnviadoEm': p.emailEnviadoEm,
      'origem': 'app',
    };

/// Documento de auditoria `tb_overbooking_events` para uma decisão.
Map<String, dynamic> overbookingEventDoc(
        String clinicId, DecisaoOverbooking d) =>
    {
      'idclinica': clinicId,
      'ator': d.ator,
      'texto': d.texto,
      // `decisao` é filtrável pelo MCP `listar_eventos_overbooking`.
      'decisao': 'realocacao',
      'at': d.at,
      'origem': 'app',
    };

/// Documento de Tarefa Agendada `tb_scheduled_tasks` para efetivar no servidor.
Map<String, dynamic> scheduledTaskDoc(
    String clinicId, RealocacaoProposta p, DateTime now) {
  final quando = '${p.slotDestino.day.toString().padLeft(2, '0')}/'
      '${p.slotDestino.month.toString().padLeft(2, '0')} '
      '${p.slotDestino.hour.toString().padLeft(2, '0')}:'
      '${p.slotDestino.minute.toString().padLeft(2, '0')}';
  return {
    'kind': 'realocacao_overbooking',
    'status': 'active',
    'clinicaId': clinicId,
    'idclinica': clinicId,
    'titulo': 'Realocar ${p.patientName}',
    'prompt': 'Realoque o paciente ${p.patientName} (agendamento '
        '${p.appointmentId}) para $quando com ${p.doctorName} '
        '(${p.specialty}). Atualize o status do agendamento de origem para '
        'reagendado, crie o novo horário e envie o e-mail de confirmação de '
        'overbooking com o novo horário ao paciente.',
    'nextRunAt': now,
    'origem': 'app',
  };
}

/// Implementação Firestore — escreve escopado por `idclinica` (SOP CUSTO.md).
class FirestoreRealocacaoService implements RealocacaoService {
  FirestoreRealocacaoService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Converte `DateTime` → `Timestamp` e injeta `createdAt`/`updatedAt`.
  Map<String, dynamic> _prepare(Map<String, dynamic> m) => {
        for (final e in m.entries)
          e.key: e.value is DateTime
              ? Timestamp.fromDate(e.value as DateTime)
              : e.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  @override
  Future<void> upsertProposta(String clinicId, RealocacaoProposta p) async {
    if (clinicId.isEmpty) return;
    await _db
        .collection('queue_realoc')
        .doc(p.appointmentId)
        .set(_prepare(realocQueueDoc(clinicId, p)), SetOptions(merge: true));
  }

  @override
  Future<void> logEvento(String clinicId, DecisaoOverbooking d) async {
    if (clinicId.isEmpty) return;
    await _db
        .collection('tb_overbooking_events')
        .add(_prepare(overbookingEventDoc(clinicId, d)));
  }

  @override
  Future<void> enqueueTask(String clinicId, RealocacaoProposta p) async {
    if (clinicId.isEmpty) return;
    // Id determinístico evita duplicar a tarefa para o mesmo agendamento.
    await _db
        .collection('tb_scheduled_tasks')
        .doc('realoc_${p.appointmentId}')
        .set(
          {
            ..._prepare(scheduledTaskDoc(clinicId, p, DateTime.now())),
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }
}
