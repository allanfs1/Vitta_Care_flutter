import 'dart:async';
import 'dart:convert';

import '../../ia/agent/agent_models.dart';
import '../../ia/agent/ai_agent_service.dart';
import '../citacao_validator.dart';
import '../phi_guard.dart';
import '../pubmed_models.dart';
import '../pubmed_service.dart';

/// Chat de pesquisa — conversa sobre literatura, com fonte verificável.
///
/// ## Como difere do modo "Perguntar à IA"
///
/// | | Perguntar (agente) | Chat |
/// |---|---|---|
/// | Formato | uma revisão estruturada | conversa |
/// | Estratégia | PICO + calibração em código | o modelo escolhe as buscas |
/// | Custo | várias chamadas, ~30 s | rápido por turno |
/// | Serve para | responder a fundo uma pergunta | explorar, refinar, tirar dúvida |
///
/// Os dois existem porque o médico faz as duas coisas. "Metformina reduz
/// eventos cardiovasculares em idosos?" pede revisão. "E se ele tiver doença
/// renal?" — a pergunta que vem logo depois — pede conversa, com o contexto
/// anterior de pé.
///
/// ## O acervo é acumulativo, e é isso que faz o follow-up funcionar
///
/// Cada busca que o modelo faz entra em [acervo], que **persiste pela conversa
/// inteira**. A validação de citação confere contra esse acervo, não só contra
/// o último turno — senão citar no turno 5 um artigo achado no turno 2 seria
/// marcado como invenção, que é exatamente o contrário do que deve acontecer.
///
/// ## A trava contra citação inventada continua valendo
///
/// Toda resposta do modelo passa pelo [CitacaoValidator] antes de virar
/// mensagem na tela. Num chat isso importa ainda mais que numa busca: a
/// conversa dá fluência, e fluência é justamente o que faz uma citação falsa
/// passar despercebida.
class ChatPesquisa {
  ChatPesquisa({
    required PubmedService pubmed,
    required AiAgentService ia,
    this.validador = const CitacaoValidator(),
    this.maxArtigosPorBusca = 8,
  })  : _pubmed = pubmed,
        _ia = ia;

  final PubmedService _pubmed;
  final AiAgentService _ia;
  final CitacaoValidator validador;

  /// Teto por busca do modelo. Baixo de propósito: num chat o modelo pode
  /// buscar várias vezes por turno, e 8 × N enche o contexto rápido.
  final int maxArtigosPorBusca;

  /// Tudo que já foi recuperado nesta conversa, por PMID.
  final Map<String, ArtigoPubmed> acervo = {};

