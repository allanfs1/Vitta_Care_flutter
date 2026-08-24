import '../data/models/aresta.dart' show removerAcentos;
import '../data/models/nota.dart';

/// Campos de uma nota já em minúsculas e sem acento, prontos para comparação.
///
/// Calculado uma vez por indexação e guardado no `VaultIndex`. Antes cada
/// consulta refazia esta normalização para o vault inteiro.
class TextoBusca {
  const TextoBusca({
    required this.titulo,
    required this.arquivo,
    required this.corpo,
    required this.aliases,
    required this.tags,
  });

  const TextoBusca.vazio()
      : titulo = '',
        arquivo = '',
        corpo = '',
        aliases = const [],
        tags = const [];

  factory TextoBusca.de(Nota nota) => TextoBusca(
        titulo: removerAcentos(nota.titulo.toLowerCase()),
        arquivo: removerAcentos(nota.nomeArquivo.toLowerCase()),
        corpo: removerAcentos(nota.conteudo.toLowerCase()),
        aliases: [
          for (final a in nota.aliases) removerAcentos(a.toLowerCase()),
        ],
        tags: [for (final t in nota.tags) removerAcentos(t.toLowerCase())],
      );

  final String titulo;
  final String arquivo;
  final String corpo;
  final List<String> aliases;
  final List<String> tags;
}
