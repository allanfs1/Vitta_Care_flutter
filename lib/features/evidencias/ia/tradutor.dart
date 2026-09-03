import 'dart:convert';

import '../../../core/i18n/idioma.dart';
import '../../ia/agent/ai_agent_service.dart';
import '../pubmed_models.dart';

/// Tradução de conteúdo científico por IA.
///
/// ## O problema que resolve
///
/// A interface pode estar em português, mas **o PubMed é em inglês**. Título,
/// resumo, rótulos de seção — tudo. Para um médico que lê inglês com esforço,
/// isso transforma triagem de dez segundos em leitura de dois minutos por
/// artigo, e é o que faz a busca de evidência ser abandonada na prática.
///
/// ## Três decisões que mantêm isto seguro
///
/// **1. O original nunca é substituído — é acrescentado.** [ArtigoTraduzido]
/// carrega os dois textos, e a tela deixa alternar. Tradução automática de
/// termo clínico erra: "positive predictive value" e "outcome" têm traduções
/// que mudam o sentido. Quem decide numa conduta precisa poder conferir a
/// frase original sem sair da tela.
///
/// **2. PMID, DOI e números nunca são traduzidos.** O prompt proíbe, e a
/// validação de citação continua rodando sobre o texto original. Um modelo que
/// "traduzisse" um PMID quebraria a rastreabilidade — a única coisa que o
/// módulo inteiro existe para garantir.
///
/// **3. A tradução é rotulada como tal, sempre.** Nunca aparece como se fosse
/// o texto do artigo.
///
/// ## Por que não um serviço de tradução dedicado
///
/// Um tradutor genérico erra mais em texto clínico do que um modelo com
/// instrução de domínio — e traria uma dependência e um segredo novos. O
/// projeto já tem o `chatProxy`; usá-lo mantém a superfície igual.
class Tradutor {
  Tradutor({required AiAgentService ia, this.maxCaracteres = 6000}) : _ia = ia;

  final AiAgentService _ia;

  /// Teto do texto enviado. Resumo do PubMed raramente passa de 3.000; acima
  /// de [maxCaracteres] o texto é cortado com aviso, em vez de estourar o
  /// contexto do modelo silenciosamente.
  final int maxCaracteres;

  /// Cache por (pmid, idioma). Traduzir de novo o mesmo artigo custa tempo e
  /// tokens sem mudar nada — e o médico volta ao mesmo artigo o tempo todo.
  final Map<String, ArtigoTraduzido> _cache = {};

  ArtigoTraduzido? doCache(String pmid, Idioma idioma) =>
      _cache['$pmid|${idioma.chave}'];

  /// Traduz título e resumo de [artigo] para [idioma].
  ///
  /// Devolve o original marcado como não traduzido quando o idioma de destino
  /// é inglês (não há o que fazer) ou quando o modelo falha — falhar aqui não
  /// pode esconder o artigo.
  Future<ArtigoTraduzido> traduzir(ArtigoPubmed artigo, Idioma idioma) async {
    final chave = '${artigo.pmid}|${idioma.chave}';
    final guardado = _cache[chave];
    if (guardado != null) return guardado;

    // O conteúdo do PubMed já é inglês: traduzir para inglês é ruído.
    if (idioma == Idioma.en) {
      return ArtigoTraduzido.original(artigo);
    }

    final secoes = artigo.abstractSecoes ?? const <SecaoResumo>[];
    final corpo = StringBuffer()..writeln('TITLE: ${artigo.titulo}');
    for (var i = 0; i < secoes.length; i++) {
      corpo.writeln('SECTION_$i${secoes[i].temRotulo ? " [${secoes[i].rotulo}]" : ""}: '
          '${secoes[i].texto}');
    }

    var texto = corpo.toString();
    var truncado = false;
    if (texto.length > maxCaracteres) {
      texto = texto.substring(0, maxCaracteres);
      truncado = true;
    }

    try {
      final bruto = await _ia.runToString(
        prompt: '${_prompt(idioma)}\n\n$texto',
        toolSpecs: const [],
        callTool: (nome, args) async => (text: '', isError: false),
        clinicaId: '',
      );
      final j = _lerJson(bruto);

      final tituloTraduzido = '${j['title'] ?? ''}'.trim();
      final secoesTraduzidas = <SecaoResumo>[];
      for (var i = 0; i < secoes.length; i++) {
        final t = '${j['section_$i'] ?? ''}'.trim();
        secoesTraduzidas.add(SecaoResumo(
          rotulo: secoes[i].rotulo,
          texto: t.isEmpty ? secoes[i].texto : t,
        ));
      }

      final r = ArtigoTraduzido(
        original: artigo,
        titulo: tituloTraduzido.isEmpty ? artigo.titulo : tituloTraduzido,
        secoes: secoesTraduzidas,
        idioma: idioma,
        truncado: truncado,
      );
      _cache[chave] = r;
      return r;
    } catch (_) {
      // Falha de tradução não pode esconder o artigo: devolve o original
      // marcado, e a tela mostra o aviso de que não deu.
      return ArtigoTraduzido.falhou(artigo, idioma);
    }
  }

