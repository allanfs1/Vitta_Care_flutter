import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/models/nota_enums.dart';
import 'grafo_engine.dart';
import 'grafo_modelo.dart';

/// Cache LRU de parágrafos de texto (`obsidian.md` §7.4).
class LabelCache {
  LabelCache({this.capacidade = 600});

  final int capacidade;
  final _lru = <String, ui.Paragraph>{};

  ui.Paragraph obter(
    String texto,
    double tamanhoFonte,
    Color cor, {
    FontWeight peso = FontWeight.w500,
    double largura = 130.0,
    bool sombra = true,
  }) {
    final chave =
        '$texto|${tamanhoFonte.toStringAsFixed(1)}|${cor.toARGB32()}|${peso.value}|$largura';
    final existente = _lru.remove(chave);
    if (existente != null) {
      _lru[chave] = existente;
      return existente;
    }

    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: tamanhoFonte,
      fontWeight: peso,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    ))
      ..pushStyle(ui.TextStyle(
        color: cor,
        shadows: sombra
            ? const [
                ui.Shadow(
                  color: Color(0xE6000000),
                  blurRadius: 3.5,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ))
      ..addText(texto);

    final p = builder.build()
      ..layout(ui.ParagraphConstraints(width: largura));

    _lru[chave] = p;
    if (_lru.length > capacidade) _lru.remove(_lru.keys.first);
    return p;
  }

  void limpar() => _lru.clear();
}

/// Paleta do grafo no estilo Obsidian, sensível ao tema (§10.5.3).
class PaletaGrafo {
  const PaletaGrafo({
    required this.fundo,
    required this.aresta,
    required this.arestaDestaque,
    required this.arestaSemantica,
    required this.rotulo,
    required this.rotuloFoco,
    required this.halo,
  });

  final Color fundo;
  final Color aresta;
  final Color arestaDestaque;
  final Color arestaSemantica;
  final Color rotulo;
  final Color rotuloFoco;
  final Color halo;

  static const escura = PaletaGrafo(
    fundo: Color(0xFF14161B),
    aresta: Color(0xFF3B4354),
    arestaDestaque: Color(0xFFF43F5E),
    arestaSemantica: Color(0xFF8B5CF6),
    rotulo: Color(0xFFCBD5E1),
    rotuloFoco: Color(0xFFFFFFFF),
    halo: Color(0x66F43F5E),
  );

  static const clara = PaletaGrafo(
    fundo: Color(0xFFF8FAFC),
    aresta: Color(0xFFCBD5E1),
    arestaDestaque: Color(0xFFE11D48),
    arestaSemantica: Color(0xFF7C3AED),
    rotulo: Color(0xFF334155),
    rotuloFoco: Color(0xFF0F172A),
    halo: Color(0x59F43F5E),
  );

  static PaletaGrafo de(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? escura : clara;
}

/// Estado visual de interação, separado da topologia.
class EstadoInteracao {
  const EstadoInteracao({
    this.selecionado,
    this.hover,
    this.emFoco = const {},
    this.arestasDestacadas = const {},
    this.fase = 0,
  });

  final int? selecionado;
  final int? hover;

  /// Índices de nós em destaque (modo foco). Vazio = tudo normal.
  final Set<int> emFoco;

  /// Índices de arestas destacadas.
  final Set<int> arestasDestacadas;

  /// Fase 0..1 da animação de fluxo das arestas.
  final double fase;

  bool get temFoco => emFoco.isNotEmpty;
}

/// Pintor do grafo com suporte a:
/// - Radar de Risco (nós críticos em alerta pulsante)
/// - Rótulos de Galáxias/Clusters
/// - Grafo de Causa e Efeito
class GrafoPainter extends CustomPainter {
  GrafoPainter({
    required this.engine,
    required this.config,
    required this.paleta,
    required this.cache,
    required this.offset,
    required this.escala,
    required this.interacao,
    required this.modoPerformance,
    this.buscaAtiva = const {},
    this.nosCriticos = const {},
    this.modoRadarRisco = false,
    this.exibirRotulosClusters = false,
    this.causas = const {},
    this.efeitos = const {},
  }) : super(repaint: engine);

