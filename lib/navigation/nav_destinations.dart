import 'package:flutter/material.dart';

import '../core/i18n/textos.dart';

import 'app_router.dart';

/// Item de navegação reutilizado pela bottom bar, nav rail e drawer.
class NavItem {
  const NavItem({
    required this.chave,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  /// Chave de tradução do rótulo (`nav.*`).
  ///
  /// A lista de destinos é `const` de topo — não existe `context` aqui para
  /// resolver o texto. Por isso o item guarda a **chave** e quem desenha
  /// resolve: `context.txt.t(item.chave)`. Tentar guardar o texto já
  /// traduzido exigiria construir a lista dentro de um `build`, e ela deixaria
  /// de ser const.
  final String chave;

  /// Rótulo em português. Continua aqui como **rede de segurança**: se a chave
  /// sumir do mapa de textos, o menu mostra isto em vez de exibir a chave crua
  /// para o usuário.
  final String label;

  final IconData icon;
  final IconData selectedIcon;
  final String route;

  /// Texto a exibir, com queda para [label].
  String texto(Textos t) {
    final traduzido = t.t(chave);
    return traduzido == chave ? label : traduzido;
  }
}

/// Destinos principais (NAV-03 — bottom navigation).
const List<NavItem> primaryDestinations = [
  NavItem(
    chave: 'nav.dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    route: AppRoutes.home,
  ),
  NavItem(
    chave: 'nav.agenda',
    label: 'Agenda',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    route: AppRoutes.agendamentos,
  ),
  NavItem(
    chave: 'nav.absenteismo',
    label: 'Absenteísmo',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    route: AppRoutes.absenteismo,
  ),
  NavItem(
    chave: 'nav.ia',
    label: 'IA',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
    route: AppRoutes.ia,
  ),
  NavItem(
    chave: 'nav.totem',
    label: 'Totem',
    icon: Icons.touch_app_outlined,
    selectedIcon: Icons.touch_app,
    route: AppRoutes.totem,
  ),
];

/// Destinos secundários (apenas no drawer / rail estendido).
const List<NavItem> secondaryDestinations = [
  NavItem(
    chave: 'nav.cerebro',
    label: 'Cérebro',
    icon: Icons.psychology_outlined,
    selectedIcon: Icons.psychology,
    route: AppRoutes.cerebro,
  ),
  NavItem(
    chave: 'nav.evidencias',
    label: 'Evidências',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    route: AppRoutes.evidencias,
  ),
  NavItem(
    chave: 'nav.pacientes',
    label: 'Pacientes',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    route: AppRoutes.pacientes,
  ),
  NavItem(
    chave: 'nav.equipeMedica',
    label: 'Equipe Médica',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    route: AppRoutes.equipeMedica,
  ),
  NavItem(
    chave: 'nav.overbooking',
    label: 'Overbooking',
    icon: Icons.event_seat_outlined,
    selectedIcon: Icons.event_seat,
    route: AppRoutes.overbooking,
  ),
  NavItem(
    chave: 'nav.simulador',
    label: 'Simulador',
    icon: Icons.casino_outlined,
    selectedIcon: Icons.casino,
    route: AppRoutes.monteCarlo,
  ),
  NavItem(
    chave: 'nav.recepcao',
    label: 'Recepção',
    icon: Icons.support_agent_outlined,
    selectedIcon: Icons.support_agent,
    route: AppRoutes.recepcao,
  ),
  NavItem(
    chave: 'nav.relatorios',
    label: 'Relatórios',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
    route: AppRoutes.relatorios,
  ),
  NavItem(
    chave: 'nav.satisfacao',
    label: 'Satisfação',
    icon: Icons.sentiment_satisfied_alt_outlined,
    selectedIcon: Icons.sentiment_satisfied_alt,
    route: AppRoutes.satisfacao,
  ),
  NavItem(
    chave: 'nav.healthScore',
    label: 'Health Score',
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
    route: AppRoutes.healthScore,
  ),
  NavItem(
    chave: 'nav.notificacoes',
    label: 'Notificações',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    route: AppRoutes.notificacoes,
  ),
  NavItem(
    chave: 'nav.perfilUsuario',
    label: 'Perfil do Usuário',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    route: AppRoutes.perfilUsuario,
  ),
  NavItem(
    chave: 'nav.perfilClinica',
    label: 'Perfil da Clínica',
    icon: Icons.local_hospital_outlined,
    selectedIcon: Icons.local_hospital,
    route: AppRoutes.perfilClinica,
  ),
  NavItem(
    chave: 'nav.gestaoDeAtend',
    label: 'Gestão de Atend.',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    route: AppRoutes.adminAgentes,
  ),
  NavItem(
    chave: 'nav.tarefasAgendadas',
    label: 'Tarefas Agendadas',
    icon: Icons.schedule_outlined,
    selectedIcon: Icons.schedule,
    route: AppRoutes.tarefasAgendadas,
  ),
  NavItem(
    chave: 'nav.whatsapp',
    label: 'WhatsApp',
    icon: Icons.chat_outlined,
    selectedIcon: Icons.chat,
    route: AppRoutes.whatsapp,
  ),
  NavItem(
    chave: 'nav.plano',
    label: 'Plano',
    icon: Icons.workspace_premium_outlined,
    selectedIcon: Icons.workspace_premium,
    route: AppRoutes.plano,
  ),
  NavItem(
    chave: 'nav.configuracoes',
    label: 'Configurações',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    route: AppRoutes.configuracoes,
  ),
  NavItem(
    chave: 'nav.mapaDeModulos',
    label: 'Mapa de Módulos',
    icon: Icons.account_tree_outlined,
    selectedIcon: Icons.account_tree,
    route: AppRoutes.arquitetura,
  ),
];
