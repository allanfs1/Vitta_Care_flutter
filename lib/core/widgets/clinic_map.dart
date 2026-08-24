import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
// Seleciona a implementação por plataforma: no navegador embute um mapa real
// do Google Maps (iframe, sem necessidade de chave); nas demais plataformas
// usa o cartão de fallback (`clinic_map_stub.dart`).
import 'clinic_map_stub.dart' if (dart.library.html) 'clinic_map_web.dart';

/// Mapa de localização da clínica. Renderiza um Google Maps embutido quando há
/// suporte (web) e, caso contrário, um cartão clicável que abre o mapa externo.
class ClinicMap extends StatelessWidget {
  const ClinicMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label,
    this.height = 220,
  });

  final double latitude;
  final double longitude;
  final String? label;
  final double height;

  /// URL para abrir a localização no Google Maps (web ou app).
  static String mapsUrl(double lat, double lng) =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceAltOf(context),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: buildClinicMap(context, latitude, longitude, label),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => openClinicMap(mapsUrl(latitude, longitude)),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Abrir no Google Maps'),
          ),
        ),
      ],
    );
  }
}
