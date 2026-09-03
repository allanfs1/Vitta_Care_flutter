import 'dart:async';
import 'dart:convert';

import '../../ia/agent/ai_agent_service.dart';
import '../citacao_validator.dart';
import '../pubmed_models.dart';
import '../pubmed_service.dart';
import 'pico.dart';

/// Agente de pesquisa de evidência.
///
/// ## O que ele faz que uma busca não faz
///
/// Uma busca devolve artigos. Este agente conduz uma **revisão rápida**: traduz
/// a pergunta clínica, monta a estratégia, mede o que voltou, corrige a
/// estratégia quando o resultado é ruim, lê os resumos e sintetiza — citando.
///
/// ```
///  pergunta em português
///        │
///        ▼
///  1. PICO ............... o modelo decompõe; o médico vê e pode corrigir
///        ▼
///  2. estratégia ......... PICO → consulta Entrez (código, não modelo)
///        ▼
///  3. busca .............. PubMed
///        ▼
///  4. calibra ◄──────────┐ 0 resultados? amplia. Milhares? restringe.
///        ▼              │ (até [maxCalibracoes] — o loop não é infinito)
///        └──────────────┘
///        ▼
///  5. lê resumos ......... EFetch dos N mais relevantes
///        ▼
///  6. sintetiza .......... o modelo escreve, citando SÓ o que recebeu
///        ▼
///  7. valida ............. CitacaoValidator confere cada PMID  ← a trava
/// ```
///
/// ## O passo 7 é o que distingue isto de um chat
///
/// A síntese é gerada por um modelo, e modelo inventa citação de forma
/// convincente. O passo 7 não confia: confere cada PMID contra o pacote
/// recuperado e marca o que não bate. Sem ele, os passos 1–6 seriam teatro.
///
/// ## Por que a montagem da consulta é código, não prompt
///
/// O passo 2 poderia ser "modelo, escreva a consulta Entrez". Seria menos
/// código e mais frágil: a sintaxe do Entrez é rígida, o modelo erra colchete e
/// parêntese, e o erro só aparece como "0 resultados" — indistinguível de "não
/// há literatura". Em [Pico.paraEntrez] a estrutura é garantida, e o modelo
/// contribui com o que ele faz bem: vocabulário clínico.
class AgenteEvidencias {
  AgenteEvidencias({
    required PubmedService pubmed,
    required AiAgentService ia,
    this.maxCalibracoes = 3,
    this.maxResumosLidos = 8,
    this.validador = const CitacaoValidator(),
  })  : _pubmed = pubmed,
        _ia = ia;

  final PubmedService _pubmed;
  final AiAgentService _ia;

  /// Quantas vezes a estratégia pode ser reescrita antes de aceitar o que veio.
  /// Sem teto, uma pergunta sem literatura viraria loop caro e silencioso.
  final int maxCalibracoes;

  /// Quantos resumos completos entram na síntese. Cada um consome contexto do
  /// modelo e cota do NCBI; acima disso a qualidade não melhora na proporção.
  final int maxResumosLidos;

  final CitacaoValidator validador;

  /// Faixa considerada boa para uma pergunta clínica.
  ///
  /// Menos que [_minBom] costuma ser estratégia estreita demais (ou desfecho
  /// que ninguém escreve no resumo). Mais que [_maxBom] indica pergunta ampla
  /// demais para sintetizar — o médico receberia uma resposta genérica.
  static const int _minBom = 3;
  static const int _maxBom = 400;

