import 'package:cloud_firestore/cloud_firestore.dart';
import '../mcp_tool.dart';

/// Ferramentas MCP para Overbooking (§6.6, §6.7) e SUS/APS (§6.13).
///
/// Expõe via:
/// ```dart
/// final tools = buildOverbookingSusTools(ctx);
/// ```
List<McpTool> buildOverbookingSusTools(McpContext ctx) {
  return [
    // ── §6.6 Overbooking — leitura ────────────────────────────────────────

    McpTool(
      name: 'listar_eventos_overbooking',
      description:
          'Lista eventos de overbooking detectados pelo sistema. '
          'Aceita filtro opcional pelo campo "decisao". '
          'Retorna lista com id e dados de cada evento.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'decisao': {
            'type': 'string',
            'description':
                'Filtra eventos pelo campo decisao (ex.: "aprovado", "rejeitado"). '
                'Se omitido, retorna todos.',
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
          final decisao = args.str('decisao');
          final limite = ctx.limit(args.intArg('limite'));

          final snap =
              await ctx.db.collection('tb_overbooking_events').get();

          final docs = snap.docs
              .where((d) {
                if (decisao == null) return true;
                return d.data()['decisao']?.toString() == decisao;
              })
              .take(limite)
              .toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_realocacoes',
      description:
          'Lista realocações na fila de processamento (queue_realoc). '
          'Permite filtrar por status e pelo campo "processado" (boolean).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'description':
                'Filtra pelo campo status (ex.: "pendente", "concluido"). '
                'Se omitido, retorna todos.',
          },
          'processado': {
            'type': 'boolean',
            'description':
                'Filtra pelo campo processado (true/false). '
                'Se omitido, retorna todos.',
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
          final processado = args.boolArg('processado');
          final limite = ctx.limit(args.intArg('limite'));

          final snap = await ctx.db.collection('queue_realoc').get();

          final docs = snap.docs
              .where((d) {
                final data = d.data();
                if (status != null &&
                    data['status']?.toString() != status) {
                  return false;
                }
                if (processado != null &&
                    data['processado'] != processado) {
                  return false;
                }
                return true;
              })
              .take(limite)
              .toList();

          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'listar_relatorios_overbooking',
      description:
          'Lista relatórios e métricas de overbooking da coleção '
          'tb_overbooking_reports.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'limite': {
            'type': 'integer',
            'description': 'Número máximo de relatórios a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final limite = ctx.limit(args.intArg('limite'));

          final snap =
              await ctx.db.collection('tb_overbooking_reports').get();

          final docs = snap.docs.take(limite).toList();
          return ok(ctx.toJsonList(docs));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── §6.7 Overbooking — painel, automação e lista de espera ───────────

    McpTool(
      name: 'overbooking_painel',
      description:
          'Retorna um resumo (painel) de overbooking para a clínica no período '
          'selecionado (dia ou semana). Inclui total de agendamentos, confirmados, '
          'faltas previstas, slots e status da automação.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, usa a clínica padrão do usuário logado.',
          },
          'periodo': {
            'type': 'string',
            'enum': ['dia', 'semana'],
            'description':
                'Período de análise: "dia" (hoje) ou "semana" (próximos 7 dias). '
                'Padrão: "dia".',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final clinicaId = ctx.clinicaId(args.str('clinicaId'));
          final periodo = args.str('periodo') ?? 'dia';

          final now = DateTime.now();
          final inicioHoje =
              DateTime(now.year, now.month, now.day);
          final fim = periodo == 'semana'
              ? inicioHoje.add(const Duration(days: 7))
              : inicioHoje.add(const Duration(days: 1));

          final clinicaRef = ctx.docRef('tb_clinica', clinicaId);

          // Busca agendamentos por clínica (campo ref ou string) sem índice composto.
          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idClinica', isEqualTo: clinicaRef)
                .get();
          } catch (_) {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idClinica', isEqualTo: clinicaId)
                .get();
          }

          // Filtragem em memória por período e clínica.
          final agendamentos = snap.docs.where((d) {
            final data = d.data();

            // Verificar clínica (ref ou string).
            final clinicaField =
                data['idClinica'] ?? data['idclinica'];
            if (clinicaField is DocumentReference) {
              if (clinicaField.id != clinicaId) return false;
            } else if (clinicaField is String) {
              if (clinicaField != clinicaId) return false;
            }

            // Verificar data.
            final dataField =
                data['dataConsulta'] ?? data['data'] ?? data['dataAgendamento'];
            DateTime? dataAgendamento;
            if (dataField is Timestamp) {
              dataAgendamento = dataField.toDate();
            } else if (dataField is String) {
              dataAgendamento = _parseDate(dataField);
            }
            if (dataAgendamento == null) return false;
            return !dataAgendamento.isBefore(inicioHoje) &&
                dataAgendamento.isBefore(fim);
          }).toList();

          final total = agendamentos.length;
          final confirmados = agendamentos
              .where((d) =>
                  d.data()['status']?.toString().toLowerCase() ==
                  'confirmado')
              .length;
          // Estimativa de faltas previstas = docs com status 'alto_risco' ou risco >= 50.
          final faltasPrevistas = agendamentos
              .where((d) {
                final data = d.data();
                final risco = data['risco'] ?? data['riskScore'] ?? 0;
                if (risco is num && risco >= 50) return true;
                return data['status']?.toString().toLowerCase() ==
                    'alto_risco';
              })
              .length;

          // Slots: estima-se 1 slot por agendamento (sem tabela de horários neste contexto).
          final slotsUtilizados = total;

          return ok({
            'clinicaId': clinicaId,
            'periodo': periodo,
            'inicioHoje': inicioHoje.toIso8601String(),
            'fim': fim.toIso8601String(),
            'totalAgendamentos': total,
            'confirmados': confirmados,
            'faltasPrevistas': faltasPrevistas,
            'slotsUtilizados': slotsUtilizados,
            'statusAutomacao': 'ativo',
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'overbooking_horarios_livres',
      description:
          'Retorna a ocupação por hora de um médico em uma data específica, '
          'comparando com a capacidade real do médico (limiteSlot + overbook, '
          'com override por período e teto maxPacientesPorHorario). '
          'Usa 4/hora como fallback quando o médico não tem config. '
          'Permite identificar horários com vagas disponíveis.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'medicoId': {
            'type': 'string',
            'description': 'ID do médico em tb_medicos (obrigatório).',
          },
          'data': {
            'type': 'string',
            'description':
                'Data a consultar no formato yyyy-MM-dd ou dd/MM/yyyy (obrigatório).',
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

          final data = _parseDate(dataStr);
          if (data == null) {
            return err(
                'Formato de data inválido. Use yyyy-MM-dd ou dd/MM/yyyy.');
          }

          final inicioDia = DateTime(data.year, data.month, data.day);
          final fimDia = inicioDia.add(const Duration(days: 1));

          // Config de capacidade do médico (ver OVERBOOKING.md §M6). Sem
          // config, mantém o comportamento legado de 4 agendamentos/hora.
          final medicoDoc =
              await ctx.db.collection('tb_medicos').doc(medicoId).get();
          final md = medicoDoc.data() ?? <String, dynamic>{};
          int asInt(dynamic v, int fallback) => v is num
              ? v.toInt()
              : (v is String ? int.tryParse(v) ?? fallback : fallback);
          final baseSlot =
              md.containsKey('limiteSlot') ? asInt(md['limiteSlot'], 1) : 4;
          final overGlobal = asInt(md['maxOverbook'], 0);
          final overPorPeriodo =
              (md['overbookingPeriodo'] as Map?)?.cast<String, dynamic>() ??
                  const {};
          final seguranca =
              (md['limitesSeguranca'] as Map?)?.cast<String, dynamic>() ??
                  const {};
          final teto = asInt(
              md['maxPacientesPorHorario'] ??
                  seguranca['maxPacientesPorHorario'],
              0);
          int capacidadePara(int hora) {
            final periodo =
                hora < 12 ? 'manha' : (hora < 18 ? 'tarde' : 'noite');
            final over =
                asInt(overPorPeriodo[periodo], overGlobal);
            final base = baseSlot < 1 ? 1 : baseSlot;
            var cap = base + (over < 0 ? 0 : over);
            if (teto > 0 && cap > teto) cap = teto;
            return cap < 1 ? 1 : cap;
          }

          final medicoRef = ctx.docRef('tb_medicos', medicoId);

          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idMedico', isEqualTo: medicoRef)
                .get();
          } catch (_) {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idMedico', isEqualTo: medicoId)
                .get();
          }

          // Filtra pelo dia e conta por hora em memória.
          final ocupacaoPorHora = <int, int>{};
          for (final doc in snap.docs) {
            final d = doc.data();

            // Confirma médico.
            final medField = d['idMedico'];
            if (medField is DocumentReference) {
              if (medField.id != medicoId) continue;
            } else if (medField is String) {
              if (medField != medicoId) continue;
            }

            // Verifica data.
            final dataField =
                d['dataConsulta'] ?? d['data'] ?? d['dataAgendamento'];
            DateTime? apptDate;
            if (dataField is Timestamp) {
              apptDate = dataField.toDate();
            } else if (dataField is String) {
              apptDate = _parseDate(dataField);
            }
            if (apptDate == null) continue;
            if (apptDate.isBefore(inicioDia) ||
                !apptDate.isBefore(fimDia)) {
              continue;
            }

            final hora = apptDate.hour;
            ocupacaoPorHora[hora] = (ocupacaoPorHora[hora] ?? 0) + 1;
          }

          // Gera resultado para horas de trabalho (7h-18h).
          final resultado = <Map<String, dynamic>>[];
          for (var h = 7; h < 18; h++) {
            final ocupacao = ocupacaoPorHora[h] ?? 0;
            final limite = capacidadePara(h);
            resultado.add({
              'hora': '${h.toString().padLeft(2, '0')}:00',
              'ocupacao': ocupacao,
              'limite': limite,
              'livres': (limite - ocupacao).clamp(0, limite),
            });
          }

          return ok({
            'medicoId': medicoId,
            'data': dataStr,
            'horarios': resultado,
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'overbooking_confirmacoes_automaticas',
      description:
          'Dispara confirmações automáticas para agendamentos de alto risco. '
          'É idempotente: grava em tb_confirmationHistory somente se ainda não '
          'houver registro para o agendamento. Retorna quantas foram disparadas '
          'e quantas foram ignoradas por já existirem.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, usa a clínica padrão do usuário logado.',
          },
          'data': {
            'type': 'string',
            'description':
                'Data de referência (yyyy-MM-dd ou dd/MM/yyyy). '
                'Se omitida, usa hoje.',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final clinicaId = ctx.clinicaId(args.str('clinicaId'));
          final dataStr = args.str('data');
          final refDate = dataStr != null ? _parseDate(dataStr) : null;
          final hoje = refDate ?? DateTime.now();
          final inicioDia =
              DateTime(hoje.year, hoje.month, hoje.day);
          final fimDia = inicioDia.add(const Duration(days: 1));

          final clinicaRef = ctx.docRef('tb_clinica', clinicaId);

          // Busca agendamentos da clínica.
          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idClinica', isEqualTo: clinicaRef)
                .get();
          } catch (_) {
            snap = await ctx.db
                .collection('tb_agendamentos')
                .where('idClinica', isEqualTo: clinicaId)
                .get();
          }

          // Filtra alto risco + hoje em memória.
          final altoRisco = snap.docs.where((d) {
            final data = d.data();

            // Clínica.
            final clinicaField =
                data['idClinica'] ?? data['idclinica'];
            if (clinicaField is DocumentReference) {
              if (clinicaField.id != clinicaId) return false;
            } else if (clinicaField is String) {
              if (clinicaField != clinicaId) return false;
            }

            // Data.
            final dataField =
                data['dataConsulta'] ?? data['data'] ?? data['dataAgendamento'];
            DateTime? apptDate;
            if (dataField is Timestamp) {
              apptDate = dataField.toDate();
            } else if (dataField is String) {
              apptDate = _parseDate(dataField);
            }
            if (apptDate == null) return false;
            if (apptDate.isBefore(inicioDia) ||
                !apptDate.isBefore(fimDia)) {
              return false;
            }

            // Alto risco.
            final risco = data['risco'] ?? data['riskScore'] ?? 0;
            if (risco is num && risco >= 50) return true;
            return data['status']?.toString().toLowerCase() == 'alto_risco';
          }).toList();

          // Carrega histórico existente para idempotência.
          final histSnap =
              await ctx.db.collection('tb_confirmationHistory').get();
          final existentes = <String>{};
          for (final h in histSnap.docs) {
            final agId = h.data()['agendamentoId']?.toString();
            if (agId != null) existentes.add(agId);
          }

          int disparadas = 0;
          int ignoradas = 0;

          for (final doc in altoRisco) {
            if (existentes.contains(doc.id)) {
              ignoradas++;
            } else {
              await ctx.db.collection('tb_confirmationHistory').add({
                'agendamentoId': doc.id,
                'action': 'auto_confirm',
                'createdAt': FieldValue.serverTimestamp(),
              });
              disparadas++;
            }
          }

          return ok({'disparadas': disparadas, 'ignoradas': ignoradas});
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── Lista de espera ───────────────────────────────────────────────────

    McpTool(
      name: 'lista_espera_adicionar',
      description:
          'Adiciona um paciente à lista de espera (tb_lista_espera) com status '
          '"aguardando". Aceita prioridade de 0 a 100 (padrão 50).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'nomePaciente': {
            'type': 'string',
            'description': 'Nome completo do paciente (obrigatório).',
          },
          'pacienteId': {
            'type': 'string',
            'description': 'ID do paciente em users (opcional).',
          },
          'telefone': {
            'type': 'string',
            'description': 'Telefone de contato do paciente (opcional).',
          },
          'medicoId': {
            'type': 'string',
            'description': 'ID do médico preferido em tb_medicos (opcional).',
          },
          'prioridade': {
            'type': 'integer',
            'description':
                'Prioridade de 0 (menor) a 100 (maior). Padrão: 50.',
          },
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, usa a clínica padrão do usuário logado.',
          },
        },
        'required': ['nomePaciente'],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final nomePaciente = args.str('nomePaciente');
          if (nomePaciente == null || nomePaciente.isEmpty) {
            return err('O argumento "nomePaciente" é obrigatório.');
          }
          final clinicaId = ctx.clinicaId(args.str('clinicaId'));
          final pacienteId = args.str('pacienteId');
          final telefone = args.str('telefone');
          final medicoId = args.str('medicoId');
          final prioridade =
              (args.intArg('prioridade') ?? 50).clamp(0, 100);

          final doc = <String, dynamic>{
            'nomePaciente': nomePaciente,
            'status': 'aguardando',
            'prioridade': prioridade,
            'idClinica': ctx.docRef('tb_clinica', clinicaId),
            'createdAt': FieldValue.serverTimestamp(),
          };
          if (pacienteId != null) {
            doc['idPaciente'] = ctx.docRef('users', pacienteId);
          }
          if (telefone != null) doc['telefone'] = telefone;
          if (medicoId != null) {
            doc['idMedico'] = ctx.docRef('tb_medicos', medicoId);
          }

          final ref =
              await ctx.db.collection('tb_lista_espera').add(doc);
          return ok({'id': ref.id, 'status': 'aguardando'});
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'lista_espera_listar',
      description:
          'Lista pacientes na lista de espera (tb_lista_espera). '
          'Permite filtrar por status e clínica. '
          'Retorna ordenado por prioridade decrescente.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'description':
                'Filtra pelo status (ex.: "aguardando", "aceito", "recusado", '
                '"convocado"). Se omitido, retorna todos.',
          },
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, usa a clínica padrão do usuário logado.',
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
          final clinicaId = ctx.clinicaId(args.str('clinicaId'));
          final limite = ctx.limit(args.intArg('limite'));

          final clinicaRef = ctx.docRef('tb_clinica', clinicaId);

          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await ctx.db
                .collection('tb_lista_espera')
                .where('idClinica', isEqualTo: clinicaRef)
                .get();
          } catch (_) {
            snap = await ctx.db
                .collection('tb_lista_espera')
                .where('idClinica', isEqualTo: clinicaId)
                .get();
          }

          var docs = snap.docs.where((d) {
            final data = d.data();

            // Clínica.
            final clinicaField =
                data['idClinica'] ?? data['idclinica'];
            if (clinicaField is DocumentReference) {
              if (clinicaField.id != clinicaId) return false;
            } else if (clinicaField is String) {
              if (clinicaField != clinicaId) return false;
            }

            if (status != null &&
                data['status']?.toString() != status) {
              return false;
            }
            return true;
          }).toList();

          // Ordena por prioridade decrescente.
          docs.sort((a, b) {
            final pa =
                (a.data()['prioridade'] as num?)?.toInt() ?? 50;
            final pb =
                (b.data()['prioridade'] as num?)?.toInt() ?? 50;
            return pb.compareTo(pa);
          });

          return ok(ctx.toJsonList(docs.take(limite).toList()));
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'lista_espera_aceitar',
      description:
          'Aceita a convocação de um paciente da lista de espera: cria um '
          'agendamento em tb_agendamentos com status "confirmado" e atualiza o '
          'documento da lista de espera para status "aceito". '
          'Retorna o ID do agendamento criado.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description':
                'ID do documento na lista de espera (tb_lista_espera).',
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

          final waitSnap =
              await ctx.db.collection('tb_lista_espera').doc(id).get();
          if (!waitSnap.exists) {
            return err('Registro da lista de espera não encontrado: $id');
          }

          final waitData = waitSnap.data()!;

          // Placeholder: dataConsulta = amanhã.
          final amanha = DateTime.now().add(const Duration(days: 1));
          final dataConsulta = DateTime(
              amanha.year, amanha.month, amanha.day, 8, 0);

          final appt = <String, dynamic>{
            'nomePaciente': waitData['nomePaciente'] ?? '',
            'status': 'confirmado',
            'dataConsulta': Timestamp.fromDate(dataConsulta),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'origemListaEspera': id,
          };

          // Clínica.
          final clinicaField =
              waitData['idClinica'] ?? waitData['idclinica'];
          if (clinicaField != null) {
            appt['idClinica'] = clinicaField;
            appt['idclinica'] = clinicaField;
          }

          // Médico.
          final medicoField = waitData['idMedico'];
          if (medicoField != null) {
            appt['idMedico'] = medicoField;
          }

          // Paciente.
          final pacienteField = waitData['idPaciente'];
          if (pacienteField != null) {
            appt['idPaciente'] = pacienteField;
          }

          final apptRef =
              await ctx.db.collection('tb_agendamentos').add(appt);

          await ctx.db.collection('tb_lista_espera').doc(id).update({
            'status': 'aceito',
            'agendamentoId': apptRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return ok({'agendamentoId': apptRef.id});
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'lista_espera_recusar',
      description:
          'Recusa a convocação de um paciente da lista de espera: define status '
          '"recusado" e convoca o próximo paciente com status "aguardando" de '
          'maior prioridade (status passa para "convocado"). '
          'Retorna o ID do próximo convocado (se houver).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description':
                'ID do documento na lista de espera (tb_lista_espera).',
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

          // Recusa o atual.
          await ctx.db.collection('tb_lista_espera').doc(id).update({
            'status': 'recusado',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Busca próximo aguardando.
          final proximosSnap = await ctx.db
              .collection('tb_lista_espera')
              .where('status', isEqualTo: 'aguardando')
              .get();

          if (proximosSnap.docs.isEmpty) {
            return ok({
              'proximoConvocado': null,
              'nota': 'Nenhum paciente aguardando na lista.',
            });
          }

          // Ordena por prioridade decrescente em memória.
          final proximos = proximosSnap.docs.toList()
            ..sort((a, b) {
              final pa =
                  (a.data()['prioridade'] as num?)?.toInt() ?? 50;
              final pb =
                  (b.data()['prioridade'] as num?)?.toInt() ?? 50;
              return pb.compareTo(pa);
            });

          final proximo = proximos.first;
          await ctx.db
              .collection('tb_lista_espera')
              .doc(proximo.id)
              .update({
            'status': 'convocado',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return ok({
            'proximoConvocado': proximo.id,
            'nomePaciente':
                proximo.data()['nomePaciente']?.toString(),
          });
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'lista_espera_remover',
      description:
          'Remove permanentemente um paciente da lista de espera (tb_lista_espera).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description':
                'ID do documento na lista de espera (tb_lista_espera).',
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

          await ctx.db.collection('tb_lista_espera').doc(id).delete();
          return ok({'removido': id});
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── §6.13 SUS / APS ───────────────────────────────────────────────────

    McpTool(
      name: 'previne_brasil_indicadores',
      description:
          'Retorna indicadores do Previne Brasil por linha de cuidado: '
          'numerador, denominador, cobertura %, meta e projeção de repasse. '
          'Se clinicaId for omitido, consolida todas as clínicas. '
          'Se não houver dados SUS, retorna lista vazia com campo "nota".',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, consolida todas as clínicas (escopo RSA).',
          },
          'linha': {
            'type': 'string',
            'description':
                'Filtra por linha de cuidado específica (ex.: "gestante", '
                '"hipertensao"). Se omitido, retorna todas as linhas.',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final clinicaId = args.str('clinicaId');
          final linhaFiltro = args.str('linha');

          // Carrega linhas válidas de sus_linhas.
          QuerySnapshot<Map<String, dynamic>> linhasSnap;
          try {
            linhasSnap =
                await ctx.db.collection('sus_linhas').get();
          } catch (_) {
            linhasSnap = await ctx.db
                .collection('sus_linhas')
                .limit(McpContext.defaultLimit)
                .get();
          }

          // Carrega indicadores.
          Query<Map<String, dynamic>> query =
              ctx.db.collection('sus_indicadores');
          QuerySnapshot<Map<String, dynamic>> indicadoresSnap;
          try {
            indicadoresSnap = await query.get();
          } catch (_) {
            return ok({
              'indicadores': <dynamic>[],
              'nota':
                  'Coleção sus_indicadores não encontrada ou vazia.',
            });
          }

          if (indicadoresSnap.docs.isEmpty &&
              linhasSnap.docs.isEmpty) {
            return ok({
              'indicadores': <dynamic>[],
              'nota': 'Nenhum dado SUS disponível para esta clínica.',
            });
          }

          // Linha ids válidos — usados para marcar indicadores com reconhecimento de linha.
          final linhasValidas = linhasSnap.docs
              .map((d) =>
                  d.data()['id']?.toString() ??
                  d.data()['linha']?.toString() ??
                  d.id)
              .toSet();

          // Filtra indicadores em memória (apenas linhas válidas, se houver catálogo).
          final indicadores = indicadoresSnap.docs.where((d) {
            final data = d.data();

            // Filtra por clínica se fornecida.
            if (clinicaId != null) {
              final clinicaField =
                  data['idClinica'] ?? data['clinicaId'];
              if (clinicaField is DocumentReference) {
                if (clinicaField.id != clinicaId) return false;
              } else if (clinicaField is String) {
                if (clinicaField != clinicaId) return false;
              }
            }

            // Filtra por linha.
            final linha =
                data['linha']?.toString() ?? data['id']?.toString();
            if (linhaFiltro != null &&
                linha != null &&
                !linha
                    .toLowerCase()
                    .contains(linhaFiltro.toLowerCase())) {
              return false;
            }

            return true;
          }).toList();

          if (indicadores.isEmpty) {
            return ok({
              'indicadores': <dynamic>[],
              'nota':
                  'Nenhum indicador encontrado para os filtros informados.',
            });
          }

          final resultado = indicadores.map((d) {
            final data = d.data();
            final numerador =
                (data['numerador'] as num?)?.toDouble() ?? 0.0;
            final denominador =
                (data['denominador'] as num?)?.toDouble() ?? 0.0;
            final cobertura = denominador > 0
                ? (numerador / denominador * 100)
                    .toStringAsFixed(2)
                : '0.00';
            final meta =
                (data['meta'] as num?)?.toDouble() ?? 0.0;
            final projecaoRepasse = denominador > 0 && meta > 0
                ? (numerador / denominador * 100 / meta * 100)
                    .toStringAsFixed(2)
                : '0.00';
            final linhaId =
                data['linha']?.toString() ?? data['id']?.toString() ?? d.id;

            return {
              'id': d.id,
              'linha': linhaId,
              'linhaReconhecida': linhasValidas.isEmpty ||
                  linhasValidas.contains(linhaId),
              'numerador': numerador,
              'denominador': denominador,
              'cobertura': '$cobertura%',
              'meta': '$meta%',
              'projecaoRepasse': '$projecaoRepasse%',
            };
          }).toList();

          return ok({'indicadores': resultado});
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'busca_ativa_linha_cuidado',
      description:
          'Retorna pacientes em atraso por linha de cuidado do SUS/APS, '
          'prontos para convocação ativa. '
          'Se não houver dados SUS, retorna lista vazia com campo "nota".',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, consolida todas as clínicas.',
          },
          'linha': {
            'type': 'string',
            'description':
                'Filtra por linha de cuidado (ex.: "gestante", "hipertensao"). '
                'Se omitido, retorna todas.',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final clinicaId = args.str('clinicaId');
          final linhaFiltro = args.str('linha');

          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await ctx.db.collection('sus_busca_ativa').get();
          } catch (_) {
            return ok({
              'pacientes': <dynamic>[],
              'nota':
                  'Coleção sus_busca_ativa não encontrada ou vazia.',
            });
          }

          if (snap.docs.isEmpty) {
            return ok({
              'pacientes': <dynamic>[],
              'nota':
                  'Nenhum paciente em atraso encontrado para busca ativa.',
            });
          }

          final pacientes = snap.docs.where((d) {
            final data = d.data();

            // Filtra por clínica se fornecida.
            if (clinicaId != null) {
              final clinicaField =
                  data['idClinica'] ?? data['clinicaId'];
              if (clinicaField is DocumentReference) {
                if (clinicaField.id != clinicaId) return false;
              } else if (clinicaField is String) {
                if (clinicaField != clinicaId) return false;
              }
            }

            // Filtra por linha.
            if (linhaFiltro != null) {
              final linha =
                  data['linha']?.toString() ?? data['linhaCuidado']?.toString();
              if (linha == null ||
                  !linha
                      .toLowerCase()
                      .contains(linhaFiltro.toLowerCase())) {
                return false;
              }
            }

            return true;
          }).toList();

          if (pacientes.isEmpty) {
            return ok({
              'pacientes': <dynamic>[],
              'nota':
                  'Nenhum paciente em atraso encontrado para os filtros informados.',
            });
          }

          return ok({'pacientes': ctx.toJsonList(pacientes)});
        } catch (e) {
          return err(e.toString());
        }
      },
    ),
  ];
}

// ── Helpers internos ──────────────────────────────────────────────────────────

/// Tenta parsear datas em formato ISO (yyyy-MM-dd) ou brasileiro (dd/MM/yyyy).
/// Retorna null se o formato for inválido.
DateTime? _parseDate(String s) {
  final trimmed = s.trim();
  // ISO: yyyy-MM-dd ou yyyy-MM-ddTHH:mm:ss...
  if (trimmed.contains('-') && trimmed.length >= 10) {
    try {
      return DateTime.parse(trimmed);
    } catch (_) {}
  }
  // Brasileiro: dd/MM/yyyy
  final parts = trimmed.split('/');
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2].split(' ').first);
    if (day != null && month != null && year != null) {
      try {
        return DateTime(year, month, day);
      } catch (_) {}
    }
  }
  return null;
}
