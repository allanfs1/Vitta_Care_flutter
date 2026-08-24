import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitta_app/app.dart';
import 'package:vitta_app/core/services/app_providers.dart';

void main() {
  testWidgets('Vitta app builds and shows the dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth_logged_in': true,
      'auth_plan_id': 'plan_pro',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const VittaApp(),
      ),
    );
    await tester.pump();

    // A clínica padrão (UBS Centro) deve aparecer no cabeçalho do dashboard.
    expect(find.text('UBS Centro'), findsWidgets);
  });
}
