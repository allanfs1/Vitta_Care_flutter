import 'package:flutter/material.dart';

/// Categoria de sugestões/atalhos do input de IA.
class SuggestionCategory {
  const SuggestionCategory(this.icon, this.title, this.items);
  final IconData icon;
  final String title;
  final List<String> items;
}

/// Catálogo de atalhos exibidos no autocomplete do chat e do modo agentes.
const List<SuggestionCategory> kIaSuggestions = [
  SuggestionCategory(Icons.calendar_month, 'Agendamentos', [
    'Quais são as consultas agendadas para hoje?',
    'Liste os agendamentos de amanhã por médico',
    'Agendamentos confirmados desta semana',
  ]),
  SuggestionCategory(Icons.medical_services_outlined, 'Médicos', [
    'Liste todos os médicos ativos da clínica',
    'Quais médicos estão disponíveis hoje?',
    'Qual médico tem mais agendamentos esta semana?',
  ]),
  SuggestionCategory(Icons.person_search, 'Pacientes', [
    'Buscar paciente pelo CPF',
    'Listar pacientes cadastrados ativos',
    'Histórico de consultas do paciente',
  ]),
  SuggestionCategory(Icons.warning_amber, 'Riscos & IA', [
    'Quais agendamentos têm alto risco de falta hoje?',
    'Taxa de absenteísmo do mês atual vs mês anterior',
    'Top 20 pacientes com maior risco de falta esta semana',
  ]),
  SuggestionCategory(Icons.event_busy, 'Overbooking', [
    'Listar eventos de overbooking recentes',
    'Realocações pendentes de overbooking',
    'Simular impacto de overbooking para o médico',
  ]),
  SuggestionCategory(Icons.mail_outline, 'Emails & Notificações', [
    'Enviar email de confirmação de consulta para o paciente',
    'Enviar lembrete de consulta por email 24h antes',
    'Enviar email de realocação com link de reagendamento',
  ]),
  SuggestionCategory(Icons.analytics_outlined, 'Relatórios & Gráficos', [
    'Gráfico de consultas por dia da semana',
    'Relatório de absenteísmo do último mês',
    'Análise completa da clínica em gráficos',
  ]),
  SuggestionCategory(Icons.chat_bubble_outline, 'WhatsApp', [
    'Verificar se a instância WhatsApp está conectada',
    'Enviar confirmação de consulta de amanhã via WhatsApp',
    'Enviar lembretes WhatsApp para pacientes de alto risco hoje',
  ]),
  SuggestionCategory(Icons.support_agent, 'Tickets & Suporte', [
    'Listar tickets abertos com prioridade alta',
    'Tickets pendentes sem responsável',
    'Quantos tickets foram resolvidos esta semana?',
  ]),
  SuggestionCategory(Icons.schedule, 'Tarefas Agendadas', [
    '/schedule enviar lembretes WhatsApp todo dia às 08:00 para os agendamentos do dia',
    '/schedule gerar o relatório de absenteísmo toda segunda-feira às 09:00 e enviar por e-mail ao gestor',
    '/schedule enviar confirmações por e-mail para os agendamentos de amanhã',
  ]),
];

/// Resultado achatado de uma sugestão (para filtragem).
class SuggestionItem {
  const SuggestionItem(this.icon, this.category, this.text);
  final IconData icon;
  final String category;
  final String text;
}

/// Filtra as sugestões pela [query] (case-insensitive). Vazio → todas.
List<SuggestionCategory> filterSuggestions(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kIaSuggestions;
  final out = <SuggestionCategory>[];
  for (final c in kIaSuggestions) {
    final items = c.items
        .where((i) =>
            i.toLowerCase().contains(q) || c.title.toLowerCase().contains(q))
        .toList();
    if (items.isNotEmpty) out.add(SuggestionCategory(c.icon, c.title, items));
  }
  return out;
}
