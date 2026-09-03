import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/appointment.dart';
import '../models/clinic.dart';
import '../models/doctor.dart';
import '../models/enums.dart';
import '../models/patient.dart';
import '../models/plan.dart';
import 'ai_service.dart';
import 'appointment_service.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'clinic_service.dart';
import 'doctor_service.dart';
import 'email_service.dart';
import 'mock_data.dart';
import 'plan_service.dart';
import 'user_service.dart';
import 'whatsapp_service.dart';

/// Instância de SharedPreferences (sobrescrita em main via override).
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPrefsProvider em main()'),
);

/// Módulos que o usuário desabilitou na tela de Arquitetura (`/arquitetura`).
/// Persistido em SharedPreferences. Base (auth/navegação/home) nunca entra aqui.
class DisabledModulesNotifier extends StateNotifier<Set<String>> {
  DisabledModulesNotifier(this._prefs)
      : super((_prefs.getStringList(_key) ?? const []).toSet());

  static const _key = 'disabled_modules';
  // Base que não pode ser desabilitada (mantém navegação mínima funcional).
  static const locked = {'auth', 'navegacao', 'home', 'agendamentos'};
  final SharedPreferences _prefs;

  bool isDisabled(String id) => state.contains(id);
  bool canToggle(String id) => !locked.contains(id);

  void setEnabled(String id, bool enabled) {
    if (!canToggle(id)) return;
    final next = {...state};
    if (enabled) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
    _prefs.setStringList(_key, next.toList());
  }

  void toggle(String id) => setEnabled(id, isDisabled(id));
}

final disabledModulesProvider =
    StateNotifierProvider<DisabledModulesNotifier, Set<String>>((ref) {
  return DisabledModulesNotifier(ref.watch(sharedPrefsProvider));
});

// ---- Serviços compartilhados ----
final aiServiceProvider = Provider<AiService>((ref) => const AiService());
final emailServiceProvider = Provider<EmailService>((ref) => const EmailService());
final whatsappServiceProvider =
    Provider<WhatsappService>((ref) => const WhatsappService());

// ---- Dados base ----

final clinicServiceProvider = Provider<ClinicService>((ref) => const MockClinicService());

class ClinicsNotifier extends StateNotifier<List<Clinic>> {
  ClinicsNotifier(this._service) : super(MockData.clinics) {
    _init();
  }
  final ClinicService _service;
  void _init() {
    _service.watchClinics().listen((data) {
      if (data.isNotEmpty && mounted) state = data;
    });
  }
}

final clinicsNotifierProvider = StateNotifierProvider<ClinicsNotifier, List<Clinic>>((ref) {
  return ClinicsNotifier(ref.watch(clinicServiceProvider));
});

final clinicsProvider = Provider<List<Clinic>>((ref) => ref.watch(clinicsNotifierProvider));

/// Serviço de planos. Padrão: mock (offline/testes). Em `main` é sobrescrito
/// por [FirestorePlanService] quando o Firebase inicializa.
final planServiceProvider =
    Provider<PlanService>((ref) => const MockPlanService());

/// Catálogo de planos (`tb_plans`). Inicia com os planos mock e é substituído
/// pelos dados reais do Firestore assim que carregam — assim os consumidores
/// síncronos continuam funcionando e a UI atualiza reativamente.
class PlansNotifier extends StateNotifier<List<Plan>> {
  PlansNotifier(this._service) : super(MockData.plans) {
    _load();
  }

  final PlanService _service;

  Future<void> _load() async {
    try {
      final plans = await _service.fetchPlans();
      if (plans.isNotEmpty && mounted) state = plans;
    } catch (_) {
      // Mantém os planos mock em caso de falha de rede/Firestore.
    }
  }
}

final plansProvider =
    StateNotifierProvider<PlansNotifier, List<Plan>>((ref) {
  return PlansNotifier(ref.watch(planServiceProvider));
});
/// Serviço da equipe médica (`tb_medicos`). Padrão: mock (offline/testes). Em
/// `main` é sobrescrito por [FirestoreDoctorService] quando o Firebase inicia.
final doctorServiceProvider =
    Provider<DoctorService>((ref) => const MockDoctorService());

