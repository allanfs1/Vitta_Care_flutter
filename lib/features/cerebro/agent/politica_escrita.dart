import '../data/models/nota_enums.dart';

/// Resultado da avaliação de uma escrita proposta pelo agente.
class VeredictoEscrita {
  const VeredictoEscrita.aprovado(this.estado)
      : permitido = true,
        motivo = '',
        padraoDetectado = '';

  const VeredictoEscrita.rejeitado(this.motivo, {this.padraoDetectado = ''})
      : permitido = false,
        estado = NotaEstado.rascunho;

  final bool permitido;
  final String motivo;
  final NotaEstado estado;

  /// Nome do padrão de PII detectado (nunca o valor em si — §15.1).
  final String padraoDetectado;
}

/// Os guardas de escrita do agente (`obsidian.md` §9.3).
///
/// Toda chamada de `cerebro_escrever` passa por aqui **antes** de tocar o
/// vault. Cada guarda existe por um motivo declarado na especificação; nenhum
/// pode ser desligado por argumento vindo do LLM.
class PoliticaEscrita {
  const PoliticaEscrita();

  /// Prefixos onde o agente pode escrever. Conhecimento normativo
  /// (`protocolos/`, `decisoes/`) é território exclusivamente humano:
  /// o agente propõe, o humano promove.
  static const prefixosPermitidos = <String>[
    'agente/',
    'diario/',
    'padroes/',
  ];

  static const double confiancaMinima = 0.60;
  static const double confiancaPublicacao = 0.85;

  /// Limite de escritas por sessão de chat (guarda 4).
  static const int maxEscritasPorSessao = 20;

  VeredictoEscrita avaliar({
    required String path,
    required String conteudo,
    required double confianca,
    required String motivo,
    Iterable<String> nomesDePacientes = const [],
  }) {
    // ── Guarda 1 · namespace ────────────────────────────────────────────────
    final p = path.trim().toLowerCase();
    if (!prefixosPermitidos.any(p.startsWith)) {
      return VeredictoEscrita.rejeitado(
        'O agente só escreve em ${prefixosPermitidos.join(", ")}. '
        'Para propor mudança em norma da clínica, escreva a proposta em '
        '"agente/" e peça revisão humana.',
      );
    }

    // ── Guarda 2 · confiança ────────────────────────────────────────────────
    if (confianca < confiancaMinima) {
      return const VeredictoEscrita.rejeitado(
        'Confiança abaixo de 0.60. Colete mais dados ou elabore melhor a '
        'análise antes de gravar no Cérebro.',
      );
    }

    // ── Guarda 3 · PII ──────────────────────────────────────────────────────
    final pii = RedatorPii.detectar(conteudo, nomesDePacientes: nomesDePacientes);
    if (pii != null) {
      return VeredictoEscrita.rejeitado(
        'Dado identificável de paciente detectado ($pii). Use '
        '[[@paciente:id]] — a interface resolve o nome para quem tem permissão.',
        padraoDetectado: pii,
      );
    }

    // ── Guarda 5 · motivo obrigatório (auditoria) ───────────────────────────
    if (motivo.trim().length < 8) {
      return const VeredictoEscrita.rejeitado(
        'Informe um motivo real para a nota existir — ele vai para a '
        'auditoria e explica a decisão para quem ler depois.',
      );
    }

    return VeredictoEscrita.aprovado(
      confianca >= confiancaPublicacao
          ? NotaEstado.publicada
          : NotaEstado.rascunho,
    );
  }
}

/// Detecção e sanitização de dado pessoal (`obsidian.md` §14.2).
///
/// É a camada 2 das 5 defesas: roda antes de qualquer escrita do agente e
/// antes de enviar texto para gerar embeddings.
class RedatorPii {
  RedatorPii._();

  static final Map<String, RegExp> padroes = {
    'CPF': RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b'),
    'CNS': RegExp(r'\b[1-2]\d{14}\b'),
    'telefone': RegExp(r'\b(?:\+55\s?)?\(?\d{2}\)?\s?9?\d{4}-?\d{4}\b'),
    'e-mail': RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]{2,}\b'),
    'RG': RegExp(r'\b\d{1,2}\.?\d{3}\.?\d{3}-?[\dxX]\b'),
    'cartão': RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
  };

  /// Devolve o nome do padrão encontrado, ou `null` se o texto está limpo.
  /// **Nunca** devolve o valor detectado — ele não pode vazar para log.
  static String? detectar(String texto,
      {Iterable<String> nomesDePacientes = const []}) {
    for (final e in padroes.entries) {
      if (e.value.hasMatch(texto)) return e.key;
    }
    final normal = _normalizar(texto);
    for (final nome in nomesDePacientes) {
      final n = _normalizar(nome);
      // Só nomes com pelo menos 2 tokens — "Ana" sozinho gera falso positivo.
      if (n.split(' ').where((t) => t.length > 2).length < 2) continue;
      if (normal.contains(n)) return 'nome de paciente';
    }
    return null;
  }

  /// Substitui PII por marcadores. Usado antes de gerar embeddings (§8.1),
  /// para que nenhum dado identificável saia da infraestrutura em vetor.
  static String sanitizar(String texto,
      {Iterable<String> nomesDePacientes = const []}) {
    var out = texto;
    padroes.forEach((nome, re) {
      out = out.replaceAll(re, '($nome removido)');
    });
    for (final nome in nomesDePacientes) {
      if (nome.trim().split(' ').where((t) => t.length > 2).length < 2) continue;
      out = out.replaceAll(
        RegExp(RegExp.escape(nome), caseSensitive: false),
        '(paciente)',
      );
    }
    // Entity-links de paciente viram rótulo genérico; médico mantém o nome.
    out = out.replaceAll(
      RegExp(r'\[\[@paciente:[^\]|]+(\|[^\]]+)?\]\]'),
      '(paciente)',
    );
    return out;
  }

  static String _normalizar(String s) {
    const com = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const sem = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final ch = String.fromCharCode(r);
      final i = com.indexOf(ch);
      b.write(i >= 0 ? sem[i] : ch);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ');
  }
}
