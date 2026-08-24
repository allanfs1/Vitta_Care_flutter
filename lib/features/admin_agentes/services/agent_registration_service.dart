import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agent_model.dart';
import '../providers/agent_provider.dart';

final agentRegistrationServiceProvider =
    Provider<AgentRegistrationService>((ref) {
  return AgentRegistrationService(ref);
});

class AgentRegistrationResult {
  const AgentRegistrationResult.success(this.agent)
      : ok = true,
        error = null;
  const AgentRegistrationResult.failure(this.error)
      : ok = false,
        agent = null;

  final bool ok;
  final String? error;
  final AgentModel? agent;
}

/// Cadastro atômico de agentes (§2.1) — fluxo de "Double Write".
///
/// Hoje roda sobre os providers mock (in-memory). Os pontos de integração com
/// o Firebase estão marcados com `TODO(firebase)` para plugar depois sem mexer
/// na UI: registrar o e-mail numa instância `secondaryApp` (sem deslogar o
/// admin) e escrever simultaneamente em `agents` e `users`.
class AgentRegistrationService {
  AgentRegistrationService(this._ref);

  final Ref _ref;

  Future<AgentRegistrationResult> registerAgent({
    required String nomeOperacional,
    required String email,
    required String pin,
    required AgentAvailability disponibilidade,
    List<String> setores = const [],
    int cargaMaxima = 5,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    // Garante unicidade do login antes de escrever (evita Auth duplicado).
    final exists = _ref
        .read(agentsProvider)
        .any((a) => a.email.toLowerCase() == normalizedEmail);
    if (exists) {
      return const AgentRegistrationResult.failure(
        'Já existe um atendente com este e-mail.',
      );
    }

    // Simula a latência do registro no Auth/Firestore.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // 1. Auth Bypass: registraria o e-mail numa instância secundária do
    //    Firebase, usando o PIN como senha, sem encerrar a sessão do admin.
    // TODO(firebase): final secondaryApp = await Firebase.initializeApp(name: 'agentCreator', options: ...);
    //   await FirebaseAuth.instanceFor(app: secondaryApp)
    //       .createUserWithEmailAndPassword(email: normalizedEmail, password: pin);
    //   await secondaryApp.delete();
    debugPrint(
      '[AgentRegistration] Auth bypass simulado: cria $normalizedEmail (senha = PIN).',
    );

    final agent = AgentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nomeOperacional: nomeOperacional.trim(),
      email: normalizedEmail,
      pin: pin,
      disponibilidade: disponibilidade,
      setores: setores,
      cargaMaxima: cargaMaxima,
    );

    // 3. Sincronia / Double Write: operacional (`agents`) + perfil (`users`).
    _ref.read(agentsProvider.notifier).addAgent(agent);
    // TODO(firebase): gravar também em `users` (perfil/roles) na mesma transação
    //   batched write para liberar o login instantaneamente.
    debugPrint(
      '[AgentRegistration] Double write simulado: agents + users para ${agent.id}.',
    );

    return AgentRegistrationResult.success(agent);
  }
}
