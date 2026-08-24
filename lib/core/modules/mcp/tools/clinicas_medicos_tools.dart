import 'package:cloud_firestore/cloud_firestore.dart';
import '../mcp_tool.dart';

/// Ferramentas MCP para Clínicas e Médicos (§6.1 e §6.2).
///
/// Expose via:
/// ```dart
/// final tools = buildClinicasMedicosTools(ctx);
/// ```
List<McpTool> buildClinicasMedicosTools(McpContext ctx) {
  return [
    // ── §6.1 Clínicas ─────────────────────────────────────────────────────

    McpTool(
      name: 'listar_clinicas',
      description:
          'Retorna a clínica do usuário logado. Por isolamento multi-tenant, '
          'o acesso é restrito à clínica do contexto — não lista clínicas de '
          'outros usuários.',
      inputSchema: {
        'type': 'object',
        'properties': <String, dynamic>{},
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          // Isolamento: o usuário só enxerga a própria clínica.
          final snap =
              await ctx.db.collection('tb_clinica').doc(ctx.clinicaId()).get();
          if (!snap.exists || snap.data()?['deleted'] == true) {
            return ok(<Map<String, dynamic>>[]);
          }
          final data = ctx.toJsonOne(snap);
          return ok(data == null ? <Map<String, dynamic>>[] : [data]);
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    McpTool(
      name: 'buscar_clinica',
      description:
          'Busca uma clínica pelo seu identificador único (ID do documento Firestore). '
          'Retorna os dados completos da clínica ou erro se não for encontrada.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'ID do documento da clínica em tb_clinica.',
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
          // Isolamento multi-tenant: só pode buscar a própria clínica.
          if (id != ctx.clinicaId()) {
            return err('acesso negado: clínica fora do escopo do usuário');
          }

          final snap = await ctx.db.collection('tb_clinica').doc(id).get();
          final data = ctx.toJsonOne(snap);
          if (data == null) {
            return err('clínica não encontrada');
          }
          return ok(data);
        } catch (e) {
          return err(e.toString());
        }
      },
    ),

    // ── §6.2 Médicos ──────────────────────────────────────────────────────

    McpTool(
      name: 'listar_medicos',
      description:
          'Lista médicos cadastrados, podendo filtrar por clínica, especialidade e '
          'se apenas os ativos devem ser retornados. '
          'Quando "clinicaId" for omitido usa a clínica padrão do contexto.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'clinicaId': {
            'type': 'string',
            'description':
                'ID da clínica. Se omitido, usa a clínica padrão do usuário logado.',
          },
          'especialidade': {
            'type': 'string',
            'description':
                'Filtra pelo nome da especialidade (busca parcial, sem distinção '
                'de maiúsculas/minúsculas).',
          },
          'apenasAtivos': {
            'type': 'boolean',
            'description':
                'Se verdadeiro, retorna somente médicos com status=true (ativos).',
          },
          'limite': {
            'type': 'integer',
            'description':
                'Número máximo de médicos a retornar (padrão: 50).',
          },
        },
        'required': <String>[],
      },
      handler: (Map<String, dynamic> args) async {
        try {
          final clinicaId = ctx.clinicaId(args.str('clinicaId'));
          final especialidade = args.str('especialidade');
          final apenasAtivos = args.boolArg('apenasAtivos');
          final limite = ctx.limit(args.intArg('limite'));

          // Referência de documento da clínica para comparar com o campo
          // idClinica que pode ser um DocumentReference.
          final clinicaRef = ctx.docRef('tb_clinica', clinicaId);

          // Filtra por um único campo (idClinica como DocumentReference)
          // para evitar índices compostos.
          QuerySnapshot<Map<String, dynamic>> snap;
          try {
            snap = await ctx.db
                .collection('tb_medicos')
                .where('idClinica', isEqualTo: clinicaRef)
                .get();
          } catch (_) {
            // Fallback: clínica guardada como string (não como referência).
            snap = await ctx.db
                .collection('tb_medicos')
                .where('idClinica', isEqualTo: clinicaId)
                .get();
          }

          // Filtragem em memória (evita índices compostos no Firestore).
          var docs = snap.docs.where((d) {
            final data = d.data();

            // Verificar vínculo com a clínica via campo alternativo idclinica
            // (string minúscula) caso o primeiro filtro tenha usado ref.
            final clinicaField = data['idClinica'] ?? data['idclinica'];
            if (clinicaField is DocumentReference) {
              if (clinicaField.id != clinicaId) return false;
            } else if (clinicaField is String) {
              if (clinicaField != clinicaId) return false;
            }
            // Se não tem campo de clínica, inclui mesmo assim (veio do filtro Firestore).

            // Filtro de status (apenas ativos).
            if (apenasAtivos == true) {
              final status = data['status'];
              if (status != true) return false;
            }

            // Filtro de especialidade (case-insensitive, contém).
            if (especialidade != null && especialidade.isNotEmpty) {
              final espec = especialidade.toLowerCase();

              bool matchesEspec = false;

              final espField = data['especialidade'];
              if (espField is String &&
                  espField.toLowerCase().contains(espec)) {
                matchesEspec = true;
              }

              if (!matchesEspec) {
                final espsField = data['especialidades'];
                if (espsField is List) {
                  matchesEspec = espsField.any(
                    (e) =>
                        e is String && e.toLowerCase().contains(espec),
                  );
                } else if (espsField is String &&
                    espsField.toLowerCase().contains(espec)) {
                  matchesEspec = true;
                }
              }

              if (!matchesEspec) return false;
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
      name: 'buscar_medico',
      description:
          'Busca um médico pelo seu identificador único (ID do documento Firestore em tb_medicos). '
          'Retorna todos os dados do médico ou erro se não for encontrado.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'ID do documento do médico em tb_medicos.',
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

          final snap = await ctx.db.collection('tb_medicos').doc(id).get();
          final data = ctx.toJsonOne(snap);
          if (data == null) {
            return err('médico não encontrado');
          }
          return ok(data);
        } catch (e) {
          return err(e.toString());
        }
      },
    ),
  ];
}
