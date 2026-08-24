import 'package:flutter/material.dart';

import 'app_router.dart';

/// Item de navegação reutilizado pela bottom bar, nav rail e drawer.
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

/// Destinos principais (NAV-03 — bottom navigation).
const List<NavItem> primaryDestinations = [
  NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    route: AppRoutes.home,
  ),
  NavItem(
    label: 'Agenda',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    route: AppRoutes.agendamentos,
  ),
  NavItem(
    label: 'Absenteísmo',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    route: AppRoutes.absenteismo,
  ),
  NavItem(
    label: 'IA',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
    route: AppRoutes.ia,
  ),
  NavItem(
    label: 'Totem',
    icon: Icons.touch_app_outlined,
    selectedIcon: Icons.touch_app,
    route: AppRoutes.totem,
  ),
];

/// Destinos secundários (apenas no drawer / rail estendido).
const List<NavItem> secondaryDestinations = [
  NavItem(
    label: 'Cérebro',
    icon: Icons.psychology_outlined,
    selectedIcon: Icons.psychology,
    route: AppRoutes.cerebro,
  ),
  NavItem(
    label: 'Pacientes',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    route: AppRoutes.pacientes,
  ),
  NavItem(
    label: 'Equipe Médica',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    route: AppRoutes.equipeMedica,
  ),
  NavItem(
    label: 'Overbooking',
    icon: Icons.event_seat_outlined,
    selectedIcon: Icons.event_seat,
    route: AppRoutes.overbooking,
  ),
  NavItem(
    label: 'Recepção',
    icon: Icons.support_agent_outlined,
    selectedIcon: Icons.support_agent,
    route: AppRoutes.recepcao,
  ),
  NavItem(
    label: 'Relatórios',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
    route: AppRoutes.relatorios,
  ),
  NavItem(
    label: 'Satisfação',
    icon: Icons.sentiment_satisfied_alt_outlined,
    selectedIcon: Icons.sentiment_satisfied_alt,
    route: AppRoutes.satisfacao,
  ),
  NavItem(
    label: 'Health Score',
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
    route: AppRoutes.healthScore,
  ),
  NavItem(
    label: 'Notificações',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    route: AppRoutes.notificacoes,
  ),
  NavItem(
    label: 'Perfil do Usuário',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    route: AppRoutes.perfilUsuario,
  ),
  NavItem(
    label: 'Perfil da Clínica',
    icon: Icons.local_hospital_outlined,
    selectedIcon: Icons.local_hospital,
    route: AppRoutes.perfilClinica,
  ),
  NavItem(
    label: 'Gestão de Atend.',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    route: AppRoutes.adminAgentes,
  ),
  NavItem(
    label: 'Tarefas Agendadas',
    icon: Icons.schedule_outlined,
    selectedIcon: Icons.schedule,
    route: AppRoutes.tarefasAgendadas,
  ),
  NavItem(
    label: 'WhatsApp',
    icon: Icons.chat_outlined,
    selectedIcon: Icons.chat,
    route: AppRoutes.whatsapp,
  ),
  NavItem(
    label: 'Plano',
    icon: Icons.workspace_premium_outlined,
    selectedIcon: Icons.workspace_premium,
    route: AppRoutes.plano,
  ),
  NavItem(
    label: 'Configurações',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    route: AppRoutes.configuracoes,
  ),
  NavItem(
    label: 'Mapa de Módulos',
    icon: Icons.account_tree_outlined,
    selectedIcon: Icons.account_tree,
    route: AppRoutes.arquitetura,
  ),
];
