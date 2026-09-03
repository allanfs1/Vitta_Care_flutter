/// Leitor do EFetch em XML.
///
/// ## Por que XML e não o formato texto
///
/// O EFetch em `retmode=text` concatena os artigos num relatório pensado para
/// humanos: citação numerada que **quebra em várias linhas**, título, autores,
/// afiliações e só então o resumo. Separar isso por heurística de linha erra —
/// e errou: a continuação da linha de citação (`10.1016/j.arteri...`) vazava
/// para dentro do resumo, porque só a primeira linha começava com `doi:`.
///
/// O XML resolve por estrutura em vez de palpite, e ainda entrega os **rótulos
/// de seção** (BACKGROUND/METHODS/RESULTS/CONCLUSIONS) que o formato texto
/// joga fora. Para quem lê evidência, saber que um trecho é CONCLUSIONS e não
/// METHODS muda o peso da frase.
///
/// ## Por que regex e não um parser de XML
///
/// A extração é de duas tags conhecidas (`PMID`, `AbstractText`) dentro de
/// blocos delimitados (`PubmedArticle`). Trazer um parser completo adicionaria
/// dependência e superfície de ataque (XXE, bombas de entidade) para um ganho
/// que não existe neste recorte. Se um dia for preciso ler MeSH, autores
/// estruturados ou afiliações, aí sim vale um parser de verdade.
library;

import 'pubmed_models.dart';

final _reArtigo =
    RegExp(r'<PubmedArticle>([\s\S]*?)</PubmedArticle>', caseSensitive: false);
final _rePmid =
    RegExp(r'<PMID[^>]*>\s*(\d+)\s*</PMID>', caseSensitive: false);
final _reAbstractText = RegExp(
  r'<AbstractText([^>]*)>([\s\S]*?)</AbstractText>',
  caseSensitive: false,
);
final _reLabel = RegExp('Label="([^"]*)"', caseSensitive: false);
final _reTag = RegExp(r'<[^>]+>');

/// Resumos por PMID, extraídos do XML do EFetch.
///
/// PMID sem `<Abstract>` recebe lista vazia — que é diferente de ausente: o
/// primeiro é "o registro não tem resumo", o segundo é "não veio na resposta".
Map<String, List<SecaoResumo>> lerAbstractsXml(String xml) {
  final out = <String, List<SecaoResumo>>{};
  if (xml.trim().isEmpty) return out;

  for (final artigo in _reArtigo.allMatches(xml)) {
    final bloco = artigo.group(1) ?? '';

    // O primeiro <PMID> do bloco é o do artigo. Os seguintes, quando existem,
    // são de referências e de correções — usar um deles trocaria o dono do
    // resumo.
    final pmid = _rePmid.firstMatch(bloco)?.group(1);
    if (pmid == null) continue;

    final secoes = <SecaoResumo>[];
    for (final m in _reAbstractText.allMatches(bloco)) {
      final atributos = m.group(1) ?? '';
      final texto = _limpar(m.group(2) ?? '');
      if (texto.isEmpty) continue;
      secoes.add(SecaoResumo(
        rotulo: _reLabel.firstMatch(atributos)?.group(1)?.trim() ?? '',
        texto: texto,
      ));
    }
    out[pmid] = secoes;
  }
  return out;
}

/// Tira a marcação inline (`<i>`, `<sup>`, `<b>`) e decodifica entidades.
///
/// A marcação é removida em vez de renderizada: um `<sub>2</sub>` em "SGLT2"
/// vira "SGLT2", que é como o médico lê e como a citação deve sair.
String _limpar(String bruto) {
  var s = bruto.replaceAll(_reTag, '');
  s = s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      // `&amp;` por último: antes desfaria as substituições acima quando o
      // texto original trouxesse `&amp;lt;`.
      .replaceAll('&amp;', '&');
  return s.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}
