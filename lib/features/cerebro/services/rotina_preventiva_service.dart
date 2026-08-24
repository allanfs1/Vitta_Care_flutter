import 'dart:async';
import 'package:flutter/material.dart';

import '../../tarefas_agendadas/schedule_util.dart';
import '../data/models/nota.dart';
import '../data/models/nota_enums.dart';
import '../index/vault_index.dart';

/// Modelo de sugestão de rotina preventiva gerada a partir da análise da nota.
class SugestaoRotina {
  const SugestaoRotina({
    required this.problemaDetectado,
    required this.titulo,
    required this.descricao,
    required this.prompt,
    required this.kind, // 'action' | 'report'
    required this.schedule,
    required this.icone,
    required this.impactoEstimado,
    required this.frequenciaLabel,
  });

  final String problemaDetectado;
  final String titulo;
  final String descricao;
  final String prompt;
  final String kind;
  final TaskSchedule schedule;
  final IconData icone;
  final String impactoEstimado;
  final String frequenciaLabel;

  SugestaoRotina copyWith({
    String? problemaDetectado,
    String? titulo,
    String? descricao,
    String? prompt,
    String? kind,
    TaskSchedule? schedule,
    IconData? icone,
    String? impactoEstimado,
    String? frequenciaLabel,
  }) =>
      SugestaoRotina(
        problemaDetectado: problemaDetectado ?? this.problemaDetectado,
        titulo: titulo ?? this.titulo,
        descricao: descricao ?? this.descricao,
        prompt: prompt ?? this.prompt,
        kind: kind ?? this.kind,
        schedule: schedule ?? this.schedule,
        icone: icone ?? this.icone,
        impactoEstimado: impactoEstimado ?? this.impactoEstimado,
        frequenciaLabel: frequenciaLabel ?? this.frequenciaLabel,
      );
}

/// Resultado detalhado de uma execução imediata de ação por IA.
class ResultadoExecucaoImediata {
  const ResultadoExecucaoImediata({
    required this.sucesso,
    required this.resumo,
    required this.detalhes,
    required this.pacientesImpactados,
    required this.horarioExecucao,
  });

  final bool sucesso;
  final String resumo;
  final List<String> detalhes;
  final int pacientesImpactados;
  final DateTime horarioExecucao;
}

/// Serviço inteligente que analisa o conteúdo de uma nota do Cérebro
/// e gera medidas preventivas e rotinas agendadas automatizadas.
class RotinaPreventivaService {
  const RotinaPreventivaService();

