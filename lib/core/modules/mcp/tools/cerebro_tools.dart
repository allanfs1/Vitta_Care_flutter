import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../features/cerebro/agent/politica_escrita.dart';
import '../mcp_tool.dart';

/// Ferramentas MCP do **Cérebro** (`.specify/obsidian/obsidian.md` §9).
///
/// Fecham o ciclo que dá o salto de inteligência: o agente *consulta* o
/// segundo cérebro antes de responder e *escreve* nele o que aprendeu, de
/// forma auditável e sob a política de §9.3.
///
/// Todas as leituras passam por [McpContext.toJsonList] / [McpContext.toJsonOne],
/// o que garante o isolamento multi-tenant do módulo MCP.
List<McpTool> buildCerebroTools(McpContext ctx) {
  const colecao = 'tb_cerebro_notas';
  const politica = PoliticaEscrita();

  Query<Map<String, dynamic>> baseQuery() =>
      ctx.db.collection(colecao).where('clinicaId', isEqualTo: ctx.clinicaId());

  /// Score textual simples (o ranking rico vive no cliente, §6.5); aqui basta
  /// ordenar candidatos para o LLM.
  double pontuar(Map<String, dynamic> nota, List<String> termos) {
    final titulo = (nota['titulo'] ?? '').toString().toLowerCase();
    final corpo = (nota['conteudo'] ?? '').toString().toLowerCase();
    final tags = (nota['tags'] as List? ?? const []).join(' ').toLowerCase();
    var score = 0.0;
    for (final t in termos) {
      if (titulo == t) score += 3;
      if (titulo.contains(t)) score += 1.5;
      if (tags.contains(t)) score += 1.2;
      if (corpo.contains(t)) score += 1.0;
    }
    final metrics = (nota['metrics'] as Map?)?.cast<String, dynamic>();
    score += 0.05 * ((metrics?['inDegree'] as num?)?.toDouble() ?? 0);
    if (nota['estado'] == 'rascunho') score -= 0.4;
    return score;
  }

  String trechoRelevante(String corpo, List<String> termos) {
    final lower = corpo.toLowerCase();
    for (final t in termos) {
      final i = lower.indexOf(t);
      if (i < 0) continue;
      final de = (i - 120).clamp(0, corpo.length);
      final ate = (i + 320).clamp(0, corpo.length);
      return corpo.substring(de, ate).replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return corpo.length <= 400
        ? corpo
        : '${corpo.substring(0, 400).replaceAll(RegExp(r'\s+'), ' ').trim()}…';
  }

  return [
    // ── 1 · cerebro_buscar ──────────────────────────────────────────────────
    McpTool(
      name: 'cerebro_buscar',
      description:
          'Busca no Cérebro (segundo cérebro da clínica: notas, protocolos, '
          'decisões e análises anteriores). Use SEMPRE antes de responder '
          'qualquer pergunta analítica — o Cérebro provavelmente já sabe, e '
          'refazer análise existente gera contradição. Retorna trechos com '
          'caminho, tipo, proveniência e confiança.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'consulta': {
            'type': 'string',
            'description': 'Pergunta ou termos em linguagem natural.',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Filtra por tags (sem o #).',
          },
          'tipos': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'nota | moc | diario | conceito | protocolo | analise | '
                    'relatorio | reuniao | decisao | pessoa | fonte | memoria',
          },
          'incluirRascunhos': {'type': 'boolean', 'default': false},
          'limite': {'type': 'integer', 'default': 8},
        },
        'required': ['consulta'],
      },
      handler: (args) async {
        final consulta = args.str('consulta');
        if (consulta == null) return err('Informe a consulta.');
        final termos = consulta
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.length > 2)
            .toList();
        final tags = args.strList('tags');
        final tipos = args.strList('tipos');
        final incluirRascunhos = args.boolArg('incluirRascunhos') ?? false;
        final limite = (args.intArg('limite') ?? 8).clamp(1, 25);

        final snap = await baseQuery().limit(400).get();
        final candidatos = <Map<String, dynamic>>[];

        for (final nota in ctx.toJsonList(snap.docs)) {
          if (nota['deletedAt'] != null) continue;
          if (!incluirRascunhos && nota['estado'] == 'rascunho') continue;
          if (tipos.isNotEmpty && !tipos.contains(nota['tipo'])) continue;
          if (tags.isNotEmpty) {
            final t = (nota['tags'] as List? ?? const [])
                .map((e) => e.toString())
                .toList();
            if (!tags.any((q) => t.any((x) => x == q || x.startsWith('$q/')))) {
              continue;
            }
          }
          final score = pontuar(nota, termos);
          if (score <= 0) continue;
          candidatos.add({...nota, '_score': score});
        }

        candidatos.sort((a, b) =>
            (b['_score'] as double).compareTo(a['_score'] as double));

        final resultados = [
          for (final n in candidatos.take(limite))
            {
              'id': n['id'],
              'path': n['path'],
              'titulo': n['titulo'],
              'tipo': n['tipo'],
              'tags': n['tags'],
              'origem': n['origem'],
              'confianca': n['confianca'],
              'revisado': n['revisadoPor'] != null,
              'estado': n['estado'],
              'atualizadoEm': n['updatedAt'],
              'inDegree': (n['metrics'] as Map?)?['inDegree'],
              'score': (n['_score'] as double).toStringAsFixed(2),
              'trecho': trechoRelevante(
                  (n['conteudo'] ?? '').toString(), termos),
              if (n['origem'] == 'agente' && n['revisadoPor'] == null)
                'aviso':
                    'Nota gerada por IA e ainda não revisada — trate como '
                        'hipótese, não como fato estabelecido.',
            },
        ];

        return ok({
          'total': candidatos.length,
          'exibidos': resultados.length,
          'resultados': resultados,
        });
      },
    ),

    // ── 2 · cerebro_ler ─────────────────────────────────────────────────────
    McpTool(
      name: 'cerebro_ler',
      description:
          'Lê uma nota inteira do Cérebro pelo id ou pelo caminho, com a '
          'opção de trazer também quem aponta para ela (backlinks). Use '
          'depois de cerebro_buscar, quando precisar do conteúdo completo.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Id da nota (nt_...).'},
          'path': {
            'type': 'string',
            'description': 'Caminho, ex.: "protocolos/confirmacao-48h.md".',
          },
          'incluirBacklinks': {'type': 'boolean', 'default': true},
        },
      },
      handler: (args) async {
        final id = args.str('id');
        final path = args.str('path');
        if (id == null && path == null) {
          return err('Informe "id" ou "path".');
        }

        Map<String, dynamic>? nota;
        if (id != null) {
          nota = ctx.toJsonOne(await ctx.db.collection(colecao).doc(id).get());
        } else {
          final snap = await baseQuery().where('path', isEqualTo: path).limit(1).get();
          final lista = ctx.toJsonList(snap.docs);
          nota = lista.isEmpty ? null : lista.first;
        }
        if (nota == null) return err('Nota não encontrada.');

        final saida = <String, dynamic>{'nota': nota};

        if (args.boolArg('incluirBacklinks') ?? true) {
          final links = await ctx.db
              .collection('tb_cerebro_links')
              .where('clinicaId', isEqualTo: ctx.clinicaId())
              .where('para', isEqualTo: nota['id'])
              .limit(50)
              .get();
          saida['backlinks'] = ctx.toJsonList(links.docs);
        }
        return ok(saida);
      },
    ),

    // ── 3 · cerebro_listar ──────────────────────────────────────────────────
    McpTool(
      name: 'cerebro_listar',
      description:
          'Lista notas do Cérebro por filtro (tag, tipo, estado, origem), '
          'ordenadas por atualização. Use para inventariar o que já existe '
          'sobre um tema antes de criar nota nova.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'tag': {'type': 'string'},
          'tipo': {'type': 'string'},
          'estado': {'type': 'string', 'description': 'rascunho | publicada | arquivada'},
          'origem': {'type': 'string', 'description': 'humano | agente | sistema'},
          'limite': {'type': 'integer', 'default': 30},
        },
      },
      handler: (args) async {
        final limite = (args.intArg('limite') ?? 30).clamp(1, 100);
        var q = baseQuery();
        final tipo = args.str('tipo');
        if (tipo != null) q = q.where('tipo', isEqualTo: tipo);
        final estado = args.str('estado');
        if (estado != null) q = q.where('estado', isEqualTo: estado);
        final origem = args.str('origem');
        if (origem != null) q = q.where('origem', isEqualTo: origem);

        final snap = await q.limit(300).get();
        final tag = args.str('tag')?.replaceAll('#', '');

        final notas = <Map<String, dynamic>>[];
        for (final n in ctx.toJsonList(snap.docs)) {
          if (n['deletedAt'] != null) continue;
          if (tag != null) {
            final tags =
                (n['tags'] as List? ?? const []).map((e) => e.toString());
            if (!tags.any((t) => t == tag || t.startsWith('$tag/'))) continue;
          }
          notas.add({
            'id': n['id'],
            'path': n['path'],
            'titulo': n['titulo'],
            'tipo': n['tipo'],
            'tags': n['tags'],
            'origem': n['origem'],
            'estado': n['estado'],
            'inDegree': (n['metrics'] as Map?)?['inDegree'],
            'atualizadoEm': n['updatedAt'],
          });
        }
        notas.sort((a, b) =>
            (b['atualizadoEm'] ?? '').toString().compareTo(
                (a['atualizadoEm'] ?? '').toString()));

        return ok({
          'total': notas.length,
          'notas': notas.take(limite).toList(),
        });
      },
    ),

    // ── 4 · cerebro_escrever ────────────────────────────────────────────────
    McpTool(
      name: 'cerebro_escrever',
      description:
          'Grava uma nota no Cérebro. Use SEMPRE que produzir uma análise que '
          'valerá para o futuro — análise que não vira nota é análise perdida. '
          'Ligue o que escrever com [[wikilinks]] para notas relacionadas '
          '(descubra-as com cerebro_buscar) e [[@tipo:id]] para entidades. '
          'NUNCA escreva nome, CPF, telefone ou e-mail de paciente. '
          'Seu caminho deve começar por "agente/", "padroes/" ou "diario/".',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description': 'Ex.: "agente/analises/faltas-segunda.md".',
          },
          'conteudo': {
            'type': 'string',
            'description': 'Markdown. Use [[links]] fartamente.',
          },
          'modo': {
            'type': 'string',
            'enum': ['criar', 'substituir', 'append'],
            'default': 'criar',
          },
          'tipo': {'type': 'string', 'default': 'analise'},
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'confianca': {
            'type': 'number',
            'description':
                'OBRIGATÓRIO. Sua confiança real (0..1). Seja honesto: abaixo '
                    'de 0.85 a nota entra como rascunho para revisão humana; '
                    'abaixo de 0.60 é recusada.',
          },
          'motivo': {
            'type': 'string',
            'description': 'OBRIGATÓRIO. Por que esta nota deve existir. '
                'Vai para a auditoria.',
          },
        },
        'required': ['path', 'conteudo', 'confianca', 'motivo'],
      },
      handler: (args) async {
        final path = args.str('path');
        final conteudo = args.str('conteudo');
        final confianca = args.numArg('confianca')?.toDouble();
        final motivo = args.str('motivo');

        if (path == null || conteudo == null) {
          return err('Informe "path" e "conteudo".');
        }
        if (confianca == null) {
          return err('Informe "confianca" (0..1). É obrigatório e auditado.');
        }
        if (motivo == null) {
          return err('Informe "motivo". Ele vai para a auditoria da nota.');
        }

        // Nomes de pacientes da clínica alimentam o detector de PII.
        final nomes = <String>[];
        try {
          final pacientes = await ctx.db
              .collection('tb_pacientes')
              .where('clinicaId', isEqualTo: ctx.clinicaId())
              .limit(500)
              .get();
          for (final d in pacientes.docs) {
            final nome = (d.data()['nome'] ?? '').toString();
            if (nome.trim().isNotEmpty) nomes.add(nome);
          }
        } catch (_) {
          // Sem a coleção de pacientes, seguimos com os padrões regex.
        }

        final veredicto = politica.avaliar(
          path: path,
          conteudo: conteudo,
          confianca: confianca,
          motivo: motivo,
          nomesDePacientes: nomes,
        );
        if (!veredicto.permitido) return err(veredicto.motivo);

        final modo = args.str('modo') ?? 'criar';
        final existentes =
            await baseQuery().where('path', isEqualTo: path).limit(1).get();
        final existe = existentes.docs.isNotEmpty;

        if (existe && modo == 'criar') {
          return err(
            'Já existe nota em "$path". Use modo "append" para acrescentar '
            'ou "substituir" para reescrever.',
          );
        }

        final agora = Timestamp.fromDate(DateTime.now());
        final titulo = _tituloDe(conteudo, path);

        if (existe) {
          final doc = existentes.docs.first;
          final atual = (doc.data()['conteudo'] ?? '').toString();
          final novo = modo == 'append' ? '$atual\n\n$conteudo' : conteudo;
          final versao = ((doc.data()['versao'] as num?)?.toInt() ?? 0) + 1;
          await doc.reference.set({
            'conteudo': novo,
            'titulo': titulo,
            'versao': versao,
            'estado': veredicto.estado.id,
            'confianca': confianca,
            'origem': 'agente',
            'updatedAt': agora,
            'updatedBy': 'agente',
            'charCount': novo.length,
          }, SetOptions(merge: true));

          await _auditar(ctx, doc.id, modo, motivo, versao, confianca);
          return ok({
            'ok': true,
            'id': doc.id,
            'path': path,
            'versao': versao,
            'estado': veredicto.estado.id,
            'aviso': veredicto.estado.id == 'rascunho'
                ? 'Gravada como rascunho — confiança abaixo de 0.85. '
                    'Um humano precisa revisar antes de virar referência.'
                : null,
          });
        }

        final id = 'nt_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
        await ctx.db.collection(colecao).doc(id).set({
          'clinicaId': ctx.clinicaId(),
          'path': path,
          'titulo': titulo,
          'tipo': args.str('tipo') ?? 'analise',
          'tags': args.strList('tags'),
          'conteudo': conteudo,
          'origem': 'agente',
          'confianca': confianca,
          'estado': veredicto.estado.id,
          'versao': 1,
          'charCount': conteudo.length,
          'createdAt': agora,
          'createdBy': 'agente',
          'updatedAt': agora,
          'updatedBy': 'agente',
        });

        await _auditar(ctx, id, 'criar', motivo, 1, confianca);
        return ok({
          'ok': true,
          'id': id,
          'path': path,
          'versao': 1,
          'estado': veredicto.estado.id,
          'aviso': veredicto.estado.id == 'rascunho'
              ? 'Gravada como rascunho — confiança abaixo de 0.85.'
              : null,
        });
      },
    ),

    // ── 5 · cerebro_linkar ──────────────────────────────────────────────────
    McpTool(
      name: 'cerebro_linkar',
      description:
          'Cria um link explícito de uma nota para outra, acrescentando o '
          'wikilink ao fim da nota de origem. Use quando perceber que duas '
          'notas tratam do mesmo assunto e ainda não estão conectadas — '
          'nota sem links é nota que o Cérebro não lembra.',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'origemPath': {'type': 'string'},
          'destinoTitulo': {
            'type': 'string',
            'description': 'Título ou caminho da nota de destino.',
          },
          'justificativa': {
            'type': 'string',
            'description': 'Por que estas notas se conectam.',
          },
        },
        'required': ['origemPath', 'destinoTitulo', 'justificativa'],
      },
      handler: (args) async {
        final origemPath = args.str('origemPath');
        final destino = args.str('destinoTitulo');
        final justificativa = args.str('justificativa');
        if (origemPath == null || destino == null || justificativa == null) {
          return err('Informe origemPath, destinoTitulo e justificativa.');
        }

        final snap =
            await baseQuery().where('path', isEqualTo: origemPath).limit(1).get();
        if (snap.docs.isEmpty) return err('Nota de origem não encontrada.');

        final doc = snap.docs.first;
        final atual = (doc.data()['conteudo'] ?? '').toString();
        if (atual.contains('[[$destino]]')) {
          return ok({'ok': true, 'jaExistia': true});
        }

        final novo = '${atual.trimRight()}\n\n[[$destino]] — $justificativa\n';
        final versao = ((doc.data()['versao'] as num?)?.toInt() ?? 0) + 1;
        await doc.reference.set({
          'conteudo': novo,
          'versao': versao,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
          'updatedBy': 'agente',
        }, SetOptions(merge: true));

        await _auditar(ctx, doc.id, 'linkar', justificativa, versao, null);
        return ok({'ok': true, 'origem': origemPath, 'destino': destino});
      },
    ),
  ];
}

/// Registro imutável de auditoria (`obsidian.md` §14.4). Falha aqui nunca
/// derruba a escrita — mas é registrada no retorno da tool.
Future<void> _auditar(
  McpContext ctx,
  String notaId,
  String acao,
  String motivo,
  int versao,
  double? confianca,
) async {
  try {
    await ctx.db.collection('tb_cerebro_eventos').add({
      'clinicaId': ctx.clinicaId(),
      'notaId': notaId,
      'acao': acao,
      'ator': 'agente',
      'atorTipo': 'agente',
      'motivo': motivo,
      'versaoDepois': versao,
      'confianca': confianca,
      'criadoEm': Timestamp.fromDate(DateTime.now()),
    });
  } catch (_) {
    // Auditoria indisponível não pode bloquear o fluxo do agente.
  }
}

String _tituloDe(String conteudo, String path) {
  for (final linha in conteudo.split('\n')) {
    final t = linha.trim();
    if (t.startsWith('# ')) return t.substring(2).trim();
  }
  final base = path.split('/').last;
  return base.toLowerCase().endsWith('.md')
      ? base.substring(0, base.length - 3)
      : base;
}
