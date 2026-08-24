import 'package:cloud_firestore/cloud_firestore.dart';
import '../mcp_tool.dart';

/// Ferramentas MCP para gerenciamento de agendamentos (`tb_agendamentos`).
///
/// Expõe [buildAgendamentosTools] que retorna as cinco tools da seção §6.3
/// do spec `.specify/MCP.md`.
List<McpTool> buildAgendamentosTools(McpContext ctx) {
  return [
    _listarAgendamentos(ctx),
    _buscarAgendamento(ctx),
    _criarAgendamento(ctx),
    _atualizarStatusAgendamento(ctx),
    _listarAgendamentosHoje(ctx),
  ];
}

// ---------------------------------------------------------------------------
// Helpers internos
// ---------------------------------------------------------------------------

/// Faz parse de uma string de data no formato ISO 8601 ou brasileiro
/// (`dd/MM/yyyy HH:mm` / `dd/MM/yyyy`).
DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  // Tenta ISO 8601 primeiro.
  final iso = DateTime.tryParse(raw);
  if (iso != null) return iso;
  // Formato brasileiro dd/MM/yyyy HH:mm ou dd/MM/yyyy.
  final parts = raw.split(' ');
  final dateParts = parts[0].split('/');
  if (dateParts.length == 3) {
    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    if (day != null && month != null && year != null) {
      int hour = 0, minute = 0;
      if (parts.length > 1) {
        final timeParts = parts[1].split(':');
        hour = int.tryParse(timeParts[0]) ?? 0;
        minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
      }
      return DateTime(year, month, day, hour, minute);
    }
  }
  return null;
}

/// Compara uma referência Firestore **ou** string com um determinado id.
bool _refMatchesId(Object? fieldValue, String id) {
  if (fieldValue == null) return false;
  if (fieldValue is DocumentReference) return fieldValue.id == id;
  if (fieldValue is String) {
    // Pode ser path completo "colecao/id" ou só o id.
    return fieldValue == id || fieldValue.endsWith('/$id');
  }
  return false;
}

/// Filtra lista de agendamentos em memória com os critérios opcionais de
/// médico, status e intervalo de datas; depois ordena por `dataConsulta` e
/// aplica o limite.
List<Map<String, dynamic>> _filtrarEmMemoria({
  required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  required McpContext ctx,
  String? medicoId,
  String? status,
  DateTime? dataInicio,
  DateTime? dataFim,
  required int maxItems,
}) {
  final result = <Map<String, dynamic>>[];

  for (final doc in docs) {
    final data = doc.data();

    // Filtro de médico.
    if (medicoId != null && medicoId.isNotEmpty) {
      if (!_refMatchesId(data['idMedico'], medicoId)) continue;
    }

    // Filtro de status.
    if (status != null && status.isNotEmpty) {
      if (data['status'] != status) continue;
    }

    // Filtro de intervalo de datas sobre `dataConsulta`.
    final dc = data['dataConsulta'];
    DateTime? dataConsulta;
    if (dc is Timestamp) {
      dataConsulta = dc.toDate();
    } else if (dc is String) {
      dataConsulta = DateTime.tryParse(dc);
    }

    if (dataInicio != null && dataConsulta != null) {
      if (dataConsulta.isBefore(dataInicio)) continue;
    }
    if (dataFim != null && dataConsulta != null) {
      if (dataConsulta.isAfter(dataFim)) continue;
    }

    result.add(<String, dynamic>{
      'id': doc.id,
      ...?(jsonSafe(data) as Map<String, dynamic>?),
    });
  }

  // Ordena por dataConsulta asc (nulos por último).
  result.sort((a, b) {
    final da = a['dataConsulta'];
    final db = b['dataConsulta'];
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    final sa = da.toString();
    final sb = db.toString();
    return sa.compareTo(sb);
  });

  return result.take(maxItems).toList();
}

// ---------------------------------------------------------------------------
// 1. listar_agendamentos
// ---------------------------------------------------------------------------

