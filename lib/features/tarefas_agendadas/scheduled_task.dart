import 'package:cloud_firestore/cloud_firestore.dart';

import 'schedule_util.dart';

/// Registro de uma execução no histórico.
class RunRecord {
  const RunRecord({
    required this.runAt,
    required this.ok,
    required this.summary,
    this.toolsUsed = 0,
    this.durationMs = 0,
    this.reportId,
  });

  final DateTime? runAt;
  final bool ok;
  final String summary;
  final int toolsUsed;
  final int durationMs;
  final String? reportId;

  Map<String, dynamic> toMap() => {
        'runAt': runAt != null ? Timestamp.fromDate(runAt!) : null,
        'ok': ok,
        'summary': summary,
        'toolsUsed': toolsUsed,
        'durationMs': durationMs,
        if (reportId != null) 'reportId': reportId,
      };

  factory RunRecord.fromMap(Map<String, dynamic> m) => RunRecord(
        runAt: m['runAt'] is Timestamp ? (m['runAt'] as Timestamp).toDate() : null,
        ok: m['ok'] == true,
        summary: (m['summary'] ?? '').toString(),
        toolsUsed: (m['toolsUsed'] is num) ? (m['toolsUsed'] as num).toInt() : 0,
        durationMs:
            (m['durationMs'] is num) ? (m['durationMs'] as num).toInt() : 0,
        reportId: m['reportId']?.toString(),
      );
}

/// Tarefa agendada — mapeia `tb_scheduled_tasks`.
class ScheduledTask {
  ScheduledTask({
    required this.id,
    required this.titulo,
    this.descricao = '',
    required this.prompt,
    required this.kind, // action | report
    required this.schedule,
    this.status = 'active',
    this.nextRunAt,
    this.lastRunAt,
    this.lockedAt,
    this.runCount = 0,
    this.errorCount = 0,
    this.maxRuns,
    this.endAt,
    this.notifyEmail,
    this.history = const [],
    required this.clinicaId,
    this.origem = 'humano',
    this.problemaDetectado = '',
    this.impactoEstimado = '',
    this.evidencias = const [],
    this.confianca,
    this.sugeridaEm,
    this.decididaEm,
    this.decididaPor,
    this.motivoRecusa,
    this.notaCerebroId,
    this.relatorioId,
  });

  final String id;
  final String titulo;
  final String descricao;
  final String prompt;
  final String kind;
  final TaskSchedule schedule;
  final String status;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final DateTime? lockedAt;
  final int runCount;
  final int errorCount;
  final int? maxRuns;
  final DateTime? endAt;
  final String? notifyEmail;
  final List<RunRecord> history;
  final String clinicaId;

  // -- Proposta da IA (status 'suggested') ----------------------------------
  //
  // Uma rotina proposta pelo Vigia entra aqui como sugestao e NAO executa: os
  // dois runners - o Dart (`getDue`) e a Cloud Function - so pegam tarefas com
  // status 'active'. Aprovar e o unico caminho que liga a execucao, e ele passa
  // por uma pessoa.

  /// 'humano' quando alguem criou a tarefa na tela; 'ia' quando o Vigia propos.
  final String origem;

  /// O que a IA observou para propor esta rotina.
  final String problemaDetectado;

  /// Ganho esperado, na linguagem de quem decide.
  final String impactoEstimado;

  /// Fatos que sustentam a proposta - numeros, notas do Cerebro, tendencias.
  /// Sem isto o gestor aprova no escuro.
  final List<String> evidencias;

  /// Confianca da IA (0..1) no diagnostico.
  final double? confianca;

  final DateTime? sugeridaEm;
  final DateTime? decididaEm;
  final String? decididaPor;

  /// Por que foi recusada - alimenta o Vigia para nao repetir a proposta.
  final String? motivoRecusa;

  /// Nota do Cerebro que originou ou registrou a proposta.
  final String? notaCerebroId;

  /// Relatorio que acompanhou a proposta.
  final String? relatorioId;

  bool get isReport => kind == 'report';
  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed';

  /// Proposta da IA aguardando decisao humana.
  bool get isSugestao => status == 'suggested';
  bool get isRecusada => status == 'rejected';
  bool get daIa => origem == 'ia';

  /// Chave de deduplicacao: evita o Vigia repropor todo dia a mesma rotina.
  /// Normaliza o titulo removendo o prefixo de origem e a pontuacao.
  String get chaveDedupe => chaveDedupeDe(titulo, kind);

  static String chaveDedupeDe(String titulo, String kind) {
    final base = titulo
        .toLowerCase()
        .replaceAll(RegExp(r'^\[[^\]]*\]\s*'), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '$kind|$base';
  }

  String get scheduleLabel => describeSchedule(schedule);

  factory ScheduledTask.fromFirestore(String id, Map<String, dynamic> d) {
    DateTime? ts(Object? v) => v is Timestamp ? v.toDate() : null;
    final sched = d['schedule'];
    final history = <RunRecord>[];
    final h = d['history'];
    if (h is List) {
      for (final e in h) {
        if (e is Map) {
          history.add(RunRecord.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }
    return ScheduledTask(
      id: id,
      titulo: (d['titulo'] ?? 'Tarefa').toString(),
      descricao: (d['descricao'] ?? '').toString(),
      prompt: (d['prompt'] ?? '').toString(),
      kind: (d['kind'] ?? 'action').toString(),
      schedule: TaskSchedule.fromMap(
          sched is Map ? Map<String, dynamic>.from(sched) : <String, dynamic>{}),
      status: (d['status'] ?? 'active').toString(),
      nextRunAt: ts(d['nextRunAt']),
      lastRunAt: ts(d['lastRunAt']),
      lockedAt: ts(d['lockedAt']),
      runCount: (d['runCount'] is num) ? (d['runCount'] as num).toInt() : 0,
      errorCount: (d['errorCount'] is num) ? (d['errorCount'] as num).toInt() : 0,
      maxRuns: (d['maxRuns'] is num) ? (d['maxRuns'] as num).toInt() : null,
      endAt: ts(d['endAt']),
      notifyEmail: d['notifyEmail']?.toString(),
      history: history,
      clinicaId: (d['clinicaId'] ?? d['idclinica'] ?? '').toString(),
      origem: (d['origem'] ?? 'humano').toString(),
      problemaDetectado: (d['problemaDetectado'] ?? '').toString(),
      impactoEstimado: (d['impactoEstimado'] ?? '').toString(),
      evidencias: [
        for (final e in (d['evidencias'] as List? ?? const [])) e.toString(),
      ],
      confianca: (d['confianca'] is num) ? (d['confianca'] as num).toDouble() : null,
      sugeridaEm: ts(d['sugeridaEm']),
      decididaEm: ts(d['decididaEm']),
      decididaPor: d['decididaPor']?.toString(),
      motivoRecusa: d['motivoRecusa']?.toString(),
      notaCerebroId: d['notaCerebroId']?.toString(),
      relatorioId: d['relatorioId']?.toString(),
    );
  }
}