  /// Ferramentas oferecidas ao modelo neste chat.
  ///
  /// São só as de literatura — **nenhuma tool de dados da clínica**. O chat
  /// fala com um serviço externo; misturar aqui uma ferramenta que lê pacientes
  /// abriria caminho para dado de paciente virar termo de busca.
  List<Map<String, dynamic>> get toolSpecs => [
        {
          'name': 'buscar_literatura',
          'description':
              'Pesquisa artigos no PubMed. Devolve PMID, título, autores, ano e '
                  'desenho do estudo. Use SEMPRE que precisar de evidência — '
                  'nunca responda pergunta clínica de memória. '
                  'O termo deve ser em INGLÊS e aceita sintaxe Entrez '
                  '([tiab], [mesh], [ptyp], AND/OR/NOT, 2020:2026[pdat]). '
                  'NUNCA inclua nome, CPF, telefone ou dado de paciente.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'termo': {'type': 'string'},
              'limite': {'type': 'integer', 'default': 8},
            },
            'required': ['termo'],
          },
        },
        {
          'name': 'ler_resumos',
          'description':
              'Lê o resumo completo de artigos já encontrados, pelo PMID. '
                  'Use antes de afirmar qualquer achado: o título sozinho não '
                  'sustenta conclusão clínica.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'pmids': {
                'type': 'array',
                'items': {'type': 'string'},
              },
            },
            'required': ['pmids'],
          },
        },
      ];

  /// Executor das ferramentas acima.
  Future<ToolOutcome> executarTool(
      String nome, Map<String, dynamic> args) async {
    try {
      final texto = switch (nome) {
        'buscar_literatura' => await _buscar(args),
        'ler_resumos' => await _ler(args),
        _ => jsonEncode({'erro': 'Ferramenta desconhecida: $nome'}),
      };
      // Ferramenta desconhecida e' falha, mesmo devolvendo JSON valido.
      return (text: texto, isError: texto.contains('"erro"'));
    } on EvidenciaErro catch (e) {
      return (text: jsonEncode({'erro': _orientar(e)}), isError: true);
    } catch (e) {
      return (text: jsonEncode({'erro': '$e'}), isError: true);
    }
  }

  Future<String> _buscar(Map<String, dynamic> args) async {
    final termo = '${args['termo'] ?? ''}'.trim();
    if (termo.isEmpty) {
      return jsonEncode({'erro': 'Informe o termo.'});
    }

    // Guarda local antes de qualquer rede. A do servidor continua sendo a
    // autoritativa; esta existe porque o caminho direto não passa por ele — e
    // porque num chat o modelo monta o termo sozinho, então a chance de um
    // dado do paciente escorregar do histórico para a busca é real.
    final phi = detectarPhi(termo);
    if (phi.isNotEmpty) {
      return jsonEncode({
        'erro': 'Busca bloqueada: o termo contém ${phi.join(", ")}. '
            'Reescreva usando apenas os elementos clínicos (condição, '
            'intervenção, desfecho). Nunca inclua dado de paciente.',
      });
    }

    final limite = switch (args['limite']) {
      final int n => n.clamp(1, maxArtigosPorBusca),
      _ => maxArtigosPorBusca,
    };

    final r = await _pubmed.buscarComMetadados(termo, limite: limite);
    for (final a in r.artigos) {
      acervo[a.pmid] = a;
    }

    if (r.vazio) {
      return jsonEncode({
        'total': 0,
        'artigos': [],
        'orientacao': 'Nenhum artigo encontrado. Diga isso ao usuário em vez de '
            'responder de memória. Tente termos mais amplos, remova o filtro de '
            'data, ou verifique a grafia em inglês.',
      });
    }

    return jsonEncode({
      'total': r.total,
      'queryTraduzida': r.queryTraduzida,
      'artigos': r.artigos
          .map((a) => {
                'pmid': a.pmid,
                'titulo': a.titulo,
                'ano': a.ano,
                'desenho': a.desenhoEstudo,
                'periodico': a.periodico,
              })
          .toList(),
      'orientacao': 'Cite os PMIDs acima ao afirmar algo com base neles. Para '
          'conclusões, leia os resumos com ler_resumos antes.',
    });
  }

  Future<String> _ler(Map<String, dynamic> args) async {
    final pmids = switch (args['pmids']) {
      final List l => l.map((e) => '$e').where((e) => e.isNotEmpty).take(6).toList(),
      _ => <String>[],
    };
    if (pmids.isEmpty) return jsonEncode({'erro': 'Informe ao menos um PMID.'});

    final secoes = await _pubmed.abstracts(pmids);
    final saida = <Map<String, dynamic>>[];
    for (final pmid in pmids) {
      final art = acervo[pmid];
      final s = secoes[pmid] ?? const <SecaoResumo>[];
      if (art != null) acervo[pmid] = art.comSecoes(s);
      saida.add({
        'pmid': pmid,
        'titulo': art?.titulo,
        'desenho': art?.desenhoEstudo,
        if (s.isEmpty)
          'resumo': '(este artigo não tem resumo no PubMed)'
        else
          'resumo': s
              .map((x) => x.temRotulo ? '${x.rotulo}: ${x.texto}' : x.texto)
              .join('\n'),
      });
    }
    return jsonEncode({
      'artigos': saida,
      'orientacao': 'Baseie as afirmações no texto do resumo. O resumo não é o '
          'texto completo: não afirme detalhe metodológico que ele não traz.',
    });
  }

  /// Envia um turno e devolve os eventos do agente.
  ///
  /// A validação **não** acontece aqui: os eventos passam crus para quem chama,
  /// que valida o texto final ([validarResposta]). Assim o texto pode ser
  /// transmitido token a token — o usuário vê a resposta nascendo — e a
  /// conferência acontece quando há texto completo para conferir.
  Stream<AgentEvent> enviar(List<ChatMessage> historico) {
    return _ia.run(
      history: [
        ChatMessage(role: ChatRole.system, content: _prompt()),
        ...historico,
      ],
      toolSpecs: toolSpecs,
      callTool: executarTool,
      clinicaId: '',
    );
  }

  /// Confere as citações do texto contra o acervo da conversa inteira.
  ResultadoValidacao validarResposta(String texto) =>
      validador.validar(texto, acervo.keys);

  /// Artigos citados num texto, na ordem em que aparecem.
  List<ArtigoPubmed> fontesDe(String texto) {
    final citados = validador.extrair(texto).map((c) => c.pmid);
    return citados
        .map((p) => acervo[p])
        .whereType<ArtigoPubmed>()
        .toList();
  }

  String _orientar(EvidenciaErro e) {
    if (e.bloqueadoPorDadoPessoal) {
      return 'Busca bloqueada por conter dado pessoal. Reescreva com apenas os '
          'elementos clínicos e tente de novo.';
    }
    if (e.precisaLogin) {
      return 'Sessão expirada — informe o usuário em vez de tentar de novo.';
    }
    if (e.limiteAtingido) {
      return 'Limite de requisições atingido. Aguarde alguns segundos e evite '
          'repetir a mesma busca.';
    }
    return e.mensagem;
  }

  String _prompt() => '''
Você é um assistente de medicina baseada em evidência, conversando com um
médico. Responda em português.

COMO TRABALHAR
1. Para QUALQUER pergunta clínica, use `buscar_literatura` ANTES de responder.
   Nunca responda de memória — você existe para trazer fonte verificável.
2. Busque em INGLÊS. É o idioma de indexação do PubMed; português reduz
   drasticamente o resultado.
3. Antes de afirmar um achado, leia o resumo com `ler_resumos`. Título e
   desenho não sustentam conclusão clínica.
4. Numa pergunta de seguimento, aproveite o que já foi encontrado antes; só
   busque de novo se o novo recorte pedir.

REGRAS DE CITAÇÃO — inegociáveis
- Cite no formato (PMID: 12345678), e SOMENTE PMIDs que as ferramentas
  devolveram nesta conversa. As citações são conferidas automaticamente; as
  que não existirem aparecem marcadas como NÃO VERIFICADAS para o médico.
- Toda afirmação clínica precisa de citação. Sem fonte, não afirme.
- Se a evidência for escassa, fraca ou conflitante, diga isso. É informação
  clínica útil, não fracasso da busca.
- Se a busca não achar nada, diga que não achou. Não preencha com o que você
  "lembra".

DADO DE PACIENTE
Nunca inclua nome, CPF, telefone, e-mail ou qualquer identificador em uma
busca — ela vai para um servidor externo. Use apenas os elementos clínicos.
Se o médico mencionar dados de um paciente, extraia só o quadro clínico.

ESTILO
Direto e denso. Comece pela resposta, depois a evidência. Diga o desenho
quando pesar ("em metanálise de 12 ensaios..."). Não repita a pergunta.
Não encerre com oferta de ajuda genérica.''';
}
