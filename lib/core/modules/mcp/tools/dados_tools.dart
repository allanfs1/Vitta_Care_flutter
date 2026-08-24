import 'package:cloud_firestore/cloud_firestore.dart';
import '../mcp_tool.dart';

/// Ferramentas MCP para Tickets, E-mails/Logs, Relatórios, Histórico,
/// Consulta Genérica e Tarefas Agendadas (§6.8–§6.11 e §6.18).
///
/// Expose via:
/// ```dart
/// final tools = buildDadosTools(ctx);
/// ```
List<McpTool> buildDadosTools(McpContext ctx) {
  return [
    // ── §6.8 Tickets de suporte ───────────────────────────────────────────

    McpTool(
      name: 'listar_tickets',
      description:
          'Lista tickets de suporte da coleção "tickets". '
          'Permite filtrar por status, prioridade, fila e responsável. '
          'A filtragem é feita em memória para evitar índices compostos.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'description': 'Filtra pelo status do ticket (ex.: aberto, fechado, em_andamento).',
          },
          'prioridade': {
            'type': 'string',
            'description': 'Filtra pela prioridade do ticket (ex.: alta, media, baixa).',
          },
          'fila': {
            'type': 'string',
            'description': 'Filtra pela fila de atendimento do ticket.',
          },
          'responsavel': {
            'type': 'string',
            'description': 'Filtra pelo responsável atribuído ao ticket.',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de tickets a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final status = args.str('status');
          final prioridade = args.str('prioridade');
          final fila = args.str('fila');
          final responsavel = args.str('responsavel');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('tickets').get();

          final docs = snap.docs.where((d) {
            final data = d.data();
            if (status != null && data['status'] != status) return false;
            if (prioridade != null && data['prioridade'] != prioridade) return false;
            if (fila != null && data['fila'] != fila) return false;
            if (responsavel != null && data['responsavel'] != responsavel) return false;
            return true;
          }).take(limite).toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'buscar_ticket',
      description:
          'Busca um ticket de suporte pelo seu ID (documento Firestore na coleção "tickets"). '
          'Retorna todos os dados do ticket ou erro se não for encontrado.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'ID do documento do ticket na coleção tickets.',
          },
        },
        'required': ['id'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final id = args.str('id');
          if (id == null || id.isEmpty) {
            return err('O argumento "id" é obrigatório.');
          }

          final snap = await ctx.db.collection('tickets').doc(id).get();
          final data = ctx.toJsonOne(snap);
          if (data == null) {
            return err('ticket não encontrado');
          }
          return ok(data);
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── §6.9 E-mails / Notificações ───────────────────────────────────────

    McpTool(
      name: 'listar_email_logs',
      description:
          'Lista o log de e-mails enviados da coleção "email_logs". '
          'Pode filtrar pelo tipo de e-mail (ex.: confirmacao, lembrete, overbooking).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tipo': {
            'type': 'string',
            'description': 'Filtra pelo tipo de e-mail (ex.: confirmacao, lembrete, relatorio).',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de registros a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final tipo = args.str('tipo');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('email_logs').get();

          final docs = snap.docs.where((d) {
            if (tipo != null && d.data()['tipo'] != tipo) return false;
            return true;
          }).take(limite).toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_email_queue',
      description:
          'Lista a fila de e-mails pendentes da coleção "email_queue". '
          'Pode filtrar pelo status da mensagem (ex.: pending, sent, failed).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'description': 'Filtra pelo status da mensagem na fila (ex.: pending, sent, failed).',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de registros a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final status = args.str('status');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('email_queue').get();

          final docs = snap.docs.where((d) {
            if (status != null && d.data()['status'] != status) return false;
            return true;
          }).take(limite).toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_lembretes',
      description:
          'Lista o controle de lembretes da coleção "tb_lembrete_controle". '
          'Pode filtrar pelo último status registrado.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'ultimoStatus': {
            'type': 'string',
            'description': 'Filtra pelo último status do lembrete (ex.: enviado, pendente, erro).',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de registros a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final ultimoStatus = args.str('ultimoStatus');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('tb_lembrete_controle').get();

          final docs = snap.docs.where((d) {
            if (ultimoStatus != null && d.data()['ultimoStatus'] != ultimoStatus) return false;
            return true;
          }).take(limite).toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── §6.10 Relatórios e histórico ──────────────────────────────────────

    McpTool(
      name: 'listar_relatorios_ia',
      description:
          'Lista relatórios gerados pela IA da coleção "tb_relatorio_ia". '
          'Pode filtrar pelo tipo de relatório.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'tipoRelatorio': {
            'type': 'string',
            'description': 'Filtra pelo tipo de relatório (ex.: absenteismo, overbooking, geral).',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de registros a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final tipoRelatorio = args.str('tipoRelatorio');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('tb_relatorio_ia').get();

          final docs = snap.docs.where((d) {
            if (tipoRelatorio != null && d.data()['tipoRelatorio'] != tipoRelatorio) return false;
            return true;
          }).take(limite).toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_historico_confirmacoes',
      description:
          'Lista o histórico de confirmações da coleção "tb_confirmationHistory". '
          'Pode filtrar pela ação realizada.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'description': 'Filtra pela ação realizada (ex.: confirmado, cancelado, reagendado).',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de registros a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final action = args.str('action');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('tb_confirmationHistory').get();

          final docs = snap.docs.where((d) {
            if (action != null && d.data()['action'] != action) return false;
            return true;
          }).take(limite).toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_historico_clinica',
      description:
          'Lista o histórico geral da agenda clínica da coleção "historico_agenda_clinica".',
      inputSchema: {
        'type': 'object',
        'properties': {
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de registros a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('historico_agenda_clinica').limit(limite).get();

          return ok(ctx.toJsonList(snap.docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_filas',
      description:
          'Lista as filas de atendimento da coleção "queues".',
      inputSchema: {
        'type': 'object',
        'properties': {
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de filas a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('queues').limit(limite).get();

          return ok(ctx.toJsonList(snap.docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_avisos',
      description:
          'Lista avisos do sistema da coleção "notices". '
          'Pode filtrar por avisos ativos ou inativos.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'ativo': {
            'type': 'boolean',
            'description': 'Se verdadeiro, retorna apenas avisos ativos; se falso, apenas inativos.',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de avisos a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final ativo = args.boolArg('ativo');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('notices').get();

          final docs = snap.docs.where((d) {
            if (ativo != null && d.data()['ativo'] != ativo) return false;
            return true;
          }).take(limite).toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── §6.11 Consulta genérica ───────────────────────────────────────────

    McpTool(
      name: 'consultar_colecao',
      description:
          'Consulta genérica de qualquer coleção Firestore. '
          'Se "campo" e "valor" forem fornecidos, aplica um filtro de igualdade (where campo == valor). '
          'Útil como fallback para coleções não cobertas pelas ferramentas específicas. '
          'Por isolamento multi-tenant, retorna SOMENTE documentos que pertencem '
          'à clínica do usuário logado (que carregam o campo de clínica correspondente).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'colecao': {
            'type': 'string',
            'description': 'Nome da coleção Firestore a consultar.',
          },
          'campo': {
            'type': 'string',
            'description': 'Campo pelo qual filtrar (opcional).',
          },
          'valor': {
            'type': 'string',
            'description': 'Valor do campo a filtrar (comparado como string; opcional).',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de documentos a retornar (padrão: 50).',
          },
        },
        'required': ['colecao'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final colecao = args.str('colecao');
          if (colecao == null || colecao.isEmpty) {
            return err('O argumento "colecao" é obrigatório.');
          }

          final campo = args.str('campo');
          final valor = args.str('valor');
          final limite = ctx.limit(args.intArg('limite') ?? 50);

          QuerySnapshot<Map<String, dynamic>> snap;
          if (campo != null && campo.isNotEmpty && valor != null) {
            snap = await ctx.db
                .collection(colecao)
                .where(campo, isEqualTo: valor)
                .get();
          } else {
            snap = await ctx.db.collection(colecao).get();
          }

          // Isolamento estrito: para a consulta genérica, mantém apenas os
          // documentos que comprovadamente pertencem à clínica do usuário
          // (carregam idClinica/idclinica/... = clínica do contexto) ou o
          // próprio documento da clínica.
          final ownClinic = ctx.clinicaId();
          final docs = snap.docs
              .where((d) =>
                  d.id == ownClinic || ctx.belongsToClinic(d.data()))
              .take(limite)
              .toList();

          if (docs.isEmpty) {
            return ok({
              'colecao': colecao,
              'resultados': <Map<String, dynamic>>[],
              'nota':
                  'Nenhum documento desta coleção pertence à clínica do usuário '
                  '(isolamento multi-tenant) ou a coleção não possui campo de clínica.',
            });
          }
          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── §6.18 Tarefas agendadas ───────────────────────────────────────────

    McpTool(
      name: 'agendar_tarefa',
      description:
          'Cria uma tarefa agendada futura ou recorrente na coleção "tb_scheduled_tasks". '
          'O campo "prompt" é a instrução em linguagem natural que será executada na hora marcada. '
          '"tipoTarefa": "acao" → kind "action"; "relatorio" → kind "report" '
          '(relatórios são salvos e enviados por e-mail). '
          'Aceita recorrência: once / interval / daily / weekly / monthly. '
          '"horario" no formato HH:MM (horário de Brasília). '
          '"dataOnce" aceita dd/MM/yyyy HH:mm ou formato ISO.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'titulo': {
            'type': 'string',
            'description': 'Título descritivo da tarefa agendada.',
          },
          'prompt': {
            'type': 'string',
            'description':
                'Instrução em linguagem natural que será executada pelo agente no horário marcado.',
          },
          'tipoTarefa': {
            'type': 'string',
            'enum': ['acao', 'relatorio'],
            'description':
                'Tipo da tarefa: "acao" (execução de ação, padrão) ou "relatorio" '
                '(gera relatório que é salvo e enviado por e-mail).',
          },
          'recorrencia': {
            'type': 'string',
            'enum': ['once', 'interval', 'daily', 'weekly', 'monthly'],
            'description':
                'Frequência de execução: once (única, padrão), interval, daily, weekly, monthly.',
          },
          'horario': {
            'type': 'string',
            'description': 'Horário de execução no formato HH:MM (horário de Brasília).',
          },
          'diasSemana': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Dias da semana para execução (ex.: ["segunda","quarta","sexta"]). '
                'Usado com recorrência weekly.',
          },
          'diaDoMes': {
            'type': 'integer',
            'description':
                'Dia do mês para execução (1–31). Usado com recorrência monthly.',
          },
          'intervaloMinutos': {
            'type': 'integer',
            'description':
                'Intervalo em minutos entre execuções. Usado com recorrência interval.',
          },
          'dataOnce': {
            'type': 'string',
            'description':
                'Data/hora de execução única no formato dd/MM/yyyy HH:mm ou ISO 8601. '
                'Usado com recorrência once.',
          },
          'notifyEmail': {
            'type': 'string',
            'description': 'E-mail para notificação após a execução da tarefa (opcional).',
          },
          'clinicaId': {
            'type': 'string',
            'description': 'ID da clínica. Se omitido, usa a clínica padrão do contexto.',
          },
        },
        'required': ['titulo', 'prompt'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final titulo = args.str('titulo');
          if (titulo == null || titulo.isEmpty) {
            return err('O argumento "titulo" é obrigatório.');
          }

          final prompt = args.str('prompt');
          if (prompt == null || prompt.isEmpty) {
            return err('O argumento "prompt" é obrigatório.');
          }

          final tipoTarefaRaw = args.str('tipoTarefa') ?? 'acao';
          final kind = tipoTarefaRaw == 'relatorio' ? 'report' : 'action';

          final recorrencia = args.str('recorrencia') ?? 'once';
          final horario = args.str('horario');
          final diasSemana = args.strList('diasSemana');
          final diaDoMes = args.intArg('diaDoMes');
          final intervaloMinutos = args.intArg('intervaloMinutos');
          final dataOnceRaw = args.str('dataOnce');
          final notifyEmail = args.str('notifyEmail');
          final clinicaId = ctx.clinicaId(args.str('clinicaId'));

          // Parse flexible date: accepts dd/MM/yyyy HH:mm or ISO 8601.
          DateTime? parsedDataOnce;
          if (dataOnceRaw != null && dataOnceRaw.isNotEmpty) {
            parsedDataOnce = _parseFlexibleDate(dataOnceRaw);
          }

          // Compute a best-effort nextRunAt timestamp.
          final now = DateTime.now();
          Timestamp nextRunAt;
          switch (recorrencia) {
            case 'once':
              nextRunAt = parsedDataOnce != null
                  ? Timestamp.fromDate(parsedDataOnce)
                  : _computeNextRunFromHorario(horario, now);
              break;
            case 'daily':
              nextRunAt = _computeNextRunFromHorario(horario, now);
              break;
            case 'weekly':
              nextRunAt = _computeNextRunFromHorario(horario, now);
              break;
            case 'monthly':
              nextRunAt = _computeNextRunFromHorario(horario, now,
                  targetDay: diaDoMes);
              break;
            case 'interval':
              final minutes = intervaloMinutos ?? 60;
              nextRunAt = Timestamp.fromDate(now.add(Duration(minutes: minutes)));
              break;
            default:
              nextRunAt = parsedDataOnce != null
                  ? Timestamp.fromDate(parsedDataOnce)
                  : Timestamp.fromDate(now.add(const Duration(hours: 1)));
          }

          final schedule = <String, dynamic>{
            'recorrencia': recorrencia,
          };
          if (horario != null) schedule['horario'] = horario;
          if (diasSemana.isNotEmpty) schedule['diasSemana'] = diasSemana;
          if (diaDoMes != null) schedule['diaDoMes'] = diaDoMes;
          if (intervaloMinutos != null) schedule['intervaloMinutos'] = intervaloMinutos;
          if (parsedDataOnce != null) schedule['dataOnce'] = parsedDataOnce.toIso8601String();

          final docData = <String, dynamic>{
            'titulo': titulo,
            'prompt': prompt,
            'kind': kind,
            'schedule': schedule,
            'status': 'active',
            'runCount': 0,
            'errorCount': 0,
            'clinicaId': clinicaId,
            'createdAt': FieldValue.serverTimestamp(),
            'nextRunAt': nextRunAt,
          };
          if (notifyEmail != null) docData['notifyEmail'] = notifyEmail;

          final ref = await ctx.db.collection('tb_scheduled_tasks').add(docData);

          return ok({
            'id': ref.id,
            'titulo': titulo,
            'kind': kind,
            'recorrencia': recorrencia,
            'status': 'active',
            'nextRunAt': nextRunAt.toDate().toIso8601String(),
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_tarefas_agendadas',
      description:
          'Lista as tarefas agendadas da coleção "tb_scheduled_tasks". '
          'Pode filtrar por status e clinicaId. Ordena por data de criação decrescente.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'description': 'Filtra pelo status da tarefa (ex.: active, paused, cancelled).',
          },
          'clinicaId': {
            'type': 'string',
            'description': 'Filtra pela clínica. Se omitido, usa a clínica padrão do contexto.',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de tarefas a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final status = args.str('status');
          final clinicaId = ctx.clinicaId(args.str('clinicaId'));
          final limite = ctx.limit(args.intArg('limite'));

          // Single-field server query; filter/sort in memory.
          final snap = await ctx.db
              .collection('tb_scheduled_tasks')
              .where('clinicaId', isEqualTo: clinicaId)
              .get();

          var docs = snap.docs.where((d) {
            if (status != null && d.data()['status'] != status) return false;
            return true;
          }).toList();

          // Sort by createdAt descending (in memory).
          docs.sort((a, b) {
            final aVal = a.data()['createdAt'];
            final bVal = b.data()['createdAt'];
            if (aVal is Timestamp && bVal is Timestamp) {
              return bVal.compareTo(aVal);
            }
            return 0;
          });

          return ok(ctx.toJsonList(docs.take(limite).toList()));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'pausar_retomar_tarefa',
      description:
          'Pausa ou retoma uma tarefa agendada na coleção "tb_scheduled_tasks". '
          '"acao": "pausar" define status como "paused"; "retomar" define como "active".',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'ID do documento da tarefa agendada.',
          },
          'acao': {
            'type': 'string',
            'enum': ['pausar', 'retomar'],
            'description': '"pausar" suspende a tarefa; "retomar" reativa a tarefa.',
          },
        },
        'required': ['id', 'acao'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final id = args.str('id');
          if (id == null || id.isEmpty) {
            return err('O argumento "id" é obrigatório.');
          }

          final acao = args.str('acao');
          if (acao == null || (acao != 'pausar' && acao != 'retomar')) {
            return err('O argumento "acao" deve ser "pausar" ou "retomar".');
          }

          final novoStatus = acao == 'pausar' ? 'paused' : 'active';

          await ctx.db.collection('tb_scheduled_tasks').doc(id).update({
            'status': novoStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return ok({'id': id, 'status': novoStatus});
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'cancelar_tarefa_agendada',
      description:
          'Exclui permanentemente uma tarefa agendada da coleção "tb_scheduled_tasks". '
          'Esta ação não pode ser desfeita.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'ID do documento da tarefa agendada a excluir.',
          },
        },
        'required': ['id'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final id = args.str('id');
          if (id == null || id.isEmpty) {
            return err('O argumento "id" é obrigatório.');
          }

          await ctx.db.collection('tb_scheduled_tasks').doc(id).delete();

          return ok({'id': id, 'cancelada': true});
        } catch (e) {
          return err(e.toString());
        }
      },
    ),
  ];
}

// ── Helpers privados ──────────────────────────────────────────────────────────

/// Tenta interpretar uma data nos formatos dd/MM/yyyy [HH:mm] ou ISO 8601.
DateTime? _parseFlexibleDate(String raw) {
  final trimmed = raw.trim();

  // Tenta formato dd/MM/yyyy HH:mm ou dd/MM/yyyy.
  final brRegex = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4})(?:\s+(\d{2}):(\d{2}))?$');
  final brMatch = brRegex.firstMatch(trimmed);
  if (brMatch != null) {
    final day = int.parse(brMatch.group(1)!);
    final month = int.parse(brMatch.group(2)!);
    final year = int.parse(brMatch.group(3)!);
    final hour = brMatch.group(4) != null ? int.parse(brMatch.group(4)!) : 0;
    final minute = brMatch.group(5) != null ? int.parse(brMatch.group(5)!) : 0;
    return DateTime(year, month, day, hour, minute);
  }

  // Tenta ISO 8601.
  return DateTime.tryParse(trimmed);
}

/// Calcula o próximo Timestamp com base no horario HH:MM fornecido.
/// Se [targetDay] for informado (para recorrência mensal), usa esse dia do mês.
Timestamp _computeNextRunFromHorario(
  String? horario,
  DateTime now, {
  int? targetDay,
}) {
  if (horario == null) {
    return Timestamp.fromDate(now.add(const Duration(hours: 1)));
  }

  final parts = horario.split(':');
  if (parts.length != 2) {
    return Timestamp.fromDate(now.add(const Duration(hours: 1)));
  }

  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;

  final day = targetDay ?? now.day;
  var candidate = DateTime(now.year, now.month, day, hour, minute);

  // Se a hora já passou hoje/neste mês, avança para o próximo período.
  if (!candidate.isAfter(now)) {
    candidate = candidate.add(const Duration(days: 1));
  }

  return Timestamp.fromDate(candidate);
}
