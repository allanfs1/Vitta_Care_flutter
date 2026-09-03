/// Confere que a IA não inventou números ao interpretar a simulação.
///
/// ## Por que um número inventado aqui é pior que um texto errado
///
/// A saída deste módulo vira **decisão de agenda**. Se a simulação disse que
/// cabem 2 encaixes e o texto da IA disser "6", alguém liga para quatro
/// pacientes a mais — e eles aparecem, de verdade, numa sala de espera real.
///
/// O prompt já proíbe inventar. Mas prompt reduz, não elimina: quando o modelo
/// erra, ele erra com um número plausível e uma frase segura. É exatamente o
/// caso em que ninguém confere.
///
/// É a mesma trava do módulo de Evidências (`CitacaoValidator`), com PMID
/// trocado por cifra.
///
/// ## O que NÃO é checado, e por quê
///
/// Percentual, ano, hora e ordinal passam livres. Exigir que "100%", "9h" ou
/// "1º dia" estivessem no conjunto de números da simulação encheria a tela de
/// alarme falso e treinaria o gestor a ignorar o aviso — que é o único jeito
/// de a trava deixar de funcionar.
library;

/// Um número citado no texto, com onde apareceu.
class NumeroCitado {
  const NumeroCitado(this.texto, this.inicio, this.fim);
  final String texto;
  final int inicio;
  final int fim;
}

class ResultadoNumeros {
  const ResultadoNumeros({
    required this.citados,
    required this.conferem,
    required this.naoConferem,
  });

  final List<String> citados;
  final List<String> conferem;

  /// Números que não aparecem em lugar nenhum da simulação.
  final List<String> naoConferem;

  bool get ok => naoConferem.isEmpty;
  bool get semNumeros => citados.isEmpty;
}

class ValidadorNumeros {
  const ValidadorNumeros();

  /// Números que valem conferir: inteiros e decimais soltos, e valores em
  /// reais. Exclui o que vem colado a `%`, `h`, `º`/`ª` e o que faz parte de
  /// uma data — ver o comentário da classe.
  static final RegExp _reNumero = RegExp(
    r'(?<![\d,./:-])'          // não no meio de outro número ou data
    r'R?\$?\s?'                // "R$ " opcional
    r'(\d{1,3}(?:\.\d{3})+|\d+(?:[.,]\d+)?)'
    r'(?![\d,.]*\s*(?:%|h\b|º|ª|/\d))',
  );

  List<NumeroCitado> extrair(String texto) {
    final out = <NumeroCitado>[];
    final vistos = <String>{};
    for (final m in _reNumero.allMatches(texto)) {
      final bruto = m.group(1);
      if (bruto == null) continue;
      final n = _normalizar(bruto);
      // Números de um dígito são ruído: "os 2 primeiros dias", "a 1ª semana".
      // Conferi-los produziria mais falso positivo que achado.
      if (n.length < 2 && !RegExp(r'^\d$').hasMatch(n)) continue;
      if (vistos.add(n)) out.add(NumeroCitado(n, m.start, m.end));
    }
    return out;
  }

  /// Confere [texto] contra os números que a simulação produziu.
  ResultadoNumeros validar(String texto, Set<String> permitidos) {
    final norm = permitidos.map(_normalizar).toSet();
    final citados = extrair(texto).map((c) => c.texto).toList();

    final conferem = <String>[];
    final naoConferem = <String>[];
    for (final n in citados) {
      (norm.contains(n) ? conferem : naoConferem).add(n);
    }
    return ResultadoNumeros(
      citados: citados,
      conferem: conferem,
      naoConferem: naoConferem,
    );
  }

  /// Marca no texto os números que não conferem.
  ///
  /// Marca em vez de apagar, pelo mesmo motivo do módulo de Evidências: apagar
  /// deixaria a frase de pé sem o número, afirmando a mesma coisa sem nada que
  /// denuncie o problema.
  String anotar(String texto, ResultadoNumeros r) {
    if (r.ok) return texto;
    var saida = texto;
    for (final n in r.naoConferem) {
      saida = saida.replaceAllMapped(
        RegExp(r'(?<![\d,.])' + RegExp.escape(n) + r'(?![\d,.])'),
        (m) => '${m[0]} ⚠️',
      );
    }
    return saida;
  }

  String? aviso(ResultadoNumeros r) {
    if (r.naoConferem.isEmpty) return null;
    final n = r.naoConferem.length;
    return n == 1
        ? 'Um número desta análise ($n) não veio da simulação e está marcado '
            'no texto. Confira antes de agir.'
        : '$n números desta análise não vieram da simulação e estão marcados '
            'no texto. Confira antes de agir.';
  }

  /// `1.234` e `1234` são o mesmo número; `2,5` e `2.5` também.
  static String _normalizar(String s) {
    var n = s.trim().replaceAll(RegExp(r'^R?\$\s*'), '');
    // Separador de milhar brasileiro.
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(n)) {
      n = n.replaceAll('.', '');
    }
    n = n.replaceAll(',', '.');
    // 5.0 e 5 são o mesmo valor para quem lê.
    if (n.endsWith('.0')) n = n.substring(0, n.length - 2);
    return n;
  }
}
