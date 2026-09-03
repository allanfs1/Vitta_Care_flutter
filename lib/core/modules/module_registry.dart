import 'package:flutter/material.dart';

import '../../navigation/app_router.dart';
import 'module.dart';

/// Registro central de módulos e do **Mapa de Dependências entre Módulos**
/// (AGENTS.md). Fonte única da verdade para o grafo de dependências, prioridades,
/// isolamento de coleções e status de implementação.
///
/// Arestas (dependsOn) reproduzem exatamente o diagrama:
/// ```
/// auth → home → agendamentos → criar_agendamento → {ia, financeiro}
///         home → recepcao → {tickets, prever}
///         ia → integracoes
/// ```
class ModuleRegistry {
  ModuleRegistry._();

  static const List<AppModule> modules = [
    // ── Base (P0) ───────────────────────────────────────────────
    AppModule(
      id: 'auth',
      title: 'Autenticação e Planos',
      code: 'Auth(9)',
      icon: Icons.lock_outline,
      priority: ModulePriority.p0,
      status: ModuleStatus.implemented,
      route: AppRoutes.login,
      ownedCollections: ['tb_plan_user', 'tb_users_term'],
      readsCollections: ['users', 'tb_plans', 'tb_limit_app'],
      description: 'Login, cadastro, recuperação de senha (Firebase) e escolha de plano.',
    ),
    AppModule(
      id: 'navegacao',
      title: 'Navegação',
      code: 'Nav(8)',
      icon: Icons.alt_route,
      priority: ModulePriority.p0,
      status: ModuleStatus.implemented,
      dependsOn: ['auth'],
      description: 'Rotas centralizadas, shell responsivo, drawer e deep linking.',
    ),
    AppModule(
      id: 'home',
      title: 'Dashboard Home',
      code: 'Home(1)',
      icon: Icons.dashboard_outlined,
      priority: ModulePriority.p0,
      status: ModuleStatus.implemented,
      route: AppRoutes.home,
      dependsOn: ['auth', 'navegacao'],
      readsCollections: ['tb_clinica', 'tb_agendamentos', 'dashboard_risco', 'tb_medicos'],
      description: 'Visão geral consolidada da clínica selecionada (KPIs, gráficos).',
    ),

    // ── Core business (P0) ──────────────────────────────────────
    AppModule(
      id: 'agendamentos',
      title: 'Agendamentos',
      code: 'Agend.(2)',
      icon: Icons.calendar_today_outlined,
      priority: ModulePriority.p0,
      status: ModuleStatus.implemented,
      route: AppRoutes.agendamentos,
      dependsOn: ['home'],
      ownedCollections: ['tb_agendamentos'],
      readsCollections: ['tb_medicos', 'tb_clinica', 'users'],
      description: 'Lista, detalhe, ações (confirmar/cancelar/reagendar) e timeline.',
    ),
    AppModule(
      id: 'carrossel_agendamentos',
      title: 'Carrossel de Agendamentos',
      code: 'Carrossel',
      icon: Icons.view_carousel_outlined,
      priority: ModulePriority.p1,
      status: ModuleStatus.implemented,
      dependsOn: ['home', 'agendamentos'],
      description: 'Módulo do dashboard que exibe os próximos agendamentos confirmados em um carrossel interativo.',
    ),
    AppModule(
      id: 'criar_agendamento',
      title: 'Criar Agendamento',
      code: 'Criar(2)',
      icon: Icons.event_available,
      priority: ModulePriority.p0,
      status: ModuleStatus.partial,
      dependsOn: ['agendamentos'],
      ownedCollections: ['tb_pre_agendamentos'],
      readsCollections: ['tb_hour_agenda', 'tb_hour_atendimento_medico'],
      description: 'Fluxo de criação/pré-agendamento de consultas.',
    ),

    // ── Fluxo diário (P1) ───────────────────────────────────────
    AppModule(
      id: 'recepcao',
      title: 'Recepção',
      code: 'Recep.(5)',
      icon: Icons.support_agent_outlined,
      priority: ModulePriority.p1,
      status: ModuleStatus.implemented,
      route: AppRoutes.recepcao,
      dependsOn: ['home'],
      ownedCollections: ['queue_realoc', 'tb_confirmationHistory'],
      readsCollections: ['tb_agendamentos'],
      description: 'Check-in, fila de espera, painel de senha e KPIs do balcão.',
    ),
    AppModule(
      id: 'pacientes',
      title: 'Pacientes',
      code: 'Pacientes(5)',
      icon: Icons.people_outline,
      priority: ModulePriority.p1,
      status: ModuleStatus.implemented,
      route: AppRoutes.pacientes,
      dependsOn: ['home'],
      ownedCollections: ['tb_historico'],
      readsCollections: ['users', 'patient_reputation', 'tb_agendamentos'],
      description: 'Lista, prontuário, jornada e notas clínicas do paciente.',
    ),
    AppModule(
      id: 'equipe_medica',
      title: 'Equipe Médica',
      code: 'Equipe(EM)',
      icon: Icons.badge_outlined,
      priority: ModulePriority.p1,
      status: ModuleStatus.implemented,
      route: AppRoutes.equipeMedica,
      dependsOn: ['home'],
      ownedCollections: ['tb_medicos', 'tb_medicos_config_history'],
      readsCollections: ['tb_clinica', 'tb_limit_app', 'tb_agendamentos'],
      description:
          'Listagem, busca e CRUD dos profissionais da clínica (cadastro, '
          'edição, ativação/desativação e configurações).',
    ),
    AppModule(
      id: 'totem',
      title: 'Totem de Autoatendimento',
      code: 'Totem(T)',
      icon: Icons.touch_app_outlined,
      priority: ModulePriority.p1,
      status: ModuleStatus.implemented,
      route: AppRoutes.totem,
      // Independente da Recepção: o quiosque cria/remarca agendamentos por conta
      // própria (via CPF) e não consome o estado da fila da recepção.
      dependsOn: ['agendamentos'],
      readsCollections: ['users', 'tb_medicos', 'tb_agendamentos'],
      description:
          'Quiosque público de autoatendimento: agendar/remarcar consultas '
          'por CPF, com senha e comprovante. Funciona sem login.',
    ),

    AppModule(
      id: 'overbooking',
      title: 'Overbooking',
      code: 'Overb.(§1)',
      icon: Icons.event_seat_outlined,
      priority: ModulePriority.p2,
      status: ModuleStatus.implemented,
      route: AppRoutes.overbooking,
      dependsOn: ['equipe_medica'],
      readsCollections: ['tb_medicos', 'tb_agendamentos'],
      ownedCollections: ['tb_overbooking_events', 'tb_overbooking_reports'],
      description:
          'Painel de gestão de overbooking: ocupação por médico/hora, '
          'capacidade (limite base + overbook) e edição da configuração.',
    ),

    // ── Analytics / atendimento (P2) ────────────────────────────
    AppModule(
      id: 'monte_carlo',
      title: 'Simulador (Monte Carlo)',
      code: 'MC(§1)',
      icon: Icons.casino_outlined,
      priority: ModulePriority.p2,
      status: ModuleStatus.implemented,
      route: AppRoutes.monteCarlo,
      dependsOn: ['agendamentos', 'equipe_medica', 'overbooking'],
      readsCollections: ['tb_agendamentos', 'tb_medicos'],
      description:
          'Distribuição de faltas do dia e decisão de overbooking por slot '
          '(médico × hora), com dependência entre faltas do mesmo dia. '
          'Puramente derivado da agenda — não escreve em nenhuma coleção.',
    ),
    AppModule(
      id: 'projecao_12m',
      title: 'Projeção 12 meses',
      code: 'Proj(12m)',
      icon: Icons.timeline_outlined,
      priority: ModulePriority.p3,
      status: ModuleStatus.partial,
      route: AppRoutes.projecao12m,
      dependsOn: ['agendamentos', 'monte_carlo'],
      readsCollections: ['tb_agendamentos'],
      description:
          'Cenário de continuidade x cenário com intervenção em 12 meses: '
          'cadeia de Markov, simulação com três camadas de incerteza — as duas '
          'epistêmicas persistem no horizonte —, restrição de capacidade e '
          'receita decomposta em defensável e antecipação. Traz a aba de '
          'governança: piso de intervenção como invariante, usos proibidos do '
          'escore bloqueados em código, poder do piloto e partida a frio. '
          'Parâmetros de impacto são hipótese até o piloto calibrar.',
    ),
    AppModule(
      id: 'absenteismo',
      title: 'Absenteísmo',
      code: 'Absent.(1)',
      icon: Icons.insights_outlined,
      priority: ModulePriority.p2,
      status: ModuleStatus.implemented,
      route: AppRoutes.absenteismo,
      dependsOn: ['home'],
      ownedCollections: ['tb_faltas_data', 'dashboard_risco'],
      readsCollections: ['tb_agendamentos', 'tb_medicos'],
      description: 'Faltas, cancelamentos, heatmap, risco e relatórios de IA.',
    ),
    AppModule(
      id: 'relatorios',
      title: 'Relatórios',
      code: 'Relat.(R)',
      icon: Icons.description_outlined,
      priority: ModulePriority.p2,
      status: ModuleStatus.implemented,
      route: AppRoutes.relatorios,
      dependsOn: ['home', 'ia'],
      readsCollections: ['tb_relatorio_ia', 'tb_faltas_data'],
      description: 'Relatórios gerados (IA e operacionais), visualização e exportação.',
    ),
    AppModule(
      id: 'satisfacao',
      title: 'Satisfação do Paciente',
      code: 'Satisf.',
      icon: Icons.sentiment_satisfied_alt,
      priority: ModulePriority.p2,
      status: ModuleStatus.implemented,
      route: AppRoutes.satisfacao,
      dependsOn: ['home'],
      ownedCollections: ['tb_avaliacoes'],
      description: 'Gestão estratégica de NPS e auditoria de qualidade.',
    ),
    AppModule(
      id: 'health_score',
      title: 'Health Score',
      code: 'HS',
      icon: Icons.monitor_heart_outlined,
      priority: ModulePriority.p2,
      status: ModuleStatus.implemented,
      route: AppRoutes.healthScore,
      dependsOn: ['home'],
      ownedCollections: ['patient_reputation'],
      readsCollections: ['tb_agendamentos', 'users'],
      description: 'Auditoria comportamental baseada em assiduidade histórica.',
    ),
    AppModule(
      id: 'notificacoes',
      title: 'Central de Notificações',
      code: 'Notif.(N)',
      icon: Icons.notifications_outlined,
      priority: ModulePriority.p3,
      status: ModuleStatus.implemented,
      route: AppRoutes.notificacoes,
      dependsOn: ['home'],
      ownedCollections: ['ff_user_push_notifications', 'notices'],
      readsCollections: ['ff_push_notifications'],
      description: 'Feed de notificações in-app, filtros, marcar como lida e badge.',
    ),
    AppModule(
      id: 'tickets',
      title: 'Atendimento (Tickets)',
      code: 'Tickets(6)',
      icon: Icons.confirmation_number_outlined,
      priority: ModulePriority.p2,
      status: ModuleStatus.planned,
      dependsOn: ['recepcao'],
      ownedCollections: ['tickets'],
      readsCollections: ['users', 'tb_clinica'],
      description: 'Atendimento ao paciente com geração de tickets/protocolos.',
    ),
    AppModule(
      id: 'financeiro',
      title: 'Financeiro',
      code: 'Financ.(3)',
      icon: Icons.payments_outlined,
      priority: ModulePriority.p2,
      status: ModuleStatus.planned,
      dependsOn: ['criar_agendamento'],
      ownedCollections: ['queues', 'tb_service'],
      readsCollections: ['tb_agendamentos', 'tb_plans'],
      description: 'Controle de receitas e faturamento por plano/consulta.',
    ),

    // ── Avançado (P3) ───────────────────────────────────────────
    AppModule(
      id: 'prever',
      title: 'Previsão de Faltas',
      code: 'Prever(7)',
      icon: Icons.online_prediction,
      priority: ModulePriority.p3,
      status: ModuleStatus.partial,
      dependsOn: ['recepcao'],
      ownedCollections: ['tb_lembrete', 'tb_lembrete_controle'],
      readsCollections: ['tb_agendamentos', 'dashboard_risco'],
      description: 'Score preditivo de faltas por paciente (insumo do Absenteísmo).',
    ),
    AppModule(
      id: 'ia',
      title: 'Inteligência Artificial',
      code: 'IA(4)',
      icon: Icons.auto_awesome_outlined,
      priority: ModulePriority.p3,
      status: ModuleStatus.implemented,
      route: AppRoutes.ia,
      dependsOn: ['criar_agendamento'],
      ownedCollections: [
        'tb_relatorio_ia',
        'tb_ia_chats',
        'tb_agent_plans',
      ],
      readsCollections: ['tb_agendamentos', 'tb_faltas_data', 'dashboard_risco'],
      description: 'Agendamento inteligente B2B, análises e relatórios por IA (Azure).',
    ),
    AppModule(
      id: 'evidencias',
      title: 'Evidências (PubMed)',
      code: 'Evid(11)',
      icon: Icons.menu_book_outlined,
      priority: ModulePriority.p3,
      status: ModuleStatus.implemented,
      route: AppRoutes.evidencias,
      dependsOn: ['ia'],
      // O cache é compartilhado entre clínicas de propósito: literatura é
      // pública e o mesmo PMID vale para todo mundo. Ver EVIDENCIAS.md §4.
      ownedCollections: ['tb_pubmed_cache', 'tb_pubmed_rate'],
      description:
          'Pesquisa de literatura científica no PubMed/NCBI com citação '
          'verificável (PMID/DOI), via Cloud Function autenticada.',
    ),
    AppModule(
      id: 'cerebro',
      title: 'Cérebro (Segundo Cérebro)',
      code: 'Cerebro(10)',
      icon: Icons.psychology_outlined,
      priority: ModulePriority.p3,
      status: ModuleStatus.implemented,
      route: AppRoutes.cerebro,
      dependsOn: ['ia'],
      ownedCollections: [
        'tb_cerebro_notas',
        'tb_cerebro_links',
        'tb_cerebro_tags',
        'tb_cerebro_vetores',
        'tb_cerebro_eventos',
        'tb_cerebro_sugestoes',
        'tb_cerebro_canvas',
        'tb_cerebro_config',
        'tb_cerebro_snapshots',
      ],
      readsCollections: ['tb_agendamentos', 'tb_medicos', 'tb_clinica'],
      description:
          'Vault de conhecimento em grafo (notas + entidades operacionais), '
          'com backlinks, busca e escrita auditável pelo agente. '
          'Spec: .specify/obsidian/obsidian.md',
    ),
    AppModule(
      id: 'integracoes',
      title: 'Integrações',
      code: 'Integr.(8)',
      icon: Icons.hub_outlined,
      priority: ModulePriority.p3,
      status: ModuleStatus.partial,
      dependsOn: ['ia'],
      ownedCollections: ['email_queue', 'email_logs', 'ff_push_notifications'],
      readsCollections: ['tb_agendamentos'],
      description: 'Google Agenda, e-mail e push (orquestração de integrações externas).',
    ),
    AppModule(
      id: 'whatsapp',
      title: 'WhatsApp (Z-API)',
      code: 'WhatsApp(7)',
      icon: Icons.chat_outlined,
      priority: ModulePriority.p3,
      status: ModuleStatus.implemented,
      route: AppRoutes.whatsapp,
      dependsOn: ['integracoes'],
      ownedCollections: ['tb_config_whatsapp', 'tb_conversas'],
      readsCollections: ['tb_agendamentos'],
      description: 'Conexão por QR Code, status, logs e mensagens automáticas.',
    ),

    // ── Complementares (P3) ─────────────────────────────────────
    AppModule(
      id: 'perfil_usuario',
      title: 'Perfil do Usuário',
      code: 'Perfil U.(5)',
      icon: Icons.person_outline,
      priority: ModulePriority.p3,
      status: ModuleStatus.implemented,
      route: AppRoutes.perfilUsuario,
      dependsOn: ['auth'],
      ownedCollections: ['users'],
      description: 'Dados pessoais, contato, endereço (CEP) e segurança.',
    ),
    AppModule(
      id: 'configuracoes',
      title: 'Configurações do Sistema',
      code: 'Config(9)',
      icon: Icons.settings_outlined,
      priority: ModulePriority.p3,
      status: ModuleStatus.implemented,
      route: AppRoutes.configuracoes,
      dependsOn: ['auth'],
      ownedCollections: ['tb_limit_app'],
      readsCollections: ['users', 'tb_clinica', 'tb_plan_user'],
      description:
          'Aparência, tipografia, tema, acessibilidade, notificações, dados e avançado.',
    ),
    AppModule(
      id: 'perfil_clinica',
      title: 'Perfil da Clínica',
      code: 'Perfil C.(6)',
      icon: Icons.local_hospital_outlined,
      priority: ModulePriority.p3,
      status: ModuleStatus.implemented,
      route: AppRoutes.perfilClinica,
      dependsOn: ['auth'],
      ownedCollections: ['tb_clinica', 'tb_horaios_atendimento'],
      description: 'Cadastro da unidade, contato, logotipo, horários e especialidades.',
    ),
  ];

  static final Map<String, AppModule> byId = {
    for (final m in modules) m.id: m,
  };

  static AppModule? find(String id) => byId[id];

  /// Id do módulo associado a uma rota (ou `null` se a rota não pertence a um
  /// módulo registrado — ex.: a própria tela de Arquitetura).
  static String? idForRoute(String route) {
    for (final m in modules) {
      if (m.route != null && m.route == route) return m.id;
    }
    return null;
  }

  /// Módulos agrupados por prioridade, na ordem P0 → P3.
  static Map<ModulePriority, List<AppModule>> get byPriority {
    final map = <ModulePriority, List<AppModule>>{
      for (final p in ModulePriority.values) p: [],
    };
    for (final m in modules) {
      map[m.priority]!.add(m);
    }
    return map;
  }
}
