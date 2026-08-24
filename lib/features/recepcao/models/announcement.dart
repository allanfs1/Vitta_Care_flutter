import 'package:flutter/material.dart';

@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.author,
    required this.authorType,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String authorType; // e.g., 'SEED', 'ALERTA', 'TREINAMENTO'
  final String message;
  final DateTime createdAt;
}
