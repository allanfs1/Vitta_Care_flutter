/// Separação e leitura do frontmatter YAML (`obsidian.md` §5.1).
///
/// Implementa um subconjunto deliberado de YAML — o suficiente para o
/// frontmatter de notas — sem adicionar dependência externa ao projeto:
///   - `chave: valor`
///   - `chave: [a, b, c]`      (lista inline)
///   - `chave:` + `  - item`   (lista em bloco)
///   - aspas simples/duplas, números, booleanos, datas ISO
///   - comentários iniciados por `#` fora de aspas
class FrontmatterResultado {
  const FrontmatterResultado({
    required this.dados,
    required this.corpo,
    required this.linhasConsumidas,
  });

  final Map<String, dynamic> dados;

  /// Texto sem o bloco de frontmatter.
  final String corpo;

  /// Quantas linhas o frontmatter ocupou — usado para reportar números de
  /// linha corretos ao usuário (o parser trabalha sobre [corpo]).
  final int linhasConsumidas;

  static const vazio =
      FrontmatterResultado(dados: {}, corpo: '', linhasConsumidas: 0);
}

class Frontmatter {
  Frontmatter._();

  /// Separa o frontmatter do corpo. Se não houver `---` na primeira linha,
  /// devolve o texto intacto.
  static FrontmatterResultado separar(String texto) {
    if (!texto.startsWith('---')) {
      return FrontmatterResultado(dados: const {}, corpo: texto, linhasConsumidas: 0);
    }
    final primeiraQuebra = texto.indexOf('\n');
    if (primeiraQuebra < 0) {
      return FrontmatterResultado(dados: const {}, corpo: texto, linhasConsumidas: 0);
    }
    // A primeira linha precisa ser exatamente `---`.
    if (texto.substring(0, primeiraQuebra).trim() != '---') {
      return FrontmatterResultado(dados: const {}, corpo: texto, linhasConsumidas: 0);
    }

    final linhas = texto.split('\n');
    var fim = -1;
    for (var i = 1; i < linhas.length; i++) {
      final t = linhas[i].trim();
      if (t == '---' || t == '...') {
        fim = i;
        break;
      }
    }
    // Frontmatter não fechado: trata tudo como corpo (tolerante a erro).
    if (fim < 0) {
      return FrontmatterResultado(dados: const {}, corpo: texto, linhasConsumidas: 0);
    }

    final dados = _parse(linhas.sublist(1, fim));
    final corpo = linhas.sublist(fim + 1).join('\n');
    return FrontmatterResultado(
      dados: dados,
      corpo: corpo,
      linhasConsumidas: fim + 1,
    );
  }

  /// Reconstrói o texto completo (frontmatter + corpo). Chaves com valor nulo
  /// ou lista vazia são omitidas.
  static String montar(Map<String, dynamic> dados, String corpo) {
    if (dados.isEmpty) return corpo;
    final b = StringBuffer('---\n');
    dados.forEach((k, v) {
      if (v == null) return;
      if (v is List) {
        if (v.isEmpty) return;
        b.writeln('$k: [${v.map(_serializar).join(', ')}]');
      } else {
        b.writeln('$k: ${_serializar(v)}');
      }
    });
    b.write('---\n');
    b.write(corpo);
    return b.toString();
  }

  static String _serializar(Object? v) {
    if (v is num || v is bool) return v.toString();
    final s = v.toString();
    final precisaAspas = s.contains(RegExp(r'[:#\[\]{},]')) || s.trim() != s;
    return precisaAspas ? '"${s.replaceAll('"', r'\"')}"' : s;
  }

  static Map<String, dynamic> _parse(List<String> linhas) {
    final out = <String, dynamic>{};
    String? chaveLista;
    List<dynamic>? listaAtual;

    void fecharLista() {
      if (chaveLista != null) {
        out[chaveLista!] = listaAtual ?? const [];
        chaveLista = null;
        listaAtual = null;
      }
    }

    for (final linhaBruta in linhas) {
      final linha = _semComentario(linhaBruta);
      if (linha.trim().isEmpty) continue;

      // Item de lista em bloco: "  - valor"
      final itemLista = RegExp(r'^\s*-\s+(.*)$').firstMatch(linha);
      if (itemLista != null && chaveLista != null) {
        (listaAtual ??= <dynamic>[]).add(_valor(itemLista.group(1)!.trim()));
        continue;
      }

      final sep = linha.indexOf(':');
      if (sep <= 0) continue;

      fecharLista();

      final chave = linha.substring(0, sep).trim();
      final resto = linha.substring(sep + 1).trim();
      if (chave.isEmpty) continue;

      if (resto.isEmpty) {
        // Pode ser abertura de lista em bloco.
        chaveLista = chave;
        listaAtual = null;
        continue;
      }

      if (resto.startsWith('[') && resto.endsWith(']')) {
        final interno = resto.substring(1, resto.length - 1);
        out[chave] = interno.trim().isEmpty
            ? const <dynamic>[]
            : [
                for (final p in _dividirRespeitandoAspas(interno))
                  _valor(p.trim()),
              ];
        continue;
      }

      out[chave] = _valor(resto);
    }
    fecharLista();
    return out;
  }

  static String _semComentario(String linha) {
    var emAspasS = false;
    var emAspasD = false;
    for (var i = 0; i < linha.length; i++) {
      final c = linha[i];
      if (c == "'" && !emAspasD) emAspasS = !emAspasS;
      if (c == '"' && !emAspasS) emAspasD = !emAspasD;
      if (c == '#' && !emAspasS && !emAspasD) {
        // Só é comentário se precedido de espaço (ou início da linha).
        if (i == 0 || linha[i - 1] == ' ') return linha.substring(0, i);
      }
    }
    return linha;
  }

  static List<String> _dividirRespeitandoAspas(String s) {
    final partes = <String>[];
    final b = StringBuffer();
    var emAspasS = false;
    var emAspasD = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == "'" && !emAspasD) emAspasS = !emAspasS;
      if (c == '"' && !emAspasS) emAspasD = !emAspasD;
      if (c == ',' && !emAspasS && !emAspasD) {
        partes.add(b.toString());
        b.clear();
        continue;
      }
      b.write(c);
    }
    if (b.isNotEmpty) partes.add(b.toString());
    return partes;
  }

  static Object? _valor(String bruto) {
    if (bruto.isEmpty) return '';
    if ((bruto.startsWith('"') && bruto.endsWith('"') && bruto.length > 1) ||
        (bruto.startsWith("'") && bruto.endsWith("'") && bruto.length > 1)) {
      return bruto.substring(1, bruto.length - 1);
    }
    final lower = bruto.toLowerCase();
    if (lower == 'true' || lower == 'yes') return true;
    if (lower == 'false' || lower == 'no') return false;
    if (lower == 'null' || lower == '~') return null;
    final i = int.tryParse(bruto);
    if (i != null) return i;
    final d = double.tryParse(bruto);
    if (d != null) return d;
    return bruto;
  }
}
