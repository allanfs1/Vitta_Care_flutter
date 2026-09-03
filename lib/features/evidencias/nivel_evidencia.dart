import 'package:flutter/material.dart';

/// Onde um estudo cai na pirâmide de evidência.
///
/// ## Por que isto existe como conceito próprio
///
/// O desenho do estudo já aparecia como um selo de texto. Texto obriga a ler e
/// interpretar cada card, um a um. Um médico triando 20 resultados não lê — ele
/// **varre**, e o que ele procura é força de evidência.
///
/// Traduzir o desenho em um nível com cor e posição dá essa leitura em
/// varredura: a barra colorida na lateral do card responde "vale a pena parar
/// aqui?" antes do título ser lido.
///
/// ## A hierarquia não é opinião nossa
///
/// Segue a pirâmide clássica da medicina baseada em evidência. Ela tem
/// críticas conhecidas — uma metanálise de ensaios ruins não vale mais que um
/// ensaio bem-feito, e desenho não é qualidade. Por isso o nível é sinalizado
/// como **ponto de partida da triagem**, nunca como nota do estudo, e o card
/// continua mostrando o desenho por extenso.
enum NivelEvidencia {
  /// Metanálises e revisões sistemáticas — síntese de múltiplos estudos.
  sintese(1, 'Síntese de estudos'),

  /// Ensaios randomizados — o desenho que melhor controla confusão.
  experimental(2, 'Estudo experimental'),

  /// Coortes, caso-controle, ensaios não randomizados.
  observacional(3, 'Estudo observacional'),

  /// Revisões narrativas e diretrizes — úteis, mas não são evidência primária.
  narrativa(4, 'Revisão ou diretriz'),

  /// Relatos e séries de caso — geram hipótese, não sustentam conduta.
  relato(5, 'Relato de caso'),

  /// O NCBI não declarou tipo, ou declarou só "Journal Article".
  indefinido(6, 'Tipo não informado');

  const NivelEvidencia(this.ordem, this.descricao);

  /// 1 = topo da pirâmide. Usado para ordenar a triagem.
  final int ordem;
  final String descricao;

  /// Desenhos que a MBE trata como topo — ganham destaque visual.
  bool get forte => ordem <= 2;

  /// Classifica pelo `pubtype` do PubMed.
  ///
  /// A ordem dos testes importa: um artigo costuma trazer vários tipos ao mesmo
  /// tempo ("Randomized Controlled Trial" **e** "Journal Article"), e vale o
  /// mais forte.
  static NivelEvidencia de(String? desenho) {
    if (desenho == null || desenho.isEmpty) return indefinido;
    return switch (desenho) {
      'Meta-Analysis' || 'Systematic Review' => sintese,
      'Randomized Controlled Trial' ||
      'Controlled Clinical Trial' =>
        experimental,
      'Clinical Trial' ||
      'Clinical Trial, Phase III' ||
      'Clinical Trial, Phase II' ||
      'Observational Study' ||
      'Comparative Study' ||
      'Multicenter Study' =>
        observacional,
      'Review' || 'Guideline' || 'Practice Guideline' => narrativa,
      'Case Reports' => relato,
      'Journal Article' => indefinido,
      _ => observacional,
    };
  }

  /// Cor do nível, derivada do tema.
  ///
  /// Deriva em vez de fixar hex porque o app tem tema claro e escuro, e um
  /// verde escolhido para o escuro fica ilegível no claro. Verde e âmbar vêm
  /// com luminosidade ajustada ao brilho do tema.
  Color cor(ThemeData theme) {
    final escuro = theme.brightness == Brightness.dark;
    return switch (this) {
      sintese => escuro ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      experimental => theme.colorScheme.primary,
      observacional =>
        escuro ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
      narrativa => escuro ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      relato => theme.colorScheme.onSurfaceVariant,
      indefinido => theme.colorScheme.outline,
    };
  }
}
