import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/evidencias/evidencias_providers.dart';
import '../../services/app_providers.dart';
import 'mcp_server.dart';

/// Servidor MCP escopado na clínica ativa do usuário (multi-tenant).
///
/// Reconstruído quando a clínica selecionada muda. O agente de IA do app
/// (`features/ia`) consome este provider para listar/executar ferramentas.
///
/// Em ambiente sem Firebase, ainda assim cria o servidor — as tools tratam
/// erros de Firestore retornando `McpResult` de erro, sem derrubar a UI. O
/// mesmo vale enquanto a clínica não resolveu: as tools recusam em vez de
/// operar em clínica arbitrária.
final mcpServerProvider = Provider<McpServer>((ref) {
  // `clinicaResolvidaProvider` e não `selectedClinicIdProvider`: este id vira
  // `where clinicaId ==` e campo de documento em ~75 ferramentas. Com o
  // placeholder do boot, a IA leria vazio e gravaria em uma clínica fantasma.
  final clinicaId = ref.watch(clinicaResolvidaProvider);
  // O Firestore é resolvido sob demanda dentro do McpContext; em modo
  // demonstração os erros viram McpResult de erro (não derrubam a UI).
  return createMcpServer(
    defaultClinicaId: clinicaId,
    // Evidência científica: `null` fora do Firebase (a Cloud Function exige
    // ID token), e as tools `pubmed_*` recusam com mensagem explicativa.
    pubmed: ref.watch(firebaseEnabledProvider)
        ? ref.watch(pubmedServiceProvider)
        : null,
  );
});

/// Especificações das ferramentas MCP disponíveis (para alimentar o LLM).
final mcpToolSpecsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(mcpServerProvider).listToolSpecs();
});