McpTool _listarAgendamentos(McpContext ctx) {
  return McpTool(
    name: 'listar_agendamentos',
    description:
        'Lista agendamentos da clínica com filtros opcionais por médico, '
        'status e intervalo de datas. Retorna lista ordenada por dataConsulta.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'clinicaId': {
          'type': 'string',
          'description':
              'ID da clínica. Opcional — usa a clínica padrão do usuário logado.',
        },
        'medicoId': {
          'type': 'string',
          'description': 'ID do médico para filtrar. Opcional.',
        },
        'status': {
          'type': 'string',
          'description':
              'Status do agendamento para filtrar (confirmado, cancelado, faltou, '
              'realizado, reagendado). Opcional.',
        },
        'dataInicio': {
          'type': 'string',
          'description':
              'Data de início do intervalo (ISO 8601 ou yyyy-MM-dd). Opcional.',
        },
        'dataFim': {
          'type': 'string',
          'description':
              'Data de fim do intervalo (ISO 8601 ou yyyy-MM-dd). Opcional.',
        },
        'limite': {
          'type': 'integer',
          'description':
              'Número máximo de resultados (padrão ${McpContext.defaultLimit}).',
        },
      },
      'required': <String>[],
    },
    handler: (args) async {
      try {
        final clinicaId = ctx.clinicaId(args.str('clinicaId'));
        final medicoId = args.str('medicoId');
        final status = args.str('status');
        final dataInicio = _parseDate(args.str('dataInicio'));
        final dataFim = _parseDate(args.str('dataFim'));
        final maxItems = ctx.limit(args.intArg('limite'));

        final clinicaRef = ctx.docRef('tb_clinica', clinicaId);

        // Busca filtrando por clinicaId server-side usando o campo `idClinica`
        // (referência). O campo `idclinica` (minúsculo) é tratado em memória
        // para evitar índice composto.
        final snap = await ctx.db
            .collection('tb_agendamentos')
            .where('idClinica', isEqualTo: clinicaRef)
            .get();

        // Complementa com docs que usam o campo alternativo `idclinica`.
        final snap2 = await ctx.db
            .collection('tb_agendamentos')
            .where('idclinica', isEqualTo: clinicaRef)
            .get();

        final seenIds = <String>{};
        final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final doc in [...snap.docs, ...snap2.docs]) {
          if (seenIds.add(doc.id)) allDocs.add(doc);
        }

        final filtered = _filtrarEmMemoria(
          docs: allDocs,
          ctx: ctx,
          medicoId: medicoId,
          status: status,
          dataInicio: dataInicio,
          dataFim: dataFim,
          maxItems: maxItems,
        );

        return ok({'total': filtered.length, 'agendamentos': filtered});
      } catch (e) {
        return err('listar_agendamentos: $e');
      }
    },
  );
}

// ---------------------------------------------------------------------------
// 2. buscar_agendamento
// ---------------------------------------------------------------------------

McpTool _buscarAgendamento(McpContext ctx) {
  return McpTool(
    name: 'buscar_agendamento',
    description: 'Busca um agendamento pelo ID do documento.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'id': {
          'type': 'string',
          'description': 'ID do documento do agendamento.',
        },
      },
      'required': ['id'],
    },
    handler: (args) async {
      try {
        final id = args.str('id');
        if (id == null || id.isEmpty) return err('O campo "id" é obrigatório.');

        final snap = await ctx.db.collection('tb_agendamentos').doc(id).get();
        final data = ctx.toJsonOne(snap);
        if (data == null) {
          return err('Agendamento "$id" não encontrado.');
        }
        return ok(data);
      } catch (e) {
        return err('buscar_agendamento: $e');
      }
    },
  );
}

// ---------------------------------------------------------------------------
// 3. criar_agendamento
// ---------------------------------------------------------------------------

