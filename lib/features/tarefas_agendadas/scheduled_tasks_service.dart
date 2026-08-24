import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_providers.dart';
import 'schedule_util.dart';
import 'scheduled_task.dart';

const _collection = 'tb_scheduled_tasks';
const _historyLimit = 20;
const _lockTtl = Duration(minutes: 10);

/// Camada de dados + lock das Tarefas Agendadas (`TAREFAS_AGENDADAS.md` §5).
/// Tudo escopado por clínica (multi-tenant); consultas por igualdade simples +
/// ordenação em memória (sem índice composto).
class ScheduledTasksService {
  ScheduledTasksService(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(_collection);

  /// Stream das tarefas da clínica (ordenadas por criação desc em memória).
  Stream<List<ScheduledTask>> watch(String clinicaId) {
    return _col.where('clinicaId', isEqualTo: clinicaId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => ScheduledTask.fromFirestore(d.id, d.data()))
          // Reforço multi-tenant: nunca expõe tarefa de outra clínica.
          .where((t) => t.clinicaId == clinicaId)
          .toList();
      list.sort((a, b) {
        final an = a.nextRunAt;
        final bn = b.nextRunAt;
        if (an == null && bn == null) return 0;
        if (an == null) return 1;
        if (bn == null) return -1;
        return an.compareTo(bn);
      });
      return list;
    });
  }

  /// Cria uma tarefa; calcula o 1º nextRunAt. Lança se não houver execução futura.
  Future<String> create({
    required String titulo,
    String descricao = '',
    required String prompt,
    required String kind,
    required TaskSchedule schedule,
    String? notifyEmail,
    int? maxRuns,
    DateTime? endAt,
    required String clinicaId,
    String? createdBy,
  }) async {
    final err = validateSchedule(schedule);
    if (err != null) throw StateError(err);
    final next = computeNextRun(schedule, DateTime.now().toUtc());
    if (next == null) throw StateError('Não há execução futura para este agendamento.');
    final ref = await _col.add({
      'titulo': titulo,
      'descricao': descricao,
      'prompt': prompt,
      'kind': kind,
      'schedule': schedule.toMap(),
      'status': 'active',
      'nextRunAt': Timestamp.fromDate(next),
      'lastRunAt': null,
      'lockedAt': null,
      'runCount': 0,
      'errorCount': 0,
      'maxRuns': maxRuns,
      'endAt': endAt != null ? Timestamp.fromDate(endAt) : null,
      'notifyEmail': notifyEmail,
      'history': <Map<String, dynamic>>[],
      'clinicaId': clinicaId,
      'idclinica': clinicaId, // compat. multi-tenant
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(
    String id, {
    String? titulo,
    String? descricao,
    String? prompt,
    String? kind,
    TaskSchedule? schedule,
    String? notifyEmail,
  }) async {
    final patch = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (titulo != null) patch['titulo'] = titulo;
    if (descricao != null) patch['descricao'] = descricao;
    if (prompt != null) patch['prompt'] = prompt;
    if (kind != null) patch['kind'] = kind;
    if (notifyEmail != null) patch['notifyEmail'] = notifyEmail;
    if (schedule != null) {
      final err = validateSchedule(schedule);
      if (err != null) throw StateError(err);
      patch['schedule'] = schedule.toMap();
      final next = computeNextRun(schedule, DateTime.now().toUtc());
      patch['nextRunAt'] = next != null ? Timestamp.fromDate(next) : null;
      patch['status'] = next != null ? 'active' : 'completed';
    }
    await _col.doc(id).update(patch);
  }

  Future<void> setStatus(String id, String status) async {
    final patch = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // Retomar sem futuro → recalcula a partir de agora.
    if (status == 'active') {
      final snap = await _col.doc(id).get();
      final task = ScheduledTask.fromFirestore(id, snap.data() ?? {});
      // Uma sugestão da IA só vira ativa por [aprovar], que registra quem
      // decidiu. Deixar `setStatus` promovê-la abriria um caminho para ligar
      // uma automação sem decisão humana rastreada — a garantia central deste
      // módulo não pode depender de a UI lembrar de não chamar isto.
      if (task.isSugestao || task.isRecusada) {
        throw StateError(
          'Esta rotina foi proposta pela IA. Use "Aprovar" para ativá-la.',
        );
      }
      if (task.nextRunAt == null) {
        final next = computeNextRun(task.schedule, DateTime.now().toUtc());
        patch['nextRunAt'] = next != null ? Timestamp.fromDate(next) : null;
        if (next == null) patch['status'] = 'completed';
      }
    }
    await _col.doc(id).update(patch);
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Tarefas vencidas e ativas (filtro de status em memória → sem índice composto).
  Future<List<ScheduledTask>> getDue(String clinicaId, {int limit = 10}) async {
    final now = Timestamp.fromDate(DateTime.now().toUtc());
    final snap = await _col
        .where('clinicaId', isEqualTo: clinicaId)
        .where('nextRunAt', isLessThanOrEqualTo: now)
        .get();
    final due = snap.docs
        .map((d) => ScheduledTask.fromFirestore(d.id, d.data()))
        .where((t) => t.status == 'active')
        .toList();
    due.sort((a, b) => (a.nextRunAt ?? DateTime(0)).compareTo(b.nextRunAt ?? DateTime(0)));
    return due.take(limit).toList();
  }

  // -- Sugestoes da IA ------------------------------------------------------
  //
  // Uma sugestao e uma tarefa que existe mas nao roda. Ela nasce com
  // `status: 'suggested'` e **sem** `nextRunAt`: mesmo que algum runner futuro
  // esqueca de filtrar por status, nao ha horario para vencer. Sao duas
  // travas independentes para a mesma garantia - a IA nunca age sozinha.

  /// Registra uma rotina proposta pela IA, aguardando decisao humana.
  Future<String> criarSugestao({
    required String titulo,
    required String descricao,
    required String prompt,
    required String kind,
    required TaskSchedule schedule,
    required String clinicaId,
    String problemaDetectado = '',
    String impactoEstimado = '',
    List<String> evidencias = const [],
    double? confianca,
    String? notaCerebroId,
    String? relatorioId,
  }) async {
    final err = validateSchedule(schedule);
    if (err != null) throw StateError(err);

    final ref = await _col.add({
      'titulo': titulo,
      'descricao': descricao,
      'prompt': prompt,
      'kind': kind,
      'schedule': schedule.toMap(),
      'status': 'suggested',
      // Sem nextRunAt de proposito - ver comentario acima.
      'nextRunAt': null,
      'runCount': 0,
      'errorCount': 0,
      'history': <Map<String, dynamic>>[],
      'clinicaId': clinicaId,
      'origem': 'ia',
      'problemaDetectado': problemaDetectado,
      'impactoEstimado': impactoEstimado,
      'evidencias': evidencias,
      'confianca': ?confianca,
      'notaCerebroId': ?notaCerebroId,
      'relatorioId': ?relatorioId,
      'sugeridaEm': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'ia',
    });
    return ref.id;
  }

  /// Aprova uma sugestao: e **aqui** que a rotina passa a poder executar.
  /// Calcula o primeiro `nextRunAt` no momento da aprovacao, nao antes.
  Future<void> aprovar(String id, {String? por}) async {
    await _db.runTransaction((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Sugestão não encontrada.');
      final task = ScheduledTask.fromFirestore(snap.id, snap.data()!);
      if (!task.isSugestao) {
        throw StateError('Esta tarefa não está aguardando aprovação.');
      }
      final next = computeNextRun(task.schedule, DateTime.now().toUtc());
      if (next == null) {
        throw StateError(
          'O agendamento proposto não tem execução futura. Edite o horário '
          'antes de aprovar.',
        );
      }
      tx.update(ref, {
        'status': 'active',
        'nextRunAt': Timestamp.fromDate(next),
        'decididaEm': FieldValue.serverTimestamp(),
        'decididaPor': ?por,
        'motivoRecusa': FieldValue.delete(),
      });
    });
  }

  /// Recusa uma sugestao. O motivo nao e burocracia: e o que o Vigia le para
  /// nao repropor a mesma coisa amanha.
  Future<void> recusar(String id, {required String motivo, String? por}) async {
    await _col.doc(id).update({
      'status': 'rejected',
      'nextRunAt': null,
      'motivoRecusa': motivo,
      'decididaEm': FieldValue.serverTimestamp(),
      'decididaPor': ?por,
    });
  }

  /// Tarefas que o Vigia deve considerar ja cobertas - ativas, pausadas ou
  /// pendentes - mais as recusadas com o motivo. Alimenta a deduplicacao.
  Future<List<ScheduledTask>> paraDeduplicar(String clinicaId) async {
    final snap = await _col.where('clinicaId', isEqualTo: clinicaId).get();
    return snap.docs
        .map((d) => ScheduledTask.fromFirestore(d.id, d.data()))
        .where((t) => t.clinicaId == clinicaId)
        .toList();
  }

  /// Lock atômico (transação): se ativa, sem lock vivo e vencida → marca
  /// `running`, grava `lockedAt` e **já avança** `nextRunAt`. Retorna a tarefa
  /// ou `null` se não ganhou o lock.
  Future<ScheduledTask?> claimDue(String id) async {
    return _db.runTransaction<ScheduledTask?>((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) return null;
      final task = ScheduledTask.fromFirestore(id, snap.data()!);
      final now = DateTime.now().toUtc();
      final lockAlive =
          task.lockedAt != null && now.difference(task.lockedAt!) < _lockTtl;
      final due = task.nextRunAt != null && !task.nextRunAt!.toUtc().isAfter(now);
      if (task.status != 'active' || lockAlive || !due) return null;

      final advanced = _advance(task);
      tx.update(ref, {
        'status': 'running',
        'lockedAt': Timestamp.fromDate(now),
        'nextRunAt':
            advanced != null ? Timestamp.fromDate(advanced) : null,
      });
      return task;
    });
  }

  /// Finaliza um claim: grava histórico/contadores, status final e libera o lock.
  Future<void> finishRun(String id, RunRecord record) async {
    final ref = _col.doc(id);
    final snap = await ref.get();
    if (!snap.exists) return;
    final task = ScheduledTask.fromFirestore(id, snap.data()!);
    final history = [record, ...task.history].take(_historyLimit).toList();
    // nextRunAt já foi avançado no claim; status final depende dele.
    final hasNext = task.nextRunAt != null;
    await ref.update({
      'status': hasNext ? 'active' : 'completed',
      'lockedAt': null,
      'lastRunAt': Timestamp.fromDate(record.runAt ?? DateTime.now().toUtc()),
      'runCount': task.runCount + 1,
      'errorCount': task.errorCount + (record.ok ? 0 : 1),
      'history': history.map((r) => r.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lock para "executar agora" (não roda se já houver execução em andamento).
  Future<bool> lockForManualRun(String id) async {
    return _db.runTransaction<bool>((tx) async {
      final ref = _col.doc(id);
      final snap = await tx.get(ref);
      if (!snap.exists) return false;
      final task = ScheduledTask.fromFirestore(id, snap.data()!);
      final now = DateTime.now().toUtc();
      final lockAlive =
          task.lockedAt != null && now.difference(task.lockedAt!) < _lockTtl;
      if (lockAlive) return false;
      tx.update(ref, {'lockedAt': Timestamp.fromDate(now)});
      return true;
    });
  }

  /// Registra execução manual **sem** mexer em nextRunAt/status.
  Future<void> recordManualRun(String id, RunRecord record) async {
    final ref = _col.doc(id);
    final snap = await ref.get();
    if (!snap.exists) return;
    final task = ScheduledTask.fromFirestore(id, snap.data()!);
    final history = [record, ...task.history].take(_historyLimit).toList();
    await ref.update({
      'lockedAt': null,
      'lastRunAt': Timestamp.fromDate(record.runAt ?? DateTime.now().toUtc()),
      'runCount': task.runCount + 1,
      'errorCount': task.errorCount + (record.ok ? 0 : 1),
      'history': history.map((r) => r.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Recupera órfãs presas em `running` com lock > TTL (volta p/ active/completed).
  Future<void> recoverStale(String clinicaId) async {
    final snap =
        await _col.where('clinicaId', isEqualTo: clinicaId).get();
    final now = DateTime.now().toUtc();
    for (final d in snap.docs) {
      final t = ScheduledTask.fromFirestore(d.id, d.data());
      if (t.status == 'running' &&
          t.lockedAt != null &&
          now.difference(t.lockedAt!) > _lockTtl) {
        await d.reference.update({
          'status': t.nextRunAt != null ? 'active' : 'completed',
          'lockedAt': null,
          'errorCount': t.errorCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// Avança nextRunAt aplicando o término automático (once / maxRuns / endAt).
  DateTime? _advance(ScheduledTask task) {
    if (task.schedule.type == 'once') return null;
    if (task.maxRuns != null && task.runCount + 1 >= task.maxRuns!) return null;
    final from = task.nextRunAt?.toUtc() ?? DateTime.now().toUtc();
    final next = computeNextRun(task.schedule, from);
    if (next == null) return null;
    if (task.endAt != null && next.isAfter(task.endAt!.toUtc())) return null;
    return next;
  }
}

final scheduledTasksServiceProvider = Provider<ScheduledTasksService>(
    (ref) => ScheduledTasksService(FirebaseFirestore.instance));

/// Clínica usada nas Tarefas Agendadas — **sempre a clínica do usuário logado**
/// (multi-tenant). Prefere a clínica selecionada apenas se ela pertencer ao
/// usuário; caso contrário cai na 1ª clínica do perfil. Evita exibir/criar
/// tarefas de outra clínica caso a seleção da UI esteja desalinhada.
final tarefasClinicaIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  // `clinicaResolvidaProvider` e nao `selectedClinicIdProvider`: no boot este
  // ultimo vale o placeholder de MockData, e uma tarefa gravada ali fica orfa
  // numa clinica que nao existe no Firestore.
  final selected = ref.watch(clinicaResolvidaProvider);
  if (user.clinicIds.contains(selected)) return selected;
  if (user.clinicIds.isNotEmpty) return user.clinicIds.first;
  return selected;
});

/// Tarefas agendadas da clínica do usuário logado.
final scheduledTasksProvider = StreamProvider<List<ScheduledTask>>((ref) {
  // Sem Firebase não há tarefas agendadas — e tocar em `FirebaseFirestore
  // .instance` neste modo lança. Antes só a própria tela lia este provider e
  // ela não existe offline; agora a tela de relatórios também lê (para avisar
  // sobre sugestões pendentes), então o modo demonstração passa por aqui.
  if (!ref.watch(firebaseEnabledProvider)) return Stream.value(const []);
  final clinicaId = ref.watch(tarefasClinicaIdProvider);
  if (clinicaId.isEmpty) return Stream.value(const []);
  return ref.watch(scheduledTasksServiceProvider).watch(clinicaId);
});
