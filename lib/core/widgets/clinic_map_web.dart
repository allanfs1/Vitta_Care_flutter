// Arquivo compilado apenas no alvo web (selecionado por conditional import em
// `clinic_map.dart`). O uso de `dart:html` é intencional para embutir o iframe.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Tipos de view já registrados — evita re-registrar o mesmo factory.
final Set<String> _registered = <String>{};

/// Implementação web: embute um Google Maps interativo via iframe usando a URL
/// pública `output=embed` (não requer chave de API).
Widget buildClinicMap(
    BuildContext context, double lat, double lng, String? label) {
  final viewType = 'clinic-map-${lat}_$lng';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      return html.IFrameElement()
        ..src = 'https://maps.google.com/maps?q=$lat,$lng&z=16&hl=pt-BR&output=embed'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
    });
  }
  return HtmlElementView(viewType: viewType);
}

/// Abre a URL do mapa numa nova aba do navegador.
void openClinicMap(String url) => html.window.open(url, '_blank');
