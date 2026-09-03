/// Guarda de dado pessoal (PHI) — **espelho em Dart** da guarda que roda em
/// `functions/lib/pubmed.js`.
///
/// ## Por que existe uma segunda cópia
///
/// A guarda autoritativa é a do servidor: roda onde o usuário não alcança, e
/// vale para toda chamada que passe pelo `pubmedProxy`. Esta cópia existe
/// porque o app tem um **caminho direto** ao NCBI ([PubmedDirect]), usado
/// quando o proxy não está publicado. Nesse caminho não há servidor nenhum
/// entre o navegador e o NIH — então ou a guarda roda aqui, ou não roda.
///
/// Duas cópias da mesma regra é dívida conhecida, e a alternativa era pior:
/// um caminho de rede sem proteção alguma. `evidencias_test.dart` trava as
/// duas contra os mesmos casos, e `.specify/EVIDENCIAS.md` §11 registra o
/// pareamento — se um lado mudar, o outro tem que mudar junto.
library;

/// Um padrão de dado pessoal e o rótulo que o usuário vê.
class _PadraoPhi {
  const _PadraoPhi(this.rotulo, this.re);
  final String rotulo;
  final RegExp re;
}

/// Os mesmos seis padrões do servidor, na mesma ordem.
final List<_PadraoPhi> _padroes = [
  _PadraoPhi('CPF', RegExp(r'\b\d{3}\.\d{3}\.\d{3}-\d{2}\b|\b\d{11}\b')),
  _PadraoPhi('Cartão Nacional de Saúde', RegExp(r'\b\d{15}\b')),
  _PadraoPhi(
    'CNPJ',
    RegExp(r'\b\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}\b|\b\d{14}\b'),
  ),
  _PadraoPhi(
    'e-mail',
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
  ),
  _PadraoPhi(
    'telefone',
    RegExp(r'\(\d{2}\)\s?9?\d{4}-?\d{4}|\b\d{2}\s9\d{4}-?\d{4}\b'),
  ),
  // Genérico por último: exige 11+ dígitos de propósito. Consulta clínica
  // legítima carrega ano (2022:2026[pdat]), dose (850 mg) e PMID (8 dígitos) —
  // abaixo de 11 o risco de barrar busca válida supera o de vazamento.
  _PadraoPhi('sequência longa de dígitos', RegExp(r'\d{11,}')),
];

/// Rótulos dos padrões de dado pessoal encontrados em [texto].
/// Lista vazia = liberado.
List<String> detectarPhi(String? texto) {
  final s = texto ?? '';
  if (s.trim().isEmpty) return const [];
  final achados = <String>[];
  for (final p in _padroes) {
    if (p.re.hasMatch(s) && !achados.contains(p.rotulo)) {
      achados.add(p.rotulo);
    }
  }
  return achados;
}

/// `true` quando o texto pode ir para o NCBI.
bool textoLiberado(String? texto) => detectarPhi(texto).isEmpty;
