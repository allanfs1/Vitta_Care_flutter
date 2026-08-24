import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'grafo_modelo.dart';
import 'quadtree.dart';

/// Simulação de forças do grafo (`obsidian.md` §7.2).
///
/// Quatro forças — repulsão (Barnes-Hut), mola por aresta, atração ao centro
/// e colisão — integradas por Verlet com resfriamento exponencial (α).
///
/// Posições vivem em [Float32List] (§7.1): o laço quente não toca objetos.
/// Estende [ChangeNotifier] para que o `CustomPainter` repinte via
/// `repaint:` sem reconstruir a árvore de widgets a 60 fps (§12, regra 3).
class GrafoEngine extends ChangeNotifier {
  GrafoEngine(this.grafo, {ConfigGrafo config = const ConfigGrafo()})
      : _config = config,
        px = Float32List(grafo.n),
        py = Float32List(grafo.n),
        vx = Float32List(grafo.n),
        vy = Float32List(grafo.n),
        massa = Float32List(grafo.n),
        travado = Uint8List(grafo.n),
        raioAlvo = Float32List(grafo.n) {
    _prepararArestas();
    semear();
  }

  final Grafo grafo;
  ConfigGrafo _config;
  ConfigGrafo get config => _config;

  // ── Estado da simulação ─────────────────────────────────────────────────
  final Float32List px, py, vx, vy, massa;

  /// 1 = posição travada (nó arrastado pelo usuário ou foco do grafo local).
  final Uint8List travado;

  /// Raio-alvo do layout radial ancorado (§7.7). `-1` desliga.
  final Float32List raioAlvo;

  late final Int32List _arDe;
  late final Int32List _arPara;
  late final Float32List _arPeso;
  late final Float32List _arRigidez;

  double alpha = 1.0;
  static const double _alphaDecay = 0.0228;
  static const double _alphaMin = 0.0012;
  static const double _theta = 0.85;

  bool get congelado => alpha < _alphaMin;

  /// Contador de ticks — usado por testes e pela status bar de performance.
  int ticks = 0;

  int get n => grafo.n;

  void atualizarConfig(ConfigGrafo novo) {
    final mudouFisica = novo.forcaCentro != _config.forcaCentro ||
        novo.forcaRepulsao != _config.forcaRepulsao ||
        novo.distanciaLinks != _config.distanciaLinks ||
        novo.atrito != _config.atrito;
    _config = novo;
    if (mudouFisica) reaquecer(0.3);
    notifyListeners();
  }

  /// Posições iniciais determinísticas em espiral de Fermat — evita o
  /// "big bang" caótico do posicionamento aleatório e torna o layout
  /// reproduzível entre sessões (importante para os golden tests).
  /// Posições iniciais determinísticas em espiral com dispersão proporcional.
  void semear() {
    const phi = 2.399963229728653; // ângulo áureo
    final espalhamento = n > 500 ? 28.0 : 18.0;
    for (var i = 0; i < n; i++) {
      final r = espalhamento * math.sqrt(i + 1.0);
      final a = i * phi;
      px[i] = r * math.cos(a);
      py[i] = r * math.sin(a);
      vx[i] = 0;
      vy[i] = 0;
      massa[i] = 1.0 + math.sqrt(grafo.nos[i].grau) * 0.4;
      raioAlvo[i] = -1;
    }
    alpha = 1.0;
    ticks = 0;
  }

  /// Carrega posições pré-computadas (snapshot noturno, §4.9) — o grafo
  /// aparece montado, sem simulação visível.
  void carregarPosicoes(Map<String, Offset> posicoes) {
    var achou = 0;
    for (var i = 0; i < n; i++) {
      final p = posicoes[grafo.nos[i].id];
      if (p == null) continue;
      px[i] = p.dx;
      py[i] = p.dy;
      achou++;
    }
    if (achou > n * 0.6) alpha = 0.08; // só um ajuste fino
  }