  final GrafoEngine engine;
  final ConfigGrafo config;
  final PaletaGrafo paleta;
  final LabelCache cache;

  /// Translação da câmera, em pixels de tela.
  final Offset offset;
  final double escala;
  final EstadoInteracao interacao;

  /// Degradação ativa (§7.5) — desliga rótulos e arestas fracas.
  final bool modoPerformance;

  /// Conjunto de IDs das notas encontradas pela busca (efeito spotlight).
  final Set<String> buscaAtiva;

  /// Conjunto de IDs de nós com desvios, faltas ou problemas.
  final Set<String> nosCriticos;

  /// Modo Radar de Risco ativo.
  final bool modoRadarRisco;

  /// Exibir banners translúcidos sobre cada cluster.
  final bool exibirRotulosClusters;

  /// Nós de causa (origem) no grafo de impacto.
  final Set<String> causas;

  /// Nós de efeito (consequência) no grafo de impacto.
  final Set<String> efeitos;

  Grafo get grafo => engine.grafo;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paleta.fundo);
    if (grafo.vazio) return;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(escala);

    // Retângulo visível no espaço do grafo com folga de culling
    final visivel = Rect.fromLTWH(
      -offset.dx / escala,
      -offset.dy / escala,
      size.width / escala,
      size.height / escala,
    ).inflate(size.width * 0.15 / escala);

    _pintarArestas(canvas, visivel);
    _pintarNos(canvas, visivel);
    canvas.restore();