McpTool _criarAgendamento(McpContext ctx) {
  return McpTool(
    name: 'criar_agendamento',
    description:
        'Cria um novo agendamento com status "confirmado". Aceita datas em '
        'formato ISO 8601 ou "dd/MM/yyyy HH:mm".',
    inputSchema: {
      'type': 'object',
      'properties': {
        'clinicaId': {
          'type': 'string',
          'description':
              'ID da clínica. Opcional — usa a clínica padrão do usuário logado.',
        },
        'medicoId': {
          'type': 'string',
          'description': 'ID do médico responsável pelo agendamento.',
        },
        'nomeMedico': {
          'type': 'string',
          'description': 'Nome do médico (desnormalizado). Opcional.',
        },
        'pacienteId': {
          'type': 'string',
          'description':
              'ID do usuário/paciente (coleção "users"). Opcional — grava referência se fornecido.',
        },
        'nomePaciente': {
          'type': 'string',
          'description': 'Nome completo do paciente.',
        },
        'cpf': {
          'type': 'string',
          'description': 'CPF do paciente. Opcional.',
        },
        'telefonePaciente': {
          'type': 'string',
          'description': 'Telefone do paciente. Opcional.',
        },
        'emailPaciente': {
          'type': 'string',
          'description': 'E-mail do paciente. Opcional.',
        },
        'especialidade': {
          'type': 'string',
          'description': 'Especialidade médica. Opcional.',
        },
        'dataConsulta': {
          'type': 'string',
          'description':
              'Data e hora da consulta. Aceita ISO 8601 ou "dd/MM/yyyy HH:mm".',
        },
        'modalidade': {
          'type': 'string',
          'enum': ['Presencial', 'Telemedicina'],
          'description':
              'Modalidade da consulta (padrão "Presencial"). Opcional.',
        },
        'tipoConsulta': {
          'type': 'string',
          'description': 'Tipo da consulta (padrão "Consulta"). Opcional.',
        },
        'motivoConsulta': {
          'type': 'string',
          'description': 'Motivo / queixa principal da consulta. Opcional.',
        },
      },
      'required': ['medicoId', 'nomePaciente', 'dataConsulta'],
    },
    handler: (args) async {
      try {
        final medicoId = args.str('medicoId');
        if (medicoId == null || medicoId.isEmpty) {
          return err('O campo "medicoId" é obrigatório.');
        }
        final nomePaciente = args.str('nomePaciente');
        if (nomePaciente == null || nomePaciente.isEmpty) {
          return err('O campo "nomePaciente" é obrigatório.');
        }
        final dataConsultaRaw = args.str('dataConsulta');
        if (dataConsultaRaw == null || dataConsultaRaw.isEmpty) {
          return err('O campo "dataConsulta" é obrigatório.');
        }
        final dataConsultaDt = _parseDate(dataConsultaRaw);
        if (dataConsultaDt == null) {
          return err(
              'Formato de data inválido para "dataConsulta": $dataConsultaRaw. '
              'Use ISO 8601 ou "dd/MM/yyyy HH:mm".');
        }

        final clinicaId = ctx.clinicaId(args.str('clinicaId'));
        final pacienteId = args.str('pacienteId');
        final modalidade = args.str('modalidade') ?? 'Presencial';

        final clinicaRef = ctx.docRef('tb_clinica', clinicaId);
        final medicoRef = ctx.docRef('tb_medicos', medicoId);

        final docData = <String, dynamic>{
          'status': 'confirmado',
          'idClinica': clinicaRef,
          'idclinica': clinicaRef,
          'idMedico': medicoRef,
          'nomeMedico': args.str('nomeMedico'),
          'nomePaciente': nomePaciente,
          'cpf': args.str('cpf'),
          'telefonePaciente': args.str('telefonePaciente'),
          'emailPaciente': args.str('emailPaciente'),
          'especialidade': args.str('especialidade'),
          'dataConsulta': Timestamp.fromDate(dataConsultaDt),
          'modalidade': modalidade,
          'tipoConsulta': args.str('tipoConsulta') ?? 'Consulta',
          'motivoConsulta': args.str('motivoConsulta'),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Adiciona referência ao paciente somente se fornecida.
        if (pacienteId != null && pacienteId.isNotEmpty) {
          docData['idPaciente'] = ctx.docRef('users', pacienteId);
        }

        // Remove entradas nulas para não poluir o documento.
        docData.removeWhere((_, v) => v == null);

        final ref = await ctx.db.collection('tb_agendamentos').add(docData);

        return ok({
          'id': ref.id,
          'status': 'confirmado',
          'medicoId': medicoId,
          'clinicaId': clinicaId,
          'nomePaciente': nomePaciente,
          'dataConsulta': dataConsultaDt.toIso8601String(),
          'modalidade': modalidade,
        });
      } catch (e) {
        return err('criar_agendamento: $e');
      }
    },
  );
}

// ---------------------------------------------------------------------------
// 4. atualizar_status_agendamento
// ---------------------------------------------------------------------------

const _statusValidos = {
  'confirmado',
  'cancelado',
  'faltou',
  'realizado',
  'reagendado',
};

McpTool _atualizarStatusAgendamento(McpContext ctx) {
  return McpTool(
    name: 'atualizar_status_agendamento',
    description:
        'Atualiza o status de um agendamento existente. '
        'Valores válidos: confirmado, cancelado, faltou, realizado, reagendado.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'id': {
          'type': 'string',
          'description': 'ID do documento do agendamento.',
        },
        'status': {
          'type': 'string',
          'enum': [
            'confirmado',
            'cancelado',
            'faltou',
            'realizado',
            'reagendado',
          ],
          'description': 'Novo status do agendamento.',
        },
      },
      'required': ['id', 'status'],
    },
    handler: (args) async {
      try {
        final id = args.str('id');
        if (id == null || id.isEmpty) return err('O campo "id" é obrigatório.');

        final status = args.str('status');
        if (status == null || status.isEmpty) {
          return err('O campo "status" é obrigatório.');
        }
        if (!_statusValidos.contains(status)) {
          return err(
              'Status inválido: "$status". '
              'Valores aceitos: ${_statusValidos.join(', ')}.');
        }

        final ref = ctx.db.collection('tb_agendamentos').doc(id);
        await ref.update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return ok({
          'id': id,
          'status': status,
          'mensagem': 'Status atualizado com sucesso.',
        });
      } catch (e) {
        return err('atualizar_status_agendamento: $e');
      }
    },
  );
}

