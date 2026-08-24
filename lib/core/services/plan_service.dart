import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/plan.dart';
import 'mock_data.dart';

/// Fonte dos planos de assinatura (módulo auth / escolher plano).
abstract class PlanService {
  /// Retorna os planos disponíveis (catálogo `tb_plans`).
  Future<List<Plan>> fetchPlans();
}

/// Lê os planos da coleção **`tb_plans`** do Firestore.
class FirestorePlanService implements PlanService {
  FirestorePlanService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<List<Plan>> fetchPlans() async {
    final snap = await _db.collection('tb_plans').get();
    final plans = <Plan>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final status = (data['status'] ?? 'active').toString().toLowerCase();
      // Ignora planos desativados/ocultos.
      if (status == 'inactive' || status == 'inativo' || status == 'hidden') {
        continue;
      }
      plans.add(Plan.fromFirestore(doc.id, data));
    }
    // Ordena pelo preço mensal (do mais barato ao mais caro).
    plans.sort((a, b) => a.monthlyPrice.compareTo(b.monthlyPrice));
    return plans;
  }
}

/// Planos simulados (offline/testes) — espelha `tb_plans`.
class MockPlanService implements PlanService {
  const MockPlanService();

  @override
  Future<List<Plan>> fetchPlans() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return MockData.plans;
  }
}
