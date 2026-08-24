import 'package:cloud_firestore/cloud_firestore.dart';

import 'mcp_tool.dart';
import 'tools/agendamentos_tools.dart';
import 'tools/cerebro_tools.dart';
import 'tools/clinicas_medicos_tools.dart';
import 'tools/comunicacao_tools.dart';
import 'tools/dados_tools.dart';
import 'tools/overbooking_sus_tools.dart';
import 'tools/pacientes_risco_tools.dart';

/// Servidor MCP em Dart — registro único e reutilizável de todas as ferramentas.
///
/// Porta da factory `createMcpServer(opts)` de `src/core/modules/mcp/mcp.server.js`
/// (ver `.specify/MCP.md`). Um mesmo servidor é consumido pelo agente de IA do
/// app (loop de ferramentas) e, futuramente, por qualquer transporte.
///
/// Nome/versão espelham o original: `Agenda Clinica MCP` v2.0.0.
class McpServer {
  McpServer._(this.ctx, this._tools);

  static const String name = 'Agenda Clinica MCP';
  static const String version = '2.0.0';

  final McpContext ctx;
  final Map<String, McpTool> _tools;

  /// Lista todas as ferramentas registradas.
  List<McpTool> get tools => _tools.values.toList(growable: false);

  /// Especificações expostas ao LLM (`name`, `description`, `inputSchema`).
  List<Map<String, dynamic>> listToolSpecs() =>
      tools.map((t) => t.toSpec()).toList();

  /// Nomes das ferramentas registradas.
  List<String> get toolNames => _tools.keys.toList(growable: false);

  bool hasTool(String toolName) => _tools.containsKey(toolName);

  /// Executa uma ferramenta pelo nome. Nunca lança: erros viram [McpResult] de erro.
  Future<McpResult> callTool(
      String toolName, Map<String, dynamic> args) async {
    final tool = _tools[toolName];
    if (tool == null) {
      return err('ferramenta desconhecida: $toolName');
    }
    // Guarda central de tenant. Deixar cada handler tropeçar sozinho tornava a
    // recusa dependente da ordem — quem tocasse o Firestore antes de pedir a
    // clínica falhava por outro motivo. Aqui a resposta é sempre a mesma, e
    // nenhuma tool chega a abrir conexão sem saber de quem são os dados.
    if (!ctx.temClinica) {
      return err(const McpSemClinica().toString());
    }
    try {
      return await tool.handler(args);
    } catch (e) {
      return err(e.toString());
    }
  }
}

/// Cria o servidor MCP registrando TODAS as ~50 ferramentas.
///
/// [defaultClinicaId] injeta a clínica do usuário logado (multi-tenant).
/// Quando omitido ou vazio o contexto fica **sem clínica** e toda tool recusa
/// com [McpSemClinica] — nunca há fallback para uma clínica arbitrária.
McpServer createMcpServer({
  FirebaseFirestore? db,
  String? defaultClinicaId,
}) {
  final ctx = McpContext(db: db, defaultClinicaId: defaultClinicaId);

  final groups = <McpTool>[
    ...buildClinicasMedicosTools(ctx),
    ...buildAgendamentosTools(ctx),
    ...buildPacientesRiscoTools(ctx),
    ...buildOverbookingSusTools(ctx),
    ...buildDadosTools(ctx),
    ...buildComunicacaoTools(ctx),
    ...buildCerebroTools(ctx),
  ];

  final map = <String, McpTool>{};
  for (final tool in groups) {
    assert(!map.containsKey(tool.name), 'tool duplicada: ${tool.name}');
    map[tool.name] = tool;
  }

  return McpServer._(ctx, map);
}
