import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Avatar circular com fallback para iniciais (estilo dos mockups).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.imageBytes,
    this.radius = 22,
    this.color,
  });

  final String initials;
  final String? imageUrl;

  /// Imagem local (ex.: foto recém-selecionada da galeria/câmera). Tem
  /// precedência sobre [imageUrl].
  final Uint8List? imageBytes;

  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(imageBytes!));
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(imageUrl!));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
