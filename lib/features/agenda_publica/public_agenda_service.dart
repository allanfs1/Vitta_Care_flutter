import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/models/doctor.dart';
import '../totem/models/totem_config.dart';

/// Host das Cloud Functions (Gen 2) — mesma convenção de
/// `lib/core/modules/mcp/tools/comunicacao_tools.dart`.
const String _functionsHost =
    'https://us-central1-agendaclinica-457713.cloudfunctions.net';

/// Dados públicos de um médico + a ocupação de um dia, devolvidos por
/// `functions/publicAgendaProxy.js`. Contém só o que a página `/agenda-publica`
/// mostra por design (perfil profissional, config de horário da clínica) — os
/// [appointments] são apenas os **horários de início** já ocupados, sem nome,
/// CPF, telefone ou motivo de ninguém (ver o cabeçalho de
/// `agenda_publica_screen.dart` para o porquê).
class AgendaPublicaDados {
  const AgendaPublicaDados({
    required this.found,
    this.doctor,
    this.totemConfig = const TotemConfig(),
    this.appointments = const [],
  });

  final bool found;
  final Doctor? doctor;
  final TotemConfig totemConfig;
  final List<DateTime> appointments;
}

/// Resultado de uma solicitação de horário (`publicAgendaSolicitar`).
class SolicitacaoResultado {
  const SolicitacaoResultado.ok({required this.protocolo})
      : ok = true,
        erro = null;

  const SolicitacaoResultado.falha(String codigo)
      : ok = false,
        protocolo = null,
        erro = codigo;

  final bool ok;
  final String? protocolo;

  /// Código cru vindo do servidor (`nome_invalido`, `sem_vaga`,
  /// `duplicado_no_dia`, `limite_futuras`, `rede`, ...) — a tela traduz para
  /// a mensagem exibida ao visitante.
  final String? erro;
}

/// Backend da agenda pública do médico — nunca fala com o Firestore
/// diretamente pelo SDK do cliente (ver o cabeçalho de
/// `agenda_publica_screen.dart`): as duas Cloud Functions usam o Admin SDK e
/// devolvem/persistem só o necessário.
abstract class PublicAgendaService {
  /// Perfil do médico + horários ocupados no dia [inicio, fim) (local).
  Future<AgendaPublicaDados> fetchAgenda({
    required String doctorId,
    required DateTime inicio,
    required DateTime fim,
  });

  /// Solicita um horário — grava como pré-agendado; a clínica confirma
  /// depois. Nunca lança: erros voltam como `SolicitacaoResultado.falha`.
  Future<SolicitacaoResultado> solicitar({
    required String doctorId,
    required DateTime start,
    required int duracao,
    required DateTime diaInicio,
    required DateTime diaFim,
    required String nome,
    required String telefone,
    String? email,
  });
}

