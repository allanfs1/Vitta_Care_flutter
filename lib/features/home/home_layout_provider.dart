import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/app_providers.dart';

/// IDs dos blocos da Home na ordem padrão.
const kDefaultBlockOrder = <String>[
  'carousel_appointments',
  'unit_profile',
  'week_selector',
  'shortcuts',
  'kpis',
  'faturamento',
  'charts',
  'density',
  'reallocation',
  'next_appointments',
];

/// Rótulos legíveis dos blocos (usado no drag handle).
const kBlockLabels = <String, String>{
  'carousel_appointments': 'Carrossel de Agendamentos',
  'unit_profile': 'Perfil da Unidade',
  'week_selector': 'Esta Semana',
  'shortcuts': 'Atalhos Rápidos',
  'kpis': 'Indicadores',
  'faturamento': 'Evolução do Faturamento',
  'charts': 'Gráficos',
  'density': 'Densidade de Agendamento',
  'reallocation': 'Eficiência de Realocação',
  'next_appointments': 'Próximos Agendamentos',
};

/// Controla a ordem dos blocos da Home, persistindo em SharedPreferences.
class HomeLayoutController extends StateNotifier<List<String>> {
  HomeLayoutController(this._prefs) : super(_load(_prefs));

  static const _key = 'home_block_order';
  final SharedPreferences _prefs;

  static List<String> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return List.of(kDefaultBlockOrder);
    try {
      final decoded = (jsonDecode(raw) as List).cast<String>();
      // Garante que todos os blocos existentes apareçam (merge seguro).
      final known = Set.of(kDefaultBlockOrder);
      final result = <String>[];
      for (final id in decoded) {
        if (known.contains(id)) {
          result.add(id);
          known.remove(id);
        }
      }
      // Blocos novos que não estavam salvos vão ao final.
      result.addAll(known);
      return result;
    } catch (_) {
      return List.of(kDefaultBlockOrder);
    }
  }

  void _save() {
    _prefs.setString(_key, jsonEncode(state));
  }

  /// Reordena via callback do ReorderableListView.
  void reorder(List<String> visibleOrder, int oldIndex, int newIndex) {
    final list = List.of(visibleOrder);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    
    // Merge back with any hidden items that are in state but not in visibleOrder
    final hiddenItems = state.where((id) => !list.contains(id)).toList();
    state = [...list, ...hiddenItems];
    _save();
  }

  /// Restaura a ordem padrão.
  void resetOrder() {
    state = List.of(kDefaultBlockOrder);
    _save();
  }
}

final homeLayoutProvider =
    StateNotifierProvider<HomeLayoutController, List<String>>((ref) {
  return HomeLayoutController(ref.watch(sharedPrefsProvider));
});
