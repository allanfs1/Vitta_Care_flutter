import 'package:cloud_firestore/cloud_firestore.dart';
import '../mcp_tool.dart';

/// Ferramentas MCP para Pacientes / Usuários (§6.4), Risco / Predição (§6.5)
/// e Pausa do Agente (§6.12) — implementa RF-01 e RF-17 de AgentAI.md.
///
/// Expose via:
/// ```dart
/// final tools = buildPacientesRiscoTools(ctx);
/// ```
List<McpTool> buildPacientesRiscoTools(McpContext ctx) {
  return [
    // ── §6.4 Pacientes / Usuários ─────────────────────────────────────────

    McpTool(
      name: 'buscar_paciente',
      description:
          'Busca um paciente/usuário pela coleção "users". '
          'Forneça exatamente um dos critérios: "uid" (ID do documento), '
          '"cpf" ou "nome". '
          'Prioridade de busca: uid → cpf → nome. '
          'Retorna a lista de correspondências ou erro se não encontrar.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'uid': {
            'type': 'string',
            'description': 'ID do documento do usuário em users.',
          },
          'cpf': {
            'type': 'string',
            'description': 'CPF do paciente (string, com ou sem máscara).',
          },
          'nome': {
            'type': 'string',
            'description':
                'Nome ou parte do nome do paciente. '
                'Busca prefixo no campo display_name e depois contém em memória.',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final uid = args.str('uid');
          final cpf = args.str('cpf');
          final nome = args.str('nome');

          // Prioridade: uid → get direto
          if (uid != null && uid.isNotEmpty) {
            final snap = await ctx.db.collection('users').doc(uid).get();
            final data = ctx.toJsonOne(snap);
            if (data == null) return err('Paciente não encontrado com uid "$uid".');
            return ok([data]);
          }

          // Prioridade: cpf → where query
          if (cpf != null && cpf.isNotEmpty) {
            final snap = await ctx.db
                .collection('users')
                .where('cpf', isEqualTo: cpf)
                .limit(10)
                .get();
            if (snap.docs.isEmpty) {
              return err('Nenhum paciente encontrado com CPF "$cpf".');
            }
            return ok(ctx.toJsonList(snap.docs));
          }

          // Prioridade: nome → prefixo no Firestore + contém em memória
          if (nome != null && nome.isNotEmpty) {
            // Prefixo search: display_name >= nome AND < nome + ''
            QuerySnapshot<Map<String, dynamic>> snap;
            try {
              snap = await ctx.db
                  .collection('users')
                  .where('display_name', isGreaterThanOrEqualTo: nome)
                  .where('display_name', isLessThan: '$nome')
                  .limit(50)
                  .get();
            } catch (_) {
              // Fallback sem índice: busca geral e filtra em memória
              snap = await ctx.db.collection('users').limit(200).get();
            }

            final lower = nome.toLowerCase();
            final docs = snap.docs.where((d) {
              final dn = (d.data()['display_name'] ?? '').toString().toLowerCase();
              final fn = (d.data()['nome'] ?? '').toString().toLowerCase();
              return dn.contains(lower) || fn.contains(lower);
            }).take(20).toList();

            if (docs.isEmpty) {
              return err('Nenhum paciente encontrado com nome "$nome".');
            }
            return ok(ctx.toJsonList(docs));
          }

          return err(
              'Forneça pelo menos um argumento: "uid", "cpf" ou "nome".');
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_usuarios',
      description:
          'Lista usuários cadastrados na coleção "users". '
          'Pode filtrar por status ativo (ativo=true ou status=true) '
          'e por clínica. Limite padrão: 50.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'apenasAtivos': {
            'type': 'boolean',
            'description':
                'Se verdadeiro, retorna somente usuários com status=true ou ativo=true.',
          },
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, usa a clínica padrão do usuário logado.',
          },
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de usuários a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final apenasAtivos = args.boolArg('apenasAtivos');
          final limite = ctx.limit(args.intArg('limite'));

          // Busca sem filtro composto; filtra em memória.
          final fetchLimit = apenasAtivos == true ? limite * 5 : limite;
          final snap = await ctx.db
              .collection('users')
              .limit(fetchLimit.clamp(1, 500))
              .get();

          var docs = snap.docs;

          if (apenasAtivos == true) {
            docs = docs.where((d) {
              final data = d.data();
              final status = data['status'];
              final ativo = data['ativo'];
              return status == true || ativo == true;
            }).toList();
          }

          return ok(ctx.toJsonList(docs.take(limite).toList()));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── §6.5 Risco / Predição ─────────────────────────────────────────────

    McpTool(
      name: 'listar_agendamentos_alto_risco',
      description:
          'Lista agendamentos de alto risco previstos pela IA na coleção '
          '"dashboard_risco". '
          'Filtra em memória por "prioridade" e "foiIgnorado". '
          'Limite padrão: 50.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'prioridade': {
            'type': 'string',
            'description':
                'Filtra pelo campo "prioridade" do documento (ex.: "alta", "media").',
          },
          'foiIgnorado': {
            'type': 'boolean',
            'description': 'Filtra pelo campo "foiIgnorado" do documento.',
          },
          'limite': {
            'type': 'integer',
            'description':
                'Número máximo de registros a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final prioridade = args.str('prioridade');
          final foiIgnorado = args.boolArg('foiIgnorado');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db
              .collection('dashboard_risco')
              .limit(limite * 5)
              .get();

          final docs = snap.docs.where((d) {
            final data = d.data();
            if (prioridade != null &&
                data['prioridade']?.toString().toLowerCase() !=
                    prioridade.toLowerCase()) {
              return false;
            }
            if (foiIgnorado != null && data['foiIgnorado'] != foiIgnorado) {
              return false;
            }
            return true;
          }).take(limite).toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_faltas_ia',
      description:
          'Lista faltas registradas pelo algoritmo de IA na coleção '
          '"tb_faltas_data". '
          'Filtra em memória por "processado" e "risco_falta". '
          'Limite padrão: 50.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'processado': {
            'type': 'boolean',
            'description': 'Filtra pelo campo "processado" do documento.',
          },
          'riscoFalta': {
            'type': 'string',
            'description':
                'Filtra pelo campo "risco_falta" do documento (ex.: "alto", "medio", "baixo").',
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
          final processado = args.boolArg('processado');
          final riscoFalta = args.str('riscoFalta');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db
              .collection('tb_faltas_data')
              .limit(limite * 5)
              .get();

          final docs = snap.docs.where((d) {
            final data = d.data();
            if (processado != null && data['processado'] != processado) {
              return false;
            }
            if (riscoFalta != null &&
                data['risco_falta']?.toString().toLowerCase() !=
                    riscoFalta.toLowerCase()) {
              return false;
            }
            return true;
          }).take(limite).toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'analisar_reputacao_paciente',
      description:
          'Retorna o registro de reputação de um paciente da coleção '
          '"patient_reputation", buscando por CPF. '
          'Tenta query where(cpf) e também acesso direto por doc id == cpf.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'cpf': {
            'type': 'string',
            'description': 'CPF do paciente (obrigatório).',
          },
        },
        'required': ['cpf'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final cpf = args.str('cpf');
          if (cpf == null || cpf.isEmpty) {
            return err('O argumento "cpf" é obrigatório.');
          }

          // Tenta busca por campo cpf
          final snap = await ctx.db
              .collection('patient_reputation')
              .where('cpf', isEqualTo: cpf)
              .limit(1)
              .get();

          if (snap.docs.isNotEmpty) {
            return ok(ctx.toJsonList(snap.docs));
          }

          // Fallback: doc id == cpf
          final docSnap =
              await ctx.db.collection('patient_reputation').doc(cpf).get();
          final data = ctx.toJsonOne(docSnap);
          if (data != null) return ok(data);

          return err('Registro de reputação não encontrado para CPF "$cpf".');
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'calcular_risco_paciente',
      description:
          'Calcula o score de risco de falta (0–100) de um paciente com base '
          'no histórico de agendamentos em "tb_agendamentos" — implementa RF-01. '
          'Recebe "pacienteId" (CPF ou UID). '
          'Retorna: pacienteId, riskScore, riskLevel '
          '(baixo ≤ 25 / medio ≤ 50 / alto ≤ 75 / critico), '
          'factors[], totalAgendamentos, faltas.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'pacienteId': {
            'type': 'string',
            'description': 'CPF ou UID do paciente (obrigatório).',
          },
        },
        'required': ['pacienteId'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final pacienteId = args.str('pacienteId');
          if (pacienteId == null || pacienteId.isEmpty) {
            return err('O argumento "pacienteId" é obrigatório.');
          }

          // Tenta buscar agendamentos por referência de documento (uid)
          List<QueryDocumentSnapshot<Map<String, dynamic>>> agendDocs = [];

          try {
            final refSnap = await ctx.db
                .collection('tb_agendamentos')
                .where('idPaciente',
                    isEqualTo: ctx.docRef('users', pacienteId))
                .limit(200)
                .get();
            agendDocs = refSnap.docs;
          } catch (_) {}

          // Fallback: busca por cpf como string
          if (agendDocs.isEmpty) {
            try {
              final cpfSnap = await ctx.db
                  .collection('tb_agendamentos')
                  .where('cpf', isEqualTo: pacienteId)
                  .limit(200)
                  .get();
              agendDocs = cpfSnap.docs;
            } catch (_) {}
          }

          final total = agendDocs.length;

          if (total == 0) {
            // Sem histórico: risco base ~20
            return ok({
              'pacienteId': pacienteId,
              'riskScore': 20,
              'riskLevel': 'baixo',
              'factors': [
                {
                  'name': 'sem_historico',
                  'weight': 1.0,
                  'value': 'Nenhum agendamento encontrado — risco base aplicado.',
                }
              ],
              'totalAgendamentos': 0,
              'faltas': 0,
            });
          }

          int faltas = 0;
          int realizados = 0;
          int cancelados = 0;

          for (final doc in agendDocs) {
            final status =
                (doc.data()['status'] ?? '').toString().toLowerCase();
            if (status == 'faltou') faltas++;
            if (status == 'realizado') realizados++;
            if (status == 'cancelado') cancelados++;
          }

          // RF-01: fator de faltas (peso elevado: 60 %)
          final faltaRatio = faltas / total;
          final faltaScore = (faltaRatio * 60).round();

          // Fator de cancelamentos (peso 20 %)
          final cancelRatio = cancelados / total;
          final cancelScore = (cancelRatio * 20).round();

          // Fator de baixo comparecimento (peso 20 %): penaliza quando realizados < 50 %
          final compareceRatio = realizados / total;
          final compareceScore =
              compareceRatio < 0.5 ? ((0.5 - compareceRatio) * 40).round() : 0;

          final rawScore = faltaScore + cancelScore + compareceScore;
          final riskScore = rawScore.clamp(0, 100);

          String riskLevel;
          if (riskScore <= 25) {
            riskLevel = 'baixo';
          } else if (riskScore <= 50) {
            riskLevel = 'medio';
          } else if (riskScore <= 75) {
            riskLevel = 'alto';
          } else {
            riskLevel = 'critico';
          }

          return ok({
            'pacienteId': pacienteId,
            'riskScore': riskScore,
            'riskLevel': riskLevel,
            'factors': [
              {
                'name': 'taxa_faltas',
                'weight': 0.60,
                'value': faltaRatio,
              },
              {
                'name': 'taxa_cancelamentos',
                'weight': 0.20,
                'value': cancelRatio,
              },
              {
                'name': 'baixo_comparecimento',
                'weight': 0.20,
                'value': 1.0 - compareceRatio,
              },
            ],
            'totalAgendamentos': total,
            'faltas': faltas,
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_agendamentos_risco_alto',
      description:
          'Lista agendamentos futuros com score de risco ≥ 50 nos próximos X dias '
          'para a clínica do contexto. '
          'Computa um score rápido por agendamento (RF-01): '
          'lead-time, dia da semana, horário, modalidade. '
          'Retorna lista ordenada por riskScore desc, limite 50.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'dias': {
            'type': 'integer',
            'description':
                'Número de dias futuros a considerar (padrão: 7).',
          },
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, usa a clínica padrão do usuário logado.',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final dias = args.intArg('dias') ?? 7;
          final clinicaId = ctx.clinicaId(args.str('clinicaId'));

          final now = DateTime.now();
          final limitDate = now.add(Duration(days: dias));

          // Busca agendamentos da clínica (campo único para evitar índice composto)
          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idClinica',
                    isEqualTo: ctx.docRef('tb_clinica', clinicaId))
                .limit(500)
                .get();
          } catch (_) {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idClinica', isEqualTo: clinicaId)
                .limit(500)
                .get();
          }

          final results = <Map<String, dynamic>>[];

          for (final doc in snap.docs) {
            final data = doc.data();
            final dataConsulta = _parseDate(data['dataConsulta']);
            if (dataConsulta == null) continue;
            if (dataConsulta.isBefore(now) ||
                dataConsulta.isAfter(limitDate)) {
              continue;
            }

            final status = (data['status'] ?? '').toString().toLowerCase();
            // Ignora já realizados/cancelados/faltou
            if (status == 'realizado' ||
                status == 'cancelado' ||
                status == 'faltou') {
              continue;
            }

            final modalidade =
                (data['modalidade'] ?? '').toString();
            final nomePaciente = (data['nomePaciente'] ??
                    data['nomeUsuario'] ??
                    '')
                .toString();
            final nomeMedico =
                (data['nomeMedico'] ?? '').toString();

            final score = _quickScore(
              dataConsulta: dataConsulta,
              createdAt: _parseDate(data['createdAt']),
              modalidade: modalidade,
              historicFaltaRatio: null,
            );

            if (score < 50) continue;

            results.add({
              'agendamentoId': doc.id,
              'nomePaciente': nomePaciente,
              'nomeMedico': nomeMedico,
              'dataConsulta': dataConsulta.toIso8601String(),
              'riskScore': score,
              'riskLevel': _riskLevel(score),
            });
          }

          results.sort((a, b) =>
              (b['riskScore'] as int).compareTo(a['riskScore'] as int));

          return ok(results.take(50).toList());
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'historico_absenteismo_paciente',
      description:
          'Retorna estatísticas de absenteísmo de um paciente a partir '
          'da coleção "tb_agendamentos": '
          'total, realizados, faltas, cancelados, taxaFalta (%), ultimaFalta.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'pacienteId': {
            'type': 'string',
            'description': 'CPF ou UID do paciente (obrigatório).',
          },
        },
        'required': ['pacienteId'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final pacienteId = args.str('pacienteId');
          if (pacienteId == null || pacienteId.isEmpty) {
            return err('O argumento "pacienteId" é obrigatório.');
          }

          List<QueryDocumentSnapshot<Map<String, dynamic>>> agendDocs = [];

          try {
            final snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idPaciente',
                    isEqualTo: ctx.docRef('users', pacienteId))
                .limit(500)
                .get();
            agendDocs = snap.docs;
          } catch (_) {}

          if (agendDocs.isEmpty) {
            try {
              final snap = await ctx.db
                  .collection('tb_agendamentos')
                  .where('cpf', isEqualTo: pacienteId)
                  .limit(500)
                  .get();
              agendDocs = snap.docs;
            } catch (_) {}
          }

          int total = agendDocs.length;
          int realizados = 0;
          int faltas = 0;
          int cancelados = 0;
          DateTime? ultimaFalta;

          for (final doc in agendDocs) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString().toLowerCase();
            if (status == 'realizado') realizados++;
            if (status == 'faltou') {
              faltas++;
              final dt = _parseDate(data['dataConsulta']);
              if (dt != null &&
                  (ultimaFalta == null || dt.isAfter(ultimaFalta))) {
                ultimaFalta = dt;
              }
            }
            if (status == 'cancelado') cancelados++;
          }

          final taxaFalta = total > 0
              ? double.parse(((faltas / total) * 100).toStringAsFixed(1))
              : 0.0;

          return ok({
            'pacienteId': pacienteId,
            'total': total,
            'realizados': realizados,
            'faltas': faltas,
            'cancelados': cancelados,
            'taxaFalta': taxaFalta,
            'ultimaFalta': ultimaFalta?.toIso8601String(),
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'taxa_absenteismo',
      description:
          'Calcula KPIs de absenteísmo da clínica para o período informado '
          '(semanal / mensal / trimestral). '
          'Retorna: total, faltas, taxa (%), comparacao (variação vs período anterior), '
          'economiaEstimada (faltas × R\$ 150).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'periodo': {
            'type': 'string',
            'enum': ['semanal', 'mensal', 'trimestral'],
            'description': 'Período de análise (padrão: mensal).',
          },
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, usa a clínica padrão do usuário logado.',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final periodo = args.str('periodo') ?? 'mensal';
          final clinicaId = ctx.clinicaId(args.str('clinicaId'));

          final now = DateTime.now();
          Duration windowDur;
          switch (periodo.toLowerCase()) {
            case 'semanal':
              windowDur = const Duration(days: 7);
              break;
            case 'trimestral':
              windowDur = const Duration(days: 91);
              break;
            default:
              windowDur = const Duration(days: 30);
          }

          final windowStart = now.subtract(windowDur);
          final prevStart = windowStart.subtract(windowDur);

          // Busca com filtro de clínica (campo único)
          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idClinica',
                    isEqualTo: ctx.docRef('tb_clinica', clinicaId))
                .limit(1000)
                .get();
          } catch (_) {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idClinica', isEqualTo: clinicaId)
                .limit(1000)
                .get();
          }

          int totalCurrent = 0;
          int faltasCurrent = 0;
          int totalPrev = 0;
          int faltasPrev = 0;

          for (final doc in snap.docs) {
            final data = doc.data();
            final dt = _parseDate(data['dataConsulta']);
            if (dt == null) continue;
            final status = (data['status'] ?? '').toString().toLowerCase();

            if (dt.isAfter(windowStart) && dt.isBefore(now)) {
              totalCurrent++;
              if (status == 'faltou') faltasCurrent++;
            } else if (dt.isAfter(prevStart) && dt.isBefore(windowStart)) {
              totalPrev++;
              if (status == 'faltou') faltasPrev++;
            }
          }

          final taxaAtual = totalCurrent > 0
              ? double.parse(
                  ((faltasCurrent / totalCurrent) * 100).toStringAsFixed(1))
              : 0.0;
          final taxaAnterior = totalPrev > 0
              ? double.parse(
                  ((faltasPrev / totalPrev) * 100).toStringAsFixed(1))
              : 0.0;
          final variacao = double.parse(
              (taxaAtual - taxaAnterior).toStringAsFixed(1));
          final economiaEstimada = faltasCurrent * 150.0;

          return ok({
            'periodo': periodo,
            'clinicaId': clinicaId,
            'total': totalCurrent,
            'faltas': faltasCurrent,
            'taxa': taxaAtual,
            'comparacao': {
              'periodoAnterior': {
                'total': totalPrev,
                'faltas': faltasPrev,
                'taxa': taxaAnterior,
              },
              'variacao': variacao,
            },
            'economiaEstimada': economiaEstimada,
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'simular_overbooking',
      description:
          'Simula o impacto de overbooking num slot do médico para uma data. '
          'Busca os agendamentos do médico naquele dia, computa o risco médio '
          'e o número de agendamentos críticos (score ≥ 76), '
          'retornando uma recomendação textual.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'medicoId': {
            'type': 'string',
            'description': 'ID do documento do médico em tb_medicos (obrigatório).',
          },
          'data': {
            'type': 'string',
            'description':
                'Data do slot a simular no formato yyyy-MM-dd ou dd/MM/yyyy (obrigatório).',
          },
        },
        'required': ['medicoId', 'data'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final medicoId = args.str('medicoId');
          if (medicoId == null || medicoId.isEmpty) {
            return err('O argumento "medicoId" é obrigatório.');
          }
          final dataStr = args.str('data');
          if (dataStr == null || dataStr.isEmpty) {
            return err('O argumento "data" é obrigatório.');
          }
          final dataAlvo = _parseDateStr(dataStr);
          if (dataAlvo == null) {
            return err(
                'Formato de data inválido. Use yyyy-MM-dd ou dd/MM/yyyy.');
          }

          final diaInicio =
              DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);
          final diaFim = diaInicio.add(const Duration(days: 1));

          // Busca agendamentos por médico (campo único)
          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idMedico',
                    isEqualTo: ctx.docRef('tb_medicos', medicoId))
                .limit(200)
                .get();
          } catch (_) {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idMedico', isEqualTo: medicoId)
                .limit(200)
                .get();
          }

          // Filtra pelo dia em memória
          final docsNoDia = snap.docs.where((doc) {
            final dt = _parseDate(doc.data()['dataConsulta']);
            if (dt == null) return false;
            return dt.isAfter(diaInicio) && dt.isBefore(diaFim);
          }).toList();

          if (docsNoDia.isEmpty) {
            return ok({
              'medicoId': medicoId,
              'data': diaInicio.toIso8601String(),
              'totalAgendamentos': 0,
              'riscoMedio': 0,
              'nAgendamentosCriticos': 0,
              'recomendacao':
                  'Nenhum agendamento encontrado para esse dia. '
                  'Overbooking seguro.',
            });
          }

          int somaScore = 0;
          int criticos = 0;

          for (final doc in docsNoDia) {
            final data = doc.data();
            final dt = _parseDate(data['dataConsulta']);
            final modalidade = (data['modalidade'] ?? '').toString();
            final score = _quickScore(
              dataConsulta: dt ?? diaInicio,
              createdAt: _parseDate(data['createdAt']),
              modalidade: modalidade,
              historicFaltaRatio: null,
            );
            somaScore += score;
            if (score >= 76) criticos++;
          }

          final riscoMedio =
              (somaScore / docsNoDia.length).round();

          String recomendacao;
          if (riscoMedio >= 76 || criticos >= 2) {
            recomendacao =
                'ATENÇÃO: risco crítico detectado ($criticos agendamento(s) crítico(s)). '
                'Não é recomendado adicionar overbooking. '
                'Acione a fila de espera e notifique o administrador.';
          } else if (riscoMedio >= 51 || criticos == 1) {
            recomendacao =
                'Risco alto no slot. Overbooking possível com cautela. '
                'Recomenda-se confirmar os agendamentos existentes antes de adicionar novos.';
          } else if (riscoMedio >= 26) {
            recomendacao =
                'Risco médio. Overbooking moderado pode ser aplicado. '
                'Monitore as confirmações e envie lembretes reforçados.';
          } else {
            recomendacao =
                'Risco baixo. Overbooking seguro para este slot. '
                'Lembrete padrão 24h antes é suficiente.';
          }

          return ok({
            'medicoId': medicoId,
            'data': diaInicio.toIso8601String(),
            'totalAgendamentos': docsNoDia.length,
            'riscoMedio': riscoMedio,
            'nAgendamentosCriticos': criticos,
            'recomendacao': recomendacao,
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── §6.12 Agente - Pausa ─────────────────────────────────────────────

    McpTool(
      name: 'pausar_agente',
      description:
          'Suspende as ações automáticas do agente de absenteísmo '
          'para um paciente específico. '
          'Grava o documento "pause_{pacienteId}" em "tb_agent_config" '
          'com {paused: true}.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'pacienteId': {
            'type': 'string',
            'description': 'ID (CPF ou UID) do paciente (obrigatório).',
          },
        },
        'required': ['pacienteId'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final pacienteId = args.str('pacienteId');
          if (pacienteId == null || pacienteId.isEmpty) {
            return err('O argumento "pacienteId" é obrigatório.');
          }

          await ctx.db
              .collection('tb_agent_config')
              .doc('pause_$pacienteId')
              .set({
            'paused': true,
            'pacienteId': pacienteId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return ok({
            'status': 'ok',
            'pacienteId': pacienteId,
            'paused': true,
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'retomar_agente',
      description:
          'Retoma as ações automáticas do agente de absenteísmo '
          'para um paciente específico. '
          'Atualiza o documento "pause_{pacienteId}" em "tb_agent_config" '
          'com {paused: false}.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'pacienteId': {
            'type': 'string',
            'description': 'ID (CPF ou UID) do paciente (obrigatório).',
          },
        },
        'required': ['pacienteId'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final pacienteId = args.str('pacienteId');
          if (pacienteId == null || pacienteId.isEmpty) {
            return err('O argumento "pacienteId" é obrigatório.');
          }

          await ctx.db
              .collection('tb_agent_config')
              .doc('pause_$pacienteId')
              .set({
            'paused': false,
            'pacienteId': pacienteId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return ok({
            'status': 'ok',
            'pacienteId': pacienteId,
            'paused': false,
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),
  ];
}

// ── Helpers privados ──────────────────────────────────────────────────────────

/// Score rápido de risco (0–100) para um agendamento futuro — RF-01.
///
/// Fatores e pesos:
/// - Dia da semana (segunda = maior risco): até 15 pts
/// - Horário extremo (7–8h ou 17–18h): até 20 pts
/// - Lead-time (quanto mais distante o agendamento, maior risco): até 25 pts
/// - Modalidade Telemedicina (mais faltas): até 20 pts
/// - Histórico de faltas do paciente: até 20 pts
int _quickScore({
  required DateTime dataConsulta,
  DateTime? createdAt,
  required String modalidade,
  double? historicFaltaRatio,
}) {
  int score = 0;

  // 1. Dia da semana — segunda (1) tem mais faltas; sexta (5) também mais.
  final weekday = dataConsulta.weekday; // 1=segunda, 7=domingo
  if (weekday == 1) {
    score += 15; // segunda
  } else if (weekday == 5) {
    score += 10; // sexta
  } else if (weekday == 6 || weekday == 7) {
    score += 5; // fim de semana
  } else {
    score += 5; // demais dias — leve penalidade base
  }

  // 2. Horário extremo (7–8h ou 17–18h)
  final hora = dataConsulta.hour;
  if ((hora >= 7 && hora < 9) || (hora >= 17 && hora < 19)) {
    score += 20;
  } else if (hora < 7 || hora >= 19) {
    score += 10; // horários muito fora do padrão
  }

  // 3. Lead-time (dias entre criação e consulta)
  if (createdAt != null) {
    final leadDays = dataConsulta.difference(createdAt).inDays;
    if (leadDays > 30) {
      score += 25;
    } else if (leadDays > 14) {
      score += 15;
    } else if (leadDays > 7) {
      score += 8;
    } else {
      score += 3;
    }
  } else {
    // Sem data de criação: penalidade média
    score += 10;
  }

  // 4. Modalidade Telemedicina tem maior taxa de não comparecimento
  if (modalidade.toLowerCase().contains('telemedicina')) {
    score += 20;
  }

  // 5. Histórico de faltas do paciente (quando disponível)
  if (historicFaltaRatio != null) {
    score += (historicFaltaRatio * 20).round();
  }

  return score.clamp(0, 100);
}

/// Classifica o riskScore em nível textual.
String _riskLevel(int score) {
  if (score <= 25) return 'baixo';
  if (score <= 50) return 'medio';
  if (score <= 75) return 'alto';
  return 'critico';
}

/// Tenta converter um campo Firestore (Timestamp, String ISO, String dd/MM/yyyy)
/// para [DateTime]. Retorna null se não conseguir.
DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    return _parseDateStr(value);
  }
  return null;
}

/// Converte string de data nos formatos yyyy-MM-dd[T...] ou dd/MM/yyyy[...].
DateTime? _parseDateStr(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return null;

  // Tenta ISO 8601 (inclui yyyy-MM-dd)
  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return iso;

  // Tenta dd/MM/yyyy ou dd/MM/yyyy HH:mm
  final parts = trimmed.split(' ');
  final dateParts = parts[0].split('/');
  if (dateParts.length == 3) {
    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    if (day != null && month != null && year != null) {
      int hour = 0;
      int minute = 0;
      if (parts.length > 1) {
        final timeParts = parts[1].split(':');
        hour = int.tryParse(timeParts[0]) ?? 0;
        minute =
            timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
      }
      try {
        return DateTime(year, month, day, hour, minute);
      } catch (_) {}
    }
  }

  return null;
}
