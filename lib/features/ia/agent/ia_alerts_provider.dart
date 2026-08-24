import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_providers.dart';

/// Severidade do alerta.
enum AlertSeverity { warning, critical }

/// Alerta proativo exibido na barra do topo da /ia (AgentAI.md §7.1.3).
class IaAlert {
  const IaAlert({
    required this.label,
    required this.icon,
    required this.severity,
    required this.prompt,
  });

  /// Texto curto exibido no chip.
  final String label;

  /// Nome do ícone material (mapeado na UI).
  final String icon;
  final AlertSeverity severity;

  /// Pergunta enviada ao chat ao clicar no alerta.
  final String prompt;
}

/// Varre o dia (escopo da clínica) a cada 60s e devolve alertas reais:
/// e-mails com falha e overbookings nas últimas 24h.
final iaAlertsProvider = StreamProvider<List<IaAlert>>((ref) async* {
  final clinicaId = ref.watch(selectedClinicIdProvider);
  if (clinicaId.isEmpty) {
    yield const [];
    return;
  }
  final db = FirebaseFirestore.instance;
  while (true) {
    yield await _compute(db, clinicaId);
    await Future<void>.delayed(const Duration(seconds: 60));
  }
});

Future<List<IaAlert>> _compute(FirebaseFirestore db, String clinicaId) async {
  final alerts = <IaAlert>[];

  // 1) E-mails com erro na fila (escopo da clínica).
  try {
    final snap = await db
        .collection('email_queue')
        .where('idclinica', isEqualTo: clinicaId)
        .limit(200)
        .get();
    final failed = snap.docs.where((d) {
      final s = (d.data()['status'] ?? '').toString().toLowerCase();
      return s == 'failed' || s == 'erro' || s == 'error';
    }).length;
    if (failed > 0) {
      alerts.add(IaAlert(
        label: '$failed e-mail(s) com erro',
        icon: 'mail',
        severity: AlertSeverity.critical,
        prompt: 'Liste os e-mails com status de falha na fila e sugira o que fazer.',
      ));
    }
  } catch (_) {/* coleção pode não existir */}

  // 2) Overbookings nas últimas 24h.
  try {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final snap = await db.collection('tb_overbooking_events').limit(300).get();
    final recent = snap.docs.where((d) {
      final data = d.data();
      final ts = data['createdAt'] ?? data['data'] ?? data['date'];
      if (ts is Timestamp) return ts.toDate().isAfter(since);
      return false;
    }).length;
    if (recent > 0) {
      alerts.add(IaAlert(
        label: '$recent overbooking nas últimas 24h',
        icon: 'calendar',
        severity: AlertSeverity.warning,
        prompt: 'Resuma os eventos de overbooking das últimas 24h.',
      ));
    }
  } catch (_) {/* coleção pode não existir */}

  return alerts;
}
