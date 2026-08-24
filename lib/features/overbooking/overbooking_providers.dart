import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/appointment.dart';
import '../../core/services/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../notificacoes_centro/notificacoes_provider.dart';
import 'overbooking_engine.dart';
import 'overbooking_models.dart';
import 'realocacao_service.dart';

/// Data selecionada no painel de overbooking (◀ Hoje ▶).
final overbookingDateProvider = StateProvider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

/// Snapshot reativo do dia (OVB-02/03): recalcula sempre que a data, os médicos
/// da clínica ou os agendamentos mudam — atualização em tempo real, sem refresh.
final overbookingSnapshotProvider = Provider<OverbookingSnapshot>((ref) {
  final date = ref.watch(overbookingDateProvider);
  final doctors =
      ref.watch(clinicDoctorsProvider).where((d) => d.active).toList();
  final appts = ref.watch(appointmentsProvider);
  return OverbookingEngine.build(
    date: date,
    doctors: doctors,
    allAppointments: appts,
  );
});

/// Modo de operação do motor de realocação (OVB-05.4).
enum RealocacaoModo {
  sugestao('Sugestão'),
  semiAutomatico('Semi-automático'),
  automatico('Automático');

  const RealocacaoModo(this.label);
  final String label;
}

final realocacaoModoProvider =
    StateProvider<RealocacaoModo>((ref) => RealocacaoModo.sugestao);

/// Serviço de persistência da realocação (OVB-05.6). Padrão: mock (offline).
/// Em `main` é sobrescrito por [FirestoreRealocacaoService] com Firebase ativo.
final realocacaoServiceProvider =
    Provider<RealocacaoService>((ref) => const MockRealocacaoService());

/// Estado da fila de realocação: propostas por agendamento + trilha de decisões.
class RealocacaoState {
  const RealocacaoState({
    this.propostas = const {},
    this.decisoes = const [],
  });

  final Map<String, RealocacaoProposta> propostas;
  final List<DecisaoOverbooking> decisoes;

  RealocacaoState copyWith({
    Map<String, RealocacaoProposta>? propostas,
    List<DecisaoOverbooking>? decisoes,
  }) {
    return RealocacaoState(
      propostas: propostas ?? this.propostas,
      decisoes: decisoes ?? this.decisoes,
    );
  }
}

/// Notifier que executa as ações de realocação (OVB-05): sugerir, enviar o
/// e-mail de overbooking com o novo horário, confirmar/aplicar, recusar,
/// desfazer — registrando cada passo na trilha de auditoria (OVB-06).
class RealocacaoNotifier extends StateNotifier<RealocacaoState> {
  RealocacaoNotifier(this.ref) : super(const RealocacaoState());

  final Ref ref;

  RealocacaoService get _service => ref.read(realocacaoServiceProvider);
  String get _clinicId => ref.read(selectedClinicIdProvider);

  /// Emite uma notificação in-app na Central de Notificações (R3).
  void _notify(String title, String message) => ref
      .read(notificacoesProvider.notifier)
      .push(
          type: NotificationType.overbooking, title: title, message: message);

  void _log(String texto, IconData icon, Color cor, {String ator = 'Motor'}) {
    final decisao = DecisaoOverbooking(
      at: DateTime.now(),
      ator: ator,
      texto: texto,
      icon: icon,
      cor: cor,
    );
    state = state.copyWith(decisoes: [decisao, ...state.decisoes]);
    // Auditoria no servidor (best-effort; no-op offline).
    unawaited(_service.logEvento(_clinicId, decisao));
  }

  void _put(RealocacaoProposta p) {
    state = state.copyWith(propostas: {...state.propostas, p.appointmentId: p});
    // Espelha a proposta na fila `queue_realoc` (best-effort; no-op offline).
    unawaited(_service.upsertProposta(_clinicId, p));
  }

  String _hhmm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Cria uma proposta a partir de um candidato do motor (OVB-05.5).
  void sugerir(SlotSobrecarga slot, CandidatoRealoc cand,
      {RealoCanal canal = RealoCanal.email}) {
    final a = cand.appointment;
    final destino = cand.destino;
    if (destino == null) return;
    final proposta = RealocacaoProposta(
      appointmentId: a.id,
      patientName: a.patientName,
      patientRisk: a.patientRisk,
      doctorId: slot.doctorId,
      doctorName: slot.doctorName,
      specialty: slot.specialty,
      crm: slot.doctorCrm,
      slotOrigem: a.start,
      slotDestino: destino,
      motivoDestino: cand.motivo,
      canal: a.patientPhone.isNotEmpty && canal == RealoCanal.email
          ? canal
          : canal,
      status: RealocacaoStatus.sugerida,
      emailStatus: RealoEmailStatus.naoEnviado,
      criadaEm: DateTime.now(),
    );
    _put(proposta);
    _log(
      'Slot ${slot.doctorName} ${slot.hour.toString().padLeft(2, '0')}:00 em '
      'estouro (${slot.booked}/${slot.capacity}). Sugerido realocar '
      '${a.patientName} → ${_hhmm(destino)}.',
      Icons.auto_awesome,
      AppColors.warning,
    );
  }

  /// Gera propostas para todos os candidatos do snapshot (ainda não tratados).
  void sugerirTodos(List<SlotSobrecarga> slots) {
    for (final s in slots) {
      for (final c in s.candidatos) {
        if (c.destino != null && !state.propostas.containsKey(c.appointment.id)) {
          sugerir(s, c);
        }
      }
    }
  }