  /// Executa a revisão, emitindo cada passo.
  ///
  /// É um `Stream` porque a espera é longa (várias chamadas de rede e de
  /// modelo). Mostrar o progresso real — e a consulta sendo montada — é o que
  /// separa "está pensando" de uma barra girando sem informação.
  Stream<PassoAgente> pesquisar(
    String pergunta, {
    Pico? picoInicial,
    int anoAtual = 2026,
  }) async* {
    final relatorio = <String, dynamic>{};

    // ── 1. PICO ────────────────────────────────────────────────────────
    Pico pico;
    if (picoInicial != null && !picoInicial.vazio) {
      // O médico já corrigiu os campos: respeitar é o ponto do passo 1.
      pico = picoInicial;
      yield PassoAgente.pico(pico, reaproveitado: true);
    } else {
      yield const PassoAgente(
        tipo: TipoPasso.pico,
        titulo: 'Interpretando a pergunta',
        detalhe: 'Decompondo em População, Intervenção, Comparador e Desfecho.',
        emAndamento: true,
      );
      try {
        pico = await _extrairPico(pergunta);
      } catch (e) {
        yield PassoAgente.erro('Não consegui interpretar a pergunta: $e');
        return;
      }
      if (pico.vazio) {
        yield PassoAgente.erro(
          'Não consegui identificar os elementos clínicos da pergunta. '
          'Tente descrever a população, a intervenção e o desfecho.',
        );
        return;
      }
      yield PassoAgente.pico(pico);
    }
    relatorio['pico'] = pico.paraJson();

    // ── 2 a 4. Estratégia, busca e calibração ──────────────────────────
    var consulta = pico.paraEntrez(anoAtual: anoAtual);
    if (consulta.isEmpty) {
      yield PassoAgente.erro('A pergunta não gerou nenhum termo pesquisável.');
      return;
    }

    ResultadoBusca? resultado;
    final tentativas = <Map<String, dynamic>>[];

    for (var i = 0; i <= maxCalibracoes; i++) {
      yield PassoAgente(
        tipo: TipoPasso.busca,
        titulo: i == 0 ? 'Pesquisando no PubMed' : 'Ajustando a estratégia',
        detalhe: consulta,
        emAndamento: true,
      );

      ResultadoBusca r;
      try {
        r = await _pubmed.buscarComMetadados(consulta, limite: 25);
      } on EvidenciaErro catch (e) {
        yield PassoAgente.erro(e.mensagem);
        return;
      }

      tentativas.add({'consulta': consulta, 'total': r.total});
      final ajuste = _avaliar(r.total);
      yield PassoAgente(
        tipo: TipoPasso.busca,
        titulo: 'Estratégia ${i + 1}',
        detalhe: consulta,
        dados: {
          'total': r.total,
          'avaliacao': ajuste.rotulo,
          'queryTraduzida': r.queryTraduzida,
        },
      );

      resultado = r;
      if (ajuste == _Ajuste.bom || i == maxCalibracoes) break;

      final proxima = _recalibrar(pico, consulta, ajuste, anoAtual);
      if (proxima == null || proxima == consulta) break;
      consulta = proxima;
    }

    final achado = resultado!;
    relatorio['tentativas'] = tentativas;
    relatorio['consultaFinal'] = achado.queryEnviada;
    relatorio['total'] = achado.total;

    if (achado.vazio) {
      yield PassoAgente.erro(
        'Nenhum artigo encontrado, mesmo após ampliar a estratégia. '
        'Isso não significa que não haja literatura — pode ser vocabulário. '
        'Tente reformular a pergunta com outros termos.',
      );
      return;
    }

    // ── 5. Ler os resumos ──────────────────────────────────────────────
    final selecionados = _priorizar(achado.artigos).take(maxResumosLidos).toList();
    yield PassoAgente(
      tipo: TipoPasso.leitura,
      titulo: 'Lendo ${selecionados.length} resumos',
      detalhe: 'Priorizando metanálises, revisões sistemáticas e ensaios '
          'randomizados, e os mais recentes dentro de cada desenho.',
      emAndamento: true,
    );

    Map<String, List<SecaoResumo>> resumos = const {};
    try {
      resumos = await _pubmed.abstracts(selecionados.map((a) => a.pmid).toList());
    } catch (_) {
      // Sem resumo dá para sintetizar com título e desenho — pior, mas honesto.
      // O prompt avisa o modelo de que ele está trabalhando só com metadados.
    }

    final lidos = selecionados
        .map((a) => a.comSecoes(resumos[a.pmid]))
        .toList();
    yield PassoAgente(
      tipo: TipoPasso.leitura,
      titulo: '${lidos.where((a) => a.temAbstract).length} resumos disponíveis',
      detalhe: lidos.where((a) => !a.temAbstract).isEmpty
          ? null
          : '${lidos.where((a) => !a.temAbstract).length} artigo(s) sem resumo '
              'no PubMed — entram na síntese apenas por título e desenho.',
      dados: {'pmids': lidos.map((a) => a.pmid).toList()},
    );

    // ── 6. Sintetizar ──────────────────────────────────────────────────
    yield const PassoAgente(
      tipo: TipoPasso.sintese,
      titulo: 'Sintetizando com citações',
      emAndamento: true,
    );

    String texto;
    try {
      texto = await _sintetizar(pergunta, pico, lidos, achado);
    } catch (e) {
      yield PassoAgente.erro('Falha ao gerar a síntese: $e');
      return;
    }

    // ── 7. Validar as citações ─────────────────────────────────────────
    final validacao = validador.validarContra(texto, lidos);
    final anotado = validador.anotarInvalidas(texto, validacao);

    yield PassoAgente(
      tipo: TipoPasso.validacao,
      titulo: validacao.ok
          ? 'Todas as citações conferem'
          : '${validacao.invalidos.length} citação(ões) não conferem',
      detalhe: validador.aviso(validacao),
      dados: {
        'validos': validacao.validos,
        'invalidos': validacao.invalidos,
        'cobertura': validacao.cobertura,
      },
    );

    yield PassoAgente(
      tipo: TipoPasso.resposta,
      titulo: 'Resposta',
      detalhe: anotado,
      dados: {
        ...relatorio,
        'artigos': lidos.map((a) => a.paraJson()).toList(),
        'validacao': {
          'ok': validacao.ok,
          'invalidos': validacao.invalidos,
          'naoCitados': validacao.naoCitados,
        },
      },
    );
  }

