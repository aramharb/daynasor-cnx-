import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart' show Matrix4;

/// Font used for all colorful-mode text. Roboto is the Android system font;
/// on other platforms Flutter falls back to the system font automatically.
const String kUiFont = 'Roboto';

/// A gradient description that works like the HTML canvas `createLinearGradient`.
class Grad {
  Grad.linear(this.x0, this.y0, this.x1, this.y1)
      : radial = false,
        r0 = 0,
        r1 = 0;
  Grad.radial(this.x0, this.y0, this.r0, this.x1, this.y1, this.r1)
      : radial = true;

  final bool radial;
  final double x0, y0, x1, y1, r0, r1;
  final List<double> _stops = [];
  final List<Color> _colors = [];

  void addColorStop(double t, Color c) {
    _stops.add(t);
    _colors.add(c);
  }

  ui.Shader toShader() {
    if (!radial) {
      return ui.Gradient.linear(Offset(x0, y0), Offset(x1, y1), _colors, _stops);
    }
    var colors = List<Color>.of(_colors);
    var stops = List<double>.of(_stops);
    if (r0 > 0 && r1 > r0) {
      final k = r0 / r1;
      stops = [0, ...stops.map((s) => k + s * (1 - k))];
      colors = [colors.first, ...colors];
    }
    return ui.Gradient.radial(Offset(x1, y1), r1, colors, stops);
  }
}

/// Thin wrapper around [Canvas] that mimics the parts of the HTML5
/// CanvasRenderingContext2D API the game uses. Keeps the drawing code short.
class Ctx {
  Ctx(this.canvas);
  Canvas canvas;

  Color fillColor = const Color(0xFF000000);
  Grad? fillGrad;
  Color strokeColor = const Color(0xFF000000);
  Grad? strokeGrad;
  double lineWidth = 1;
  double globalAlpha = 1;
  Path _path = Path();

  final List<_State> _stack = [];

  // ---- state ----------------------------------------------------------------
  set fillStyle(Object v) {
    if (v is Grad) {
      fillGrad = v;
    } else {
      fillGrad = null;
      fillColor = v as Color;
    }
  }

  set strokeStyle(Object v) {
    if (v is Grad) {
      strokeGrad = v;
    } else {
      strokeGrad = null;
      strokeColor = v as Color;
    }
  }

  void save() {
    _stack.add(_State(fillColor, fillGrad, strokeColor, strokeGrad, lineWidth, globalAlpha));
    canvas.save();
  }

  void restore() {
    canvas.restore();
    if (_stack.isNotEmpty) {
      final s = _stack.removeLast();
      fillColor = s.fc;
      fillGrad = s.fg;
      strokeColor = s.sc;
      strokeGrad = s.sg;
      lineWidth = s.lw;
      globalAlpha = s.ga;
    }
  }

  void translate(double x, double y) => canvas.translate(x, y);
  void rotate(double a) => canvas.rotate(a);
  void scale(double x, [double? y]) => canvas.scale(x, y ?? x);

  // ---- paints ---------------------------------------------------------------
  Paint _fillPaint() {
    final p = Paint()..style = PaintingStyle.fill..isAntiAlias = true;
    if (fillGrad != null) {
      p.shader = fillGrad!.toShader(); // gradients ignore globalAlpha (use saveLayerAlpha)
    } else {
      p.color = _withAlpha(fillColor);
    }
    return p;
  }

  Paint _strokePaint() {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..isAntiAlias = true;
    if (strokeGrad != null) {
      p.shader = strokeGrad!.toShader();
    } else {
      p.color = _withAlpha(strokeColor);
    }
    return p;
  }

  Color _withAlpha(Color c) {
    if (globalAlpha >= 1) return c;
    return c.withValues(alpha: (c.a * globalAlpha).clamp(0.0, 1.0));
  }

