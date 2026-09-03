/// Strings em português — **a fonte da verdade**.
///
/// Toda chave nova nasce aqui. Os outros idiomas podem ficar para trás sem
/// quebrar nada (há fallback), e `traducoes_test.dart` lista o que falta.
///
/// Convenção da chave: `modulo.contexto.item`. Agrupada por módulo, para que
/// migrar um módulo de cada vez seja possível.
const Map<String, String> textosPt = {
  // ── Comum ────────────────────────────────────────────────────────────
  'comum.cancelar': 'Cancelar',
  'comum.limpar': 'Limpar',
  'comum.salvar': 'Salvar',
  'comum.excluir': 'Excluir',
  'comum.renomear': 'Renomear',
  'comum.entendi': 'Entendi',

  // ── Evidências: tela ─────────────────────────────────────────────────
  'evid.titulo': 'Evidências',
  'evid.modo.buscar': 'Buscar',
  'evid.modo.perguntar': 'Perguntar',
  'evid.modo.chat': 'Chat',
  'evid.modo.buscar.dica': 'Consulta direta no PubMed, com filtros',
  'evid.modo.perguntar.dica': 'Uma revisão a fundo: PICO, calibração e síntese citada',
  'evid.modo.chat.dica': 'Conversa com seguimento, citando as fontes a cada resposta',

  'evid.campo.buscar.hint': 'Ex.: SGLT2 inhibitor[tiab] AND heart failure[tiab]',
  'evid.campo.buscar.ajuda': 'Termos em inglês. Aceita [tiab], [mesh], AND/OR/NOT.',
  'evid.campo.perguntar.hint': 'Ex.: em idosos com diabetes tipo 2, metformina reduz eventos cardiovasculares?',
  'evid.campo.perguntar.ajuda': 'Português. A IA decompõe em PICO, calibra a busca e sintetiza citando.',
  'evid.campo.chat.hint': 'Pergunte algo — e depois pergunte de novo.',
  'evid.campo.chat.ajuda': 'Português. A conversa guarda o contexto e as fontes.',
  'evid.campo.enviar': 'Enviar',
  'evid.campo.perguntar': 'Perguntar',

  'evid.ordenar.relevancia': 'Relevância',
  'evid.filtros': 'Filtros',
  'evid.filtros.ativos': 'Filtros ({n})',
  'evid.filtros.limpar': 'Limpar filtros',

  // ── Evidências: intro ────────────────────────────────────────────────
  'evid.intro.continuar': 'Continuar de onde parou',

  'evid.lgpd': 'Nunca inclua nome, CPF, telefone ou qualquer dado do paciente. A consulta vai para um serviço externo (NIH, Estados Unidos) e dado pessoal é bloqueado automaticamente antes do envio.',

  // ── Evidências: resultados ───────────────────────────────────────────
  'evid.res.exibindo': 'exibindo {n}',
  'evid.res.fim': 'Fim dos resultados desta busca.',
  'evid.res.vazio.titulo': 'Nenhum artigo encontrado',
  'evid.res.vazio.para': 'para "{termo}"',
  'evid.res.vazio.filtros': 'Você tem {n} filtro(s) ativo(s). Eles podem estar excluindo os resultados.',
  'evid.res.vazio.sugestao': 'Você quis dizer?',
  'evid.res.vazio.tentar': 'O que tentar',
  'evid.res.interpretou': 'O PubMed interpretou como:',

  'evid.como.titulo': 'Como pesquisamos',
  'evid.como.enviada': 'Consulta enviada',
  'evid.como.interpretada': 'O PubMed interpretou',
  'evid.como.executada': 'Executado em',
  'evid.como.origem': 'Origem',
  'evid.como.cache': 'Resultado em cache — o PubMed não foi consultado novamente.',

  // ── Evidências: artigo ───────────────────────────────────────────────
  'evid.art.semTitulo': '(sem título)',
  'evid.art.carregandoResumo': 'Carregando o resumo…',
  'evid.art.semResumo': 'Este registro não tem resumo no PubMed. Abra o artigo para ver o conteúdo completo, quando disponível.',
  'evid.art.citar': 'Citar',
  'evid.art.copiarCitacao': 'Copiar citação',
  'evid.art.textoCompleto': 'Texto completo',
  'evid.art.citadoNaSintese': 'Citado na síntese',

  // ── Evidências: aviso de caminho direto ──────────────────────────────
  'evid.direto.aviso': 'Buscando direto no PubMed. Os resultados são os mesmos e a proteção de dados continua ativa.',
  'evid.direto.reconectar': 'Reconectar',
  'evid.direto.dispensar': 'Dispensar',

  // ── Evidências: bloqueio de dado pessoal ─────────────────────────────
  'evid.phi.titulo': 'Busca bloqueada por proteção de dados',

  // ── Evidências: tradução ─────────────────────────────────────────────
  'evid.trad.traduzir': 'Traduzir',
  'evid.trad.verOriginal': 'Ver original',
  'evid.trad.traduzindo': 'Traduzindo…',
  'evid.trad.porIA': 'Tradução por IA — o original em inglês é a referência.',
  'evid.trad.falhou': 'Não foi possível traduzir. O original segue abaixo.',

  // ── Evidências: sessões ──────────────────────────────────────────────
  'evid.sessao.salvar': 'Salvar sessão',
  'evid.sessao.salvas': 'Sessões salvas',
  'evid.sessao.nenhuma': 'Nenhuma sessão salva ainda.',
  'evid.sessao.nenhuma.ajuda': 'Salve uma pesquisa para retomar depois — com os artigos, a síntese e a conversa como estavam.',
  'evid.sessao.salva': 'Sessão salva.',
  'evid.sessao.excluida': 'Sessão excluída.',
  'evid.sessao.nome': 'Nome da sessão',
  'evid.sessao.artigos': '{n} artigo(s)',
  'evid.sessao.exportar.md': 'Exportar como Markdown',
  'evid.sessao.exportar.ris': 'Exportar referências (RIS)',
  'evid.sessao.exportar.bib': 'Exportar referências (BibTeX)',

  // ── Evidências: histórico ────────────────────────────────────────────
  'evid.hist.titulo': 'Buscas recentes',
  'evid.hist.limpar': 'Limpar histórico',
  'evid.hist.resultados': '{n} resultado(s)',

  // ── Navegação ────────────────────────────────────────────────────────
  'nav.dashboard': 'Dashboard',
  'nav.agenda': 'Agenda',
  'nav.absenteismo': 'Absenteísmo',
  'nav.totem': 'Totem',
  'nav.cerebro': 'Cérebro',
  'nav.evidencias': 'Evidências',
  'nav.pacientes': 'Pacientes',
  'nav.equipeMedica': 'Equipe Médica',
  'nav.overbooking': 'Overbooking',
  'nav.simulador': 'Simulador',
  'nav.recepcao': 'Recepção',
  'nav.relatorios': 'Relatórios',
  'nav.satisfacao': 'Satisfação',
  'nav.healthScore': 'Health Score',
  'nav.notificacoes': 'Notificações',
  'nav.perfilUsuario': 'Perfil do Usuário',
  'nav.perfilClinica': 'Perfil da Clínica',

  // ── home ────────────────────────────────────────────────────
  'home.estaSemana': 'Esta semana',
  'home.verTudo': 'Ver tudo',
  'home.indicadores': 'Indicadores',
  'home.proximosAgendamentos': 'Próximos agendamentos',
  'home.verTodos': 'Ver todos',
  'home.restaurarOrdemPadrao': 'Restaurar ordem padrão',
  'home.personalizarLayout': 'Personalizar layout',
  'home.taxaGlobalDeAbsenteismo': 'Taxa global de absenteísmo',
  'home.eficienciaDeRealocacao': 'Eficiência de realocação',
  'home.taxaDeSucessoAoPreencherHorariosCancelados': 'Taxa de sucesso ao preencher horários cancelados',
  'home.atual': 'Atual',
  'home.evolucaoDoFaturamento': 'EVOLUÇÃO DO FATURAMENTO',
  'home.receitaConfirmadaNosUltimos6Meses': 'RECEITA CONFIRMADA NOS ÚLTIMOS 6 MESES',
  'home.semanaAnterior': 'Semana anterior',
  'home.proximaSemana': 'Próxima semana',
  'home.todos': 'Todos',
  'home.confirmados': 'Confirmados',
  'home.pendentes': 'Pendentes',
  'home.cancelados': 'Cancelados',

  // ── auth ────────────────────────────────────────────────────
  'auth.vitta': 'Vitta',
  'auth.bemVindoDeVolta': 'Bem-vindo de volta',
  'auth.acesseOPainelDaSuaClinica': 'Acesse o painel da sua clínica.',
  'auth.senha': 'Senha',
  'auth.modoDemonstracao': 'Modo demonstração',
  'auth.primeiroAcesso': 'Primeiro acesso?',
  'auth.crieSuaContaEConfigureAClinica': 'Crie sua conta e configure a clínica.',
  'auth.criarConta': 'Criar conta',
  'auth.nenhumPlanoAtivo': 'Nenhum plano ativo',
  'auth.escolhaUmPlanoParaLiberarTodosOsRecursos': 'Escolha um plano para liberar todos os recursos.',
  'auth.escolherPlano': 'Escolher plano',
  'auth.todosOsPlanos': 'Todos os planos',
  'auth.comeceAGerenciarSuaClinicaEmMinutos': 'Comece a gerenciar sua clínica em minutos.',
  'auth.min8CaracteresComMaiusculaNumeroESimbolo': 'Mín. 8 caracteres, com maiúscula, número e símbolo',

  // ── pacientes ───────────────────────────────────────────────
  'pacientes.buscarPaciente': 'Buscar paciente',
  'pacientes.riscoDeFaltas': 'Risco de faltas',
  'pacientes.atendidos': 'Atendidos',
  'pacientes.faltas': 'Faltas',
  'pacientes.notasClinicas': 'Notas clínicas',
  'pacientes.adicionar': 'Adicionar',

  // ── relatorios ──────────────────────────────────────────────
  'relatorios.gerarRelatorio': 'Gerar relatório',
  'relatorios.tipo': 'Tipo',
  'relatorios.periodo': 'Período',
  'relatorios.copiar': 'Copiar',

  // ── perfil_usuario ──────────────────────────────────────────
  'perfil.endereco': 'Endereço',
  'perfil.buscarCep': 'Buscar CEP',
  'perfil.alterarSenha': 'Alterar senha',

  // ── perfil_clinica ──────────────────────────────────────────
  'clinica.enderecoCompletoComBuscaPorCepDisponivelNa': 'Endereço completo com busca por CEP disponível na edição (PC-02).',
  'clinica.fechado': 'Fechado',

  // ── notificacoes_centro ─────────────────────────────────────

  // ── satisfacao ──────────────────────────────────────────────
  'satisfacao.pacienteNome': 'PACIENTE / NOME',
  'satisfacao.eMail': 'E-MAIL',
  'satisfacao.inicio': 'INÍCIO',
  'satisfacao.mediaGeral': 'MÉDIA GERAL',
  'satisfacao.indiceNps': 'ÍNDICE NPS',
  'satisfacao.totalFeedbacks': 'TOTAL FEEDBACKS',
  'satisfacao.criticos': 'CRÍTICOS',
  'satisfacao.critico': 'CRÍTICO',

  // ── health_score ────────────────────────────────────────────
  'health.buscarPorNomeOuCpfDoPaciente': 'Buscar por nome ou CPF do paciente...',
  'health.eliteDiamante': 'ELITE (DIAMANTE)',
  'health.assiduosOuro': 'ASSÍDUOS (OURO)',
  'health.atencaoPrata': 'ATENÇÃO (PRATA)',
  'health.riscoBronze': 'RISCO (BRONZE)',
  'health.periodo': 'PERÍODO',
  'health.corpoClinico': 'CORPO CLÍNICO',
  'health.mediaAtual': 'MÉDIA ATUAL',
  'health.variacaoMes': 'VARIAÇÃO (MÊS)',

  // ── Restauradas ────────────────────────────────────────────────
  'evid.intro.buscar.titulo': 'Pesquise literatura científica',
  'evid.intro.buscar.texto': 'Busca direta no PubMed (NCBI), a base de referência da literatura biomédica. Os resultados trazem PMID, periódico e desenho do estudo para você verificar a fonte.',
  'evid.intro.perguntar.titulo': 'Pergunte em português',
  'evid.intro.perguntar.texto': 'A IA decompõe a pergunta, monta a estratégia de busca, calibra até achar a faixa certa, lê os resumos e sintetiza — citando cada artigo. Todo PMID citado é conferido contra o que foi recuperado.',
  'evid.intro.exemplos.busca': 'Exemplos de busca',
  'evid.intro.exemplos.pergunta': 'Exemplos de pergunta',
  'evid.ordenar.data': 'Mais recentes',
  'evid.ordenar.data.curto': 'Recentes',
  'evid.res.um': '{n} artigo encontrado',
  'evid.res.muitos': '{n} artigos encontrados',
  'evid.como.origem.proxy': 'Serviço interno (pubmedProxy)',
  'evid.como.origem.direto': 'Direto no NCBI',
  'nav.ia': 'I.A.',
  'nav.gestaoDeAtend': 'Gestão de Atend.',
  'nav.tarefasAgendadas': 'Tarefas Agendadas',
  'nav.whatsapp': 'WhatsApp',
  'nav.plano': 'Plano',
  'nav.configuracoes': 'Configurações',
  'nav.mapaDeModulos': 'Mapa de Módulos',
};