  void limparCache() => _cache.clear();

  String _prompt(Idioma idioma) => '''
Translate the following biomedical article text into ${idioma.nomeIngles}.

Respond ONLY with a JSON object, no prose and no code fences:
{"title": "...", "section_0": "...", "section_1": "..."}

Use exactly the same keys as the input labels (TITLE -> "title",
SECTION_0 -> "section_0", and so on).

RULES:
- Keep it faithful and clinical. This is read by physicians making decisions;
  do not simplify, soften or embellish.
- NEVER translate or alter: numbers, doses, units, p-values, confidence
  intervals, PMIDs, DOIs, gene and drug names, scale and trial acronyms
  (HbA1c, NYHA, DAPA-HF, NNT, HR, OR, RR).
- Keep established English terms that clinicians use untranslated when the
  local translation is ambiguous — put the translation in parentheses on first
  use if it helps.
- Preserve the meaning of hedging exactly ("may reduce" is not "reduces").
  Overstating certainty in a clinical text is the worst possible error here.
- Do not add anything that is not in the source.''';

  static Map<String, dynamic> _lerJson(String bruto) {
    final i = bruto.indexOf('{');
    final f = bruto.lastIndexOf('}');
    if (i < 0 || f <= i) throw const FormatException('sem JSON');
    final d = jsonDecode(bruto.substring(i, f + 1));
    if (d is! Map<String, dynamic>) throw const FormatException('não é objeto');
    return d;
  }
}

/// Um artigo com tradução ao lado do original.
///
/// Os dois textos convivem: a tela alterna, e a citação e a validação de PMID
/// continuam usando o original.
class ArtigoTraduzido {
  const ArtigoTraduzido({
    required this.original,
    required this.titulo,
    required this.secoes,
    required this.idioma,
    this.traduzido = true,
    this.falha = false,
    this.truncado = false,
  });

  /// Nada a traduzir (o conteúdo já está no idioma pedido).
  factory ArtigoTraduzido.original(ArtigoPubmed a) => ArtigoTraduzido(
        original: a,
        titulo: a.titulo,
        secoes: a.abstractSecoes ?? const [],
        idioma: Idioma.en,
        traduzido: false,
      );

  /// O modelo falhou. O artigo continua utilizável no original.
  factory ArtigoTraduzido.falhou(ArtigoPubmed a, Idioma idioma) =>
      ArtigoTraduzido(
        original: a,
        titulo: a.titulo,
        secoes: a.abstractSecoes ?? const [],
        idioma: idioma,
        traduzido: false,
        falha: true,
      );

  final ArtigoPubmed original;
  final String titulo;
  final List<SecaoResumo> secoes;
  final Idioma idioma;

  /// `false` quando o texto exibido é o original (sem tradução ou após falha).
  final bool traduzido;
  final bool falha;

  /// O texto passou do teto e foi cortado antes de ir ao modelo.
  final bool truncado;

  /// O PMID nunca muda — é a âncora da citação e da validação.
  String get pmid => original.pmid;
}
