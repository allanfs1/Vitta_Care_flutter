import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Fallback (mobile/desktop): sem iframe disponível, mostra um cartão com as
/// coordenadas. Um mapa interativo nativo exigiria `google_maps_flutter`.
Widget buildClinicMap(
    BuildContext context, double lat, double lng, String? label) {
  final t = Theme.of(context).textTheme;
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.place, color: AppColors.primary, size: 36),
        const SizedBox(height: AppSpacing.sm),
        if (label != null && label.isNotEmpty)
          Text(label, style: t.titleMedium, textAlign: TextAlign.center),
        Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            style: t.bodySmall),
      ],
    ),
  );
}

/// Fallback fora da web: sem navegador disponível, não há ação. Um app real
/// usaria `url_launcher` para abrir o mapa nativo.
void openClinicMap(String url) {}
