import 'dart:convert';

/// Plano de assinatura. Mapeia `tb_plans` (vínculo via `tb_plan_user`).
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.features,
    this.isPopular = false,
    this.userLimit,
    this.appointmentLimit,
    this.supportLevel = 'Padrão',
    this.hasIntegrations = false,
  });

  final String id;
  final String name;
  final String description;
  final double monthlyPrice;
  final double yearlyPrice;
  final List<String> features;
  final bool isPopular;
  final int? userLimit;
  final int? appointmentLimit;
  final String supportLevel;
  final bool hasIntegrations;

  /// Cria um [Plan] a partir de um documento `tb_plans` do Firestore.
  factory Plan.fromFirestore(String id, Map<String, dynamic> data) {
    double num$(dynamic v) => (v is num) ? v.toDouble() : 0;
    int? intOrNull(dynamic v) => (v is num) ? v.toInt() : null;

    // `recursosInclusos` pode ser uma string única ou lista separada por
    // quebras de linha / ';' / ','. Une com `beneficiosAdicionais` (array).
    final recursos = data['recursosInclusos'];
    final features = <String>[];

    void addFeatureStr(String str) {
      final s = str.trim();
      if (s.isNotEmpty) features.add(s);
    }

    if (recursos is String) {
      final text = recursos.trim();
      if ((text.startsWith('[') && text.endsWith(']')) ||
          (text.startsWith('{') && text.endsWith('}'))) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is List) {
            for (final e in decoded) {
              if (e is Map) {
                final nome = e['nomeRecurso']?.toString() ?? '';
                addFeatureStr(nome);
              } else {
                addFeatureStr(e.toString());
              }
            }
          } else if (decoded is Map) {
             final nome = decoded['nomeRecurso']?.toString() ?? '';
             addFeatureStr(nome);
          }
        } catch (_) {
          // Fallback to normal split
          text.split(RegExp(r'[\n;,]')).forEach(addFeatureStr);
        }
      } else {
        text.split(RegExp(r'[\n;,]')).forEach(addFeatureStr);
      }
    } else if (recursos is List) {
      for (final e in recursos) {
        if (e is Map) {
           final nome = e['nomeRecurso']?.toString() ?? '';
           addFeatureStr(nome);
        } else {
           addFeatureStr(e.toString());
        }
      }
    }

    if (data['beneficiosAdicionais'] is List) {
      for (final e in (data['beneficiosAdicionais'] as List)) {
        if (e is Map) {
           final nome = e['nomeRecurso']?.toString() ?? '';
           addFeatureStr(nome);
        } else {
           addFeatureStr(e.toString());
        }
      }
    }

    final monthly = num$(data['precoMensal'] ?? data['inter_preco_mes']);
    final yearly = num$(data['precoAnual'] ?? data['inter_preco_ano']);

    return Plan(
      id: id,
      name: (data['nome'] ?? 'Plano').toString(),
      description: (data['descricao'] ?? '').toString(),
      monthlyPrice: monthly,
      yearlyPrice: yearly > 0 ? yearly : monthly * 12,
      features: features.isEmpty ? const ['Recursos do plano'] : features,
      isPopular: data['isPopular'] == true,
      userLimit: intOrNull(data['limiteUsuarios']),
      appointmentLimit: intOrNull(data['limite_consulta']),
      supportLevel: (data['nivelSuporte'] ?? 'Padrão').toString(),
      hasIntegrations: data['intergracao'] == true,
    );
  }

  /// Economia percentual ao optar pelo plano anual.
  int get yearlyDiscountPercent {
    if (monthlyPrice <= 0) return 0;
    final fullYear = monthlyPrice * 12;
    if (fullYear <= 0) return 0;
    return (((fullYear - yearlyPrice) / fullYear) * 100).round();
  }
}
