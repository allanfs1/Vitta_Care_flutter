import 'package:flutter/material.dart';

/// Papel de uma mensagem no chat do assistente.
enum AssistantRole { user, assistant }

/// Mensagem do chat do assistente.
class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.text,
    this.tourSuggestions = const [],
    this.streaming = false,
  });

  final AssistantRole role;
  final String text;

  /// Ids de tours oferecidos como chips de ação ("▶ iniciar tour").
  final List<String> tourSuggestions;

  /// `true` enquanto a resposta da IA ainda está sendo gerada.
  final bool streaming;

  AssistantMessage copyWith({
    String? text,
    List<String>? tourSuggestions,
    bool? streaming,
  }) =>
      AssistantMessage(
        role: role,
        text: text ?? this.text,
        tourSuggestions: tourSuggestions ?? this.tourSuggestions,
        streaming: streaming ?? this.streaming,
      );
}

/// Resposta da base de conhecimento local (FAQ/intents) do assistente.
class HelpAnswer {
  const HelpAnswer({
    required this.keywords,
    required this.answer,
    this.tour,
  });

  /// Termos/frases que disparam esta resposta (casamento sem acento).
  final List<String> keywords;

  /// Texto da resposta (curto, prático).
  final String answer;

  /// Tour relacionado oferecido como chip (opcional).
  final String? tour;
}

/// Um passo de um tour guiado.
class HelpStep {
  const HelpStep({
    required this.title,
    required this.body,
    this.anchorId,
    this.route,
  });

  final String title;
  final String body;

  /// Id do elemento a destacar (spotlight). Se nulo/não registrado, o passo é
  /// exibido centralizado.
  final String? anchorId;

  /// Rota para navegar antes de exibir o passo.
  final String? route;
}

/// Um tour guiado de uma funcionalidade.
class HelpTour {
  const HelpTour({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
    this.keywords = const [],
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<HelpStep> steps;
  final List<String> keywords;
}
