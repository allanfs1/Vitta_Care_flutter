import 'package:flutter/material.dart';

/// Enums canônicos do Cérebro (`.specify/obsidian/obsidian.md` §4.3).
///
/// Todo código do módulo usa estes termos — divergência quebra o glossário
/// definido na especificação (§2).

/// Tipo de uma nota. Define ícone, cor no grafo e peso no ranking de busca.
enum NotaTipo {
  nota('nota', 'Nota', Icons.description_outlined, Color(0xFF94A3B8)),
  moc('moc', 'MOC', Icons.hub_outlined, Color(0xFFF43F5E)),
  diario('diario', 'Diário', Icons.today_outlined, Color(0xFF64748B)),
  conceito('conceito', 'Conceito', Icons.lightbulb_outline, Color(0xFF7C3AED)),
  protocolo('protocolo', 'Protocolo', Icons.rule_folder_outlined, Color(0xFF2E9E8F)),
  analise('analise', 'Análise', Icons.query_stats, Color(0xFF1B53D0)),
  relatorio('relatorio', 'Relatório', Icons.assessment_outlined, Color(0xFF0EA5E9)),
  reuniao('reuniao', 'Reunião', Icons.groups_outlined, Color(0xFF64748B)),
  decisao('decisao', 'Decisão', Icons.gavel_outlined, Color(0xFFC77700)),
  pessoa('pessoa', 'Pessoa', Icons.person_outline, Color(0xFF10B981)),
  fonte('fonte', 'Fonte', Icons.link_outlined, Color(0xFF8B5CF6)),
  template('template', 'Template', Icons.dashboard_customize_outlined, Color(0xFF94A3B8)),
  canvas('canvas', 'Canvas', Icons.grid_view_outlined, Color(0xFFA855F7)),
  memoria('memoria', 'Memória', Icons.psychology_outlined, Color(0xFF7C3AED));

  const NotaTipo(this.id, this.label, this.icon, this.cor);

  final String id;
  final String label;
  final IconData icon;
  final Color cor;

  static NotaTipo fromId(String? id) => NotaTipo.values.firstWhere(
        (t) => t.id == id,
        orElse: () => NotaTipo.nota,
      );

  /// Tipos considerados "autoridade operacional" — sobem no rerank do RAG (§8.4).
  bool get ehAutoridade => this == protocolo || this == decisao;
}

/// Quem escreveu a nota. Governa a política de escrita (§9.3) e o rerank.
enum NotaOrigem {
  humano('humano', 'Humano'),
  agente('agente', 'IA'),
  sistema('sistema', 'Sistema'),
  importado('importado', 'Importado');

  const NotaOrigem(this.id, this.label);
  final String id;
  final String label;

  static NotaOrigem fromId(String? id) => NotaOrigem.values.firstWhere(
        (o) => o.id == id,
        orElse: () => NotaOrigem.humano,
      );
}

/// Ciclo de vida da nota.
enum NotaEstado {
  rascunho('rascunho', 'Rascunho'),
  publicada('publicada', 'Publicada'),
  arquivada('arquivada', 'Arquivada');

  const NotaEstado(this.id, this.label);
  final String id;
  final String label;

  static NotaEstado fromId(String? id) => NotaEstado.values.firstWhere(
        (e) => e.id == id,
        orElse: () => NotaEstado.publicada,
      );
}

/// Natureza de uma aresta do grafo.
enum LinkTipo {
  wiki('wiki'),
  embed('embed'),
  entidade('entidade'),
  tag('tag'),
  semantico('semantico'),
  hierarquico('hierarquico');

  const LinkTipo(this.id);
  final String id;

  static LinkTipo fromId(String? id) => LinkTipo.values.firstWhere(
        (t) => t.id == id,
        orElse: () => LinkTipo.wiki,
      );

  /// Peso base da aresta no PageRank — embeds valem o dobro (§7.6).
  double get pesoBase => this == LinkTipo.embed ? 2.0 : 1.0;
}

/// Entidades operacionais projetadas como nós virtuais do grafo (§4.3).
enum EntidadeTipo {
  paciente('paciente', 'Paciente', Icons.personal_injury_outlined, Color(0xFF0EA5E9)),
  medico('medico', 'Médico', Icons.medical_services_outlined, Color(0xFF10B981)),
  agendamento('agendamento', 'Consulta', Icons.event_outlined, Color(0xFFF59E0B)),
  clinica('clinica', 'Clínica', Icons.local_hospital_outlined, Color(0xFF1B53D0)),
  alerta('alerta', 'Alerta', Icons.warning_amber_outlined, Color(0xFFC62828)),
  score('score', 'Score de risco', Icons.speed_outlined, Color(0xFFC62828)),
  overbooking('overbooking', 'Overbooking', Icons.event_seat_outlined, Color(0xFFC77700)),
  tarefa('tarefa', 'Tarefa', Icons.task_alt_outlined, Color(0xFF2E9E8F)),
  conversa('conversa', 'Conversa', Icons.forum_outlined, Color(0xFF7C3AED)),
  avaliacao('avaliacao', 'Avaliação', Icons.star_outline, Color(0xFFC77700)),
  removido('removido', 'Removido (LGPD)', Icons.lock_outline, Color(0xFF475569));

  const EntidadeTipo(this.id, this.label, this.icon, this.cor);

  final String id;
  final String label;
  final IconData icon;
  final Color cor;

  static EntidadeTipo? fromId(String? id) {
    if (id == null) return null;
    for (final e in EntidadeTipo.values) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Entidades cujo dado é PII de paciente — exigem checagem de papel (§14.3).
  bool get ehSensivel => this == EntidadeTipo.paciente;
}

/// Estado de resolução de um wikilink (§5.2).
enum LinkEstado { resolvido, ambiguo, quebrado, entidade }
