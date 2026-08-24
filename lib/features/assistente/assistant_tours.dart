import 'package:flutter/material.dart';

import '../../navigation/app_router.dart';
import 'assistant_models.dart';

/// Ids de âncoras de spotlight usados pelos tours. Widgets reais se registram
/// com `AssistantTarget(anchorId: ...)` para serem destacados.
class HelpAnchors {
  HelpAnchors._();
  static const navHome = 'nav.home';
  static const navAgenda = 'nav.agenda';
  static const navTotem = 'nav.totem';
  static const navConfig = 'nav.config';
  static const navArquitetura = 'nav.arquitetura';
  static const fab = 'assistant.fab';
  static const totemCard = 'cfg.totem';
  static const agendaNew = 'agenda.new';
  static const pacientesSearch = 'pacientes.search';
  static const recepTabs = 'recepcao.tabs';
  static const homeKpis = 'home.kpis';
  static const clinicSwitcher = 'app.clinicSwitcher';
  static const whatsappConnect = 'whatsapp.connect';
}

/// Roteiros de ajuda (passo a passo) por funcionalidade. Fonte determinística
/// do assistente híbrido — a IA só entra quando nenhum tour casa com a pergunta.
const List<HelpTour> kHelpTours = [
  // ───────────────────────────────────────────── Visão geral
  HelpTour(
    id: 'visao_geral',
    title: 'Visão geral do sistema',
    description: 'Conheça as áreas principais e como tudo se conecta.',
    icon: Icons.explore_outlined,
    keywords: [
      'começar', 'visao', 'visão', 'geral', 'inicio', 'início', 'tour',
      'ajuda', 'como usar', 'overview', 'apresentação', 'primeiros passos'
    ],
    steps: [
      HelpStep(
        title: 'Bem-vindo ao Vitta 👋',
        body: 'O Vitta organiza a clínica em módulos: Dashboard, Agenda, '
            'Recepção, Pacientes, Totem de autoatendimento, IA e Configurações. '
            'Vou te levar por cada área. Use "Avançar" para seguir e "Sair" '
            'quando quiser parar.',
        route: AppRoutes.home,
      ),
      HelpStep(
        title: 'Dashboard',
        body: 'Esta é a tela inicial: estes **indicadores** consolidam a clínica '
            'selecionada — agendamentos, ocupação, absenteísmo e gráficos. É o '
            'seu "raio-x" diário. O seletor de clínica no topo troca a unidade.',
        anchorId: HelpAnchors.homeKpis,
        route: AppRoutes.home,
      ),
      HelpStep(
        title: 'Trocar de clínica',
        body: 'Toque aqui no topo para **alternar a unidade ativa**. Todos os '
            'dados (agenda, indicadores) passam a refletir a clínica escolhida.',
        anchorId: HelpAnchors.clinicSwitcher,
        route: AppRoutes.home,
      ),
      HelpStep(
        title: 'Agenda',
        body: 'Aqui ficam todas as consultas. Você confirma, cancela, remarca e '
            'abre o detalhe de cada uma, além de criar novos agendamentos. É o '
            'coração do fluxo diário.',
        anchorId: HelpAnchors.navAgenda,
        route: AppRoutes.agendamentos,
      ),
      HelpStep(
        title: 'Totem de autoatendimento',
        body: 'O Totem é uma tela cheia, pública, onde o próprio paciente agenda '
            'ou remarca pelo CPF e recebe a senha — sem precisar do balcão. '
            'Ele é totalmente configurável (veja o tour "Configurar o Totem").',
        anchorId: HelpAnchors.navTotem,
        route: AppRoutes.home,
      ),
      HelpStep(
        title: 'Configurações',
        body: 'Em Configurações você personaliza aparência, tema, notificações '
            'e o Totem (com prévia ao vivo e perfis prontos por tipo de unidade). '
            'Tudo é salvo automaticamente.',
        anchorId: HelpAnchors.navConfig,
        route: AppRoutes.configuracoes,
      ),
      HelpStep(
        title: 'Precisa de algo específico?',
        body: 'A qualquer momento, toque no botão "Ajuda" e descreva o que quer '
            'fazer. Eu respondo e, quando der, inicio um tour que destaca os '
            'botões na própria tela. Bom trabalho! 🚀',
        route: AppRoutes.home,
      ),
    ],
  ),

  // ───────────────────────────────────────────── Agenda
  HelpTour(
    id: 'agenda',
    title: 'Gerenciar a Agenda',
    description: 'Confirmar, cancelar, remarcar, abrir detalhes e criar.',
    icon: Icons.calendar_today_outlined,
    keywords: [
      'agenda', 'agendamento', 'agendamentos', 'consulta', 'confirmar',
      'cancelar', 'reagendar', 'remarcar', 'criar consulta', 'marcar'
    ],
    steps: [
      HelpStep(
        title: 'A tela da Agenda',
        body: 'A Agenda lista as consultas do dia/período da clínica ativa, com '
            'paciente, horário, profissional e status (pendente, confirmada, '
            'cancelada, concluída).',
        anchorId: HelpAnchors.navAgenda,
        route: AppRoutes.agendamentos,
      ),
      HelpStep(
        title: 'Ações rápidas',
        body: 'Em cada consulta você pode Confirmar, Cancelar ou Reagendar. '
            'Confirmar muda o status e ajuda nos indicadores de absenteísmo; '
            'reagendar abre a escolha de novo horário.',
        route: AppRoutes.agendamentos,
      ),
      HelpStep(
        title: 'Detalhe da consulta',
        body: 'Tocar em uma consulta abre o detalhe com a linha do tempo '
            '(timeline) e todas as informações do paciente e do atendimento. '
            'Também é possível chegar direto por link (deep link).',
        route: AppRoutes.agendamentos,
      ),
      HelpStep(
        title: 'Criar agendamento',
        body: 'Toque neste botão (+) para criar uma consulta escolhendo '
            'paciente, especialidade, profissional, data e horário. O paciente '
            'também pode se agendar sozinho pelo Totem.',
        anchorId: HelpAnchors.agendaNew,
        route: AppRoutes.agendamentos,
      ),
    ],
  ),

  // ───────────────────────────────────────────── Recepção
  HelpTour(
    id: 'recepcao',
    title: 'Recepção e fila de atendimento',
    description: 'Check-in, classificação de risco e painel de senhas.',
    icon: Icons.support_agent_outlined,
    keywords: [
      'recepção', 'recepcao', 'fila', 'senha', 'check-in', 'checkin',
      'acolhimento', 'manchester', 'risco', 'balcão', 'painel', 'monitor'
    ],
    steps: [
      HelpStep(
        title: 'O balcão digital',
        body: 'A Recepção gerencia quem chegou: acolhimento com classificação '
            'de risco (protocolo Manchester), fila de espera e chamadas por '
            'senha. É o controle do fluxo presencial.',
        route: AppRoutes.recepcao,
      ),
      HelpStep(
        title: 'Abas da recepção',
        body: 'Use as abas para alternar entre Meus Pacientes, Fila Geral, '
            'Kanban Clínico, Finalizados, Indicadores e Mural. A fila é ordenada '
            'por risco e chegada — casos graves/prioritários sobem sozinhos.',
        anchorId: HelpAnchors.recepTabs,
        route: AppRoutes.recepcao,
      ),
      HelpStep(
        title: 'Chamar o próximo',
        body: 'Ao chamar, a senha é exibida e a locução é disparada no painel. '
            'Há chamada automática quando chega a hora de um agendamento.',
        route: AppRoutes.recepcao,
      ),
      HelpStep(
        title: 'Monitor público',
        body: 'O "Monitor da Recepção" é um display em tela cheia (rota pública) '
            'para a sala de espera, mostrando as senhas chamadas em tempo real.',
        route: AppRoutes.recepcaoMonitor,
      ),
    ],
  ),

  // ───────────────────────────────────────────── Pacientes
  HelpTour(
    id: 'pacientes',
    title: 'Pacientes e prontuário',
    description: 'Lista, jornada, notas clínicas e reputação.',
    icon: Icons.people_outline,
    keywords: [
      'paciente', 'pacientes', 'prontuário', 'prontuario', 'jornada',
      'histórico', 'historico', 'reputação', 'health score', 'assiduidade'
    ],
    steps: [
      HelpStep(
        title: 'Buscar paciente',
        body: 'Use esta busca para encontrar o paciente por nome. A partir dele '
            'você acessa contato, histórico de consultas e notas clínicas.',
        anchorId: HelpAnchors.pacientesSearch,
        route: AppRoutes.pacientes,
      ),
      HelpStep(
        title: 'Jornada e prontuário',
        body: 'Cada paciente tem uma jornada (linha do tempo de atendimentos) e '
            'espaço para anotações clínicas — útil para continuidade do cuidado.',
        route: AppRoutes.pacientes,
      ),
      HelpStep(
        title: 'Health Score',
        body: 'O Health Score audita o comportamento do paciente pela '
            'assiduidade histórica (faltas/comparecimentos), ajudando a prever '
            'risco de falta e priorizar confirmações ativas.',
        route: AppRoutes.healthScore,
      ),
    ],
  ),

  // ───────────────────────────────────────────── Analytics / IA
  HelpTour(
    id: 'analytics',
    title: 'Absenteísmo, IA e Relatórios',
    description: 'Insights, previsão de faltas e relatórios automáticos.',
    icon: Icons.insights_outlined,
    keywords: [
      'absenteísmo', 'absenteismo', 'faltas', 'previsão', 'previsao', 'ia',
      'inteligência', 'inteligencia', 'relatório', 'relatorio', 'analytics',
      'dashboard de risco', 'heatmap', 'insights'
    ],
    steps: [
      HelpStep(
        title: 'Absenteísmo',
        body: 'Esta área mostra faltas e cancelamentos com heatmap por '
            'dia/horário, identificando os pontos críticos (ex.: quartas às 15h) '
            'para você agir com confirmação ativa e overbooking.',
        route: AppRoutes.absenteismo,
      ),
      HelpStep(
        title: 'Inteligência Artificial',
        body: 'O módulo de IA gera sugestões de horários, análises e relatórios '
            'em linguagem natural. Você conversa com o assistente analítico para '
            'entender tendências e pedir recomendações.',
        route: AppRoutes.ia,
      ),
      HelpStep(
        title: 'Relatórios',
        body: 'Os Relatórios reúnem o que a IA e o sistema produzem — '
            'desempenho, absenteísmo, ocupação — prontos para visualizar e '
            'exportar.',
        route: AppRoutes.relatorios,
      ),
    ],
  ),

  // ───────────────────────────────────────────── Configurar o Totem
  HelpTour(
    id: 'totem_config',
    title: 'Configurar o Totem',
    description: 'Perfis, marca, fluxos, horários, regras e prévia ao vivo.',
    icon: Icons.touch_app_outlined,
    keywords: [
      'configurar totem', 'totem', 'personalizar', 'quiosque', 'perfil',
      'cor', 'logo', 'marca', 'almoço', 'horário', 'horario', 'prévia',
      'previa', 'regras', 'limite', 'whatsapp', 'confirmação'
    ],
    steps: [
      HelpStep(
        title: 'Abra Configurações',
        body: 'Tudo do Totem fica em Configurações. Toque aqui para ver as '
            'seções do sistema.',
        anchorId: HelpAnchors.navConfig,
        route: AppRoutes.configuracoes,
      ),
      HelpStep(
        title: 'Cartão "Totem"',
        body: 'Abra o cartão "Totem" para o painel de configuração. À direita '
            '(ou no topo, no celular) há uma PRÉVIA AO VIVO: tudo que você muda '
            'aparece na hora, com abas Início e Agendar.',
        anchorId: HelpAnchors.totemCard,
        route: AppRoutes.configuracoes,
      ),
      HelpStep(
        title: 'Perfis por tipo de unidade',
        body: 'No topo do painel há perfis prontos: UBS, UPA, APS, Clínica '
            'Popular e Clínica Normal. Toque em um para aplicar tudo de uma vez; '
            'depois ajuste o que quiser — as mudanças são salvas automaticamente '
            'no perfil. "Restaurar" volta ao preset original.',
        route: AppRoutes.configuracoes,
      ),
      HelpStep(
        title: 'Marca, cor e logo',
        body: 'Em "Marca e textos" você define nome da clínica, título de '
            'boas-vindas, cor de destaque e a URL do logo (com miniatura de '
            'status). A cor de destaque afeta só o Totem, não esta tela.',
        route: AppRoutes.configuracoes,
      ),
      HelpStep(
        title: 'Fluxos e confirmações',
        body: 'Em "Fluxos" você liga Agendar/Remarcar, exige telefone, define o '
            'rodapé do comprovante e ativa a confirmação por WhatsApp (Z-API) '
            'com o link de confirmação. O e-mail de confirmação é enviado '
            'automaticamente.',
        route: AppRoutes.configuracoes,
      ),
      HelpStep(
        title: 'Regras anti-abuso',
        body: 'Em "Regras" há limites por paciente: máximo de consultas por dia '
            'e máximo de consultas ativas. Isso evita que a mesma pessoa marque '
            'várias de uma vez e bagunce a agenda (0 = ilimitado).',
        route: AppRoutes.configuracoes,
      ),
      HelpStep(
        title: 'Horários de funcionamento',
        body: 'Em "Funcionamento" você define abertura/fechamento, sábado, '
            'domingo e o intervalo de almoço (que bloqueia os horários). A prévia '
            'na aba "Agendar" reflete tudo isso.',
        route: AppRoutes.configuracoes,
      ),
    ],
  ),

  // ───────────────────────────────────────────── Como o paciente usa o Totem
  HelpTour(
    id: 'totem_uso',
    title: 'Como o paciente usa o Totem',
    description: 'O fluxo completo de agendar e remarcar no quiosque.',
    icon: Icons.event_available_outlined,
    keywords: [
      'agendar', 'remarcar', 'autoatendimento', 'senha', 'cpf', 'paciente usa',
      'fluxo do totem', 'comprovante'
    ],
    steps: [
      HelpStep(
        title: 'Tela de boas-vindas',
        body: 'O Totem abre em tela cheia com o logo, o nome da clínica e os '
            'botões grandes "Agendar" e "Remarcar". A sessão expira sozinha por '
            'inatividade, voltando ao início — ideal para um quiosque.',
        route: AppRoutes.totem,
      ),
      HelpStep(
        title: 'Agendar — especialidade e data',
        body: 'No "Agendar", o paciente escolhe a especialidade (com sugestões '
            '"Mais procuradas"), a data pela faixa de semana ou calendário, e '
            'vê os horários livres com indicador de ocupação.',
        route: AppRoutes.totem,
      ),
      HelpStep(
        title: 'Identificação por CPF',
        body: 'Ao confirmar, ele digita o CPF no teclado da tela. Se já tiver '
            'cadastro, seguimos direto; se não, faz um cadastro rápido (quando '
            'permitido nas configurações).',
        route: AppRoutes.totem,
      ),
      HelpStep(
        title: 'Remarcar — escolher a consulta',
        body: 'No "Remarcar", o paciente digita o CPF e o sistema lista TODAS '
            'as consultas ativas dele. Se houver mais de uma, ele escolhe qual '
            'remarcar antes de selecionar o novo horário.',
        route: AppRoutes.totem,
      ),
      HelpStep(
        title: 'Senha e confirmação',
        body: 'No fim, é gerada uma senha/comprovante (com opção de imprimir). '
            'A confirmação é enviada por e-mail e, se ativado, por WhatsApp '
            '(Z-API) com o link de confirmação.',
        route: AppRoutes.totem,
      ),
    ],
  ),

  // ───────────────────────────────────────────── Mapa de Módulos
  HelpTour(
    id: 'modulos',
    title: 'Mapa de Módulos',
    description: 'Ative/desative módulos e entenda as dependências.',
    icon: Icons.account_tree_outlined,
    keywords: [
      'módulo', 'modulo', 'módulos', 'arquitetura', 'ativar', 'desativar',
      'dependência', 'dependencia', 'mapa', 'ligar', 'desligar'
    ],
    steps: [
      HelpStep(
        title: 'O que é o Mapa de Módulos',
        body: 'Cada funcionalidade do Vitta é um módulo. Esta tela mostra todos, '
            'agrupados por prioridade, com o grafo de dependências e a validação '
            '(acíclico, sem dependências faltando).',
        anchorId: HelpAnchors.navArquitetura,
        route: AppRoutes.arquitetura,
      ),
      HelpStep(
        title: 'Ligar e desligar',
        body: 'O interruptor de cada card ativa ou desativa o módulo. Os módulos '
            'de base (auth, navegação, home, agenda) ficam travados para manter o '
            'sistema funcional.',
        route: AppRoutes.arquitetura,
      ),
      HelpStep(
        title: 'O Totem como módulo independente',
        body: 'O Totem é independente da Recepção: ao ligá-lo, ele aparece na '
            'barra de navegação; ao desligá-lo, some do menu e a rota /totem '
            'fica bloqueada. Tudo reativo, na hora.',
        anchorId: HelpAnchors.navTotem,
        route: AppRoutes.arquitetura,
      ),
    ],
  ),

  // ───────────────────────────────────────────── WhatsApp (Z-API)
  HelpTour(
    id: 'whatsapp',
    title: 'Conectar o WhatsApp (Z-API)',
    description: 'Pareie o número da clínica para enviar confirmações.',
    icon: Icons.chat_outlined,
    keywords: [
      'whatsapp', 'zapi', 'z-api', 'conectar whatsapp', 'parear', 'qr code',
      'numero da clinica', 'whats'
    ],
    steps: [
      HelpStep(
        title: 'Tela do WhatsApp',
        body: 'Abra **WhatsApp** no menu. Aqui você conecta o número da clínica '
            'à Z-API e acompanha o status da conexão.',
        route: AppRoutes.whatsapp,
      ),
      HelpStep(
        title: 'Gerar QR Code',
        body: 'Toque em **Gerar QR Code** e escaneie pelo WhatsApp da clínica '
            'para parear. Quando conectado, o status fica verde.',
        anchorId: HelpAnchors.whatsappConnect,
        route: AppRoutes.whatsapp,
      ),
      HelpStep(
        title: 'Ativar confirmações',
        body: 'Com o WhatsApp conectado, vá em **Configurações → Totem → '
            'Fluxos** e ative **"Confirmação por WhatsApp"** para enviar o link '
            'ao paciente automaticamente.',
        anchorId: HelpAnchors.totemCard,
        route: AppRoutes.configuracoes,
      ),
    ],
  ),
];
