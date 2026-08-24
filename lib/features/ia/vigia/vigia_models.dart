import 'package:cloud_firestore/cloud_firestore.dart';

import '../../tarefas_agendadas/schedule_util.dart';

/// Uma rotina que o Vigia propõe — ainda **não** é uma tarefa agendada.
///
/// Vira `ScheduledTask` com `status: 'suggested'` só depois de passar pelos
/// filtros de sanidade e deduplicação; e só executa depois que uma pessoa
/// aprova.
class RotinaProposta {
  const RotinaProposta({
    required this.titulo,
    required this.descricao,
    required this.prompt,
    required this.kind,
    required this.schedule,
    required this.problemaDetectado,
    required this.impactoEstimado,
    required this.evidencias,
    required this.confianca,
  });

  final String titulo;
  final String descricao;

  /// O que o agente vai executar quando a rotina rodar.
  final String prompt;

  /// `action` (faz algo) ou `report` (produz um relatório).
  final String kind;

  final TaskSchedule schedule;
  final String problemaDetectado;
  final String impactoEstimado;
  final List<String> evidencias;
  final double confianca;

  /// Lê uma proposta do JSON devolvido pelo modelo, tolerando campos ausentes.
  /// Devolve `null` quando o essencial não veio — melhor descartar a proposta
  /// do que sugerir uma rotina sem prompt ou sem horário.
  static RotinaProposta? doJson(Map<String, dynamic> j) {
    String txt(String k) => (j[k] ?? '').toString().trim();

    final titulo = txt('titulo');
    final prompt = txt('prompt');
    if (titulo.isEmpty || prompt.isEmpty) return null;

    final schedule = _scheduleDoJson(j['schedule']);
    if (schedule == null) return null;
    if (validateSchedule(schedule) != null) return null;

    final kind = txt('kind') == 'report' ? 'report' : 'action';
    final conf = j['confianca'];
    return RotinaProposta(
      titulo: titulo,
      descricao: txt('descricao'),
      prompt: prompt,
      kind: kind,
      schedule: schedule,
      problemaDetectado: txt('problemaDetectado'),
      impactoEstimado: txt('impactoEstimado'),
      evidencias: [
        for (final e in (j['evidencias'] as List? ?? const []))
          if (e.toString().trim().isNotEmpty) e.toString().trim(),
      ],
      confianca: conf is num ? conf.toDouble().clamp(0.0, 1.0) : 0.5,
    );
  }

  static TaskSchedule? _scheduleDoJson(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final tipo = (m['type'] ?? '').toString();
    const validos = {'once', 'interval', 'daily', 'weekly', 'monthly'};
    if (!validos.contains(tipo)) return null;

    return TaskSchedule(
      type: tipo,
      time: m['time']?.toString(),
      weekdays: [
        for (final d in (m['weekdays'] as List? ?? const []))
          if (d is num && d >= 0 && d <= 6) d.toInt(),
      ],
      dayOfMonth: (m['dayOfMonth'] is num)
          ? (m['dayOfMonth'] as num).toInt().clamp(1, 31)
          : null,
      intervalMinutes: (m['intervalMinutes'] is num)
          ? (m['intervalMinutes'] as num).toInt()
          : null,
    );
  }

  /// Chave usada para não repropor a mesma rotina em ciclos seguintes.
  String get chaveDedupe => _chave(titulo, kind);

  static String _chave(String titulo, String kind) {
    final base = titulo
        .toLowerCase()
        .replaceAll(RegExp(r'^\[[^\]]*\]\s*'), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '$kind|$base';
  }
}

/// O relatório do dia, na forma que a tela `/relatorios` consome.
class RelatorioProposto {
  const RelatorioProposto({
    required this.titulo,
    required this.periodo,
    required this.corpo,
    required this.metricas,
  });

  final String titulo;
  final String periodo;

  /// Markdown — é o que o leitor vê.
  final String corpo;

  /// Pares rótulo/valor destacados no topo do relatório.
  final List<(String, String)> metricas;

  static RelatorioProposto? doJson(Map<String, dynamic> j) {
    final titulo = (j['titulo'] ?? '').toString().trim();
    final corpo = (j['corpo'] ?? j['markdown'] ?? '').toString().trim();
    if (titulo.isEmpty || corpo.isEmpty) return null;

    final metricas = <(String, String)>[];
    for (final m in (j['metricas'] as List? ?? const [])) {
      if (m is! Map) continue;
      final label = (m['label'] ?? m['rotulo'] ?? '').toString().trim();
      final valor = (m['valor'] ?? m['value'] ?? '').toString().trim();
      if (label.isEmpty || valor.isEmpty) continue;
      metricas.add((label, valor));
    }

    return RelatorioProposto(
      titulo: titulo,
      periodo: (j['periodo'] ?? 'Últimas 24 horas').toString(),
      corpo: corpo,
      metricas: metricas,
    );
  }
}

/// Resultado de um ciclo do Vigia — o que foi produzido e o que foi descartado.
class ResultadoCiclo {
  const ResultadoCiclo({
    required this.executou,
    this.motivo = '',
    this.relatorioId,
    this.sugestoesCriadas = 0,
    this.sugestoesDescartadas = 0,
    this.notaCerebroId,
    this.duracao = Duration.zero,
  });

  /// `false` quando o ciclo foi pulado (já rodou hoje, sem clínica, IA
  /// indisponível) — [motivo] explica.
  final bool executou;
  final String motivo;

  final String? relatorioId;
  final int sugestoesCriadas;

  /// Propostas rejeitadas pelos filtros locais (duplicadas, malformadas,
  /// confiança baixa). Contam para a auditoria: um Vigia que descarta tudo
  /// está mal calibrado.
  final int sugestoesDescartadas;

  final String? notaCerebroId;
  final Duration duracao;

  Map<String, dynamic> toMap() => {
        'executou': executou,
        'motivo': motivo,
        'relatorioId': ?relatorioId,
        'sugestoesCriadas': sugestoesCriadas,
        'sugestoesDescartadas': sugestoesDescartadas,
        'notaCerebroId': ?notaCerebroId,
        'duracaoMs': duracao.inMilliseconds,
        'em': FieldValue.serverTimestamp(),
      };
}