  Map<String, Offset> exportarPosicoes() => {
        for (var i = 0; i < n; i++) grafo.nos[i].id: Offset(px[i], py[i]),
      };

  void reaquecer([double a = 0.4]) {
    alpha = math.max(alpha, a);
    notifyListeners();
  }

  /// Configura o layout radial ancorado do grafo local (§7.7): o nó focal é
  /// travado no centro e os demais recebem um raio-alvo por número de saltos.
  void ancorarRadial(int indiceFocal, Map<int, int> saltosPorNo) {
    for (var i = 0; i < n; i++) {
      raioAlvo[i] = -1;
      travado[i] = 0;
    }
    px[indiceFocal] = 0;
    py[indiceFocal] = 0;
    vx[indiceFocal] = 0;
    vy[indiceFocal] = 0;
    travado[indiceFocal] = 1;
    saltosPorNo.forEach((i, saltos) {
      if (i != indiceFocal && saltos > 0) raioAlvo[i] = 90.0 * saltos;
    });
    reaquecer(0.9);
  }

  void travar(int i, double x, double y) {
    px[i] = x;
    py[i] = y;
    vx[i] = 0;
    vy[i] = 0;
    travado[i] = 1;
  }

  void destravar(int i) => travado[i] = 0;

  bool estaTravado(int i) => travado[i] == 1;

  /// Um passo da simulação. Retorna `false` quando já congelou.
  bool tick() {
    if (congelado || n == 0) return false;

    alpha += (0 - alpha) * _alphaDecay;
    ticks++;

    final kRep = -480.0 * (_config.forcaRepulsao / 6.2);
    final comprimento = _config.distanciaLinks;
    final atrito = _config.atrito;
    final kCentro = _config.forcaCentro * (n > 500 ? 0.25 : 0.6);

    // Acumuladores de força — reutilizados entre ticks para não alocar.
    final fx = _fx ??= Float32List(n);
    final fy = _fy ??= Float32List(n);
    fx.fillRange(0, n, 0);
    fy.fillRange(0, n, 0);

    // 1 · Repulsão (Barnes-Hut).
    final arvore = Quadtree.construir(px, py, n, massa: massa);
    for (var i = 0; i < n; i++) {
      arvore.repulsao(i, px[i], py[i], kRep, _theta, (dx, dy) {
        fx[i] += dx;
        fy[i] += dy;
      });
    }

    // 2 · Mola por aresta.
    for (var e = 0; e < _arDe.length; e++) {
      final i = _arDe[e];
      final j = _arPara[e];
      var dx = px[j] - px[i];
      var dy = py[j] - py[i];
      var d = math.sqrt(dx * dx + dy * dy);
      if (d < 0.01) {
        dx = 0.05;
        dy = 0.05;
        d = 0.0707;
      }
      final f = (d - comprimento) * _arRigidez[e] * _arPeso[e];
      final ux = dx / d, uy = dy / d;
      fx[i] += f * ux;
      fy[i] += f * uy;
      fx[j] -= f * ux;
      fy[j] -= f * uy;
    }

    // 3 · Centro (ou raio-alvo radial, quando ancorado).
    for (var i = 0; i < n; i++) {
      final alvo = raioAlvo[i];
      if (alvo >= 0) {
        final d = math.sqrt(px[i] * px[i] + py[i] * py[i]);
        if (d > 0.01) {
          final f = (alvo - d) * 0.08;
          fx[i] += f * px[i] / d;
          fy[i] += f * py[i] / d;
        } else {
          fx[i] += alvo * 0.08;
        }
      } else {
        fx[i] -= px[i] * kCentro;
        fy[i] -= py[i] * kCentro;
      }
    }

    // 4 · Colisão — em grafos médios/pequenos.
    if (n < 800) _resolverColisoes(fx, fy);

    // Integração.
    for (var i = 0; i < n; i++) {
      if (travado[i] == 1) {
        vx[i] = 0;
        vy[i] = 0;
        continue;
      }
      vx[i] = (vx[i] + fx[i]) * atrito;
      vy[i] = (vy[i] + fy[i]) * atrito;
      // Limite de velocidade: impede explosão numérica em grafos densos.
      const vMax = 240.0;
      if (vx[i] > vMax) vx[i] = vMax;
      if (vx[i] < -vMax) vx[i] = -vMax;
      if (vy[i] > vMax) vy[i] = vMax;
      if (vy[i] < -vMax) vy[i] = -vMax;
      px[i] += vx[i] * alpha;
      py[i] += vy[i] * alpha;
    }

    notifyListeners();
    return true;
  }