  // ---- rectangles -------------------------------------------------------------
  void fillRect(double x, double y, double w, double h) {
    final p = _fillPaint();
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), p);
  }

  void strokeRect(double x, double y, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), _strokePaint());
  }

  void clipRect(double x, double y, double w, double h) {
    canvas.clipRect(Rect.fromLTWH(x, y, w, h));
  }

  // ---- paths ------------------------------------------------------------------
  bool _hasPoint = false;

  void beginPath() {
    _path = Path();
    _hasPoint = false;
  }

  void closePath() => _path.close();

  void moveTo(double x, double y) {
    _path.moveTo(x, y);
    _hasPoint = true;
  }

  void lineTo(double x, double y) {
    if (_hasPoint) {
      _path.lineTo(x, y);
    } else {
      _path.moveTo(x, y);
      _hasPoint = true;
    }
  }

  void quadraticCurveTo(double cx, double cy, double x, double y) {
    if (!_hasPoint) _path.moveTo(cx, cy);
    _path.quadraticBezierTo(cx, cy, x, y);
    _hasPoint = true;
  }

  void rect(double x, double y, double w, double h) {
    _path.addRect(Rect.fromLTWH(x, y, w, h));
    _hasPoint = true;
  }

  void roundRect(double x, double y, double w, double h, double r) {
    _path.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(math.min(r, math.min(w, h) / 2))));
  }

  void arc(double x, double y, double r, double a0, double a1, [bool ccw = false]) {
    ellipse(x, y, r, r, 0, a0, a1, ccw);
  }

  void ellipse(double x, double y, double rx, double ry, double rot, double a0, double a1, [bool ccw = false]) {
    const twoPi = math.pi * 2;
    final full = (a1 - a0).abs() >= twoPi - 1e-6;
    final oval = Rect.fromLTRB(-rx, -ry, rx, ry);
    final sub = Path();
    if (full) {
      sub.addOval(oval);
    } else {
      double sweep;
      if (!ccw) {
        sweep = (a1 - a0) % twoPi;
        if (sweep < 0) sweep += twoPi;
      } else {
        sweep = -((a0 - a1) % twoPi);
        if (sweep > 0) sweep -= twoPi;
      }
      sub.arcTo(oval, a0, sweep, true);
    }
    final m = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..rotateZ(rot);
    _path.addPath(sub.transform(m.storage), Offset.zero);
    _hasPoint = true;
  }

  void fill() => canvas.drawPath(_path, _fillPaint());
  void stroke() => canvas.drawPath(_path, _strokePaint());
  void clip() => canvas.clipPath(_path);

  // convenience shapes
  void fillCircle(double x, double y, double r) => canvas.drawCircle(Offset(x, y), r, _fillPaint());
  void strokeCircle(double x, double y, double r) => canvas.drawCircle(Offset(x, y), r, _strokePaint());
  void fillEllipse(double x, double y, double rx, double ry, [double rot = 0]) {
    if (rot == 0) {
      canvas.drawOval(Rect.fromLTRB(x - rx, y - ry, x + rx, y + ry), _fillPaint());
    } else {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawOval(Rect.fromLTRB(-rx, -ry, rx, ry), _fillPaint());
      canvas.restore();
    }
  }

  void strokeEllipse(double x, double y, double rx, double ry, [double rot = 0]) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    canvas.drawOval(Rect.fromLTRB(-rx, -ry, rx, ry), _strokePaint());
    canvas.restore();
  }

  void strokeLine(double x0, double y0, double x1, double y1) {
    canvas.drawLine(Offset(x0, y0), Offset(x1, y1), _strokePaint());
  }

  // ---- text -------------------------------------------------------------------
  /// Draws text. [align]: -1 left, 0 center, 1 right. [baseline]: 0 top, 0.5 middle.
  void text(
    String s,
    double x,
    double y, {
    double size = 12,
    FontWeight weight = FontWeight.w700,
    String? family,
    int align = 0,
    double baseline = 0.5,
    bool fill = true,
    bool strokeText = false,
    Color? color,
    Color? strokeColorOverride,
    double strokeWidth = 3,
  }) {
    final c = color ?? fillColor;
    void paintWith(TextStyle style) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = align == 0 ? -tp.width / 2 : align > 0 ? -tp.width : 0.0;
      tp.paint(canvas, Offset(x + dx, y - tp.height * baseline));
    }

    if (strokeText) {
      paintWith(TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontFamily: family ?? kUiFont,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round
          ..color = _withAlpha(strokeColorOverride ?? strokeColor),
      ));
    }
    if (fill) {
      final shader = color == null ? fillGrad?.toShader() : null;
      paintWith(TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontFamily: family ?? kUiFont,
        color: shader == null ? _withAlpha(c) : null,
        foreground: shader == null ? null : (Paint()..shader = shader),
      ));
    }
  }

  double measure(String s, {double size = 12, FontWeight weight = FontWeight.w700, String? family}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, fontWeight: weight, fontFamily: family ?? kUiFont)),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  /// Draws everything until [restoreLayer] with the given opacity.
  void saveLayerAlpha(double a) {
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, a.clamp(0.0, 1.0)));
  }

  void restoreLayer() => canvas.restore();
}

class _State {
  _State(this.fc, this.fg, this.sc, this.sg, this.lw, this.ga);
  final Color fc, sc;
  final Grad? fg, sg;
  final double lw, ga;
}
