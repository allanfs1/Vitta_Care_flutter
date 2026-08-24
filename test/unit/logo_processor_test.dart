import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vitta_app/features/configuracoes/widgets/logo_processor.dart';

/// Testes do processamento de logotipo (corte, fundo, filtros, redimensionar).
Uint8List _sampleLogo() {
  // Fundo branco com um quadrado azul central (simula logo com fundo).
  final image = img.Image(width: 120, height: 120, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
  img.fillRect(image,
      x1: 40, y1: 40, x2: 80, y2: 80, color: img.ColorRgba8(20, 80, 200, 255));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('process gera PNG quadrado no tamanho de saída', () {
    final out = LogoProcessor.process(
      _sampleLogo(),
      const LogoEditOptions(size: 128),
    );
    final decoded = img.decodeImage(out);
    expect(decoded, isNotNull);
    expect(decoded!.width, 128);
    expect(decoded.height, 128);
  });

  test('limpar fundo torna o fundo branco transparente', () {
    final out = LogoProcessor.process(
      _sampleLogo(),
      const LogoEditOptions(size: 128, removeBackground: true),
    );
    final decoded = img.decodeImage(out)!;
    // Canto (fundo) deve ficar transparente; centro (logo) opaco.
    expect(decoded.getPixel(2, 2).a, lessThan(16));
    expect(decoded.getPixel(64, 64).a, greaterThan(200));
  });

  test('corte inteligente recorta nas bordas do conteúdo', () {
    final out = LogoProcessor.process(
      _sampleLogo(),
      const LogoEditOptions(size: 100, removeBackground: true, smartCrop: true),
    );
    final decoded = img.decodeImage(out)!;
    // Após o trim, o conteúdo ocupa boa parte da imagem → centro opaco.
    expect(decoded.getPixel(50, 50).a, greaterThan(200));
  });

  test('filtro P&B remove a saturação (R≈G≈B)', () {
    final out = LogoProcessor.process(
      _sampleLogo(),
      const LogoEditOptions(size: 64, filter: LogoFilter.grayscale),
    );
    final decoded = img.decodeImage(out)!;
    final px = decoded.getPixel(32, 32);
    expect((px.r - px.g).abs(), lessThan(4));
    expect((px.g - px.b).abs(), lessThan(4));
  });
}