  // ── Passos que usam o modelo ────────────────────────────────────────

  Future<Pico> _extrairPico(String pergunta) async {
    final bruto = await _ia.runToString(
      prompt: '${_promptPico()}\n\nPERGUNTA: $pergunta',
      toolSpecs: const [],
      callTool: (nome, args) async => (text: '', isError: false),
      clinicaId: '',
    );
    return Pico.doJson(_lerJson(bruto));
  }

  Future<String> _sintetizar(
    String pergunta,
    Pico pico,
    List<ArtigoPubmed> artigos,
    ResultadoBusca busca,
  ) {
    final dossie = StringBuffer();
    for (final a in artigos) {
      dossie.writeln('---');
      dossie.writeln('PMID: ${a.pmid}');
      dossie.writeln('Título: ${a.titulo}');
      dossie.writeln('Desenho: ${a.desenhoEstudo ?? "não informado"}');
      dossie.writeln('Periódico: ${a.periodico} (${a.dataPublicacao})');
      if (a.abstractSecoes != null && a.abstractSecoes!.isNotEmpty) {
        for (final s in a.abstractSecoes!) {
          dossie.writeln(s.temRotulo ? '${s.rotulo}: ${s.texto}' : s.texto);
        }
      } else {
        dossie.writeln('(sem resumo disponível)');
      }
    }

    return _ia.runToString(
      prompt: '${_promptSintese()}\n\n'
          'PERGUNTA DO MÉDICO: $pergunta\n\n'
          'ESTRATÉGIA USADA: ${busca.queryEnviada}\n'
          'TOTAL NO PUBMED: ${busca.total}\n\n'
          'ARTIGOS RECUPERADOS:\n$dossie',
      toolSpecs: const [],
      callTool: (nome, args) async => (text: '', isError: false),
      clinicaId: '',
    );
  }

