import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_providers.dart';
import '../../../core/theme/app_colors.dart';

/// Tipos de interface gráfica do chat de IA. Cada um casa com um perfil de uso
/// e muda o layout das mensagens, a densidade, o acento e as sugestões iniciais.
enum ChatInterface { assistente, executivo, recepcao, clinico }

/// Sugestão inicial exibida na tela de boas-vindas do chat.
class ChatSuggestion {
  const ChatSuggestion(this.icon, this.color, this.title, this.prompt);
  final IconData icon;
  final Color color;
  final String title;
  final String prompt;
}

/// Configuração visual/comportamental de uma [ChatInterface].
class ChatInterfaceStyle {
  const ChatInterfaceStyle({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.bubbles,
    required this.fontScale,
    required this.density,
    required this.accent,
    required this.welcomeTitle,
    required this.welcomeSubtitle,
    required this.suggestions,
  });

  final ChatInterface id;
  final String label;
  final String description;
  final IconData icon;

  /// `true` → mensagens em balões (usuário à direita); `false` → estilo
  /// "documento" full-width (assistente rotulado, leitura corrida).
  final bool bubbles;

  /// Multiplicador do tamanho da fonte (acessibilidade/densidade).
  final double fontScale;

  /// Multiplicador do espaçamento interno das mensagens.
  final double density;

  /// Cor de destaque (balão do usuário, rótulos, ícones).
  final Color accent;

  final String welcomeTitle;
  final String welcomeSubtitle;
  final List<ChatSuggestion> suggestions;
}

/// Catálogo das interfaces disponíveis.
final Map<ChatInterface, ChatInterfaceStyle> chatInterfaceStyles = {
  ChatInterface.assistente: ChatInterfaceStyle(
    id: ChatInterface.assistente,
    label: 'Assistente',
    description: 'Conversa clássica em balões. Equilíbrio para uso geral.',
    icon: Icons.chat_bubble_outline,
    bubbles: true,
    fontScale: 1.0,
    density: 1.0,
    accent: AppColors.pinkAccent,
    welcomeTitle: 'Como posso ajudar?',
    welcomeSubtitle:
        'Ferramentas MCP conectadas (clínica do usuário). Pergunte sobre\n'
        'agendamentos, médicos, pacientes ou risco de absenteísmo.',
    suggestions: const [
      ChatSuggestion(Icons.calendar_month, AppColors.pinkAccent, 'Agenda',
          'Quais agendamentos temos hoje?'),
      ChatSuggestion(Icons.people, Colors.tealAccent, 'Médicos',
          'Liste os médicos ativos da clínica'),
      ChatSuggestion(Icons.warning_amber, Colors.orangeAccent, 'Riscos',
          'Quais pacientes têm maior risco de faltar nos próximos 7 dias?'),
      ChatSuggestion(Icons.insights, Colors.blueAccent, 'Absenteísmo',
          'Qual a taxa de absenteísmo deste mês? Mostre um gráfico.'),
    ],
  ),
  ChatInterface.executivo: ChatInterfaceStyle(
    id: ChatInterface.executivo,
    label: 'Executivo',
    description:
        'Painel de gestão: respostas full-width com foco em indicadores e gráficos.',
    icon: Icons.insights_outlined,
    bubbles: false,
    fontScale: 1.0,
    density: 1.2,
    accent: Color(0xFFC084FC),
    welcomeTitle: 'Visão executiva',
    welcomeSubtitle:
        'Peça indicadores, comparativos e gráficos consolidados da clínica.\n'
        'Ideal para decisões de gestão.',
    suggestions: const [
      ChatSuggestion(Icons.insights, Color(0xFFC084FC), 'KPIs',
          'Resuma os principais indicadores da clínica neste mês com gráficos.'),
      ChatSuggestion(Icons.trending_down, Colors.orangeAccent, 'Absenteísmo',
          'Compare a taxa de absenteísmo das últimas 4 semanas em um gráfico.'),
      ChatSuggestion(Icons.event_available, Colors.tealAccent, 'Ocupação',
          'Qual a taxa de ocupação por especialidade? Mostre um gráfico.'),
      ChatSuggestion(Icons.summarize, Colors.blueAccent, 'Relatório',
          'Gere um relatório executivo da operação desta semana.'),
    ],
  ),
  ChatInterface.recepcao: ChatInterfaceStyle(
    id: ChatInterface.recepcao,
    label: 'Recepção',
    description:
        'Atendimento: fonte maior, layout simples e ações rápidas do dia.',
    icon: Icons.support_agent_outlined,
    bubbles: true,
    fontScale: 1.18,
    density: 1.25,
    accent: Colors.tealAccent,
    welcomeTitle: 'Atendimento rápido',
    welcomeSubtitle:
        'Consulte a agenda do dia, confirme pacientes e organize a fila.',
    suggestions: const [
      ChatSuggestion(Icons.today, Colors.tealAccent, 'Agenda de hoje',
          'Mostre a agenda de hoje, por horário.'),
      ChatSuggestion(Icons.check_circle_outline, Colors.green, 'Confirmar',
          'Quais pacientes de hoje ainda não confirmaram presença?'),
      ChatSuggestion(Icons.people_outline, Colors.orangeAccent, 'Fila',
          'Como está a fila de espera da recepção agora?'),
      ChatSuggestion(Icons.event_repeat, AppColors.pinkAccent, 'Encaixe',
          'Há horários livres para encaixe nesta tarde?'),
    ],
  ),
  ChatInterface.clinico: ChatInterfaceStyle(
    id: ChatInterface.clinico,
    label: 'Clínico',
    description:
        'Leitura clínica: texto corrido full-width, denso e sem distrações.',
    icon: Icons.medical_information_outlined,
    bubbles: false,
    fontScale: 1.0,
    density: 0.9,
    accent: Colors.blueAccent,
    welcomeTitle: 'Apoio clínico',
    welcomeSubtitle:
        'Consulte pacientes do dia, históricos e sinais de risco para a consulta.',
    suggestions: const [
      ChatSuggestion(Icons.assignment_ind_outlined, Colors.blueAccent,
          'Meus pacientes', 'Quais são meus pacientes agendados para hoje?'),
      ChatSuggestion(Icons.history, Colors.tealAccent, 'Histórico',
          'Resuma o histórico de atendimentos do próximo paciente.'),
      ChatSuggestion(Icons.warning_amber, Colors.orangeAccent, 'Risco',
          'Algum paciente de hoje tem alto risco de falta ou retorno pendente?'),
      ChatSuggestion(Icons.event_repeat, AppColors.pinkAccent, 'Retornos',
          'Liste os retornos previstos para os próximos 15 dias.'),
    ],
  ),
};

