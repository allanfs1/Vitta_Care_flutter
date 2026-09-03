import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/app_providers.dart';
import 'core/services/appointment_service.dart';
import 'core/services/error_reporter.dart';
import 'core/services/auth_service.dart';
import 'core/services/clinic_service.dart';
import 'core/services/doctor_service.dart';
import 'core/services/plan_service.dart';
import 'core/services/user_service.dart';
import 'features/overbooking/overbooking_providers.dart';
import 'features/monte_carlo/monte_carlo_persistencia.dart';
import 'features/monte_carlo/monte_carlo_providers.dart';
import 'features/overbooking/realocacao_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final prefs = await SharedPreferences.getInstance();

  // Inicializa o Firebase Authentication. Se falhar (config/rede ausente),
  // o app continua com o serviço de auth simulado.
  var firebaseOk = false;
  AuthService authService = MockAuthService();
  PlanService planService = const MockPlanService();
  ClinicService clinicService = const MockClinicService();
  UserService userService = const MockUserService();
  AppointmentService appointmentService = const MockAppointmentService();
  DoctorService doctorService = const MockDoctorService();
  RealocacaoService realocacaoService = const MockRealocacaoService();
  MonteCarloRepositorio mcRepositorio = const MockMonteCarloRepositorio();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    authService = FirebaseAuthService();
    planService = FirestorePlanService();
    clinicService = FirestoreClinicService();
    userService = FirestoreUserService();
    appointmentService = FirestoreAppointmentService();
    doctorService = FirestoreDoctorService();
    realocacaoService = FirestoreRealocacaoService();
    mcRepositorio = FirestoreMonteCarloRepositorio(FirebaseFirestore.instance);
    firebaseOk = true;
  } catch (e) {
    debugPrint('Firebase indisponível, usando serviços simulados: $e');
  }

  // Captura erros não tratados antes de qualquer widget subir. Sem isto, um
  // crash em produção só aparecia se o usuário reportasse — e a maioria não
  // reporta, só para de usar a tela que quebrou.
  ErrorReporter.instalar(podeGravar: firebaseOk);

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(authService),
        planServiceProvider.overrideWithValue(planService),
        clinicServiceProvider.overrideWithValue(clinicService),
        userServiceProvider.overrideWithValue(userService),
        appointmentServiceProvider.overrideWithValue(appointmentService),
        doctorServiceProvider.overrideWithValue(doctorService),
        realocacaoServiceProvider.overrideWithValue(realocacaoService),
        mcRepositorioProvider.overrideWithValue(mcRepositorio),
      ],
      child: const VittaApp(),
    ),
  );
}