  // ── Calibração (determinística) ─────────────────────────────────────

  _Ajuste _avaliar(int total) {
    if (total < _minBom) return _Ajuste.ampliar;
    if (total > _maxBom) return _Ajuste.restringir;
    return _Ajuste.bom;
  }

  /// Reescreve a estratégia. `null` quando não há mais o que afrouxar/apertar.
  ///
  /// A ordem de afrouxamento não é arbitrária — vai do que menos custa ao que
  /// mais custa em precisão: primeiro tira o desfecho (o campo que mais zera
  /// busca), depois o filtro de desenho, depois a janela de datas.
  String? _recalibrar(Pico pico, String atual, _Ajuste ajuste, int anoAtual) {
    if (ajuste == _Ajuste.ampliar) {
      final semDesfecho =
          pico.paraEntrez(incluirDesfecho: false, anoAtual: anoAtual);
      if (semDesfecho.isNotEmpty && semDesfecho != atual) return semDesfecho;

      final semDesenho = pico
          .copyWith(desenhosPreferidos: const [])
          .paraEntrez(incluirDesfecho: false, anoAtual: anoAtual);
      if (semDesenho != atual) return semDesenho;

      final semJanela = pico
          .copyWith(desenhosPreferidos: const [], limparJanela: true)
          .paraEntrez(incluirDesfecho: false, anoAtual: anoAtual);
      return semJanela == atual ? null : semJanela;
    }

    // Restringir: exigir evidência mais forte é mais útil que apertar o texto —
    // devolve menos e melhor, em vez de menos e aleatório.
    if (pico.desenhosPreferidos.isEmpty) {
      return pico.copyWith(desenhosPreferidos: const [
        'Meta-Analysis',
        'Systematic Review',
        'Randomized Controlled Trial',
      ]).paraEntrez(anoAtual: anoAtual);
    }
    if (pico.janelaAnos == null) {
      return pico.copyWith(janelaAnos: 5).paraEntrez(anoAtual: anoAtual);
    }
    return null;
  }

  /// Ordena por força de evidência e, dentro dela, por recência.
  ///
  /// É a mesma triagem que um médico faz de olho: uma metanálise de 2024 antes
  /// de um relato de caso de 2003.
  List<ArtigoPubmed> _priorizar(List<ArtigoPubmed> artigos) {
    const peso = {
      'Meta-Analysis': 0,
      'Systematic Review': 1,
      'Randomized Controlled Trial': 2,
      'Clinical Trial': 3,
      'Observational Study': 4,
      'Review': 5,
      'Case Reports': 7,
    };
    final lista = [...artigos];
    lista.sort((a, b) {
      final pa = peso[a.desenhoEstudo] ?? 6;
      final pb = peso[b.desenhoEstudo] ?? 6;
      if (pa != pb) return pa.compareTo(pb);
      return (b.ano ?? 0).compareTo(a.ano ?? 0);
    });
    return lista;
  }

  // ── Prompts ─────────────────────────────────────────────────────────

  String _promptPico() => '''
Você decompõe perguntas clínicas no formato PICO para busca no PubMed.

Responda APENAS com um objeto JSON, sem texto ao redor e sem cercas de código:
{
  "populacao": "termos em INGLÊS, separados por ' OR ' se houver sinônimos",
  "intervencao": "termos em INGLÊS",
  "comparador": "termos em INGLÊS, ou string vazia se a pergunta não tiver",
  "desfecho": "termos em INGLÊS",
  "termosMesh": ["descritores MeSH prováveis"],
  "desenhosPreferidos": ["Meta-Analysis", "Randomized Controlled Trial"],
  "janelaAnos": 5
}

REGRAS:
- SEMPRE em inglês: é o idioma de indexação do PubMed. Português reduz
  drasticamente o resultado.
- NÃO inclua nome, CPF, telefone, e-mail nem qualquer dado de paciente.
  Use somente os elementos clínicos.
- "comparador" vazio é resposta correta quando a pergunta não compara nada.
  Não invente um.
- "desenhosPreferidos" só quando a pergunta pedir força de evidência
  (eficácia, tratamento, prognóstico). Para pergunta descritiva, deixe vazio.
- "janelaAnos": 5 para terapêutica, 10 para epidemiologia, null quando
  recência não importa.
- Prefira 2 a 4 sinônimos por campo. Muitos sinônimos trazem ruído.''';

