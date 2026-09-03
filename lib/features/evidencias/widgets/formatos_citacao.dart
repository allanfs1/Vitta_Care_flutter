import '../pubmed_models.dart';

/// Formatos de citação oferecidos ao copiar.
///
/// Existem quatro porque o destino manda: periódico biomédico pede Vancouver,
/// trabalho acadêmico brasileiro pede ABNT, e gerenciador de referências
/// (Zotero, Mendeley, EndNote) quer BibTeX ou RIS. Oferecer só um formato faz o
/// médico reformatar à mão — que é onde erro de citação entra.
enum FormatoCitacao {
  vancouver('Vancouver'),
  abnt('ABNT'),
  bibtex('BibTeX'),
  ris('RIS');

  const FormatoCitacao(this.rotulo);
  final String rotulo;
}

String formatarCitacao(ArtigoPubmed a, FormatoCitacao f) => switch (f) {
      FormatoCitacao.vancouver => _vancouver(a),
      FormatoCitacao.abnt => _abnt(a),
      FormatoCitacao.bibtex => _bibtex(a),
      FormatoCitacao.ris => _ris(a),
    };

/// Vancouver — o padrão da literatura biomédica.
///
/// Regra do ICMJE: até 6 autores lista todos; a partir do 7º, lista os 6
/// primeiros e "et al.".
String _vancouver(ArtigoPubmed a) {
  final autores = a.autores.isEmpty
      ? ''
      : (a.autores.length <= 6
          ? a.autores.join(', ')
          : '${a.autores.take(6).join(', ')}, et al');

  final partes = <String>[
    if (autores.isNotEmpty) '$autores.',
    if (a.titulo.isNotEmpty) '${_semPontoFinal(a.titulo)}.',
    if (a.periodico.isNotEmpty) '${a.periodico}.',
    if (a.dataPublicacao.isNotEmpty) '${a.dataPublicacao};',
    if (a.volume.isNotEmpty) a.volume,
    if (a.paginas.isNotEmpty) ':${a.paginas}',
    '. PMID: ${a.pmid}',
    if (a.doi != null) '. doi:${a.doi}',
  ];
  return partes.join(' ').replaceAll(' ;', ';').replaceAll(' :', ':').replaceAll(' .', '.');
}

/// ABNT NBR 6023 — sobrenome em versal, título em negrito (aqui em texto puro).
String _abnt(ArtigoPubmed a) {
  String versal(String nome) {
    // O ESummary devolve "McMurray JJV": sobrenome primeiro, iniciais depois.
    final p = nome.trim().split(RegExp(r'\s+'));
    if (p.length < 2) return nome.toUpperCase();
    return '${p.first.toUpperCase()}, ${p.sublist(1).join(" ")}';
  }

  final autores = a.autores.isEmpty
      ? ''
      : (a.autores.length <= 3
          ? a.autores.map(versal).join('; ')
          : '${versal(a.autores.first)} et al.');

  return [
    if (autores.isNotEmpty) '$autores.',
    if (a.titulo.isNotEmpty) '${_semPontoFinal(a.titulo)}.',
    if (a.periodico.isNotEmpty) '${a.periodico},',
    if (a.volume.isNotEmpty) 'v. ${a.volume},',
    if (a.paginas.isNotEmpty) 'p. ${a.paginas},',
    if (a.ano != null) '${a.ano}.',
    if (a.doi != null) 'DOI: ${a.doi}.',
    'PMID: ${a.pmid}.',
  ].join(' ');
}

String _bibtex(ArtigoPubmed a) {
  final chave = _chaveBibtex(a);
  final campos = <String, String>{
    'title': a.titulo,
    if (a.autores.isNotEmpty) 'author': a.autores.join(' and '),
    if (a.periodico.isNotEmpty) 'journal': a.periodico,
    if (a.ano != null) 'year': '${a.ano}',
    if (a.volume.isNotEmpty) 'volume': a.volume,
    if (a.paginas.isNotEmpty) 'pages': a.paginas,
    if (a.doi != null) 'doi': a.doi!,
    'pmid': a.pmid,
    'url': a.url,
  };
  final corpo =
      campos.entries.map((e) => '  ${e.key} = {${e.value}}').join(',\n');
  return '@article{$chave,\n$corpo\n}';
}

/// Chave curta e estável: sobrenome do primeiro autor + ano + PMID.
///
/// O PMID no fim garante unicidade — dois artigos do mesmo autor no mesmo ano
/// colidiriam, e um gerenciador de referências rejeita chave repetida.
String _chaveBibtex(ArtigoPubmed a) {
  final sobrenome = a.autores.isEmpty
      ? 'anon'
      : a.autores.first.split(RegExp(r'\s+')).first.toLowerCase();
  final limpo = sobrenome.replaceAll(RegExp(r'[^a-z]'), '');
  return '${limpo.isEmpty ? "anon" : limpo}${a.ano ?? ""}_${a.pmid}';
}

/// RIS — o formato que EndNote, Mendeley e Zotero importam.
String _ris(ArtigoPubmed a) {
  final linhas = <String>[
    'TY  - JOUR',
    for (final autor in a.autores) 'AU  - $autor',
    if (a.titulo.isNotEmpty) 'TI  - ${a.titulo}',
    if (a.periodico.isNotEmpty) 'JO  - ${a.periodico}',
    if (a.ano != null) 'PY  - ${a.ano}',
    if (a.volume.isNotEmpty) 'VL  - ${a.volume}',
    if (a.paginas.isNotEmpty) 'SP  - ${a.paginas}',
    if (a.doi != null) 'DO  - ${a.doi}',
    'AN  - ${a.pmid}',
    'UR  - ${a.url}',
    'ER  - ',
  ];
  return linhas.join('\n');
}

String _semPontoFinal(String s) =>
    s.endsWith('.') ? s.substring(0, s.length - 1) : s;