class HttpPublicAgendaService implements PublicAgendaService {
  HttpPublicAgendaService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AgendaPublicaDados> fetchAgenda({
    required String doctorId,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final uri = Uri.parse('$_functionsHost/publicAgendaProxy').replace(
      queryParameters: {
        'medicoId': doctorId,
        'inicioMs': inicio.millisecondsSinceEpoch.toString(),
        'fimMs': fim.millisecondsSinceEpoch.toString(),
      },
    );
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return const AgendaPublicaDados(found: false);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['found'] != true) return const AgendaPublicaDados(found: false);

      final dRaw = (body['doctor'] as Map).cast<String, dynamic>();
      final photoUrl = (dRaw['photoUrl'] as String? ?? '').trim();
      final doctor = Doctor(
        id: dRaw['id'] as String? ?? doctorId,
        name: dRaw['name'] as String? ?? 'Sem nome',
        crm: dRaw['crm'] as String? ?? '',
        specialties: ((dRaw['specialties'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        clinicId: dRaw['clinicId'] as String? ?? '',
        photoUrl: photoUrl.isEmpty ? null : photoUrl,
        email: dRaw['email'] as String?,
        phone: dRaw['phone'] as String?,
        address: dRaw['address'] as String?,
        bio: dRaw['bio'] as String?,
        experience: dRaw['experience'] as String?,
        active: dRaw['active'] as bool? ?? true,
        slotLimit: (dRaw['slotLimit'] as num?)?.toInt() ?? 1,
        maxOverbook: (dRaw['maxOverbook'] as num?)?.toInt() ?? 0,
      );

      final cfgRaw =
          (body['totemConfig'] as Map?)?.cast<String, dynamic>() ?? const {};
      final totemConfig = TotemConfig(
        clinicName: cfgRaw['clinicName'] as String? ?? 'Agenda Clínica',
        accent: (cfgRaw['accent'] as num?)?.toInt() ?? 0xFFFF3B30,
        showClock: cfgRaw['showClock'] as bool? ?? true,
        showOccupancy: cfgRaw['showOccupancy'] as bool? ?? true,
        scale: (cfgRaw['scale'] as num?)?.toDouble() ?? 1.0,
        showCalendarButton: cfgRaw['showCalendarButton'] as bool? ?? true,
        appointmentDuration:
            (cfgRaw['appointmentDuration'] as num?)?.toInt() ?? 30,
        maxDaysAhead: (cfgRaw['maxDaysAhead'] as num?)?.toInt() ?? 365,
        openHour: (cfgRaw['openHour'] as num?)?.toInt() ?? 8,
        closeHour: (cfgRaw['closeHour'] as num?)?.toInt() ?? 17,
        openSaturday: cfgRaw['openSaturday'] as bool? ?? true,
        saturdayCloseHour:
            (cfgRaw['saturdayCloseHour'] as num?)?.toInt() ?? 12,
        openSunday: cfgRaw['openSunday'] as bool? ?? false,
        lunchBreakEnabled: cfgRaw['lunchBreakEnabled'] as bool? ?? false,
        lunchStartHour: (cfgRaw['lunchStartHour'] as num?)?.toInt() ?? 12,
        lunchEndHour: (cfgRaw['lunchEndHour'] as num?)?.toInt() ?? 13,
      );

      final apptsRaw = (body['appointments'] as List?) ?? const [];
      final appointments = apptsRaw
          .map((e) => ((e as Map)['startMs'] as num?)?.toInt())
          .whereType<int>()
          .map(DateTime.fromMillisecondsSinceEpoch)
          .toList();

      return AgendaPublicaDados(
        found: true,
        doctor: doctor,
        totemConfig: totemConfig,
        appointments: appointments,
      );
    } catch (_) {
      return const AgendaPublicaDados(found: false);
    }
  }

  @override
  Future<SolicitacaoResultado> solicitar({
    required String doctorId,
    required DateTime start,
    required int duracao,
    required DateTime diaInicio,
    required DateTime diaFim,
    required String nome,
    required String telefone,
    String? email,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_functionsHost/publicAgendaSolicitar'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'medicoId': doctorId,
              'startMs': start.millisecondsSinceEpoch,
              'diaInicioMs': diaInicio.millisecondsSinceEpoch,
              'diaFimMs': diaFim.millisecondsSinceEpoch,
              'duracao': duracao,
              'nome': nome,
              'telefone': telefone,
              if (email != null && email.isNotEmpty) 'email': email,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['ok'] == true) {
        return SolicitacaoResultado.ok(
            protocolo: (body['protocolo'] as String?) ?? '—');
      }
      return SolicitacaoResultado.falha(
          (body['error'] as String?) ?? 'falha_interna');
    } catch (_) {
      return const SolicitacaoResultado.falha('rede');
    }
  }
}

final publicAgendaServiceProvider =
    Provider<PublicAgendaService>((ref) => HttpPublicAgendaService());

/// Chave: `(doctorId, início do dia local em ms, fim do dia local em ms)`.
final publicAgendaDataProvider =
    FutureProvider.family<AgendaPublicaDados, (String, int, int)>((ref, key) {
  final svc = ref.watch(publicAgendaServiceProvider);
  return svc.fetchAgenda(
    doctorId: key.$1,
    inicio: DateTime.fromMillisecondsSinceEpoch(key.$2),
    fim: DateTime.fromMillisecondsSinceEpoch(key.$3),
  );
});
