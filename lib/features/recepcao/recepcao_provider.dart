import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/announcement.dart';
import 'models/call_record.dart';
import 'models/care_line.dart';
import 'models/manchester_priority.dart';
import 'models/queue_entry.dart';
import 'models/timeline_event.dart';
import 'models/vital_signs.dart';

class RecepcaoState {
  const RecepcaoState({
    required this.entries,
    required this.announcements,
    this.currentSenha,
    this.currentName,
    this.servedToday = 0,
    this.nextNumber = 1,
    this.calledHistory = const [],
    this.callTick = 0,
  });

  final List<QueueEntry> entries;
  final List<Announcement> announcements;
  final String? currentSenha;
  final String? currentName;
  final int servedToday;
  final int nextNumber;

  /// Histórico de chamadas exibido no Monitor da Recepção (mais recente primeiro).
  final List<CallRecord> calledHistory;

  /// Incrementa a cada chamada/rechamada — dispara a locução no monitor.
  final int callTick;

  CallRecord? get currentCall =>
      calledHistory.isEmpty ? null : calledHistory.first;

  List<QueueEntry> get waiting =>
      entries.where((e) => e.status == QueueStatus.waiting).toList();

  List<QueueEntry> get inService =>
      entries.where((e) => e.status == QueueStatus.inService || e.status == QueueStatus.called).toList();

  List<QueueEntry> get done =>
      entries.where((e) => e.status == QueueStatus.done).toList();

  List<QueueEntry> get myPatients =>
      entries.where((e) => e.assignedTo != null && e.assignedTo!.contains('Admin')).toList();

  /// Fila de espera ordenada por risco Manchester e depois por chegada (§1.3).
  List<QueueEntry> get triagedQueue {
    final list = waiting.toList()
      ..sort((a, b) {
        final byRisk = a.manchester.index.compareTo(b.manchester.index);
        if (byRisk != 0) return byRisk;
        // Atendimento prioritário (idoso/gestante/PcD) primeiro no mesmo risco.
        if (a.priority != b.priority) return a.priority ? -1 : 1;
        return a.checkInAt.compareTo(b.checkInAt);
      });
    return list;
  }

  /// Contagem de pacientes em espera por cor de risco (para o painel).
  Map<ManchesterPriority, int> get riskCounts {
    final map = {for (final p in ManchesterPriority.values) p: 0};
    for (final e in waiting) {
      map[e.manchester] = (map[e.manchester] ?? 0) + 1;
    }
    return map;
  }

  RecepcaoState copyWith({
    List<QueueEntry>? entries,
    List<Announcement>? announcements,
    String? currentSenha,
    String? currentName,
    int? servedToday,
    int? nextNumber,
    List<CallRecord>? calledHistory,
    int? callTick,
  }) {
    return RecepcaoState(
      entries: entries ?? this.entries,
      announcements: announcements ?? this.announcements,
      currentSenha: currentSenha ?? this.currentSenha,
      currentName: currentName ?? this.currentName,
      servedToday: servedToday ?? this.servedToday,
      nextNumber: nextNumber ?? this.nextNumber,
      calledHistory: calledHistory ?? this.calledHistory,
      callTick: callTick ?? this.callTick,
    );
  }
}

class RecepcaoNotifier extends StateNotifier<RecepcaoState> {
  RecepcaoNotifier() : super(_seed());

  static final _rng = Random();

  static String _senha(int n) => 'A${n.toString().padLeft(3, '0')}';

  /// Protocolo no formato `YYMMDD + Random(1000-9999)` (§1.3).
  static String _protocol([DateTime? when]) {
    final d = when ?? DateTime.now();
    final ymd =
        '${(d.year % 100).toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final rand = 1000 + _rng.nextInt(9000);
    return '$ymd$rand';
  }