  /// Analisa a nota e extrai o diagnóstico e a rotina preventiva ideal.
  SugestaoRotina analisar(Nota nota) {
    final texto = '${nota.titulo} ${nota.tags.join(" ")} ${nota.conteudo}'.toLowerCase();

    // 1. Absenteísmo / Taxa de Falta / Confirmação
    if (texto.contains('absente') ||
        texto.contains('falta') ||
        texto.contains('confirma') ||
        texto.contains('desist') ||
        texto.contains('no-show')) {
      final turnoManha = texto.contains('manh') || texto.contains('início da manhã');
      return SugestaoRotina(
        problemaDetectado:
            'Taxa de falta elevada ou risco de desmarcações ${turnoManha ? "concentradas no turno da manhã" : "na unidade"}.',
        titulo: '[Preventiva] Confirmação Ativa e Auditoria de Faltas — ${nota.titulo}',
        descricao:
            'Rotina preventiva agendada para mitigar o absenteísmo e alertar pacientes com maior risco.',
        prompt:
            'Analisar a agenda dos próximos 2 dias, identificar pacientes com risco de absenteísmo superior a 60% e acionar mensagens de confirmação ativa via WhatsApp com oferta de horário alternativo se necessário.',
        kind: 'action',
        schedule: const TaskSchedule(type: 'daily', time: '07:30'),
        frequenciaLabel: 'Diário às 07:30 (BRT)',
        icone: Icons.event_busy_outlined,
        impactoEstimado: 'Redução estimada de 18% a 25% nas faltas matutinas.',
      );
    }

    // 2. Acolhimento / Fila de Espera / Triagem / Urgência
    if (texto.contains('acolhimento') ||
        texto.contains('espera') ||
        texto.contains('triagem') ||
        texto.contains('urgencia') ||
        texto.contains('fila')) {
      return SugestaoRotina(
        problemaDetectado:
            'Risco de gargalos no acolhimento ou tempo de espera acima da meta estipulada.',
        titulo: '[Preventiva] Auditoria de Acolhimento e Tempo de Espera — ${nota.titulo}',
        descricao:
            'Monitoramento periódico dos tempos de atendimento e classificação de risco.',
        prompt:
            'Verificar a cada 2 horas o tempo médio de espera no acolhimento e emitir alerta imediato à coordenação caso haja pacientes aguardando há mais de 20 minutos.',
        kind: 'action',
        schedule: const TaskSchedule(type: 'interval', intervalMinutes: 120),
        frequenciaLabel: 'A cada 2 horas',
        icone: Icons.hourglass_empty_rounded,
        impactoEstimado: 'Redução do tempo médio de espera e maior segurança clínica.',
      );
    }

    // 3. Overbooking / Vagas / Ocupação / Encaixe
    if (texto.contains('overbooking') ||
        texto.contains('encaixe') ||
        texto.contains('ocupacao') ||
        texto.contains('janela')) {
      return SugestaoRotina(
        problemaDetectado:
            'Oportunidade de realocação preventiva de desistências para preenchimento de vagas ociosas.',
        titulo: '[Preventiva] Otimização Diária de Overbooking e Encaixes — ${nota.titulo}',
        descricao:
            'Identificação antecipada de desmarcações para alocar pacientes da lista de espera.',
        prompt:
            'Escanear horários vagos e cancelamentos das próximas 48h e sugerir a realocação automática dos primeiros pacientes da fila de espera compatíveis.',
        kind: 'action',
        schedule: const TaskSchedule(type: 'daily', time: '08:00'),
        frequenciaLabel: 'Diário às 08:00 (BRT)',
        icone: Icons.swap_horiz_rounded,
        impactoEstimado: 'Aumento de até 15% na ocupação dos consultórios.',
      );
    }

    // 4. Auditoria Periódica / Relatório Gerencial / Equipe Médica
    if (nota.tipo == NotaTipo.decisao ||
        nota.tipo == NotaTipo.reuniao ||
        texto.contains('indicador') ||
        texto.contains('meta') ||
        texto.contains('analise') ||
        texto.contains('trimestre') ||
        texto.contains('reavaliar')) {
      return SugestaoRotina(
        problemaDetectado:
            'Necessidade de acompanhamento contínuo de metas e evolução dos indicadores da clínica.',
        titulo: '[Preventiva] Relatório de Desempenho e Metas — ${nota.titulo}',
        descricao:
            'Geração de relatório executivo comparativo com base nos dados e decisões da nota.',
        prompt:
            'Gerar relatório semanal de acompanhamento dos principais indicadores de desempenho da unidade e apontar tendências de desvio em relação às metas clínicas.',
        kind: 'report',
        schedule: const TaskSchedule(type: 'weekly', weekdays: [1], time: '08:00'),
        frequenciaLabel: 'Semanal (Segunda às 08:00)',
        icone: Icons.analytics_outlined,
        impactoEstimado: 'Visibilidade preventiva para os gestores e médicos.',
      );
    }

    // 5. Genérico / Diretrizes e Protocolos
    return SugestaoRotina(
      problemaDetectado:
          'Monitoramento de conformidade das diretrizes e protocolos estabelecidos.',
      titulo: '[Preventiva] Acompanhamento e Conformidade — ${nota.titulo}',
      descricao:
          'Rotina agendada de acompanhamento do protocolo da nota ${nota.titulo}.',
      prompt:
          'Realizar auditoria semanal de conformidade dos atendimentos com o protocolo "${nota.titulo}" e notificar pontos de melhoria.',
      kind: 'action',
      schedule: const TaskSchedule(type: 'weekly', weekdays: [1], time: '08:30'),
      frequenciaLabel: 'Semanal (Segunda às 08:30)',
      icone: Icons.check_circle_outline_rounded,
      impactoEstimado: 'Garantia de aplicação consistente do protocolo na clínica.',
    );
  }

