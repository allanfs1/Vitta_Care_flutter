import 'dart:convert';

/// Decomposição PICO de uma pergunta clínica.
///
/// PICO é o formato que a medicina baseada em evidência usa para tornar uma
/// pergunta pesquisável: **P**opulação, **I**ntervenção, **C**omparador,
/// **O**utcome (desfecho). É o que separa "serve metformina pra idoso?" de uma
/// consulta que o PubMed consegue responder.
///
/// Aqui ele tem uma segunda função, mais importante que a busca: **mostrar ao
/// médico o que a IA entendeu**. Se a decomposição estiver errada, o erro fica
/// visível antes de virar resposta com citação — e o médico corrige o campo em
/// vez de descobrir depois que a busca era de outra coisa.
class Pico {
  const Pico({
    this.populacao = '',
    this.intervencao = '',
    this.comparador = '',
    this.desfecho = '',
    this.termosMesh = const [],
    this.desenhosPreferidos = const [],
    this.janelaAnos,
  });

  final String populacao;
  final String intervencao;

  /// Vazio é comum e legítimo: muita pergunta clínica não tem comparador
  /// explícito ("qual o efeito de X?"). Forçar um inventaria a pergunta.
  final String comparador;
  final String desfecho;

  /// Descritores MeSH sugeridos pelo modelo. São **sugestão**, não verdade: o
  /// modelo pode citar um descritor que não existe. Por isso entram na consulta
  /// junto com `[tiab]`, nunca sozinhos — assim um MeSH inválido reduz o
  /// resultado, mas não o zera.
  final List<String> termosMesh;

  /// Desenhos de estudo priorizados (ex.: `Meta-Analysis`).
  final List<String> desenhosPreferidos;

  /// Recorte temporal em anos a partir de hoje. `null` = sem recorte.
  final int? janelaAnos;

  bool get vazio =>
      populacao.isEmpty && intervencao.isEmpty && desfecho.isEmpty;

  Pico copyWith({
    String? populacao,
    String? intervencao,
    String? comparador,
    String? desfecho,
    List<String>? termosMesh,
    List<String>? desenhosPreferidos,
    int? janelaAnos,
    bool limparJanela = false,
  }) =>
      Pico(
        populacao: populacao ?? this.populacao,
        intervencao: intervencao ?? this.intervencao,
        comparador: comparador ?? this.comparador,
        desfecho: desfecho ?? this.desfecho,
        termosMesh: termosMesh ?? this.termosMesh,
        desenhosPreferidos: desenhosPreferidos ?? this.desenhosPreferidos,
        janelaAnos: limparJanela ? null : (janelaAnos ?? this.janelaAnos),
      );

  /// Lê o JSON que o modelo devolve, tolerando o que ele costuma errar:
  /// campo ausente, `null`, string onde devia haver lista, número como texto.
  factory Pico.doJson(Map<String, dynamic> j) {
    String txt(String k) => (j[k] ?? '').toString().trim();
    List<String> lista(String k) {
      final v = j[k];
      if (v is List) {
        return v
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      // O modelo às vezes manda "a, b" em vez de ["a","b"].
      final s = (v ?? '').toString().trim();
      if (s.isEmpty) return const [];
      return s.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final anos = j['janelaAnos'];
    return Pico(
      populacao: txt('populacao'),
      intervencao: txt('intervencao'),
      comparador: txt('comparador'),
      desfecho: txt('desfecho'),
      termosMesh: lista('termosMesh'),
      desenhosPreferidos: lista('desenhosPreferidos'),
      janelaAnos: anos is num ? anos.toInt() : int.tryParse('${anos ?? ''}'),
    );
  }

  Map<String, dynamic> paraJson() => {
        'populacao': populacao,
        'intervencao': intervencao,
        'comparador': comparador,
        'desfecho': desfecho,
        'termosMesh': termosMesh,
        'desenhosPreferidos': desenhosPreferidos,
        'janelaAnos': janelaAnos,
      };

  /// Monta a consulta Entrez a partir dos campos.
  ///
  /// ## As duas regras que fazem esta consulta funcionar
  ///
  /// **1. Cada conceito vira um bloco `OR`, e os blocos se combinam com `AND`.**
  /// É a estrutura padrão de busca sensível: sinônimos dentro do bloco ampliam,
  /// a interseção entre blocos restringe.
  ///
  /// **2. O comparador NÃO entra com `AND`.** Um erro comum e caro: exigir o
  /// comparador reduz o resultado a estudos que citam os dois braços no
  /// título/resumo, e joga fora justamente as metanálises. Ele entra como
  /// sinônimo do bloco da intervenção, ampliando em vez de restringir.
  ///
  /// O desfecho é opcional na consulta ([incluirDesfecho]) porque é o campo que
  /// mais frequentemente zera a busca: nem todo resumo menciona o desfecho com
  /// as palavras que o médico usou.
  String paraEntrez({bool incluirDesfecho = true, int anoAtual = 2026}) {
    final blocos = <String>[];

    String bloco(String texto, List<String> extras) {
      final termos = <String>[
        ...texto.split(RegExp(r'\s+OR\s+', caseSensitive: false)),
        ...extras,
      ].map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
      if (termos.isEmpty) return '';
      final partes = termos.map(_campo).toList();
      return partes.length == 1 ? partes.first : '(${partes.join(" OR ")})';
    }

    // MeSH entra junto com o texto livre: se o descritor não existir, o bloco
    // ainda casa pelo `[tiab]`.
    final b1 = bloco(populacao, termosMesh.where(_pareceDaPopulacao).toList());
    if (b1.isNotEmpty) blocos.add(b1);

    final b2 = bloco(
      intervencao,
      [
        if (comparador.isNotEmpty) comparador,
        ...termosMesh.where((m) => !_pareceDaPopulacao(m)),
      ],
    );
    if (b2.isNotEmpty) blocos.add(b2);

    if (incluirDesfecho) {
      final b3 = bloco(desfecho, const []);
      if (b3.isNotEmpty) blocos.add(b3);
    }

    if (blocos.isEmpty) return '';
    var q = blocos.join(' AND ');

    if (desenhosPreferidos.isNotEmpty) {
      final tipos =
          desenhosPreferidos.map((d) => '"$d"[ptyp]').join(' OR ');
      q = '$q AND ($tipos)';
    }
    if (janelaAnos != null && janelaAnos! > 0) {
      q = '$q AND ${anoAtual - janelaAnos!}:$anoAtual[pdat]';
    }
    return q;
  }

  /// Um termo com espaço vira frase entre aspas; senão o PubMed o quebraria em
  /// palavras soltas e traria ruído.
  static String _campo(String termo) {
    final t = termo.trim();
    if (t.isEmpty) return '';
    // Já tem qualificador de campo — respeita o que o modelo escreveu.
    if (RegExp(r'\[[a-z]+\]$', caseSensitive: false).hasMatch(t)) return t;
    return t.contains(' ') ? '"$t"[tiab]' : '$t[tiab]';
  }

  /// Heurística simples para separar MeSH de população dos de intervenção.
  /// Errar aqui só troca o bloco do termo — a consulta continua válida.
  static bool _pareceDaPopulacao(String mesh) {
    const marcas = [
      'patient', 'adult', 'child', 'elderly', 'aged', 'infant',
      'pregnan', 'female', 'male', 'population',
    ];
    final m = mesh.toLowerCase();
    return marcas.any(m.contains);
  }

  @override
  String toString() => jsonEncode(paraJson());
}
