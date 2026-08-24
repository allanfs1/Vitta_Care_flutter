import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Filtros inteligentes aplicáveis ao logotipo.
enum LogoFilter { original, enhance, grayscale, brand }

extension LogoFilterLabel on LogoFilter {
  String get label => switch (this) {
        LogoFilter.original => 'Original',
        LogoFilter.enhance => 'Realçar',
        LogoFilter.grayscale => 'P&B',
        LogoFilter.brand => 'Marca',
      };
}

/// Opções de edição do logotipo.
class LogoEditOptions {
  const LogoEditOptions({
    this.zoom = 1.0,
    this.size = 256,
    this.removeBackground = false,
    this.smartCrop = false,
    this.filter = LogoFilter.original,
    this.circle = false,
    this.brandColor = 0xFF1B53D0,
  });

  final double zoom; // 1.0–3.0 (recorte central / aproximação)
  final int size; // tamanho de saída em px
  final bool removeBackground;
  final bool smartCrop;
  final LogoFilter filter;
  final bool circle;
  final int brandColor;

  LogoEditOptions copyWith({
    double? zoom,
    int? size,
    bool? removeBackground,
    bool? smartCrop,
    LogoFilter? filter,
    bool? circle,
    int? brandColor,
  }) {
    return LogoEditOptions(
      zoom: zoom ?? this.zoom,
      size: size ?? this.size,
      removeBackground: removeBackground ?? this.removeBackground,
      smartCrop: smartCrop ?? this.smartCrop,
      filter: filter ?? this.filter,
      circle: circle ?? this.circle,
      brandColor: brandColor ?? this.brandColor,
    );
  }
}

/// Processamento de imagem do logotipo (corte, fundo, filtros) com o pacote `image`.
class LogoProcessor {
  LogoProcessor._();

  /// Processa [src] segundo [opt] e retorna um PNG (Uint8List) quadrado.
  static Uint8List process(Uint8List src, LogoEditOptions opt) {
    var image = img.decodeImage(src);
    if (image == null) return src;

    // Trabalha com alfa e limita o tamanho de processamento para performance.
    image = image.convert(numChannels: 4);
    if (image.width > 768 || image.height > 768) {
      image = img.copyResize(image,
          width: image.width >= image.height ? 768 : null,
          height: image.height > image.width ? 768 : null);
    }

    // Cor de referência do fundo: média dos 4 cantos.
    final ref = _cornerColor(image);

    if (opt.removeBackground) {
      _removeBackground(image, ref, threshold: 60);
    }

    if (opt.smartCrop) {
      final box = _contentBounds(image, ref,
          useAlpha: opt.removeBackground, threshold: 48);
      if (box != null) {
        image = img.copyCrop(image,
            x: box[0], y: box[1], width: box[2], height: box[3]);
      }
    }

    // Recorte central quadrado com zoom.
    final side = (image.width < image.height ? image.width : image.height);
    final cropSide = (side / opt.zoom).round().clamp(8, side);
    final cx = (image.width - cropSide) ~/ 2;
    final cy = (image.height - cropSide) ~/ 2;
    image = img.copyCrop(image, x: cx, y: cy, width: cropSide, height: cropSide);

    // Filtros inteligentes.
    switch (opt.filter) {
      case LogoFilter.enhance:
        image = img.adjustColor(image, contrast: 1.15, brightness: 1.05, saturation: 1.1);
        break;
      case LogoFilter.grayscale:
        image = img.grayscale(image);
        break;
      case LogoFilter.brand:
        _duotone(image, opt.brandColor);
        break;
      case LogoFilter.original:
        break;
    }

    image = img.copyResize(image, width: opt.size, height: opt.size);

    if (opt.circle) {
      _applyCircleMask(image);
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  static List<int> _cornerColor(img.Image image) {
    final pts = [
      [0, 0],
      [image.width - 1, 0],
      [0, image.height - 1],
      [image.width - 1, image.height - 1],
    ];
    var r = 0, g = 0, b = 0;
    for (final p in pts) {
      final px = image.getPixel(p[0], p[1]);
      r += px.r.toInt();
      g += px.g.toInt();
      b += px.b.toInt();
    }
    return [r ~/ 4, g ~/ 4, b ~/ 4];
  }

  static double _dist(num r, num g, num b, List<int> ref) {
    final dr = r - ref[0], dg = g - ref[1], db = b - ref[2];
    return (dr * dr + dg * dg + db * db).toDouble();
  }

  static void _removeBackground(img.Image image, List<int> ref, {required double threshold}) {
    final t = threshold * threshold * 3;
    for (final px in image) {
      if (_dist(px.r, px.g, px.b, ref) < t) {
        px.a = 0;
      }
    }
  }

  /// Bounding box do conteúdo: [x, y, w, h] ou null.
  static List<int>? _contentBounds(img.Image image, List<int> ref,
      {required bool useAlpha, required double threshold}) {
    final t = threshold * threshold * 3;
    int minX = image.width, minY = image.height, maxX = -1, maxY = -1;
    for (final px in image) {
      final isContent = useAlpha
          ? px.a > 16
          : _dist(px.r, px.g, px.b, ref) > t;
      if (isContent) {
        final x = px.x, y = px.y;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0) return null;
    const pad = 4;
    minX = (minX - pad).clamp(0, image.width - 1);
    minY = (minY - pad).clamp(0, image.height - 1);
    maxX = (maxX + pad).clamp(0, image.width - 1);
    maxY = (maxY + pad).clamp(0, image.height - 1);
    return [minX, minY, maxX - minX + 1, maxY - minY + 1];
  }

  static void _duotone(img.Image image, int brandArgb) {
    final br = (brandArgb >> 16) & 0xFF;
    final bg = (brandArgb >> 8) & 0xFF;
    final bb = brandArgb & 0xFF;
    for (final px in image) {
      final lum = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b) / 255.0;
      // sombras → cor da marca, luzes → branco
      px.r = (br + (255 - br) * lum).round();
      px.g = (bg + (255 - bg) * lum).round();
      px.b = (bb + (255 - bb) * lum).round();
    }
  }

  static void _applyCircleMask(img.Image image) {
    final cx = image.width / 2, cy = image.height / 2;
    final radius = (image.width < image.height ? image.width : image.height) / 2;
    final r2 = radius * radius;
    for (final px in image) {
      final dx = px.x - cx, dy = px.y - cy;
      if (dx * dx + dy * dy > r2) px.a = 0;
    }
  }
}
