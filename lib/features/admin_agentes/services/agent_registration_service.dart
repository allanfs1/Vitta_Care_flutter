import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';
import '../../../firebase_options.dart';
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
/// Sem Firebase (modo demonstração), roda inteiramente sobre o repositório em
/// memória — sem login real, sem `users`, mas com o mesmo contrato de retorno.
/// Com Firebase, faz os dois passos que o cadastro precisa:
///
///  1. **Auth bypass**: cria o login do agente (e-mail + PIN como senha) numa
///     instância *secundária* do Firebase. Autenticar nela não afeta a sessão
///     do admin — só a instância `agentCreator` fica logada, e ela é
///     descartada (`app.delete()`) assim que a criação termina.
///  2. **Double write**: grava o perfil em `users/{uid}` (role `agente`,
///     `idclinica`) e o operacional em `tb_agentes`
///     ([AdminAgentesRepository], já persistido desde a auditoria de
///     2026-08-20).
class AgentRegistrationService {
  AgentRegistrationService(this._ref);

  final Ref _ref;

  /// Nome da instância secundária — criada e destruída (`app.delete()`) a
  /// cada cadastro, para não deixar sessão de agente nenhuma pendurada nela.
  static const String _appSecundario = 'agentCreator';

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

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final agent = AgentModel(
      id: id,
      nomeOperacional: nomeOperacional.trim(),
      email: normalizedEmail,
      pin: pin,
      disponibilidade: disponibilidade,
      setores: setores,
      cargaMaxima: cargaMaxima,
    );

    if (!_ref.read(firebaseEnabledProvider)) {
      // Modo demonstração: sem Auth real, mas o operacional persiste igual.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _ref.read(agentsProvider.notifier).addAgent(agent);
      return AgentRegistrationResult.success(agent);
    }

    String uid;
    try {
      uid = await _criarLoginAuth(normalizedEmail, pin);
    } on FirebaseAuthException catch (e) {
      return AgentRegistrationResult.failure(_mensagemAuth(e));
    } catch (e) {
      return AgentRegistrationResult.failure('Não foi possível criar o login: $e');
    }

    try {
      await _gravarPerfil(uid, agent);
      // O operacional (`tb_agentes`) já persiste desde que
      // `AdminAgentesRepository` existe — este era o passo que faltava.
      await _ref.read(agentsProvider.notifier).addAgent(agent.copyWith(id: uid));
    } catch (e) {
      // O login já foi criado; não desfazemos silenciosamente (apagar a conta
      // de outra pessoa por engano é pior que um perfil incompleto). O erro
      // fica visível para o admin decidir — geralmente é rodar de novo.
      return AgentRegistrationResult.failure(
        'Login criado, mas falhou ao salvar o perfil: $e. '
        'Tente cadastrar novamente com o mesmo e-mail.',
      );
    }

    return AgentRegistrationResult.success(agent.copyWith(id: uid));
  }

  /// Cria o usuário do Firebase Auth numa instância isolada e a descarta.
  /// A sessão do admin na instância `[DEFAULT]` nunca é tocada.
  Future<String> _criarLoginAuth(String email, String pin) async {
    // Se um cadastro anterior travou antes de rodar `app.delete()` (queda de
    // rede, app fechado no meio), a instância secundária ainda existe — usa a
    // que sobrou em vez de falhar com "duplicate-app".
    FirebaseApp app;
    try {
      app = Firebase.app(_appSecundario);
    } on FirebaseException {
      app = await Firebase.initializeApp(
        name: _appSecundario,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    try {
      final cred = await FirebaseAuth.instanceFor(app: app)
          .createUserWithEmailAndPassword(email: email, password: pin);
      final uid = cred.user?.uid;
      if (uid == null) throw StateError('Auth não devolveu um uid.');
      return uid;
    } finally {
      // Derruba só a sessão secundária — a do admin continua intacta.
      await FirebaseAuth.instanceFor(app: app).signOut();
      await app.delete();
    }
  }

  Future<void> _gravarPerfil(String uid, AgentModel agent) async {
    final clinicaId = _ref.read(clinicaResolvidaProvider);
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'display_name': agent.nomeOperacional,
      'email': agent.email,
      'roles': ['agente'],
      'idclinica': clinicaId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String _mensagemAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este e-mail já tem uma conta no Firebase.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'O PIN não atende ao mínimo de segurança do Firebase.';
      default:
        return 'Falha ao criar o login (${e.code}).';
    }
  }
}