  static RecepcaoState _seed() {
    final now = DateTime.now();
    final entries = <QueueEntry>[
      QueueEntry(
        id: 'q1',
        senha: _senha(1),
        protocol: _protocol(now),
        patientName: 'Ricardo Dias',
        specialty: 'TRIAGEM GERAL',
        doctorName: 'A definir',
        assignedTo: null,
        checkInAt: now.subtract(const Duration(minutes: 12)),
        status: QueueStatus.waiting,
        manchester: ManchesterPriority.orange,
        attendanceType: AttendanceType.espontanea,
        careLine: CareLine.geral,
        microarea: '03',
        acs: 'Joana ACS',
        vitals: const VitalSigns(
            paSistolica: 185, paDiastolica: 110, fc: 98, dor: 7, satO2: 96),
        origin: 'BALCÃO',
        photoUrl: 'https://i.pravatar.cc/200?img=12',
      ),
      QueueEntry(
        id: 'q2',
        senha: _senha(2),
        protocol: _protocol(now),
        patientName: 'Letícia Lima',
        specialty: 'PRÉ-NATAL',
        doctorName: 'A definir',
        checkInAt: now.subtract(const Duration(minutes: 35)),
        status: QueueStatus.waiting,
        manchester: ManchesterPriority.yellow,
        attendanceType: AttendanceType.agendada,
        careLine: CareLine.preNatal,
        microarea: '01',
        acs: 'Pedro ACS',
        vitals: const VitalSigns(paSistolica: 120, paDiastolica: 80, fc: 84),
        origin: 'BALCÃO',
        scheduledAt: now.add(const Duration(seconds: 40)),
        photoUrl: 'https://i.pravatar.cc/200?img=45',
      ),
      QueueEntry(
        id: 'q3',
        senha: _senha(3),
        protocol: _protocol(now),
        patientName: 'Carlos Eduardo',
        specialty: 'HIPERDIA',
        doctorName: 'Você (Admin)',
        assignedTo: 'Você (Admin)',
        checkInAt: now.subtract(const Duration(minutes: 8)),
        status: QueueStatus.inService,
        manchester: ManchesterPriority.yellow,
        attendanceType: AttendanceType.agendada,
        careLine: CareLine.hiperdia,
        microarea: '02',
        acs: 'Joana ACS',
        vitals: const VitalSigns(glicemia: 260, paSistolica: 150, paDiastolica: 95),
        origin: 'BALCÃO',
      ),
      QueueEntry(
        id: 'q4',
        senha: _senha(4),
        protocol: _protocol(now),
        patientName: 'Aline Souza',
        specialty: 'PUERICULTURA',
        doctorName: 'Maria Silva',
        assignedTo: 'Maria Silva',
        checkInAt: now.subtract(const Duration(minutes: 90)),
        status: QueueStatus.done,
        manchester: ManchesterPriority.green,
        attendanceType: AttendanceType.agendada,
        careLine: CareLine.puericultura,
        microarea: '01',
        acs: 'Pedro ACS',
        origin: 'BALCÃO',
      ),
      QueueEntry(
        id: 'q5',
        senha: _senha(5),
        protocol: _protocol(now),
        patientName: 'Bernardo Costa',
        specialty: 'SAÚDE MENTAL',
        doctorName: 'Você (Admin)',
        assignedTo: 'Você (Admin)',
        checkInAt: now.subtract(const Duration(minutes: 50)),
        status: QueueStatus.waiting,
        manchester: ManchesterPriority.green,
        attendanceType: AttendanceType.espontanea,
        careLine: CareLine.saudeMental,
        microarea: '04',
        acs: 'Lucas ACS',
        origin: 'BALCÃO',
      ),
    ];

    final announcements = [
      Announcement(
        id: '1',
        author: 'SEED',
        authorType: 'SEED',
        message: 'A reunião de equipe acontece na primeira quinta do mês, às 19h, na sala 3.',
        createdAt: now.subtract(const Duration(days: 4, hours: 3)),
      ),
      Announcement(
        id: '2',
        author: 'ALERTA: EDUARDO',
        authorType: 'ALERTA',
        message: 'Sistema com problema',
        createdAt: now.subtract(const Duration(days: 35, hours: 2)),
      ),
      Announcement(
        id: '3',
        author: 'TREINAMENTO DE ACOLHIMENTO HOJE ÀS 14H',
        authorType: 'TREINAMENTO',
        message: 'Capacitação em Acolhimento com Classificação de Risco (Protocolo Manchester) para a equipe.',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
    ];

    return RecepcaoState(
        entries: entries, announcements: announcements, nextNumber: entries.length + 1);
  }

  /// Acolhimento completo: cria o ticket com classificação de risco, vitais,
  /// linha de cuidado, tipo de demanda e vínculo eSF. Retorna o ticket criado.
  QueueEntry checkInAcolhimento({
    required String name,
    required String specialty,
    required ManchesterPriority manchester,
    VitalSigns vitals = const VitalSigns(),
    CareLine careLine = CareLine.geral,
    AttendanceType attendanceType = AttendanceType.espontanea,
    String microarea = '',
    String acs = '',
    bool priority = false,
    String origin = 'BALCÃO',
  }) {
    final now = DateTime.now();
    final senha = _senha(state.nextNumber);
    final entry = QueueEntry(
      id: 'q${now.microsecondsSinceEpoch}',
      senha: senha,
      protocol: _protocol(now),
      patientName: name.trim().isEmpty ? 'Senha $senha' : name.trim(),
      specialty: specialty,
      doctorName: 'A definir',
      checkInAt: now,
      status: QueueStatus.waiting,
      manchester: manchester,
      vitals: vitals,
      careLine: careLine,
      attendanceType: attendanceType,
      microarea: microarea,
      acs: acs,
      priority: priority,
      origin: origin,
      timeline: [
        TimelineEvent(
          action: origin == 'TOTEM' ? 'Senha retirada no totem' : 'Acolhimento',
          timestamp: now,
          details:
              '${careLine.label} • ${attendanceType.label}${priority ? ' • PRIORITÁRIO' : ''}',
        ),
      ],
    );
    state = state.copyWith(
      entries: [...state.entries, entry],
      nextNumber: state.nextNumber + 1,
    );
    return entry;
  }

  /// Atalho legado mantido para chamadas simples.
  void checkIn({
    required String name,
    String specialty = 'TRIAGEM GERAL',
    String doctor = 'A definir',
  }) {
    checkInAcolhimento(
        name: name, specialty: specialty, manchester: ManchesterPriority.green);
  }

  /// Reclassifica o risco de um ticket, registrando na timeline.
  void reclassify(String id, ManchesterPriority priority) {
    final now = DateTime.now();
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.id == id)
            e.copyWith(
              manchester: priority,
              timeline: [
                ...e.timeline,
                TimelineEvent(
                  action: 'Reclassificação de risco',
                  timestamp: now,
                  details: 'Novo nível: ${priority.label}',
                ),
              ],
            )
          else
            e,
      ],
    );
  }

  /// Encaminha (referência) o paciente para outra unidade (UPA/hospital),
  /// registrando o destino na timeline e finalizando o atendimento local.
  void refer(String id, String destino, {String motivo = ''}) {
    final now = DateTime.now();
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.id == id)
            e.copyWith(
              status: QueueStatus.done,
              referral: destino,
              timeline: [
                ...e.timeline,
                TimelineEvent(
                  action: 'Encaminhado (Referência)',
                  timestamp: now,
                  details: motivo.isEmpty ? destino : '$destino — $motivo',
                ),
              ],
            )
          else
            e,
      ],
      servedToday: state.servedToday + 1,
    );
  }

  void resetAndPopulate() {
    state = _seed();
  }

  void clearAll() {
    state = state.copyWith(entries: [], announcements: [], nextNumber: 1, currentName: null, currentSenha: null, servedToday: 0);
  }

  /// Chama o próximo da fila triada (maior risco / mais antigo).
  void callNext() {
    final queue = state.triagedQueue;
    if (queue.isEmpty) return;
    callEntry(queue.first.id);
  }

  /// Chama um paciente específico (usado pela fila e pela chamada automática).
  void callEntry(String id) {
    final match = state.entries.where((e) => e.id == id);
    if (match.isEmpty) return;
    final next = match.first;
    if (next.status != QueueStatus.waiting) return;

    final now = DateTime.now();
    const attendant = 'Você (Admin)';
    final updated = [
      for (final e in state.entries)
        if (e.id == next.id)
          e.copyWith(
            status: QueueStatus.called,
            assignedTo: attendant,
            timeline: [
              ...e.timeline,
              TimelineEvent(action: 'Chamado', timestamp: now),
            ],
          )
        else if (e.status == QueueStatus.called)
          e.copyWith(status: QueueStatus.inService)
        else
          e,
    ];
    final record = CallRecord(
      senha: next.senha,
      patientName: next.patientName,
      local: next.specialty,
      attendant: attendant,
      at: now,
      manchester: next.manchester,
      photoUrl: next.photoUrl,
    );
    state = state.copyWith(
      entries: updated,
      currentSenha: next.senha,
      currentName: next.patientName,
      calledHistory: [record, ...state.calledHistory].take(12).toList(),
      callTick: state.callTick + 1,
    );
  }

  /// Chamada automática: se houver agendamento cuja hora chegou, chama-o.
  /// Retorna `true` quando alguém foi chamado.
  bool autoCallDue(DateTime now) {
    final due = state.waiting.where((e) => e.autoCallDue(now)).toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    if (due.isEmpty) return false;
    callEntry(due.first.id);
    return true;
  }

  /// Rechama o paciente atual (ou um da fila pela senha), reemitindo a locução.
  void recall([String? senha]) {
    final target = senha == null
        ? state.currentCall
        : () {
            final e = state.entries.where((x) => x.senha == senha);
            if (e.isEmpty) return null;
            final x = e.first;
            return CallRecord(
              senha: x.senha,
              patientName: x.patientName,
              local: x.specialty,
              attendant: x.assignedTo ?? 'Você (Admin)',
              at: DateTime.now(),
              manchester: x.manchester,
            );
          }();
    if (target == null) return;
    final record = CallRecord(
      senha: target.senha,
      patientName: target.patientName,
      local: target.local,
      attendant: target.attendant,
      at: DateTime.now(),
      manchester: target.manchester,
    );
    state = state.copyWith(
      currentSenha: record.senha,
      currentName: record.patientName,
      calledHistory: [record, ...state.calledHistory].take(12).toList(),
      callTick: state.callTick + 1,
    );
  }

  void complete(String id) {
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.id == id) e.copyWith(status: QueueStatus.done) else e,
      ],
      servedToday: state.servedToday + 1,
    );
  }

  /// Move um ticket para outro estado (usado no arrastar-e-soltar do Kanban).
  void moveTo(String id, QueueStatus status) {
    final current = state.entries.where((e) => e.id == id);
    if (current.isEmpty || current.first.status == status) return;
    final goingDone = status == QueueStatus.done &&
        current.first.status != QueueStatus.done;
    final now = DateTime.now();
    state = state.copyWith(
      entries: [
        for (final e in state.entries)
          if (e.id == id)
            e.copyWith(
              status: status,
              timeline: [
                ...e.timeline,
                TimelineEvent(
                    action: 'Movido para ${status.label}', timestamp: now),
              ],
            )
          else
            e,
      ],
      servedToday: goingDone ? state.servedToday + 1 : state.servedToday,
    );
  }

  void deleteAnnouncement(String id) {
    state = state.copyWith(
      announcements: state.announcements.where((a) => a.id != id).toList(),
    );
  }
}

final recepcaoProvider =
    StateNotifierProvider<RecepcaoNotifier, RecepcaoState>((ref) {
  return RecepcaoNotifier();
});

/// Texto de busca compartilhado pelas abas (nome ou protocolo).
final recepcaoSearchProvider = StateProvider<String>((ref) => '');

/// Filtra entradas por nome do paciente ou protocolo (case-insensitive).
List<QueueEntry> filterBySearch(List<QueueEntry> list, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return list;
  return list
      .where((e) =>
          e.patientName.toLowerCase().contains(q) ||
          e.protocol.toLowerCase().contains(q) ||
          e.senha.toLowerCase().contains(q))
      .toList();
}