/// Catálogo global de médicos (`tb_medicos`) — usado por seleções gerais
/// (totem, timeline da agenda, detalhe da consulta) que não dependem da clínica
/// ativa. Inicia com os médicos mock e reflete os dados reais do Firestore
/// assim que o stream emite.
class DoctorsNotifier extends StateNotifier<List<Doctor>> {
  DoctorsNotifier(this._service) : super(MockData.doctors) {
    _init();
  }

  final DoctorService _service;
  StreamSubscription<List<Doctor>>? _sub;

  void _init() {
    _sub = _service.watchAll().listen((data) {
      // Mantém os mocks se o Firestore vier vazio (evita sumir seleção offline).
      if (mounted && data.isNotEmpty) state = data;
    }, onError: (_) {/* mantém o estado atual em caso de falha */});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final doctorsProvider =
    StateNotifierProvider<DoctorsNotifier, List<Doctor>>((ref) {
  return DoctorsNotifier(ref.watch(doctorServiceProvider));
});

/// Médicos ativos do catálogo global (exclui desativados).
final activeDoctorsProvider = Provider<List<Doctor>>(
    (ref) => ref.watch(doctorsProvider).where((d) => d.active).toList());

/// Estado da equipe médica da **clínica selecionada** (`tb_medicos` filtrado
/// por `idclinica`). Base da Equipe Médica (EM-01..EM-08).
///
/// Inicia com o seed do serviço (mock offline / vazio até o Firestore carregar)
/// e passa a refletir os dados reais assim que o stream emite. As escritas são
/// otimistas (a UI reage na hora) e persistidas via [DoctorService]; o próximo
/// snapshot do servidor reconcilia o estado.
class ClinicDoctorsNotifier extends StateNotifier<List<Doctor>> {
  ClinicDoctorsNotifier(this._service, this._clinicId)
      : super(_service.seed(_clinicId)) {
    _init();
  }

  final DoctorService _service;
  final String _clinicId;
  StreamSubscription<List<Doctor>>? _sub;

  void _init() {
    _sub = _service.watchForClinic(_clinicId).listen((data) {
      if (mounted) state = data;
    }, onError: (_) {/* mantém o estado atual em caso de falha */});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Cadastra um novo médico (EM-03), ativo por padrão.
  void add(Doctor doctor) {
    state = [...state, doctor];
    unawaited(_service.upsert(doctor));
  }

  /// Atualiza os dados de um médico (EM-04, EM-07).
  void update(Doctor doctor) {
    final updated = doctor.copyWith(updatedAt: DateTime.now());
    state = [
      for (final d in state)
        if (d.id == updated.id) updated else d,
    ];
    unawaited(_service.upsert(updated));
  }

  /// Ativa/desativa um médico (EM-06). Inativo some das seleções de
  /// agendamento, mas o registro é mantido.
  void setActive(String id, bool active) {
    state = [
      for (final d in state)
        if (d.id == id)
          d.copyWith(active: active, updatedAt: DateTime.now())
        else
          d,
    ];
    unawaited(_service.setActive(id, active));
  }

  /// Exclusão lógica (EM-08): mantém o documento para preservar a integridade
  /// dos agendamentos existentes, apenas marcando como inativo.
  void softDelete(String id) => setActive(id, false);
}

final clinicDoctorsProvider =
    StateNotifierProvider<ClinicDoctorsNotifier, List<Doctor>>((ref) {
  final clinicId = ref.watch(selectedClinicIdProvider);
  return ClinicDoctorsNotifier(ref.watch(doctorServiceProvider), clinicId);
});

/// Médico por id (`tb_medicos/{id}`), independente da clínica. Base da agenda
/// pública do médico (acessível sem login, via QR Code).
final doctorByIdProvider = FutureProvider.family<Doctor?, String>((ref, id) {
  return ref.watch(doctorServiceProvider).fetchById(id);
});

/// Agenda do médico em tempo real (`tb_agendamentos` filtrado por `idMedico`),
/// independente da clínica selecionada — alimenta a agenda pública (PM-09).
final doctorAgendaProvider =
    StreamProvider.family<List<Appointment>, String>((ref, doctorId) {
  return ref.watch(appointmentServiceProvider).watchForDoctor(doctorId);
});

final patientsProvider = Provider<List<Patient>>((ref) => MockData.patients);

/// Serviço de usuário (`users`). Padrão mock; em `main` é sobrescrito por
/// [FirestoreUserService] quando o Firebase inicializa.
final userServiceProvider =
    Provider<UserService>((ref) => const MockUserService());

/// Usuário autenticado. Inicia no mock e é substituído pelo perfil real do
/// Firestore (`users`) assim que o login fornece o `uid`.
///
/// Quando o e-mail de login não é encontrado em `users`, verifica se pertence
/// a alguma clínica em `tb_clinica` e cria um perfil virtual vinculado a ela.
class CurrentUserNotifier extends StateNotifier<AppUser> {
  CurrentUserNotifier(this._service, this._clinicService)
      : super(MockData.usuarioAtual);

  final UserService _service;
  final ClinicService _clinicService;
  String? _loadedKey;

  Future<void> load(String? uid, [String? email]) async {
    final key = '${uid ?? ''}|${email ?? ''}';
    if (uid == null && email == null) {
      _loadedKey = null;
      state = MockData.usuarioAtual;
      return;
    }
    if (key == _loadedKey) return;
    _loadedKey = key;
    try {
      AppUser? user;
      if (uid != null) user = await _service.fetchByUid(uid);
      // Fallback por e-mail: os `uid` do Firebase Auth podem divergir dos
      // gravados em `users`. O e-mail é a chave estável e evita cair em outra
      // conta/clínica por engano.
      if (user == null && email != null) {
        user = await _service.fetchByEmail(email);
      }
      // Fallback por clínica: se o e-mail pertence a uma clínica em
      // `tb_clinica`, cria um perfil virtual vinculado a ela. Isso permite
      // login com o e-mail da clínica sem precisar de cadastro em `users`.
      if (user == null && email != null) {
        final clinic = await _clinicService.fetchByEmail(email);
        if (clinic != null) {
          final clinicName = clinic.razaoSocial ?? clinic.name;
          final parts = clinicName.split(RegExp(r'\s+'));
          user = AppUser(
            id: uid ?? email,
            firstName: parts.first,
            lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
            email: email,
            phone: clinic.phone,
            roleLabel: 'Gestor',
            clinicIds: [clinic.id],
          );
        }
      }
      if (user != null && mounted) {
        state = user;
      } else if (mounted) {
        // Não encontrou o perfil: evita exibir dados de outra conta.
        state = MockData.usuarioAtual;
      }
    } catch (_) {
      // Mantém o usuário atual em caso de falha.
    }
  }

  /// Persiste as alterações do perfil (PU-02) e atualiza o estado.
  ///
  /// Propaga a exceção de propósito: a tela só pode dizer "salvo" depois que a
  /// gravação voltou. Antes, o botão Salvar exibia sucesso sem escrever nada.
  Future<void> salvar(AppUser atualizado) async {
    final salvo = await _service.salvar(atualizado);
    if (mounted) state = salvo;
  }
}

final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, AppUser>((ref) {
  final notifier = CurrentUserNotifier(
    ref.watch(userServiceProvider),
    ref.watch(clinicServiceProvider),
  );
  ref.listen(authProvider, (prev, next) => notifier.load(next.uid, next.email),
      fireImmediately: true);
  return notifier;
});

/// Clínicas que pertencem ao usuário autenticado (filtra `clinicsProvider`
/// pelos `clinicIds` do perfil). Se o usuário não tiver clínicas vinculadas,
/// retorna todas (evita tela vazia).
final userClinicsProvider = Provider<List<Clinic>>((ref) {
  final all = ref.watch(clinicsProvider);
  final ids = ref.watch(currentUserProvider).clinicIds;
  if (ids.isEmpty) return all;
  final filtered = all.where((c) => ids.contains(c.id)).toList();
  return filtered.isEmpty ? all : filtered;
});

// ---- Autenticação (módulo auth: LOGIN / CADASTRO / PLANO) ----

enum AuthStatus { unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.selectedPlanId,
    this.email,
    this.uid,
  });

  final AuthStatus status;
  final String? selectedPlanId;
  final String? email;
  final String? uid;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasPlan => selectedPlanId != null;

  AuthState copyWith({
    AuthStatus? status,
    String? selectedPlanId,
    String? email,
    String? uid,
  }) {
    return AuthState(
      status: status ?? this.status,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      email: email ?? this.email,
      uid: uid ?? this.uid,
    );
  }
}

/// Serviço de autenticação. Por padrão usa o mock (offline/testes); em `main`
/// é sobrescrito por [FirebaseAuthService] quando o Firebase inicializa.
final authServiceProvider = Provider<AuthService>((ref) => MockAuthService());

/// Serviço de biometria (digital / Windows Hello / passkey). A implementação é
/// escolhida por plataforma em [createBiometricService]. Sobrescrito em testes.
final biometricServiceProvider =
    Provider<BiometricService>((ref) => createBiometricService());

/// `true` quando o login real (Firebase) está disponível.
final firebaseEnabledProvider =
    Provider<bool>((ref) => ref.watch(authServiceProvider).isFirebaseEnabled);

/// Controla login/cadastro/recuperação de senha e seleção de plano.
///
/// As credenciais são verificadas pelo **Firebase Authentication** (via
/// [AuthService]); o plano escolhido é cacheado localmente e, em produção,
/// gravado em `tb_plan_user`.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._prefs, this._service)
      : super(AuthState(
          status: (_service.currentEmail != null ||
                  (_prefs.getBool(_loggedKey) ?? false))
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          selectedPlanId: _prefs.getString(_planKey),
          email: _service.currentEmail ?? _prefs.getString(_emailKey),
          uid: _service.currentUid,
        )) {
    // Mantém o estado em sincronia com o Firebase Auth (login/logout externos).
    _sub = _service.authStateChanges().listen((email) {
      if (email == null && state.isAuthenticated) {
        _prefs.remove(_loggedKey);
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  static const _loggedKey = 'auth_logged_in';
  static const _planKey = 'auth_plan_id';
  static const _emailKey = 'auth_email';
  static const _biometricKey = 'auth_biometric_enabled';
  final SharedPreferences _prefs;
  final AuthService _service;
  StreamSubscription<String?>? _sub;

  /// Retorna `null` em sucesso ou a mensagem de erro.
  Future<String?> login({required String email, required String password}) async {
    final r = await _service.signIn(email: email, password: password);
    if (!r.ok) return r.error;
    await _persistSession(r.email ?? email);
    final planId = _prefs.getString(_planKey) ?? '1'; // Simula plano existente
    await _prefs.setString(_planKey, planId);
    state = state.copyWith(
        status: AuthStatus.authenticated,
        email: r.email ?? email,
        selectedPlanId: planId,
        uid: _service.currentUid);
    return null;
  }

  /// Login com conta Google (módulo pronto do Firebase).
  Future<String?> loginWithGoogle() async {
    final r = await _service.signInWithGoogle();
    if (!r.ok) return r.error;
    final email = r.email ?? '';
    await _persistSession(email);
    final planId = _prefs.getString(_planKey) ?? '1';
    await _prefs.setString(_planKey, planId);
    state = state.copyWith(
        status: AuthStatus.authenticated,
        email: email,
        selectedPlanId: planId,
        uid: _service.currentUid);
    return null;
  }

  /// Existe uma sessão salva localmente que a biometria pode desbloquear?
  bool get hasSavedSession =>
      _prefs.getBool(_loggedKey) == true && _prefs.getString(_emailKey) != null;

  /// Há um e-mail salvo cuja sessão a biometria pode restaurar. Persiste mesmo
  /// após o logout, para permitir reentrar com biometria sem digitar a senha.
  bool get canRestoreSession => _prefs.getString(_emailKey) != null;

  bool get biometricEnabled => _prefs.getBool(_biometricKey) ?? false;

  Future<void> setBiometricEnabled(bool enabled) =>
      _prefs.setBool(_biometricKey, enabled);

  /// Conclui o login após biometria bem-sucedida, restaurando a sessão salva.
  Future<String?> completeBiometricLogin() async {
    final email = _prefs.getString(_emailKey);
    if (email == null) return 'Nenhuma sessão salva neste dispositivo.';
    final planId = _prefs.getString(_planKey) ?? '1';
    await _prefs.setString(_planKey, planId);
    await _prefs.setBool(_loggedKey, true);
    state = state.copyWith(status: AuthStatus.authenticated, email: email, selectedPlanId: planId);
    return null;
  }

  /// Cadastro de nova conta (Firebase) — sem plano escolhido ainda.
  Future<String?> register({required String email, required String password}) async {
    final r = await _service.register(email: email, password: password);
    if (!r.ok) return r.error;
    await _persistSession(r.email ?? email);
    state = AuthState(
        status: AuthStatus.authenticated,
        email: r.email ?? email,
        uid: _service.currentUid);
    return null;
  }

  /// Envia e-mail de recuperação de senha (módulo pronto do Firebase).
  Future<String?> resetPassword(String email) async {
    final r = await _service.sendPasswordReset(email);
    return r.ok ? null : r.error;
  }

  Future<void> choosePlan(String planId) async {
    await _prefs.setString(_planKey, planId);
    state = state.copyWith(selectedPlanId: planId);
  }

  Future<void> logout() async {
    await _service.signOut();
    await _prefs.remove(_loggedKey);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _persistSession(String email) async {
    await _prefs.setBool(_loggedKey, true);
    await _prefs.setString(_emailKey, email);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(sharedPrefsProvider),
    ref.watch(authServiceProvider),
  );
});

/// Plano atualmente ativo do usuário (ou nulo se ainda não escolheu).
final activePlanProvider = Provider<Plan?>((ref) {
  final id = ref.watch(authProvider).selectedPlanId;
  if (id == null) return null;
  final plans = ref.watch(plansProvider);
  for (final p in plans) {
    if (p.id == id) return p;
  }
  return null;
});

/// Seleção da clínica ativa (H-01), persistida em SharedPreferences.
class SelectedClinicNotifier extends StateNotifier<String> {
  SelectedClinicNotifier(this._prefs, List<Clinic> clinics, AppUser user)
      : super(_getDefault(user, clinics, _prefs));

  static const _key = 'selected_clinic_id';
  final SharedPreferences _prefs;

  static String _getDefault(AppUser user, List<Clinic> clinics, SharedPreferences prefs) {
    if (clinics.isEmpty) return '';
    // Conjunto de clínicas que pertencem ao usuário (se houver vínculo).
    final userClinics = user.clinicIds.isNotEmpty
        ? clinics.where((c) => user.clinicIds.contains(c.id)).toList()
        : const <Clinic>[];
    final pool = userClinics.isNotEmpty ? userClinics : clinics;
    // Só aceita a clínica persistida se ela pertencer ao usuário atual —
    // evita "vazar" a clínica de uma conta anterior ao trocar de login.
    final savedId = prefs.getString(_key);
    if (savedId != null && pool.any((c) => c.id == savedId)) {
      return savedId;
    }
    return pool.first.id;
  }

  void select(String clinicId) {
    state = clinicId;
    _prefs.setString(_key, clinicId);
  }
}

final selectedClinicIdProvider =
    StateNotifierProvider<SelectedClinicNotifier, String>((ref) {
  return SelectedClinicNotifier(
    ref.watch(sharedPrefsProvider),
    ref.watch(clinicsProvider),
    ref.watch(currentUserProvider),
  );
});

/// Clínica ativa **só depois de resolvida** — `''` enquanto não se sabe.
///
/// [clinicsProvider] nasce com o placeholder de [MockData] e só troca pelos
/// dados reais quando o snapshot de `tb_clinica` chega, alguns frames depois.
/// Nessa janela [selectedClinicIdProvider] devolve `'c1'`, uma clínica que não
/// existe no Firestore. Qualquer módulo que use esse id como **chave de dados**
/// lê um conjunto vazio e grava documentos órfãos, que somem no boot seguinte.
///
/// Use este provider (e não [selectedClinicIdProvider]) sempre que o id for
/// virar `where clinicaId ==` ou campo de documento. Para exibir a clínica na
/// UI, o placeholder é inofensivo e [selectedClinicProvider] continua servindo.
///
/// Sem Firebase o mock é a fonte legítima de dados e o id passa direto.
final clinicaResolvidaProvider = Provider<String>((ref) {
  final id = ref.watch(selectedClinicIdProvider);
  if (!ref.watch(firebaseEnabledProvider)) return id;
  final placeholder = MockData.clinics.any((c) => c.id == id);
  return placeholder ? '' : id;
});

final selectedClinicProvider = Provider<Clinic>((ref) {
  final id = ref.watch(selectedClinicIdProvider);
  // Resolve dentro das clínicas do usuário; se o id persistido não pertencer
  // a este usuário (ex.: troca de conta), cai para a 1ª clínica dele.
  final clinics = ref.watch(userClinicsProvider);
  if (clinics.isEmpty) {
    final all = ref.watch(clinicsProvider);
    return all.isNotEmpty ? all.first : MockData.clinics.first;
  }
  return clinics.firstWhere((c) => c.id == id, orElse: () => clinics.first);
});

/// Serviço de agendamentos. Padrão: mock (offline/testes). Em `main` é
/// sobrescrito por [FirestoreAppointmentService] quando o Firebase inicializa.
final appointmentServiceProvider =
    Provider<AppointmentService>((ref) => const MockAppointmentService());

/// Estado mutável dos agendamentos da clínica ativa (A-01..A-03).
///
/// Inicia com os agendamentos mock (para resposta imediata/offline) e passa a
/// refletir os dados reais de `tb_agendamentos` filtrados pela clínica logada
/// assim que o stream do [AppointmentService] emite.
class AppointmentsNotifier extends StateNotifier<List<Appointment>> {
  AppointmentsNotifier(this._service, this._clinicId)
      : super(MockData.appointmentsFor(_clinicId)) {
    _init();
  }

  final AppointmentService _service;
  final String _clinicId;
  StreamSubscription<List<Appointment>>? _sub;

  void _init() {
    _sub = _service.watchForClinic(_clinicId).listen((data) {
      if (mounted) state = data;
    }, onError: (_) {/* mantém o estado atual em caso de falha */});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void setStatus(String id, AppointmentStatus status) {
    // Atualização otimista: a UI reage na hora; a escrita persiste o estado em
    // `tb_agendamentos` para que o próximo snapshot do servidor não a reverta.
    state = [
      for (final a in state)
        if (a.id == id) a.copyWith(status: status) else a,
    ];
    unawaited(_persistStatus(id, status));
  }

  void reschedule(String id, DateTime newStart) {
    state = [
      for (final a in state)
        if (a.id == id)
          a.copyWith(start: newStart, status: AppointmentStatus.pending)
        else
          a,
    ];
    unawaited(_persistReschedule(id, newStart));
  }

  Future<void> _persistStatus(String id, AppointmentStatus status) async {
    try {
      await _service.updateStatus(id, status);
    } catch (_) {
      // Falha de rede/permite: o próximo snapshot reconcilia o estado real.
    }
  }

  Future<void> _persistReschedule(String id, DateTime newStart) async {
    try {
      await _service.reschedule(id, newStart);
    } catch (_) {
      // Falha de rede/permite: o próximo snapshot reconcilia o estado real.
    }
  }

  /// Adiciona um agendamento (ex.: criado pelo totem de autoatendimento).
  void add(Appointment appointment) {
    state = [...state, appointment];
  }

  /// Cria um agendamento manual (A-02, botão "+" da agenda): reage na hora
  /// (otimista) e persiste em `tb_agendamentos`. O próximo snapshot do servidor
  /// reconcilia o estado quando o Firestore está ativo.
  void create(Appointment appointment) {
    state = [...state, appointment];
    unawaited(_persistCreate(appointment));
  }

  Future<void> _persistCreate(Appointment appointment) async {
    try {
      await _service.create(appointment);
    } catch (_) {
      // Falha de rede/permissão: o próximo snapshot reconcilia o estado real.
    }
  }

  /// Remarca um agendamento existente: novo horário e, se informado, novo
  /// médico/especialidade. Usado pelo totem (fluxo "Remarcar" via CPF).
  void move(
    String id, {
    required DateTime start,
    String? doctorId,
    String? doctorName,
    String? specialty,
    String? crm,
  }) {
    state = [
      for (final a in state)
        if (a.id == id)
          a.copyWith(
            start: start,
            doctorId: doctorId,
            doctorName: doctorName,
            specialty: specialty,
            crm: crm,
            status: AppointmentStatus.pending,
          )
        else
          a,
    ];
    // Persiste a remarcação (novo horário + status) em `tb_agendamentos` — sem
    // isso a mudança some ao recarregar e a recepção nunca a vê. A troca de
    // médico/especialidade ainda só vale localmente (limitação de
    // `AppointmentService.reschedule`).
    unawaited(_persistReschedule(id, start));
  }
}

final appointmentsProvider =
    StateNotifierProvider<AppointmentsNotifier, List<Appointment>>((ref) {
  final clinicId = ref.watch(selectedClinicIdProvider);
  return AppointmentsNotifier(ref.watch(appointmentServiceProvider), clinicId);
});

/// Editável: perfil da clínica ativa (módulo perfil_clinica).
final editableClinicProvider =
    StateProvider<Clinic>((ref) => ref.watch(selectedClinicProvider));

/// Editável: perfil do usuário (módulo perfil_usuario).
final editableUserProvider =
    StateProvider<AppUser>((ref) => ref.watch(currentUserProvider));
