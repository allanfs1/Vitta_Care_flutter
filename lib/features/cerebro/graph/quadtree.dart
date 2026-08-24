import 'dart:math' as math;
import 'dart:typed_data';

/// Quadtree para aproximação de Barnes-Hut (`obsidian.md` §7.2) e consulta
/// espacial por região (culling do painter, §7.5).
///
/// Reduz a repulsão n-corpos de O(n²) para O(n log n): subárvores distantes
/// o suficiente (largura/distância < θ) são tratadas como uma massa única
/// no seu centro de massa.
class Quadtree {
  Quadtree._(this._x0, this._y0, this._x1, this._y1, this._capacidade);

  /// Constrói a árvore a partir das posições. [massa] é opcional (padrão 1).
  factory Quadtree.construir(
    Float32List px,
    Float32List py,
    int n, {
    Float32List? massa,
  }) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < n; i++) {
      final x = px[i], y = py[i];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
    if (n == 0 || !minX.isFinite) {
      minX = minY = -1;
      maxX = maxY = 1;
    }
    // Quadrado com folga — evita divisões degeneradas.
    final largura = math.max(maxX - minX, maxY - minY) + 2;
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final meia = largura / 2;

    final t = Quadtree._(cx - meia, cy - meia, cx + meia, cy + meia, 1);
    for (var i = 0; i < n; i++) {
      t.inserir(i, px[i], py[i], massa == null ? 1.0 : massa[i]);
    }
    return t;
  }

  final double _x0, _y0, _x1, _y1;
  final int _capacidade;

  // Centro de massa acumulado da subárvore.
  double _massa = 0;
  double _mx = 0;
  double _my = 0;

  // Folha: guarda um único corpo (índice + posição).
  int _corpo = -1;
  double _bx = 0, _by = 0, _bm = 0;

  List<Quadtree?>? _filhos;

  double get _largura => _x1 - _x0;

  void inserir(int indice, double x, double y, double massa) {
    _massa += massa;
    _mx += x * massa;
    _my += y * massa;

    if (_filhos == null && _corpo == -1) {
      _corpo = indice;
      _bx = x;
      _by = y;
      _bm = massa;
      return;
    }

    if (_filhos == null) {
      // Vira nó interno: reinsere o corpo que estava aqui.
      // Guarda de segurança contra recursão infinita com pontos coincidentes.
      if (_largura < 1e-6) {
        _corpo = indice;
        return;
      }
      _filhos = List<Quadtree?>.filled(4, null);
      final antigoIdx = _corpo;
      final ax = _bx, ay = _by, am = _bm;
      _corpo = -1;
      _inserirNoFilho(antigoIdx, ax, ay, am);
    }

    _inserirNoFilho(indice, x, y, massa);
  }

  void _inserirNoFilho(int indice, double x, double y, double massa) {
    final mx = (_x0 + _x1) / 2;
    final my = (_y0 + _y1) / 2;
    final leste = x >= mx;
    final sul = y >= my;
    final q = (sul ? 2 : 0) + (leste ? 1 : 0);

    var filho = _filhos![q];
    if (filho == null) {
      final x0 = leste ? mx : _x0;
      final x1 = leste ? _x1 : mx;
      final y0 = sul ? my : _y0;
      final y1 = sul ? _y1 : my;
      filho = Quadtree._(x0, y0, x1, y1, _capacidade);
      _filhos![q] = filho;
    }
    filho.inserir(indice, x, y, massa);
  }

  /// Acumula a força de repulsão sobre o corpo [indice] em ([x], [y]).
  ///
  /// [k] é negativo (repulsão). [theta] controla a agressividade da
  /// aproximação: maior = mais rápido e menos preciso.
  void repulsao(
    int indice,
    double x,
    double y,
    double k,
    double theta,
    void Function(double fx, double fy) acumular,
  ) {
    if (_massa == 0) return;

    // Folha com um único corpo.
    if (_filhos == null) {
      if (_corpo == indice || _corpo == -1) return;
      var dx = x - _bx;
      var dy = y - _by;
      var d2 = dx * dx + dy * dy;
      if (d2 < 0.01) {
        // Pontos coincidentes: desloca deterministicamente pelo índice.
        dx = ((indice % 7) - 3) * 0.1;
        dy = ((indice % 5) - 2) * 0.1;
        d2 = dx * dx + dy * dy + 0.01;
      }
      final f = k * _bm / d2;
      final d = math.sqrt(d2);
      acumular(f * dx / d, f * dy / d);
      return;
    }

    final comX = _mx / _massa;
    final comY = _my / _massa;
    var dx = x - comX;
    var dy = y - comY;
    var d2 = dx * dx + dy * dy;
    if (d2 < 1e-9) d2 = 1e-9;

    // Critério de Barnes-Hut.
    if (_largura * _largura / d2 < theta * theta) {
      final f = k * _massa / d2;
      final d = math.sqrt(d2);
      acumular(f * dx / d, f * dy / d);
      return;
    }

    for (final filho in _filhos!) {
      filho?.repulsao(indice, x, y, k, theta, acumular);
    }
  }

  /// Índices dos corpos dentro do retângulo — usado no culling de render.
  void consultar(
    double rx0,
    double ry0,
    double rx1,
    double ry1,
    void Function(int indice) visitar,
  ) {
    if (_x1 < rx0 || _x0 > rx1 || _y1 < ry0 || _y0 > ry1) return;
    if (_filhos == null) {
      if (_corpo >= 0 && _bx >= rx0 && _bx <= rx1 && _by >= ry0 && _by <= ry1) {
        visitar(_corpo);
      }
      return;
    }
    for (final filho in _filhos!) {
      filho?.consultar(rx0, ry0, rx1, ry1, visitar);
    }
  }
}