// ---------------------------------------------------------------------------
// 5. listar_agendamentos_hoje
// ---------------------------------------------------------------------------

McpTool _listarAgendamentosHoje(McpContext ctx) {
  return McpTool(
    name: 'listar_agendamentos_hoje',
    description:
        'Lista os agendamentos do dia atual com filtros opcionais por clínica '
        'e médico. Retorna lista ordenada por dataConsulta.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'clinicaId': {
          'type': 'string',
          'description':
              'ID da clínica. Opcional — usa a clínica padrão do usuário logado.',
        },
        'medicoId': {
          'type': 'string',
          'description': 'ID do médico para filtrar. Opcional.',
        },
        'limite': {
          'type': 'integer',
          'description':
              'Número máximo de resultados (padrão ${McpContext.defaultLimit}).',
        },
      },
      'required': <String>[],
    },
    handler: (args) async {
      try {
        final clinicaId = ctx.clinicaId(args.str('clinicaId'));
        final medicoId = args.str('medicoId');
        final maxItems = ctx.limit(args.intArg('limite'));

        final now = DateTime.now();
        final dataInicio = DateTime(now.year, now.month, now.day);
        final dataFim =
            DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

        final clinicaRef = ctx.docRef('tb_clinica', clinicaId);

        final snap = await ctx.db
            .collection('tb_agendamentos')
            .where('idClinica', isEqualTo: clinicaRef)
            .get();

        final snap2 = await ctx.db
            .collection('tb_agendamentos')
            .where('idclinica', isEqualTo: clinicaRef)
            .get();

        final seenIds = <String>{};
        final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final doc in [...snap.docs, ...snap2.docs]) {
          if (seenIds.add(doc.id)) allDocs.add(doc);
        }

        final filtered = _filtrarEmMemoria(
          docs: allDocs,
          ctx: ctx,
          medicoId: medicoId,
          dataInicio: dataInicio,
          dataFim: dataFim,
          maxItems: maxItems,
        );

        return ok({
          'data': dataInicio.toIso8601String().substring(0, 10),
          'total': filtered.length,
          'agendamentos': filtered,
        });
      } catch (e) {
        return err('listar_agendamentos_hoje: $e');
      }
    },
  );
}
