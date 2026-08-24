import 'package:flutter/material.dart';

/// Prioridade de implementação de um módulo (AGENTS.md › Ordem de Implementação).
enum ModulePriority {
  p0('P0', 'Base — sem isso nada funciona', Color(0xFFC62828)),
  p1('P1', 'Fluxo diário da clínica', Color(0xFFC62828)),
  p2('P2', 'Essencial / analytics', Color(0xFFC77700)),
  p3('P3', 'Complementar / depende de integração', Color(0xFF2EA043));

  const ModulePriority(this.label, this.description, this.color);
  final String label;
  final String description;
  final Color color;
}

/// Estado de implementação do módulo no app atual.
enum ModuleStatus {
  implemented('Implementado', Color(0xFF2EA043)),
  partial('Parcial', Color(0xFFC77700)),
  planned('Planejado', Color(0xFF6B7280));

  const ModuleStatus(this.label, this.color);
  final String label;
  final Color color;
}

/// Descreve um módulo de funcionalidade (`features/<id>`) e suas dependências,
/// conforme o "Mapa de Dependências entre Módulos" do AGENTS.md.
///
/// Regras de isolamento codificadas:
/// - [ownedCollections]: coleções Firestore onde o módulo PODE escrever.
/// - [readsCollections]: coleções compartilhadas que o módulo apenas LÊ.
/// - [dependsOn]: ids de módulos dos quais este depende (arestas do grafo).
@immutable
class AppModule {
  const AppModule({
    required this.id,
    required this.title,
    required this.code,
    required this.icon,
    required this.priority,
    required this.status,
    this.route,
    this.dependsOn = const [],
    this.ownedCollections = const [],
    this.readsCollections = const [],
    this.description = '',
  });

  /// Identificador estável (corresponde à pasta em `features/`).
  final String id;

  /// Nome de exibição.
  final String title;

  /// Rótulo curto do diagrama (ex.: "Agend.(2)").
  final String code;

  final IconData icon;
  final ModulePriority priority;
  final ModuleStatus status;

  /// Rota associada (se navegável). `null` para módulos transversais.
  final String? route;

  final List<String> dependsOn;
  final List<String> ownedCollections;
  final List<String> readsCollections;
  final String description;
}