  /// Envia o **e-mail de overbooking** com o novo horário (OVB-05.7). Dispara o
  /// serviço real (best-effort) e marca o status ao vivo no card.
  Future<void> enviarEmail(String id) async {
    final p = state.propostas[id];
    if (p == null) return;
    final appt = _apptById(id);
    _put(p.copyWith(
      status: RealocacaoStatus.aguardandoConfirmacao,
      emailStatus: RealoEmailStatus.enviado,
      emailEnviadoEm: DateTime.now(),
    ));
    _log(
      'E-mail de overbooking enviado a ${p.patientName} com o novo horário '
      '${_hhmm(p.slotDestino)} (${p.canal.label}).',
      Icons.mark_email_read_outlined,
      AppColors.primary,
      ator: 'Recepção',
    );
    _notify('E-mail de overbooking enviado',
        '${p.patientName} → novo horário ${_hhmm(p.slotDestino)}.');
    if (appt != null) {
      final clinicName = ref.read(selectedClinicProvider).name;
      final destinoAppt = appt.copyWith(start: p.slotDestino);
      // Best-effort: em dev/offline pode falhar; o fluxo segue simulado.
      try {
        await ref.read(emailServiceProvider).sendConfirmation(
              to: _emailFor(appt),
              appointment: destinoAppt,
              isReschedule: true,
              clinicName: clinicName,
            );
      } catch (_) {/* mantém status enviado */}
    }
  }

  /// Efetiva a realocação: remarca o agendamento para o novo horário e conclui
  /// a proposta (OVB-05: confirmar/aplicar).
  void aplicar(String id, {bool confirmadoPeloPaciente = false}) {
    final p = state.propostas[id];
    if (p == null) return;
    ref.read(appointmentsProvider.notifier).move(
          id,
          start: p.slotDestino,
          doctorId: p.doctorId,
          doctorName: p.doctorName,
          specialty: p.specialty,
          crm: p.crm,
        );
    _put(p.copyWith(
      status: RealocacaoStatus.concluida,
      emailStatus: confirmadoPeloPaciente
          ? RealoEmailStatus.confirmado
          : p.emailStatus,
    ));
    _log(
      '${p.patientName} realocado(a) para ${_hhmm(p.slotDestino)} com '
      '${p.doctorName}. Vaga de overbooking normalizada.',
      Icons.check_circle_outline,
      AppColors.success,
      ator: confirmadoPeloPaciente ? 'Paciente' : 'Gestor',
    );
    _notify('Realocação concluída',
        '${p.patientName} realocado(a) para ${_hhmm(p.slotDestino)} com ${p.doctorName}.');
  }

  void recusar(String id) {
    final p = state.propostas[id];
    if (p == null) return;
    _put(p.copyWith(
      status: RealocacaoStatus.recusada,
      emailStatus: RealoEmailStatus.recusado,
    ));
    _log('${p.patientName} recusou a realocação. Voltando para tratamento '
        'manual.', Icons.cancel_outlined, AppColors.danger, ator: 'Paciente');
  }

  void alterarDestino(String id, DateTime novo) {
    final p = state.propostas[id];
    if (p == null) return;
    _put(p.copyWith(
      slotDestino: novo,
      motivoDestino: 'Horário ajustado manualmente',
    ));
    _log('Horário destino de ${p.patientName} ajustado para ${_hhmm(novo)}.',
        Icons.edit_calendar_outlined, AppColors.primary, ator: 'Gestor');
  }

  void alterarCanal(String id, RealoCanal canal) {
    final p = state.propostas[id];
    if (p == null) return;
    _put(p.copyWith(canal: canal));
  }

  /// Delega a efetivação ao servidor: enfileira uma Tarefa Agendada
  /// (`tb_scheduled_tasks`) para o `scheduledTasksCron` realocar e notificar o
  /// paciente mesmo com o app fechado (OVB-05.6). Best-effort/no-op offline.
  Future<void> delegarAoServidor(String id) async {
    final p = state.propostas[id];
    if (p == null) return;
    _put(p.copyWith(status: RealocacaoStatus.aguardandoConfirmacao));
    _log(
      'Realocação de ${p.patientName} delegada ao servidor (Tarefa Agendada). '
      'O cron efetivará e notificará o novo horário.',
      Icons.cloud_upload_outlined,
      AppColors.primary,
      ator: 'Gestor',
    );
    try {
      await _service.enqueueTask(_clinicId, p);
    } catch (_) {/* offline/sem permissão: fica só a proposta local */}
  }

  void descartar(String id) {
    final next = {...state.propostas}..remove(id);
    state = state.copyWith(propostas: next);
  }

  Appointment? _apptById(String id) {
    for (final a in ref.read(appointmentsProvider)) {
      if (a.id == id) return a;
    }
    return null;
  }

  // Os agendamentos mock não têm e-mail do paciente; usa um derivado estável
  // para o fluxo (em produção vem de `tb_agendamentos.emailPaciente`).
  String _emailFor(Appointment a) {
    if (a.patientName.trim().isEmpty) return '';
    final slug = a.patientName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '.');
    return '$slug@paciente.local';
  }
}

final realocacaoProvider =
    StateNotifierProvider<RealocacaoNotifier, RealocacaoState>(
        (ref) => RealocacaoNotifier(ref));