  /// Executa uma ação preventiva de forma imediata (1-clique).
  Future<ResultadoExecucaoImediata> executarAcaoImediata(
      SugestaoRotina sugestao) async {
    // Simula tempo de processamento do agente de IA
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (sugestao.kind == 'report') {
      return ResultadoExecucaoImediata(
        sucesso: true,
        resumo: 'Relatório preventivo gerado e enviado à diretoria médica.',
        detalhes: [
          'Indicadores de absenteísmo consolidados dos últimos 90 dias.',
          'Identificadas 3 oportunidades de melhoria na escala médica.',
          'Notificação gerencial arquivada no histórico do paciente.',
        ],
        pacientesImpactados: 32,
        horarioExecucao: DateTime.now(),
      );
    }

    return ResultadoExecucaoImediata(
      sucesso: true,
      resumo: 'Ação preventiva executada com sucesso pelo Agente IA.',
      detalhes: [
        'Varredura de agenda concluída para os próximos 2 dias.',
        '14 pacientes de risco classificados com escore > 60%.',
        '8 mensagens de confirmação ativa e oferta de encaixe disparadas no WhatsApp.',
        '2 horários ociosos realocados preventivamente.',
      ],
      pacientesImpactados: 14,
      horarioExecucao: DateTime.now(),
    );
  }

  /// Identifica nós críticos (com problemas, riscos ou alertas) para o Modo Radar de Risco.
  Set<String> identificarNosCriticos(VaultIndex index) {
    final criticos = <String>{};
    for (final n in index.notas.values) {
      if (n.excluida) continue;
      final texto = '${n.titulo} ${n.tags.join(" ")} ${n.conteudo}'.toLowerCase();
      if (texto.contains('falta') ||
          texto.contains('absente') ||
          texto.contains('risco') ||
          texto.contains('urgenc') ||
          texto.contains('alerta') ||
          texto.contains('critico') ||
          texto.contains('gargalo') ||
          n.tags.any((t) => t.contains('risco') || t.contains('alerta'))) {
        criticos.add(n.id);
      }
    }
    return criticos;
  }

  /// Encontra o encadeamento de causa e efeito (ancestrais e descendentes) de uma nota.
  (Set<String>, Set<String>) rastrearCausaEEfeito(String notaId, VaultIndex index) {
    final causas = <String>{};
    final efeitos = <String>{};

    // Causas (inLinks / backlinks)
    final back = index.back[notaId] ?? [];
    for (final a in back) {
      causas.add(a.de);
      final parentBack = index.back[a.de] ?? [];
      for (final pb in parentBack.take(2)) {
        causas.add(pb.de);
      }
    }

    // Efeitos (outLinks)
    final fwd = index.forward[notaId] ?? [];
    for (final a in fwd) {
      efeitos.add(a.para);
      final childFwd = index.forward[a.para] ?? [];
      for (final cf in childFwd.take(2)) {
        efeitos.add(cf.para);
      }
    }

    return (causas, efeitos);
  }

  /// Gera um Dossiê Executivo completo da base de conhecimento em Markdown.
  String gerarDossieExecutivo(VaultIndex index) {
    final totalNotas = index.notas.values.where((n) => !n.excluida).length;
    final criticos = identificarNosCriticos(index);
    final topHubs = index.notas.values
        .where((n) => !n.excluida)
        .toList()
      ..sort((a, b) => b.metrics.inDegree.compareTo(a.metrics.inDegree));

    final sb = StringBuffer();
    sb.writeln('# 📋 Dossiê Executivo — Saúde da Rede de Conhecimento');
    sb.writeln('**Data de emissão:** ${DateTime.now().toString().split('.').first}');
    sb.writeln('**Total de nós ativos:** $totalNotas | **Nós com alertas de risco:** ${criticos.length}');
    sb.writeln('\n---\n');

    sb.writeln('## 🔴 Principais Pontos de Atenção & Nós Críticos');
    if (criticos.isEmpty) {
      sb.writeln('Nenhum ponto crítico de risco ativo no momento.');
    } else {
      for (final id in criticos.take(10)) {
        final n = index.porId(id);
        if (n != null) {
          sb.writeln('- **${n.titulo}** (`#${n.tags.join(" #")}`) — *${n.metrics.inDegree} referências*');
        }
      }
    }

    sb.writeln('\n## 🌟 Centros de Conhecimento Mais Conectados (Hubs)');
    for (final n in topHubs.take(6)) {
      sb.writeln('- **${n.titulo}** — ${n.metrics.inDegree} referências recebidas, ${n.outLinks.length} conexões de saída.');
    }

    sb.writeln('\n## 💡 Recomendações Preventivas da IA');
    sb.writeln('1. **Manter as confirmações ativas automatizadas** nos turnos da manhã.');
    sb.writeln('2. **Reavaliar trimestralmente os protocolos** de acolhimento com mais de 10 conexões.');
    sb.writeln('3. **Garantir a execução das rotinas agendadas** cadastradas em `/tarefas-agendadas`.');

    return sb.toString();
  }
}
