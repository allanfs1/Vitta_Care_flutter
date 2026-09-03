import '../nivel_evidencia.dart';
import '../widgets/formatos_citacao.dart';
import 'sessao_models.dart';

/// Formatos de exportação de uma sessão.
enum FormatoExport {
  markdown('Markdown', 'md', 'text/markdown'),
  ris('RIS', 'ris', 'application/x-research-info-systems'),
  bibtex('BibTeX', 'bib', 'application/x-bibtex'),
  json('JSON', 'json', 'application/json');

  const FormatoExport(this.rotulo, this.extensao, this.mime);
  final String rotulo;
  final String extensao;
  final String mime;
}

/// Converte uma sessão em arquivo.
///
/// ## Quatro formatos, quatro destinos
///
/// | Formato | Para onde vai |
/// |---|---|
/// | Markdown | prontuário, e-mail, discussão de caso — legível por gente |
/// | RIS / BibTeX | Zotero, Mendeley, EndNote — entra no gerenciador |
/// | JSON | backup e reimportação — nada se perde |
///
/// ## O que o Markdown carrega além dos artigos
///
/// A **estratégia de busca** e a **data**. Um export que trouxesse só a lista
/// de artigos seria uma bibliografia; com a estratégia e a data ele é um
/// registro reprodutível — dá para outra pessoa repetir a busca e ver o que
/// mudou desde então. É a diferença entre "achei estes artigos" e "pesquisei
/// assim, neste dia, e achei estes artigos".
class SessaoExport {
  const SessaoExport._();

  static String gerar(SessaoPesquisa s, FormatoExport formato) =>
      switch (formato) {
        FormatoExport.markdown => _markdown(s),
        FormatoExport.ris =>
          s.artigos.map((a) => formatarCitacao(a, FormatoCitacao.ris)).join('\n'),
        FormatoExport.bibtex => s.artigos
            .map((a) => formatarCitacao(a, FormatoCitacao.bibtex))
            .join('\n\n'),
        FormatoExport.json => s.paraJsonTexto(),
      };

  /// Nome de arquivo seguro em qualquer sistema.
  static String nomeArquivo(SessaoPesquisa s, FormatoExport formato) {
    final base = s.titulo
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9à-ú\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final curto = base.length > 48 ? base.substring(0, 48) : base;
    final d = s.salvaEm;
    String dd(int n) => n.toString().padLeft(2, '0');
    final data = '${d.year}${dd(d.month)}${dd(d.day)}';
    return 'evidencias-${curto.isEmpty ? "sessao" : curto}-$data.${formato.extensao}';
  }

  static String _markdown(SessaoPesquisa s) {
    final b = StringBuffer();

    b.writeln('# ${s.titulo}');
    b.writeln();
    if (s.pergunta.isNotEmpty && s.pergunta != s.titulo) {
      b.writeln('> ${s.pergunta}');
      b.writeln();
    }

    // Bloco de reprodutibilidade: é o que separa um export de uma bibliografia.
    b.writeln('## Como esta busca foi feita');
    b.writeln();
    b.writeln('| | |');
    b.writeln('|---|---|');
    b.writeln('| Data | ${_data(s.salvaEm)} |');
    b.writeln('| Modo | ${_modo(s.modo)} |');
    if (s.consultaEnviada.isNotEmpty) {
      b.writeln('| Consulta enviada | `${s.consultaEnviada}` |');
    }
    if (s.queryTraduzida.isNotEmpty) {
      b.writeln('| O PubMed interpretou | `${s.queryTraduzida}` |');
    }
    if (s.totalNoPubmed > 0) {
      b.writeln('| Total no PubMed | ${s.totalNoPubmed} |');
    }
    b.writeln('| Artigos nesta sessão | ${s.artigos.length} |');
    b.writeln('| Origem | ${s.viaProxy ? "Serviço interno" : "Direto no NCBI"} |');
    if (s.filtros != null && s.filtros!.quantidadeAtiva > 0) {
      b.writeln('| Filtros | ${s.filtros!.resumo.join(" · ")} |');
    }
    b.writeln();

    if (s.temSintese) {
      b.writeln('## Síntese');
      b.writeln();
      b.writeln(s.sintese!.trim());
      b.writeln();
      b.writeln('> Texto gerado por IA a partir dos resumos abaixo. As citações '
          'foram conferidas contra os artigos recuperados. Não substitui a '
          'leitura dos estudos nem o julgamento clínico.');
      b.writeln();
    }

    if (s.temConversa) {
      b.writeln('## Conversa');
      b.writeln();
      for (final m in s.conversa) {
        final quem = m['papel'] == 'user' ? '**Pergunta**' : '**Resposta**';
        b.writeln('$quem — ${m['texto']}');
        b.writeln();
      }
    }

    b.writeln('## Artigos');
    b.writeln();
    for (var i = 0; i < s.artigos.length; i++) {
      final a = s.artigos[i];
      final nivel = NivelEvidencia.de(a.desenhoEstudo);
      final citado = s.pmidsCitados.contains(a.pmid);

      b.writeln('### ${i + 1}. ${a.titulo}${citado ? " *(citado)*" : ""}');
      b.writeln();
      b.writeln('- **${nivel.descricao}**'
          '${a.desenhoEstudo != null ? " — ${a.desenhoEstudo}" : ""}');
      b.writeln('- ${a.autoresCurto}');
      if (a.periodico.isNotEmpty) {
        b.writeln('- *${a.periodico}*'
            '${a.dataPublicacao.isNotEmpty ? ", ${a.dataPublicacao}" : ""}');
      }
      b.writeln('- PMID: [${a.pmid}](${a.url})');
      if (a.doi != null) b.writeln('- DOI: [${a.doi}](${a.urlDoi})');
      if (a.urlPmc != null) b.writeln('- Texto completo: ${a.urlPmc}');

      final secoes = a.abstractSecoes;
      if (secoes != null && secoes.isNotEmpty) {
        b.writeln();
        for (final sec in secoes) {
          if (sec.temRotulo) {
            b.writeln('**${sec.rotuloPt}** — ${sec.texto}');
          } else {
            b.writeln(sec.texto);
          }
          b.writeln();
        }
      } else {
        b.writeln();
      }
    }

    b.writeln('---');
    b.writeln();
    b.writeln('*Exportado do módulo Evidências do Vitta em '
        '${_data(DateTime.now())}. Fonte: PubMed/NCBI.*');
    return b.toString();
  }

  static String _modo(String m) => switch (m) {
        'agente' => 'Pergunta à IA (revisão estruturada)',
        'chat' => 'Chat de pesquisa',
        _ => 'Busca direta',
      };

  static String _data(DateTime d) {
    final l = d.toLocal();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(l.day)}/${dd(l.month)}/${l.year} ${dd(l.hour)}:${dd(l.minute)}';
  }
}
