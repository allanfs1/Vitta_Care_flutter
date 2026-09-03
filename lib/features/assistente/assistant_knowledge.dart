import 'assistant_models.dart';

/// Normaliza texto para casamento robusto: minúsculas, sem acentos e sem
/// pontuação (mantém letras/números/espaços).
String normalizeText(String input) {
  var s = input.toLowerCase();
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  s = buf.toString().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Pontua o quão bem um conjunto de palavras-chave casa com a consulta.
/// Frases (multi-palavra) valem mais que termos isolados.
double scoreKeywords(String normalizedQuery, List<String> keywords) {
  final qTokens = normalizedQuery.split(' ').toSet();
  var score = 0.0;
  for (final k in keywords) {
    final nk = normalizeText(k);
    if (nk.isEmpty) continue;
    final tokens = nk.split(' ');
    // Termos curtos de 1 palavra casam só como palavra inteira (evita casar
    // "oi" dentro de "coisa"). Frases usam substring.
    final bool hit = (tokens.length == 1 && tokens.first.length <= 3)
        ? qTokens.contains(tokens.first)
        : normalizedQuery.contains(nk);
    if (hit) score += tokens.length >= 2 ? 2.0 + tokens.length : 1.0;
  }
  return score;
}

/// Intenção do usuário de ser GUIADO na tela (inicia o tour direto).
bool wantsGuidedTour(String normalizedQuery) {
  const triggers = [
    'me mostra', 'me mostre', 'me guie', 'me guia', 'passo a passo',
    'demonstra', 'demonstre', 'faz um tour', 'faça um tour', 'inicia o tour',
    'inicie o tour', 'tour guiado', 'me ensina na tela', 'mostra na tela',
    'me leva', 'me leve'
  ];
  return triggers.any(normalizedQuery.contains);
}

/// Perguntas sugeridas (chips) exibidas no início da conversa.
const List<String> kSuggestedQuestions = [
  'Como configuro o totem?',
  'Como o paciente remarca uma consulta?',
  'Como vejo as faltas?',
  'Como confirmo ou cancelo uma consulta?',
  'Como limito agendamentos por paciente?',
  'Como ativar a confirmação por WhatsApp?',
];

/// Base de conhecimento local (FAQ/intents). Responde de imediato, sem custo,
/// e oferece o tour relacionado. A IA só entra quando nada casa aqui.
const List<HelpAnswer> kHelpAnswers = [
  HelpAnswer(
    keywords: ['oi', 'ola', 'bom dia', 'boa tarde', 'boa noite', 'quem e voce',
        'o que voce faz', 'o que voce pode fazer'],
    answer: 'Sou o assistente do Vitta. Posso explicar qualquer funcionalidade e '
        'te guiar na tela, passo a passo. Pergunte algo como “como configuro o '
        'totem?” ou escolha um dos tours abaixo. 🙂',
    tour: 'visao_geral',
  ),
  HelpAnswer(
    keywords: ['configurar totem', 'configurar o totem', 'configuro o totem',
        'config totem', 'personalizar totem', 'mudar o totem', 'ajustar totem',
        'opcoes do totem'],
    answer: '**Configurar o Totem:**\n\n'
        '1. Abra **Configurações → Totem**.\n'
        '2. Escolha um **perfil** pronto no topo (UBS, UPA, APS, Clínica '
        'Popular/Normal).\n'
        '3. Ajuste **marca, cor, logo, fluxos, horários e regras**.\n\n'
        'A **prévia ao vivo** mostra cada mudança na hora, e tudo é **salvo '
        'automaticamente** no perfil.',
    tour: 'totem_config',
  ),
  HelpAnswer(
    keywords: ['cor do totem', 'mudar cor', 'cor de destaque', 'logo do totem',
        'logotipo', 'marca do totem', 'nome da clinica no totem'],
    answer: 'Em Configurações → Totem → "Marca e textos" você define nome, '
        'título de boas-vindas, cor de destaque e a URL do logo (com miniatura '
        'de status). A cor de destaque afeta só o Totem e a prévia, não as '
        'telas de gestão.',
    tour: 'totem_config',
  ),
  HelpAnswer(
    keywords: ['como o paciente usa', 'paciente agenda sozinho', 'autoatendimento',
        'como funciona o totem', 'quiosque', 'fluxo do totem', 'usar o totem'],
    answer: 'No Totem o paciente:\n\n'
        '1. Toca em **Agendar** ou **Remarcar**.\n'
        '2. Escolhe **especialidade, data e horário**.\n'
        '3. Identifica-se pelo **CPF** (ou cadastro rápido).\n'
        '4. Recebe a **senha/comprovante**.\n\n'
        'A confirmação vai por **e-mail** e, se ativado, por **WhatsApp**.',
    tour: 'totem_uso',
  ),
  HelpAnswer(
    keywords: ['agendar consulta', 'marcar consulta', 'nova consulta',
        'criar agendamento', 'novo agendamento', 'como agendo'],
    answer: 'Há dois caminhos: na Agenda, use o botão de novo agendamento '
        '(paciente, especialidade, profissional, data e hora); ou deixe o '
        'próprio paciente agendar pelo Totem.',
    tour: 'agenda',
  ),
  HelpAnswer(
    keywords: ['remarcar', 'remarca', 'paciente remarca', 'reagendar',
        'mudar horario', 'trocar horario', 'alterar consulta',
        'mudar a data da consulta'],
    answer: '**Remarcar pelo Totem:**\n\n'
        '1. Toque em **Remarcar** e digite o **CPF**.\n'
        '2. O sistema lista **todas as consultas ativas** do paciente.\n'
        '3. Escolha **qual remarcar** e o **novo horário**.\n\n'
        'Pela gestão, use a ação **Reagendar** na Agenda.',
    tour: 'totem_uso',
  ),
  HelpAnswer(
    keywords: ['confirmar consulta', 'cancelar consulta', 'confirmar ou cancelar',
        'confirmo ou cancelo', 'confirmo', 'cancelo', 'status da consulta',
        'acoes da agenda'],
    answer: 'Na Agenda, cada consulta tem ações de Confirmar, Cancelar e '
        'Reagendar. Confirmar atualiza o status e melhora os indicadores de '
        'absenteísmo.',
    tour: 'agenda',
  ),
  HelpAnswer(
    keywords: ['faltas', 'absenteismo', 'no show', 'no-show', 'quem faltou',
        'heatmap', 'taxa de falta', 'cancelamentos'],
    answer: 'No módulo Absenteísmo você vê faltas e cancelamentos com heatmap '
        'por dia/horário e os pontos críticos para agir (confirmação ativa e '
        'overbooking). A previsão de faltas usa o histórico do paciente.',
    tour: 'analytics',
  ),
  HelpAnswer(
    keywords: ['inteligencia artificial', ' ia ', 'assistente analitico',
        'previsao de faltas', 'sugestao de horario', 'sugestao de horarios',
        'analise por ia', 'relatorio por ia'],
    answer: 'O módulo de IA gera sugestões de horários, análises e relatórios em '
        'linguagem natural, e responde perguntas sobre os dados da clínica. '
        'Encontre-o no menu como "IA".',
    tour: 'analytics',
  ),
  HelpAnswer(
    keywords: ['relatorio', 'relatorios', 'exportar', 'desempenho da clinica'],
    answer: 'Em Relatórios você acessa os relatórios gerados (IA e '
        'operacionais), com visualização e exportação — desempenho, '
        'absenteísmo e ocupação.',
    tour: 'analytics',
  ),
  HelpAnswer(
    keywords: ['recepcao', 'fila', 'senha', 'chamar paciente', 'acolhimento',
        'manchester', 'classificacao de risco', 'monitor da recepcao',
        'painel de senha'],
    answer: 'A Recepção controla o presencial: acolhimento com classificação de '
        'risco (Manchester), fila priorizada e chamada por senha. O "Monitor da '
        'Recepção" é um display público para a sala de espera.',
    tour: 'recepcao',
  ),
  HelpAnswer(
    keywords: ['paciente', 'pacientes', 'prontuario', 'historico do paciente',
        'jornada', 'notas clinicas', 'ficha do paciente'],
    answer: 'No módulo Pacientes você busca a pessoa, vê a jornada (linha do '
        'tempo de atendimentos), histórico e notas clínicas.',
    tour: 'pacientes',
  ),
  HelpAnswer(
    keywords: ['health score', 'reputacao do paciente', 'assiduidade',
        'risco de falta', 'pontuacao do paciente'],
    answer: 'O Health Score audita o comportamento do paciente pela assiduidade '
        'histórica (faltas x comparecimentos), ajudando a prever risco de falta '
        'e priorizar confirmações.',
    tour: 'pacientes',
  ),
  HelpAnswer(
    keywords: ['modulo', 'modulos', 'ativar funcionalidade', 'desativar',
        'arquitetura', 'dependencia', 'ligar modulo', 'desligar modulo',
        'mapa de modulos'],
    answer: 'O "Mapa de Módulos" lista cada funcionalidade como um módulo, com '
        'grafo de dependências. O interruptor de cada card liga/desliga o módulo '
        '(os de base ficam travados). Desligar um módulo o remove do menu e '
        'bloqueia a rota.',
    tour: 'modulos',
  ),
  HelpAnswer(
    keywords: ['conectar whatsapp', 'parear whatsapp', 'qr code', 'z-api',
        'zapi', 'numero da clinica', 'ligar whatsapp'],
    answer: '**Conectar o WhatsApp (Z-API):**\n\n'
        '1. Abra **WhatsApp** no menu.\n'
        '2. Toque em **Gerar QR Code** e escaneie pelo WhatsApp da clínica.\n'
        '3. Depois, ative **Configurações → Totem → Fluxos → "Confirmação por '
        'WhatsApp"**.',
    tour: 'whatsapp',
  ),
  HelpAnswer(
    keywords: ['email de confirmacao', 'confirmacao por email', 'enviar email',
        'whatsapp', 'zapi', 'confirmacao por whatsapp', 'enviar confirmacao',
        'link de confirmacao'],
    answer: '**Confirmações de consulta:**\n\n'
        '- **E-mail**: enviado automaticamente ao agendar/remarcar.\n'
        '- **WhatsApp (Z-API)**: ative em **Configurações → Totem → Fluxos → '
        '"Confirmação por WhatsApp"** e informe o **link de confirmação**.',
    tour: 'totem_config',
  ),
  HelpAnswer(
    keywords: ['limite de consultas', 'limito', 'limitar agendamentos',
        'agendamentos por paciente', 'varias consultas', 'quantas consultas',
        'maximo de consultas', 'anti-abuso', 'anti abuso', 'limitar paciente',
        'regra de agendamento', 'paciente marcando muito'],
    answer: '**Limites por paciente** (Configurações → Totem → *Regras*):\n\n'
        '- **Consultas por dia** — evita marcar várias na mesma data.\n'
        '- **Consultas ativas** — teto de agendamentos futuros em aberto.\n\n'
        'Ao estourar, o totem oferece **remarcar a existente** em vez de '
        'duplicar. Use **0** para ilimitado.',
    tour: 'totem_config',
  ),
  HelpAnswer(
    keywords: ['horario de funcionamento', 'almoco', 'intervalo', 'que horas abre',
        'que horas fecha', 'sabado', 'domingo', 'fechar aos sabados'],
    answer: 'Em **Configurações → Totem → Funcionamento** você define:\n\n'
        '- **Abertura/fechamento**\n'
        '- **Sábado** e **Domingo**\n'
        '- **Intervalo de almoço** (bloqueia os horários)\n\n'
        'A prévia (aba **Agendar**) reflete tudo isso.',
    tour: 'totem_config',
  ),
  HelpAnswer(
    keywords: ['perfil da clinica', 'dados da clinica', 'logotipo da clinica',
        'horarios de atendimento', 'especialidades da clinica'],
    answer: 'O "Perfil da Clínica" guarda dados da unidade, contato, logotipo, '
        'horários e especialidades. Acesse pelo menu lateral.',
  ),
  HelpAnswer(
    keywords: ['meu perfil', 'dados pessoais', 'trocar senha', 'perfil do usuario',
        'minha conta'],
    answer: 'No "Perfil do Usuário" você edita seus dados pessoais, contato, '
        'endereço (CEP) e segurança.',
  ),
  HelpAnswer(
    keywords: ['aparencia', 'tema', 'modo escuro', 'modo claro', 'cor do app',
        'fonte', 'tipografia', 'acessibilidade', 'daltonismo', 'contraste'],
    answer: 'Em Configurações você ajusta aparência (cores/paletas), tipografia, '
        'tema (claro/escuro/contraste) e acessibilidade (movimento, daltonismo). '
        'Tudo aplica em tempo real.',
  ),
  HelpAnswer(
    keywords: ['notificacao', 'notificacoes', 'avisos', 'push', 'nao perturbe'],
    answer: 'A Central de Notificações reúne os avisos in-app, com filtros e '
        'marcar como lida. As preferências (push, e-mail, sons, não perturbe) '
        'ficam em Configurações → Notificações.',
  ),
  HelpAnswer(
    keywords: ['trocar clinica', 'mudar clinica', 'selecionar clinica',
        'clinica ativa', 'outra unidade'],
    answer: 'Use o seletor de clínica no topo do Dashboard para trocar a unidade '
        'ativa. Todos os dados (agenda, indicadores) passam a refletir a clínica '
        'escolhida.',
  ),

  // ───────────────────────────────────────────── Simulador de Agenda
  HelpAnswer(
    keywords: ['o que e o simulador', 'para que serve o simulador',
        'como funciona o simulador', 'simulador de agenda', 'monte carlo',
        'o que e monte carlo', 'como o simulador funciona'],
    answer: 'O **Simulador de Agenda** responde uma pergunta: quantos '
        'encaixes cabem hoje sem lotar a sala de espera? Em vez de uma média, '
        'ele roda milhares de cenários de faltas para o dia escolhido e '
        'mostra a distribuição inteira — o dia bom, o típico e o ruim. A '
        'decisão de overbooking usa o dia ruim (P95), não a média.',
    tour: 'simulador',
  ),
  HelpAnswer(
    keywords: ['quantos encaixes', 'posso encaixar', 'cabe encaixe',
        'quantos pacientes encaixar', 'overbooking hoje', 'abrir encaixe'],
    answer: 'Abra o **Simulador** (menu lateral) na data desejada e veja o '
        'cartão de recomendação na aba Decisão — ele diz quantos encaixes '
        'cabem, ou explica por que nenhum cabe hoje. Antes disso, confira o '
        'cartão de lista de espera: chamar quem já tem vaga liberada vem '
        'sempre primeiro.',
    tour: 'simulador',
  ),
  HelpAnswer(
    keywords: ['p95', 'sobredispersao', 'sobredispersão', 'o que e phi',
        'o que e p95', 'dia ruim', 'faltas p95'],
    answer: '**P95** é o número de faltas do "dia ruim" — em 1 a cada 20 '
        'dias, as faltas passam desse valor. É por isso que ele decide '
        'overbooking, e não a média. **Sobredispersão (φ)** mede se as '
        'faltas de um mesmo dia se movem juntas: φ = 1,00 é independência; '
        'acima disso, um fator comum (chuva, feriado) empurra várias faltas '
        'ao mesmo tempo.',
    tour: 'simulador',
  ),
  HelpAnswer(
    keywords: ['calibracao do simulador', 'calibração do simulador',
        'simulador nao calibrado', 'dados nao permitem calibrar',
        'calibrar simulador'],
    answer: 'A aba **Calibração** do simulador compara o modelo com o '
        'histórico real da clínica. Quando aparece "os dados não permitem '
        'calibrar", a simulação está usando taxas padrão — não medidas nesta '
        'clínica — geralmente por faltar histórico suficiente ou por '
        'inconsistência nos dados. Vale abrir essa aba antes de tratar a '
        'recomendação como definitiva.',
    tour: 'simulador',
  ),
  HelpAnswer(
    keywords: ['planejar a semana', 'plano semanal', 'planejador de agenda',
        'simular a semana toda'],
    answer: 'Na aba **Planejador** do Simulador, escolha a janela (3, 7 ou '
        '14 dias) e toque em "Montar plano" — ele roda a simulação para cada '
        'dia e monta o plano de encaixes da semana inteira de uma vez, com a '
        'IA apontando onde olhar primeiro. Nenhum encaixe é criado '
        'automaticamente: aplicar na agenda continua sendo uma ação sua.',
    tour: 'simulador',
  ),
];