  Float32List? _fx;
  Float32List? _fy;

  void _resolverColisoes(Float32List fx, Float32List fy) {
    for (var i = 0; i < n; i++) {
      final ri = grafo.nos[i].raio;
      for (var j = i + 1; j < n; j++) {
        final rj = grafo.nos[j].raio;
        final minD = ri + rj + 1.5;
        final dx = px[j] - px[i];
        final dy = py[j] - py[i];
        final d2 = dx * dx + dy * dy;
        if (d2 >= minD * minD || d2 < 1e-6) continue;
        final d = math.sqrt(d2);
        final empurrao = (minD - d) * 0.45;
        final ux = dx / d, uy = dy / d;
        fx[i] -= ux * empurrao;
        fy[i] -= uy * empurrao;
        fx[j] += ux * empurrao;
        fy[j] += uy * empurrao;
      }
    }
  }

  void _prepararArestas() {
    final m = grafo.arestas.length;
    _arDe = Int32List(m);
    _arPara = Int32List(m);
    _arPeso = Float32List(m);
    _arRigidez = Float32List(m);
    for (var e = 0; e < m; e++) {
      final a = grafo.arestas[e];
      _arDe[e] = a.de;
      _arPara[e] = a.para;
      _arPeso[e] = a.peso;

      final deNo = grafo.nos[a.de];
      final paraNo = grafo.nos[a.para];
      final gi = deNo.grau;
      final gj = paraNo.grau;

      // Amortecimento para tags e entidades para não colapsar o grafo
      var fatorTipo = 1.0;
      if (deNo.noTipo == NoTipo.tag || paraNo.noTipo == NoTipo.tag) {
        fatorTipo = 0.25;
      } else if (deNo.noTipo == NoTipo.entidade || paraNo.noTipo == NoTipo.entidade) {
        fatorTipo = 0.35;
      }

      // Rigidez harmônica proporcional ao grau para espalhamento galáctico
      final grauHarmonico = math.sqrt((gi * gj).clamp(1, 100000));
      _arRigidez[e] = (0.7 / grauHarmonico.clamp(1.0, 15.0)) * fatorTipo;
    }
  }

  /// Limites do layout — usado para enquadrar (`F`).
  ({double x0, double y0, double x1, double y1}) get limites {
    if (n == 0) return (x0: -100, y0: -100, x1: 100, y1: 100);
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (var i = 0; i < n; i++) {
      final r = grafo.nos[i].raio;
      if (px[i] - r < x0) x0 = px[i] - r;
      if (py[i] - r < y0) y0 = py[i] - r;
      if (px[i] + r > x1) x1 = px[i] + r;
      if (py[i] + r > y1) y1 = py[i] + r;
    }
    return (x0: x0, y0: y0, x1: x1, y1: y1);
  }

  /// Nó mais próximo de um ponto do espaço do grafo, dentro de [tolerancia].
  int? noEm(double x, double y, {double tolerancia = 6}) {
    var melhor = -1;
    var melhorD2 = double.infinity;
    for (var i = 0; i < n; i++) {
      final r = grafo.nos[i].raio + tolerancia;
      final dx = px[i] - x;
      final dy = py[i] - y;
      final d2 = dx * dx + dy * dy;
      if (d2 <= r * r && d2 < melhorD2) {
        melhorD2 = d2;
        melhor = i;
      }
    }
    return melhor < 0 ? null : melhor;
  }
}
