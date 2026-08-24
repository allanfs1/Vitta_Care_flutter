/// Zonas do texto onde a sintaxe proprietária do VFM **não** é interpretada
/// (`obsidian.md` §5.5 › "Zonas de exclusão").
///
/// Sem isso, `#fragmento` numa URL viraria tag e `` `[[a]]` `` viraria link —
/// bugs clássicos de parser de markdown estendido.
class Intervalo {
  const Intervalo(this.inicio, this.fim);

  /// Inclusivo.
  final int inicio;

  /// Exclusivo.
  final int fim;

  bool contem(int i) => i >= inicio && i < fim;
}

/// Conjunto ordenado e imutável de zonas proibidas, com busca binária.
class MascaraCodigo {
  MascaraCodigo._(this._zonas);

  final List<Intervalo> _zonas;

  bool get vazia => _zonas.isEmpty;

  /// `true` se a posição [i] está dentro de uma zona proibida. O(log n).
  bool bloqueado(int i) {
    var lo = 0;
    var hi = _zonas.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final z = _zonas[mid];
      if (i < z.inicio) {
        hi = mid - 1;
      } else if (i >= z.fim) {
        lo = mid + 1;
      } else {
        return true;
      }
    }
    return false;
  }

  /// Fim da zona que contém [i], ou o próprio [i] se não estiver bloqueado.
  /// Permite ao tokenizer pular a região inteira de uma vez.
  int fimDaZona(int i) {
    for (final z in _zonas) {
      if (z.contem(i)) return z.fim;
      if (z.inicio > i) break;
    }
    return i;
  }

  /// Analisa [texto] e devolve as zonas de: blocos cercados (``` / ~~~),
  /// código inline (`…`), URLs e comentários `%%…%%`.
  static MascaraCodigo analisar(String texto) {
    final zonas = <Intervalo>[];
    final n = texto.length;
    var i = 0;
    var inicioLinha = true;

    while (i < n) {
      final c = texto[i];

      // ── Bloco cercado: ``` ou ~~~ no início da linha ──────────────────────
      if (inicioLinha && (c == '`' || c == '~')) {
        final cerca = _contarRepetido(texto, i, c);
        if (cerca >= 3) {
          final marcador = c * cerca;
          final fimLinhaAbertura = _fimDaLinha(texto, i);
          final fechamento = _acharFechamentoCerca(texto, fimLinhaAbertura, marcador);
          zonas.add(Intervalo(i, fechamento));
          i = fechamento;
          inicioLinha = true;
          continue;
        }
      }

      // ── Código inline: uma ou mais crases na mesma linha ──────────────────
      if (c == '`') {
        final abertura = _contarRepetido(texto, i, '`');
        final marcador = '`' * abertura;
        final fecha = texto.indexOf(marcador, i + abertura);
        final fimLinha = _fimDaLinha(texto, i);
        if (fecha > 0 && fecha < fimLinha) {
          final fim = fecha + abertura;
          zonas.add(Intervalo(i, fim));
          i = fim;
          inicioLinha = false;
          continue;
        }
      }

      // ── Comentário do Obsidian: %%…%% ─────────────────────────────────────
      if (c == '%' && i + 1 < n && texto[i + 1] == '%') {
        final fecha = texto.indexOf('%%', i + 2);
        final fim = fecha < 0 ? n : fecha + 2;
        zonas.add(Intervalo(i, fim));
        i = fim;
        inicioLinha = false;
        continue;
      }

      // ── URL: http:// ou https:// até espaço em branco ─────────────────────
      if (c == 'h' && texto.startsWith(RegExp(r'https?://'), i)) {
        var j = i;
        while (j < n && !_ehEspaco(texto.codeUnitAt(j))) {
          j++;
        }
        // Não engole pontuação final colada ao link.
        while (j > i && '.,;:!?)]}'.contains(texto[j - 1])) {
          j--;
        }
        zonas.add(Intervalo(i, j));
        i = j;
        inicioLinha = false;
        continue;
      }

      inicioLinha = c == '\n';
      i++;
    }

    zonas.sort((a, b) => a.inicio.compareTo(b.inicio));
    return MascaraCodigo._(zonas);
  }

  static int _contarRepetido(String s, int i, String ch) {
    var n = 0;
    while (i + n < s.length && s[i + n] == ch) {
      n++;
    }
    return n;
  }

  static int _fimDaLinha(String s, int i) {
    final j = s.indexOf('\n', i);
    return j < 0 ? s.length : j;
  }

  /// Procura a linha de fechamento da cerca a partir de [de].
  static int _acharFechamentoCerca(String s, int de, String marcador) {
    var i = de;
    while (i < s.length) {
      final fimLinha = _fimDaLinha(s, i + 1);
      final linha = s.substring(i + 1 > s.length ? s.length : i + 1, fimLinha).trim();
      if (linha.startsWith(marcador)) return fimLinha;
      if (fimLinha >= s.length) return s.length;
      i = fimLinha;
    }
    return s.length;
  }

  static bool _ehEspaco(int code) =>
      code == 32 || code == 9 || code == 10 || code == 13;
}