/// Estilo correspondente a uma interface (sempre presente no catálogo).
ChatInterfaceStyle chatStyleOf(ChatInterface i) => chatInterfaceStyles[i]!;

/// Interface padrão para a [roleLabel] do usuário (mapeamento por palavra-chave).
ChatInterface defaultChatInterfaceForRole(String roleLabel) {
  final r = roleLabel.toLowerCase();
  if (r.contains('recep') || r.contains('atend') || r.contains('secret')) {
    return ChatInterface.recepcao;
  }
  if (r.contains('méd') ||
      r.contains('med') ||
      r.contains('doutor') ||
      r.contains('enferm') ||
      r.startsWith('dr')) {
    return ChatInterface.clinico;
  }
  if (r.contains('gestor') ||
      r.contains('admin') ||
      r.contains('diretor') ||
      r.contains('gerente') ||
      r.contains('coorden')) {
    return ChatInterface.executivo;
  }
  return ChatInterface.assistente;
}

/// Override do usuário para a interface do chat. `null` = automático (por role).
/// Persistido em SharedPreferences.
class ChatInterfaceNotifier extends StateNotifier<ChatInterface?> {
  ChatInterfaceNotifier(this._prefs) : super(_load(_prefs));

  static const _key = 'chat_interface';
  final SharedPreferences _prefs;

  static ChatInterface? _load(SharedPreferences p) {
    final v = p.getString(_key);
    if (v == null || v == 'auto') return null;
    for (final i in ChatInterface.values) {
      if (i.name == v) return i;
    }
    return null;
  }

  /// Volta ao modo automático (interface derivada da role).
  void setAuto() {
    state = null;
    _prefs.setString(_key, 'auto');
  }

  /// Fixa uma interface escolhida manualmente.
  void select(ChatInterface i) {
    state = i;
    _prefs.setString(_key, i.name);
  }
}

/// Override manual da interface (ou `null` para automático).
final chatInterfaceProvider =
    StateNotifierProvider<ChatInterfaceNotifier, ChatInterface?>((ref) {
  return ChatInterfaceNotifier(ref.watch(sharedPrefsProvider));
});

/// `true` quando a interface está no modo automático (sem override).
final chatInterfaceIsAutoProvider =
    Provider<bool>((ref) => ref.watch(chatInterfaceProvider) == null);

/// Interface efetiva do chat: override do usuário ou padrão da role.
final effectiveChatInterfaceProvider = Provider<ChatInterface>((ref) {
  final override = ref.watch(chatInterfaceProvider);
  if (override != null) return override;
  final role = ref.watch(currentUserProvider).roleLabel;
  return defaultChatInterfaceForRole(role);
});
