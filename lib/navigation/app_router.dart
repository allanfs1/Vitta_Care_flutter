import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/modules/module_registry.dart';
import '../core/services/app_providers.dart';
import '../features/absenteismo/absenteismo_screen.dart';
import '../features/agenda_publica/agenda_publica_screen.dart';
import '../features/agendamentos/agendamentos_screen.dart';
import '../features/agendamentos/appointment_detail_screen.dart';
import '../features/arquitetura/arquitetura_screen.dart';
import '../features/cerebro/cerebro_screen.dart';
import '../features/evidencias/evidencias_screen.dart';
import '../features/auth/choose_plan_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/plano_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/configuracoes/screens/configuracoes_hub_screen.dart';
import '../features/equipe_medica/equipe_medica_screen.dart';
import '../features/equipe_medica/medico_agenda_screen.dart';
import '../features/monte_carlo/monte_carlo_screen.dart';
import '../features/projecao_12m/projecao_screen.dart';
import '../features/overbooking/overbooking_screen.dart';
import '../features/home/home_screen.dart';
import '../features/ia/ia_screen.dart';
import '../features/notificacoes_centro/notificacoes_centro_screen.dart';
import '../features/pacientes/pacientes_screen.dart';
import '../features/perfil_clinica/perfil_clinica_screen.dart';
import '../features/perfil_usuario/perfil_usuario_screen.dart';
import '../features/recepcao/recepcao_screen.dart';
import '../features/recepcao/recepcao_monitor_screen.dart';
import '../features/relatorios/relatorios_screen.dart';
import '../features/satisfacao/satisfacao_screen.dart';
import '../features/tarefas_agendadas/tarefas_agendadas_screen.dart';
import '../features/health_score/health_score_screen.dart';
import '../features/health_score/health_score_detail_screen.dart';
import '../features/whatsapp/whatsapp_screen.dart';
import '../features/admin_agentes/admin_agentes_screen.dart';
import '../features/agent_dashboard/agent_dashboard_screen.dart';
import '../features/totem/totem_screen.dart';
import 'app_shell.dart';

/// Rotas centralizadas (NAV-01). Suporta deep linking (NAV-04), ex.:
/// `/agendamentos/a1` abre o detalhe da consulta diretamente.
class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const register = '/register';
  static const choosePlan = '/choose-plan';

  static const home = '/home';
  static const agendamentos = '/agendamentos';
  static const absenteismo = '/absenteismo';
  static const ia = '/ia';
  static const cerebro = '/cerebro';
  static const evidencias = '/evidencias';
  static const perfilUsuario = '/perfil-usuario';
  static const perfilClinica = '/perfil-clinica';
  static const whatsapp = '/whatsapp';
  static const arquitetura = '/arquitetura';
  static const plano = '/plano';
  static const configuracoes = '/configuracoes';
  static const pacientes = '/pacientes';
  static const equipeMedica = '/equipe-medica';
  static const monteCarlo = '/simulador';
  static const projecao12m = '/projecao-12m';
  static const overbooking = '/overbooking';
  static const recepcao = '/recepcao';
  static const recepcaoMonitor = '/monitor-recepcao';
  static const notificacoes = '/notificacoes';
  static const relatorios = '/relatorios';
  static const satisfacao = '/satisfacao';
  static const healthScore = '/health-score';
  static const tarefasAgendadas = '/tarefas-agendadas';
  static const adminAgentes = '/admin-agentes';
  static const agentDashboard = '/agent-dashboard';
  static const totem = '/totem';
  static const agendaMedico = '/agenda-medico';
  static const agendaPublica = '/agenda-publica';

  static String appointmentDetail(String id) => '/agendamentos/$id';
  static String agendaMedicoPath(String id) => '/agenda-medico/$id';
  static String agendaPublicaPath(String id) => '/agenda-publica/$id';

  static const authRoutes = {login, register, choosePlan};
}

final _shellKey = GlobalKey<NavigatorState>();

