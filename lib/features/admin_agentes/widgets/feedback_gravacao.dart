import 'package:flutter/material.dart';

/// Executa uma gravação e reporta a falha ao usuário.
///
/// Os notifiers deste módulo revertem o estado local quando o banco recusa —
/// sem esta mensagem, a linha simplesmente "voltaria" na tela e o usuário
/// ficaria sem saber que a operação não valeu.
Future<bool> comFeedback(
  BuildContext context,
  Future<void> Function() acao, {
  String? sucesso,
}) async {
  // Messenger e cor resolvidos ANTES do await: depois dele o `context` pode
  // já não estar montado.
  final messenger = ScaffoldMessenger.of(context);
  final corErro = Theme.of(context).colorScheme.error;
  try {
    await acao();
    if (sucesso != null) {
      messenger.showSnackBar(SnackBar(content: Text(sucesso)));
    }
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      backgroundColor: corErro,
      content: Text('Não foi possível salvar: $e'),
    ));
    return false;
  }
}
