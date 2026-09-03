/// Filtros clínicos da busca.
///
/// Traduzem escolhas de interface em sintaxe Entrez. Existem porque a diferença
/// entre uma busca útil e uma inútil quase nunca está no termo — está no
/// recorte: desenho do estudo, janela de tempo, espécie, faixa etária.
///
/// ## Uma decisão que muda o resultado: os filtros são aditivos, não exclusivos
///
/// Marcar "Metanálise" e "Ensaio randomizado" traz **os dois** (`OR` dentro do
/// grupo), não a interseção — que seria vazia, já que um artigo não é os dois
/// ao mesmo tempo. Grupos diferentes se combinam com `AND`.
library;

/// Desenhos de estudo oferecidos como filtro, do mais forte ao mais fraco.
enum DesenhoFiltro {
  metanalise('Meta-Analysis', 'Metanálise'),
  revisaoSistematica('Systematic Review', 'Revisão sistemática'),
  ensaioRandomizado('Randomized Controlled Trial', 'Ensaio randomizado'),
  ensaioClinico('Clinical Trial', 'Ensaio clínico'),
  coorte('Observational Study', 'Estudo observacional'),
  revisao('Review', 'Revisão'),
  diretriz('Guideline', 'Diretriz'),
  relatoCaso('Case Reports', 'Relato de caso');

  const DesenhoFiltro(this.ptyp, this.rotulo);

  /// Valor exato do campo `[ptyp]` no PubMed.
  final String ptyp;
  final String rotulo;

  /// Desenhos que a medicina baseada em evidência trata como topo da pirâmide.
  bool get forte =>
      this == metanalise ||
      this == revisaoSistematica ||
      this == ensaioRandomizado;
}

/// Faixa etária — mapeia para os grupos MeSH do PubMed.
enum FaixaEtaria {
  nenhuma('', ''),
  crianca('child[mesh]', 'Criança (0–18)'),
  adulto('adult[mesh]', 'Adulto (19–44)'),
  meiaIdade('middle aged[mesh]', 'Meia-idade (45–64)'),
  idoso('aged[mesh]', 'Idoso (65+)');

  const FaixaEtaria(this.expressao, this.rotulo);
  final String expressao;
  final String rotulo;
}

class FiltrosBusca {
  const FiltrosBusca({
    this.desenhos = const {},
    this.anosRecentes,
    this.somenteHumanos = false,
    this.somenteComResumo = false,
    this.somenteTextoLivre = false,
    this.faixaEtaria = FaixaEtaria.nenhuma,
    this.idiomaIngles = false,
  });

  final Set<DesenhoFiltro> desenhos;

  /// Janela em anos a partir de hoje. `null` = sem recorte.
  final int? anosRecentes;

  /// Exclui estudos apenas em animais. Recorte que quase sempre se quer numa
  /// pergunta assistencial, e quase nunca numa pergunta de pesquisa básica —
  /// por isso é opção, não padrão.
  final bool somenteHumanos;
  final bool somenteComResumo;

  /// Só artigos com texto completo gratuito. Reduz bastante o resultado, mas é
  /// o filtro mais prático para quem vai de fato ler o artigo hoje.
  final bool somenteTextoLivre;
  final FaixaEtaria faixaEtaria;
  final bool idiomaIngles;

  bool get vazio =>
      desenhos.isEmpty &&
      anosRecentes == null &&
      !somenteHumanos &&
      !somenteComResumo &&
      !somenteTextoLivre &&
      faixaEtaria == FaixaEtaria.nenhuma &&
      !idiomaIngles;

  int get quantidadeAtiva => [
        desenhos.isNotEmpty,
        anosRecentes != null,
        somenteHumanos,
        somenteComResumo,
        somenteTextoLivre,
        faixaEtaria != FaixaEtaria.nenhuma,
        idiomaIngles,
      ].where((e) => e).length;

  FiltrosBusca copyWith({
    Set<DesenhoFiltro>? desenhos,
    int? anosRecentes,
    bool limparAnos = false,
    bool? somenteHumanos,
    bool? somenteComResumo,
    bool? somenteTextoLivre,
    FaixaEtaria? faixaEtaria,
    bool? idiomaIngles,
  }) =>
      FiltrosBusca(
        desenhos: desenhos ?? this.desenhos,
        anosRecentes: limparAnos ? null : (anosRecentes ?? this.anosRecentes),
        somenteHumanos: somenteHumanos ?? this.somenteHumanos,
        somenteComResumo: somenteComResumo ?? this.somenteComResumo,
        somenteTextoLivre: somenteTextoLivre ?? this.somenteTextoLivre,
        faixaEtaria: faixaEtaria ?? this.faixaEtaria,
        idiomaIngles: idiomaIngles ?? this.idiomaIngles,
      );

  /// Aplica os filtros a [termo], devolvendo a consulta Entrez completa.
  ///
  /// O termo do usuário vai entre parênteses: sem isso, um `OR` que ele tenha
  /// escrito se combinaria errado com os `AND` dos filtros — e a busca traria
  /// algo diferente do que a tela mostra.
  String aplicar(String termo, {int anoAtual = 2026}) {
    final base = termo.trim();
    if (base.isEmpty) return '';
    if (vazio) return base;

    final partes = <String>[
      // Só parenteseia quando há operador — evita poluir a consulta simples
      // que o médico lê no painel "Como pesquisamos".
      RegExp(r'\b(OR|AND|NOT)\b').hasMatch(base) ? '($base)' : base,
    ];

    if (desenhos.isNotEmpty) {
      final tipos = desenhos.map((d) => '"${d.ptyp}"[ptyp]').join(' OR ');
      partes.add(desenhos.length == 1 ? tipos : '($tipos)');
    }
    if (somenteHumanos) partes.add('humans[mesh]');
    if (faixaEtaria != FaixaEtaria.nenhuma) partes.add(faixaEtaria.expressao);
    if (idiomaIngles) partes.add('english[lang]');
    if (somenteComResumo) partes.add('hasabstract');
    if (somenteTextoLivre) partes.add('free full text[filter]');
    if (anosRecentes != null && anosRecentes! > 0) {
      partes.add('${anoAtual - anosRecentes!}:$anoAtual[pdat]');
    }

    return partes.join(' AND ');
  }

  /// Rótulos curtos dos filtros ativos, para a UI listar o que está valendo.
  List<String> get resumo {
    final out = <String>[];
    for (final d in desenhos) {
      out.add(d.rotulo);
    }
    if (anosRecentes != null) out.add('Últimos $anosRecentes anos');
    if (somenteHumanos) out.add('Humanos');
    if (faixaEtaria != FaixaEtaria.nenhuma) out.add(faixaEtaria.rotulo);
    if (idiomaIngles) out.add('Em inglês');
    if (somenteComResumo) out.add('Com resumo');
    if (somenteTextoLivre) out.add('Texto completo grátis');
    return out;
  }
}
