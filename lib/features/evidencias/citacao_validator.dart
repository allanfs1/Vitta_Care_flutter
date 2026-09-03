import 'pubmed_models.dart';

/// Validação de citações — a trava contra PMID inventado.
///
/// **Por que isto é código e não instrução de prompt.** O prompt já manda o
/// modelo citar só o que recebeu. Um prompt bem escrito reduz muito a
/// invenção, mas não a elimina: quando o modelo erra, ele erra de forma
/// convincente — um PMID de 8 dígitos plausível, num artigo que não existe. E
/// esse é o pior erro possível num produto médico, porque a citação é
/// justamente o que faz o médico confiar na resposta.
///
/// A regra aqui é determinística: **todo PMID citado tem que estar no pacote de
/// evidências recuperado**. O que não estiver é marcado como inválido, e a UI
/// não o apresenta como fonte.
///
/// Ver `.specify/EVIDENCIAS.md` §6.

/// PMID citado num texto, com a posição onde apareceu.
class CitacaoEncontrada {
  const CitacaoEncontrada(this.pmid, this.inicio, this.fim);
  final String pmid;
  final int inicio;
  final int fim;
}

/// Resultado da validação de um texto contra o pacote de evidências.
class ResultadoValidacao {
  const ResultadoValidacao({
    required this.citados,
    required this.validos,
    required this.invalidos,
    required this.naoCitados,
  });

  /// Todos os PMIDs citados no texto, sem duplicata, na ordem de aparição.
  final List<String> citados;

  /// Citados que existem no pacote recuperado.
  final List<String> validos;

  /// Citados que **não** existem — inventados pelo modelo ou digitados errado.
  final List<String> invalidos;

  /// Recuperados que o modelo não usou. Não é erro: sinaliza quanto do pacote
  /// foi aproveitado, útil para calibrar o tamanho da recuperação.
  final List<String> naoCitados;

  bool get ok => invalidos.isEmpty;
  bool get semCitacao => citados.isEmpty;

  /// Fração das citações que se sustentam (1.0 quando não há citação alguma —
  /// "nada citado" não é o mesmo que "citação errada"; quem trata o caso de
  /// resposta sem fonte é [semCitacao]).
  double get cobertura =>
      citados.isEmpty ? 1.0 : validos.length / citados.length;

  @override
  String toString() =>
      'ResultadoValidacao(validos: ${validos.length}, invalidos: ${invalidos.length})';
}

/// Extrai e valida PMIDs de um texto gerado pelo modelo.
class CitacaoValidator {
  const CitacaoValidator();

  /// Formatos aceitos de citação, do mais explícito ao mais solto:
  ///   `PMID: 12345678` · `PMID 12345678` · `[PMID: 12345678]` ·
  ///   `pmid:12345678` · `[12345678]`
  ///
  /// Números soltos **não** contam. Um ano (2024), uma dose (850) ou um
  /// tamanho de amostra (12345) viraria citação fantasma, e a validação
  /// passaria a acusar erro onde não há.
  static final RegExp _rePmid = RegExp(
    r'\bPMID\s*[:\-]?\s*(\d{1,8})\b|\[\s*(?:PMID\s*[:\-]?\s*)?(\d{7,8})\s*\]',
    caseSensitive: false,
  );

  /// Encontra as citações no [texto], preservando ordem e posição.
  List<CitacaoEncontrada> extrair(String texto) {
    final out = <CitacaoEncontrada>[];
    final vistos = <String>{};
    for (final m in _rePmid.allMatches(texto)) {
      final pmid = m.group(1) ?? m.group(2);
      if (pmid == null || pmid.isEmpty) continue;
      if (vistos.add(pmid)) {
        out.add(CitacaoEncontrada(pmid, m.start, m.end));
      }
    }
    return out;
  }

  /// Valida o [texto] contra os PMIDs efetivamente recuperados.
  ResultadoValidacao validar(String texto, Iterable<String> pmidsRecuperados) {
    final pacote = pmidsRecuperados.map((e) => e.trim()).toSet();
    final citados = extrair(texto).map((c) => c.pmid).toList();

    final validos = <String>[];
    final invalidos = <String>[];
    for (final p in citados) {
      (pacote.contains(p) ? validos : invalidos).add(p);
    }

    return ResultadoValidacao(
      citados: citados,
      validos: validos,
      invalidos: invalidos,
      naoCitados: pacote.where((p) => !citados.contains(p)).toList(),
    );
  }

  /// Valida contra uma lista de artigos.
  ResultadoValidacao validarContra(String texto, List<ArtigoPubmed> artigos) =>
      validar(texto, artigos.map((a) => a.pmid));

  /// Marca as citações inválidas no texto, para o médico ver o que não se
  /// sustenta em vez de a citação sumir silenciosamente.
  ///
  /// Apagar a citação esconderia o problema: o texto continuaria afirmando a
  /// mesma coisa, só que sem fonte aparente — o que é pior que uma fonte
  /// visivelmente furada.
  String anotarInvalidas(String texto, ResultadoValidacao r) {
    if (r.ok) return texto;
    var saida = texto;
    for (final pmid in r.invalidos) {
      saida = saida.replaceAllMapped(
        RegExp(r'(\bPMID\s*[:\-]?\s*' + RegExp.escape(pmid) + r'\b)',
            caseSensitive: false),
        (m) => '${m[1]} ⚠️(não verificada)',
      );
    }
    return saida;
  }

  /// Aviso pronto para a UI quando algo não fecha. `null` = está tudo certo.
  String? aviso(ResultadoValidacao r) {
    if (r.invalidos.isNotEmpty) {
      final n = r.invalidos.length;
      return n == 1
          ? 'Uma citação (PMID ${r.invalidos.first}) não corresponde a nenhum '
              'artigo recuperado nesta busca e foi marcada como não verificada.'
          : '$n citações não correspondem a artigos recuperados nesta busca e '
              'foram marcadas como não verificadas.';
    }
    if (r.semCitacao) {
      return 'Esta resposta não cita nenhuma fonte. Trate-a como orientação '
          'geral, não como evidência.';
    }
    return null;
  }
}