  String _promptSintese() => '''
Você é um assistente de medicina baseada em evidência. Sintetize os artigos
recuperados para responder à pergunta do médico.

REGRAS ABSOLUTAS:
1. Cite SOMENTE os PMIDs presentes na lista de artigos recuperados, no formato
   (PMID: 12345678). NUNCA escreva um PMID que não esteja na lista — as
   citações são conferidas automaticamente e as inventadas são marcadas como
   não verificadas na tela do médico.
2. Toda afirmação clínica precisa de citação. Se os artigos não sustentam uma
   afirmação, NÃO a faça.
3. Não afirme mais do que o resumo permite. Artigo marcado "(sem resumo
   disponível)" sustenta no máximo o que o título e o desenho dizem.
4. Se a evidência for fraca, escassa ou conflitante, diga isso — é informação
   clínica, não fracasso da busca.

FORMATO (markdown, em português):
**Resposta curta** — 2 a 3 frases respondendo diretamente, com citações.

**O que a evidência mostra** — parágrafos por achado, cada um citando. Diga o
desenho quando importar ("em metanálise de X ensaios...").

**Força da evidência** — uma frase: quantos estudos, que desenhos, quão
consistentes.

**Limitações** — o que estes artigos NÃO respondem.

Encerre com: "Esta síntese apoia, mas não substitui, o julgamento clínico."''';

  /// Extrai o objeto JSON de uma resposta do modelo.
  ///
  /// Modelos frequentemente devolvem o JSON dentro de cercas de código ou com
  /// um parágrafo antes, apesar da instrução. Recortar entre a primeira `{` e a
  /// última `}` resolve os dois casos sem depender de obediência.
  static Map<String, dynamic> _lerJson(String bruto) {
    final i = bruto.indexOf('{');
    final f = bruto.lastIndexOf('}');
    if (i < 0 || f <= i) {
      throw const FormatException('resposta sem JSON');
    }
    final d = jsonDecode(bruto.substring(i, f + 1));
    if (d is! Map<String, dynamic>) {
      throw const FormatException('JSON não é um objeto');
    }
    return d;
  }
}

enum _Ajuste {
  ampliar('poucos resultados'),
  restringir('resultados demais'),
  bom('faixa boa');

  const _Ajuste(this.rotulo);
  final String rotulo;
}

/// Etapas visíveis do agente.
enum TipoPasso { pico, busca, leitura, sintese, validacao, resposta, erro }

/// Um passo do agente, para a tela mostrar.
class PassoAgente {
  const PassoAgente({
    required this.tipo,
    required this.titulo,
    this.detalhe,
    this.dados = const {},
    this.emAndamento = false,
  });

  final TipoPasso tipo;
  final String titulo;
  final String? detalhe;
  final Map<String, dynamic> dados;

  /// `true` enquanto o passo está rodando — a tela troca por um resultado
  /// quando o passo seguinte do mesmo tipo chega.
  final bool emAndamento;

  factory PassoAgente.erro(String mensagem) => PassoAgente(
        tipo: TipoPasso.erro,
        titulo: 'Não foi possível concluir',
        detalhe: mensagem,
      );

  factory PassoAgente.pico(Pico pico, {bool reaproveitado = false}) =>
      PassoAgente(
        tipo: TipoPasso.pico,
        titulo: reaproveitado
            ? 'Usando os campos que você ajustou'
            : 'Pergunta interpretada',
        dados: pico.paraJson(),
      );

  bool get eErro => tipo == TipoPasso.erro;
}