/// Router como provider para reagir ao estado de autenticação (Firebase Auth).
final routerProvider = Provider<GoRouter>((ref) {
  // Notifica o GoRouter quando muda a autenticação ou os módulos habilitados.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (prev, next) => refresh.value++);
  ref.listen(disabledModulesProvider, (prev, next) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/') return AppRoutes.home;

      // O totem é público (acessível sem login), mas pode ser desligado no
      // Mapa de Módulos (/arquitetura). Quando desabilitado, bloqueia a rota.
      final disabledModules = ref.read(disabledModulesProvider);
      if (loc == AppRoutes.totem && disabledModules.contains('totem')) {
        return AppRoutes.home;
      }

      final isPublic = loc == AppRoutes.totem ||
          loc == AppRoutes.recepcaoMonitor ||
          loc.startsWith('${AppRoutes.agendaMedico}/') ||
          loc.startsWith('${AppRoutes.agendaPublica}/');
      if (isPublic) return null;

      final auth = ref.read(authProvider);
      final inAuthArea = AppRoutes.authRoutes.contains(loc);

      // Não autenticado → vai para login (exceto se já está em login/cadastro).
      if (!auth.isAuthenticated) {
        return inAuthArea && loc != AppRoutes.choosePlan ? null : AppRoutes.login;
      }
      // Autenticado mas sem plano → escolher plano.
      if (!auth.hasPlan && loc != AppRoutes.choosePlan) {
        return AppRoutes.choosePlan;
      }
      // Já tem plano vinculado → /choose-plan só é permitido em modo "trocar".
      final changingPlan = state.uri.queryParameters['change'] == 'true';
      if (auth.hasPlan && loc == AppRoutes.choosePlan && !changingPlan) {
        return AppRoutes.home;
      }
      // Autenticado em tela de login/cadastro → segue para a home.
      if (loc == AppRoutes.login || loc == AppRoutes.register) {
        return AppRoutes.home;
      }
      // Módulo desabilitado pelo usuário → bloqueia a rota (volta para a home).
      for (final id in disabledModules) {
        final route = ModuleRegistry.find(id)?.route;
        if (route != null && (loc == route || loc.startsWith('$route/'))) {
          return AppRoutes.home;
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (c, s) => const RegisterScreen()),
      GoRoute(path: AppRoutes.choosePlan, builder: (c, s) => const ChoosePlanScreen()),
      // Monitor da Recepção — display público em tela cheia (fora do shell).
      GoRoute(
        path: AppRoutes.recepcaoMonitor,
        builder: (c, s) => const RecepcaoMonitorScreen(),
      ),
      // Totem de Autoatendimento
      GoRoute(
        path: AppRoutes.totem,
        builder: (c, s) => const TotemScreen(),
      ),
      // Agenda pública do médico (em tempo real) — acessível sem login (QR Code).
      GoRoute(
        path: '${AppRoutes.agendaMedico}/:id',
        builder: (c, s) =>
            MedicoAgendaScreen(doctorId: s.pathParameters['id']!),
      ),
      // Página pública do médico (perfil + horários disponíveis, no estilo do
      // totem) — o link que o profissional compartilha com os pacientes.
      GoRoute(
        path: '${AppRoutes.agendaPublica}/:id',
        builder: (c, s) =>
            AgendaPublicaScreen(doctorId: s.pathParameters['id']!),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (c, s) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.agendamentos,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: AgendamentosScreen()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (c, s) =>
                    AppointmentDetailScreen(appointmentId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.absenteismo,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: AbsenteismoScreen()),
          ),
          GoRoute(
            path: AppRoutes.ia,
            pageBuilder: (c, s) => const NoTransitionPage(child: IaScreen()),
          ),
          // Cérebro Vitta — segundo cérebro (.specify/obsidian/obsidian.md)
          GoRoute(
            path: AppRoutes.cerebro,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: CerebroScreen()),
          ),
          // Evidências — pesquisa PubMed/NCBI (.specify/EVIDENCIAS.md)
          GoRoute(
            path: AppRoutes.evidencias,
            pageBuilder: (c, s) =>
                const NoTransitionPage(child: EvidenciasScreen()),
          ),
          GoRoute(
            path: AppRoutes.perfilUsuario,
            builder: (c, s) => const PerfilUsuarioScreen(),
          ),
          GoRoute(
            path: AppRoutes.perfilClinica,
            builder: (c, s) => const PerfilClinicaScreen(),
          ),
          GoRoute(
            path: AppRoutes.whatsapp,
            builder: (c, s) => const WhatsappScreen(),
          ),
          GoRoute(
            path: AppRoutes.arquitetura,
            builder: (c, s) => const ArquiteturaScreen(),
          ),
          GoRoute(
            path: AppRoutes.plano,
            builder: (c, s) => const PlanoScreen(),
          ),
          GoRoute(
            path: AppRoutes.configuracoes,
            builder: (c, s) => const ConfiguracoesHubScreen(),
          ),
          GoRoute(
            path: AppRoutes.pacientes,
            builder: (c, s) => const PacientesScreen(),
          ),
          GoRoute(
            path: AppRoutes.equipeMedica,
            builder: (c, s) => const EquipeMedicaScreen(),
          ),
          GoRoute(
            path: AppRoutes.overbooking,
            builder: (c, s) => const OverbookingScreen(),
          ),
          GoRoute(
            path: AppRoutes.monteCarlo,
            builder: (c, s) => const MonteCarloScreen(),
          ),
          GoRoute(
            path: AppRoutes.projecao12m,
            builder: (c, s) => const Projecao12mScreen(),
          ),
          GoRoute(
            path: AppRoutes.recepcao,
            builder: (c, s) => const RecepcaoScreen(),
          ),
          GoRoute(
            path: AppRoutes.notificacoes,
            builder: (c, s) => const NotificacoesCentroScreen(),
          ),
          GoRoute(
            path: AppRoutes.relatorios,
            builder: (c, s) => const RelatoriosScreen(),
          ),
          GoRoute(
            path: AppRoutes.satisfacao,
            builder: (c, s) => const SatisfacaoScreen(),
          ),
          GoRoute(
            path: AppRoutes.tarefasAgendadas,
            builder: (c, s) => const TarefasAgendadasScreen(),
          ),
          GoRoute(
            path: AppRoutes.healthScore,
            builder: (c, s) => const HealthScoreScreen(),
          ),
          GoRoute(
            path: '${AppRoutes.healthScore}/:id',
            builder: (c, s) => HealthScoreDetailScreen(
              patientId: s.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.adminAgentes,
            builder: (c, s) => const AdminAgentesScreen(),
          ),
          GoRoute(
            path: '${AppRoutes.agentDashboard}/:uid',
            builder: (c, s) => AgentDashboardScreen(
              uid: s.pathParameters['uid']!,
            ),
          ),
        ],
      ),
    ],
  );
});