    if (exibirRotulosClusters && escala >= 0.15) {
      _pintarRotulosClusters(canvas, size, visivel);
    }
    _pintarRotulos(canvas, size, visivel);
  }

  // ── Arestas ────────────────────────────────────────────────────────────────

  void _pintarArestas(Canvas canvas, Rect visivel) {
    final px = engine.px;
    final py = engine.py;
    final destacadas = <double>[];
    final temFoco = interacao.temFoco;
    final temCausaEfeito = causas.isNotEmpty || efeitos.isNotEmpty;

    final buckets = <int, List<double>>{1: [], 2: [], 3: [], 4: []};

    for (var e = 0; e < grafo.arestas.length; e++) {
      final a = grafo.arestas[e];
      final u = a.de, v = a.para;
      final x1 = px[u], y1 = py[u];
      final x2 = px[x2Idx(v)], y2 = py[x2Idx(v)];

      if (!_segmentoVisivel(x1, y1, x2, y2, visivel)) continue;

      final deId = grafo.nos[u].id;
      final paraId = grafo.nos[v].id;

      final ehCausaEfeito = temCausaEfeito &&
          ((causas.contains(deId) && causas.contains(paraId)) ||
              (efeitos.contains(deId) && efeitos.contains(paraId)) ||
              (causas.contains(deId) && paraId == grafo.nos[interacao.selecionado ?? 0].id) ||
              (deId == grafo.nos[interacao.selecionado ?? 0].id && efeitos.contains(paraId)));

      final ehDestacada =
          ehCausaEfeito || interacao.arestasDestacadas.contains(e);

      if (ehDestacada) {
        destacadas..add(x1)..add(y1)..add(x2)..add(y2);
      } else if (!temFoco && !modoRadarRisco) {
        final bucket = buckets[a.tipo.index + 1] ?? buckets[1]!;
        bucket..add(x1)..add(y1)..add(x2)..add(y2);
      }
    }

    final temBusca = buscaAtiva.isNotEmpty;
    final opacidades = grafo.n > 400
        ? const {1: 0.45, 2: 0.25, 3: 0.10, 4: 0.04}
        : const {1: 0.85, 2: 0.45, 3: 0.20, 4: 0.08};
    final espessura = config.espessuraLinha * (grafo.n > 500 ? 0.7 : 1.0);

    buckets.forEach((nivel, pontos) {
      if (pontos.isEmpty) return;
      final alfaBase = opacidades[nivel]!;
      final alfaFinal =
          (temBusca || modoRadarRisco) ? (alfaBase * 0.12) : alfaBase;
      final paint = Paint()
        ..color = paleta.aresta.withValues(alpha: alfaFinal)
        ..strokeWidth = espessura
        ..strokeCap = StrokeCap.round;
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(pontos),
        paint,
      );
    });

    if (destacadas.isNotEmpty) {
      final paint = Paint()
        ..color = temCausaEfeito
            ? const Color(0xFFF43F5E)
            : paleta.arestaDestaque
        ..strokeWidth = espessura * 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(destacadas),
        paint,
      );
    }
  }

  int x2Idx(int v) => v < grafo.n ? v : 0;

  bool _segmentoVisivel(double x1, double y1, double x2, double y2, Rect r) {
    final minX = x1 < x2 ? x1 : x2;
    final maxX = x1 < x2 ? x2 : x1;
    final minY = y1 < y2 ? y1 : y2;
    final maxY = y1 < y2 ? y2 : y1;
    return maxX >= r.left && minX <= r.right && maxY >= r.top && minY <= r.bottom;
  }

  // ── Nós ───────────────────────────────────────────────────────────────────

  void _pintarNos(Canvas canvas, Rect visivel) {
    final px = engine.px;
    final py = engine.py;
    final temFoco = interacao.temFoco;
    final temBusca = buscaAtiva.isNotEmpty;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < grafo.n; i++) {
      final x = px[i], y = py[i];
      final no = grafo.nos[i];
      if (!visivel.contains(Offset(x, y))) continue;

      final casaBusca = temBusca && buscaAtiva.contains(no.id);
      final ehCritico = nosCriticos.contains(no.id);
      final ehCausa = causas.contains(no.id);
      final ehEfeito = efeitos.contains(no.id);

      var opacidade = 1.0;
      if (modoRadarRisco) {
        opacidade = ehCritico ? 1.0 : 0.08;
      } else if (temBusca) {
        opacidade = casaBusca ? 1.0 : 0.08;
      } else if (temFoco && !interacao.emFoco.contains(i)) {
        opacidade = 0.12;
      }

      final r = no.raio;

      // 1. Halo do Modo Radar de Risco (Vermelho Pulsante)
      if (modoRadarRisco && ehCritico) {
        canvas.drawCircle(
          Offset(x, y),
          r + 8.0,
          Paint()
            ..color = const Color(0xFFEF4444).withValues(alpha: 0.60)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
        );
      }

      // 2. Halo Causa (Vermelho) & Efeito (Âmbar/Ciano)
      if (ehCausa) {
        canvas.drawCircle(
          Offset(x, y),
          r + 6.0,
          Paint()
            ..color = const Color(0xFFEF4444).withValues(alpha: 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
        );
      } else if (ehEfeito) {
        canvas.drawCircle(
          Offset(x, y),
          r + 6.0,
          Paint()
            ..color = const Color(0xFFF59E0B).withValues(alpha: 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
        );
      }

      // 3. Halo de busca (dourado)
      if (casaBusca && !modoRadarRisco) {
        canvas.drawCircle(
          Offset(x, y),
          r + 5.5,
          Paint()
            ..color = const Color(0xF5F59E0B)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
        );
      }

      // 4. Halo de seleção/hover
      if (i == interacao.selecionado || i == interacao.hover) {
        canvas.drawCircle(
          Offset(x, y),
          r + 4.5,
          Paint()
            ..color = paleta.halo
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }

      Color corFinal = (modoRadarRisco && ehCritico)
          ? const Color(0xFFEF4444)
          : no.cor.withValues(alpha: opacidade);

      paint.color = corFinal;
      _desenharForma(canvas, no.forma, Offset(x, y), r, paint);

      // Anéis de destaque
      if ((modoRadarRisco && ehCritico) || casaBusca || ehCausa || ehEfeito) {
        canvas.drawCircle(
          Offset(x, y),
          r + 1.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = (ehCausa || (modoRadarRisco && ehCritico))
                ? const Color(0xFFFECACA)
                : const Color(0xFFFDE047),
        );
      }
    }
  }

  void _desenharForma(
      Canvas canvas, NoForma forma, Offset c, double r, Paint paint) {
    switch (forma) {
      case NoForma.circulo:
        canvas.drawCircle(c, r, paint);
      case NoForma.circuloVazado:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = paint.color,
        );
      case NoForma.quadrado:
        canvas.drawRect(
          Rect.fromCenter(center: c, width: r * 1.7, height: r * 1.7),
          paint,
        );
      case NoForma.losango:
        final p = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
        canvas.drawPath(p, paint);
      case NoForma.triangulo:
        final p = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.92, c.dy + r * 0.7)
          ..lineTo(c.dx - r * 0.92, c.dy + r * 0.7)
          ..close();
        canvas.drawPath(p, paint);
    }
  }

  // ── Rótulos de Galáxias/Clusters ──────────────────────────────────────────

  void _pintarRotulosClusters(Canvas canvas, Size size, Rect visivel) {
    if (!exibirRotulosClusters) return;
    final grupos = <int, List<int>>{};
    for (var i = 0; i < grafo.n; i++) {
      final c = grafo.nos[i].cluster;
      if (c > 0) {
        (grupos[c] ??= []).add(i);
      }
    }
    if (grupos.isEmpty) return;

    final px = engine.px;
    final py = engine.py;

    grupos.forEach((clusterId, membros) {
      if (membros.length < 3) return;

      var somaX = 0.0, somaY = 0.0, cont = 0;
      for (final idx in membros) {
        if (idx < grafo.n) {
          somaX += px[idx];
          somaY += py[idx];
          cont++;
        }
      }
      if (cont == 0) return;
      final cx = somaX / cont;
      final cy = somaY / cont;

      if (!visivel.contains(Offset(cx, cy))) return;

      final telaX = cx * escala + offset.dx;
      final telaY = cy * escala + offset.dy;

      if (telaX < -150 ||
          telaX > size.width + 150 ||
          telaY < -50 ||
          telaY > size.height + 50) {
        return;
      }

      // Nome do cluster baseado no nó de maior pagerank
      membros.sort((a, b) =>
          grafo.nos[b].pagerank.compareTo(grafo.nos[a].pagerank));
      final noPrincipal = grafo.nos[membros.first];
      final nomeCluster = noPrincipal.rotulo.toUpperCase();
      final corCluster = noPrincipal.cor;

      final p = cache.obter(
        '✦ $nomeCluster',
        13.0,
        corCluster.withValues(alpha: 0.90),
        peso: FontWeight.w700,
        largura: 260.0,
        sombra: true,
      );

      final pillW = (p.maxIntrinsicWidth + 14).clamp(30.0, 280.0);
      final pillH = p.height + 6;
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(telaX, telaY),
          width: pillW,
          height: pillH,
        ),
        const Radius.circular(12),
      );

      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = paleta.fundo.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        pillRect,
        Paint()
          ..color = corCluster.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      canvas.drawParagraph(
        p,
        Offset(telaX - p.width / 2, telaY - p.height / 2),
      );
    });
  }

  // ── Rótulos de Nós ────────────────────────────────────────────────────────

  void _pintarRotulos(Canvas canvas, Size size, Rect visivel) {
    if (!config.mostrarRotulos &&
        !interacao.temFoco &&
        interacao.hover == null &&
        interacao.selecionado == null &&
        buscaAtiva.isEmpty &&
        !modoRadarRisco &&
        causas.isEmpty &&
        efeitos.isEmpty) {
      return;
    }

    final px = engine.px;
    final py = engine.py;
    final tamanhoBase = (10.5 * config.tamanhoRotulo).clamp(8.0, 18.0);
    final tamanhoDestaque = (11.5 * config.tamanhoRotulo).clamp(9.0, 20.0);
    final larguraMax = 140.0 * config.tamanhoRotulo;

    var nVisiveis = 0;
    for (var i = 0; i < grafo.n; i++) {
      if (visivel.contains(Offset(px[i], py[i]))) nVisiveis++;
    }

    final vizinhosHover = (interacao.hover != null && interacao.hover! < grafo.n)
        ? grafo.vizinhos(interacao.hover!)
        : const <int>{};

    for (var i = 0; i < grafo.n; i++) {
      final x = px[i], y = py[i];
      if (!visivel.contains(Offset(x, y))) continue;

      final telaX = x * escala + offset.dx;
      final telaY = y * escala + offset.dy;

      // Culling em coordenadas de tela
      if (telaX < -90 ||
          telaX > size.width + 90 ||
          telaY < -40 ||
          telaY > size.height + 40) {
        continue;
      }

      final no = grafo.nos[i];
      final casaBusca = buscaAtiva.contains(no.id);
      final ehCritico = nosCriticos.contains(no.id) && modoRadarRisco;
      final ehHoverOuVizinho =
          i == interacao.hover || vizinhosHover.contains(i);
      final emDestaque = casaBusca ||
          ehCritico ||
          causas.contains(no.id) ||
          efeitos.contains(no.id) ||
          i == interacao.selecionado ||
          ehHoverOuVizinho ||
          (interacao.temFoco && interacao.emFoco.contains(i));

      // Sob modo performance severo, ainda renderiza destaques e hubs
      if (modoPerformance && !emDestaque && no.grau < 4) continue;

      if (!_mostrarRotulo(i, no, nVisiveis, emDestaque)) continue;

      var cor = emDestaque ? paleta.rotuloFoco : paleta.rotulo;
      if (ehCritico) cor = const Color(0xFFFCA5A5);
      if (interacao.temFoco && !interacao.emFoco.contains(i) && !emDestaque) {
        cor = cor.withValues(alpha: 0.15);
      }

      final tamanho = emDestaque ? tamanhoDestaque : tamanhoBase;
      final peso = emDestaque ? FontWeight.w700 : FontWeight.w500;

      final p = cache.obter(
        no.rotulo,
        tamanho,
        cor,
        peso: peso,
        largura: larguraMax,
        sombra: !emDestaque,
      );

      final raioTela = (no.raio * escala).clamp(1.5, 30.0);
      final posY = telaY + raioTela + 2.5;

      if (emDestaque) {
        final pillW = (p.maxIntrinsicWidth + 8).clamp(20.0, larguraMax + 8);
        final pillH = p.height + 4;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(telaX, posY + p.height / 2),
            width: pillW,
            height: pillH,
          ),
          const Radius.circular(4),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = paleta.fundo.withValues(alpha: 0.88)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = (ehCritico
                    ? const Color(0xFFEF4444)
                    : (casaBusca
                        ? const Color(0xFFF59E0B)
                        : (i == interacao.selecionado || i == interacao.hover
                            ? paleta.arestaDestaque
                            : paleta.aresta)))
                .withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }

      canvas.drawParagraph(p, Offset(telaX - p.width / 2, posY));
    }
  }

  bool _mostrarRotulo(int i, GrafoNo no, int nVisiveis, bool emDestaque) {
    if (emDestaque) return true;
    if (!config.mostrarRotulos) return false;

    // Se rótulos automáticos desligado, usuário prefere ver tudo
    if (!config.rotulosAuto) return true;

    // Grafo local ou pequeno
    if (nVisiveis <= 60) return true;

    // Zoom aproximado (>= 1.3): todos os nós visíveis
    if (escala >= 1.3) return true;

    // Zoom médio-alto (>= 0.8): nós conectados ou MOCs/entidades
    if (escala >= 0.8) {
      return no.grau >= 1 ||
          no.notaTipo == NotaTipo.moc ||
          no.noTipo == NoTipo.entidade;
    }

    final nTotal = grafo.n;

    // Zoom médio (>= 0.45): nós de destaque ou grau >= 2
    if (escala >= 0.45) {
      return no.grau >= 2 ||
          no.notaTipo == NotaTipo.moc ||
          no.noTipo == NoTipo.entidade ||
          (no.pagerank * nTotal >= 1.0);
    }

    // Zoom afastado / visão global (< 0.45):
    // MOCs, hubs principais (grau >= 3) e nós centrais
    return no.notaTipo == NotaTipo.moc ||
        no.grau >= 3 ||
        (no.pagerank * nTotal >= 1.8);
  }

  @override
  bool shouldRepaint(covariant GrafoPainter old) =>
      old.offset != offset ||
      old.escala != escala ||
      old.interacao != interacao ||
      old.config != config ||
      old.paleta != paleta ||
      old.modoPerformance != modoPerformance ||
      old.buscaAtiva != buscaAtiva ||
      old.modoRadarRisco != modoRadarRisco ||
      old.nosCriticos != nosCriticos ||
      old.causas != causas ||
      old.efeitos != efeitos ||
      !identical(old.engine, engine);
}
