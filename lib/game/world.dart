// Backgrounds, biomes, obstacle and pickup art for both modes.
import 'dart:math' as math;
import 'dart:ui';

import 'ctx.dart';
import 'entities.dart';

class Biome {
  const Biome({
    required this.id,
    required this.name,
    required this.sky0,
    required this.sky1,
    required this.far,
    required this.mid,
    required this.near,
    required this.ground,
    required this.groundTop,
    required this.pebble,
    required this.sun,
    required this.decor,
    required this.weather,
    required this.obstacle,
    required this.flyer,
    this.flyerWing = const Color(0xFFFFFFFF),
    this.meteors = false,
  });
  final String id, name, decor, weather, obstacle;
  final Color sky0, sky1, far, mid, near, ground, groundTop, pebble, sun, flyer, flyerWing;
  final bool meteors;
  bool get ufo => id == 'cosmic';
}

const List<Biome> kBiomes = [
  Biome(
      id: 'jungle', name: 'Jungle', sky0: Color(0xFF5EC8F2), sky1: Color(0xFFD6F6FF), far: Color(0xFF7CC69A), mid: Color(0xFF3F9A5A),
      near: Color(0xFF2A7140), ground: Color(0xFF7A5230), groundTop: Color(0xFF5DBB46), pebble: Color(0xFF5E3D22),
      sun: Color(0xFFFFF3B0), decor: 'tree', weather: 'leaf', obstacle: 'stump', flyer: Color(0xFF8E5A2B), flyerWing: Color(0xFFC98B4C)),
  Biome(
      id: 'desert', name: 'Desert', sky0: Color(0xFFFF9F43), sky1: Color(0xFFFFE6B8), far: Color(0xFFF0B77A), mid: Color(0xFFD69454),
      near: Color(0xFFB9743A), ground: Color(0xFFE0A95F), groundTop: Color(0xFFF2CB88), pebble: Color(0xFFB98245),
      sun: Color(0xFFFFF7D6), decor: 'cactus', weather: 'dust', obstacle: 'cactus', flyer: Color(0xFFC0392B), flyerWing: Color(0xFFE67E22)),
  Biome(
      id: 'glacier', name: 'Glacier', sky0: Color(0xFF7FC3FF), sky1: Color(0xFFEEF8FF), far: Color(0xFFD6ECFF), mid: Color(0xFFA9D2F5),
      near: Color(0xFF80B4E0), ground: Color(0xFFDCECFF), groundTop: Color(0xFFFFFFFF), pebble: Color(0xFFA9C8EA),
      sun: Color(0xFFFFFFFF), decor: 'pine', weather: 'snow', obstacle: 'ice', flyer: Color(0xFF455A64), flyerWing: Color(0xFF90A4AE)),
  Biome(
      id: 'volcano', name: 'Volcano', sky0: Color(0xFF2A0A17), sky1: Color(0xFFFF6A3D), far: Color(0xFF5A1F26), mid: Color(0xFF3A1418),
      near: Color(0xFF240C0F), ground: Color(0xFF2E1B1B), groundTop: Color(0xFFFF5722), pebble: Color(0xFFFF8A50),
      sun: Color(0xFFFF3D00), decor: 'volcano', weather: 'ember', obstacle: 'lava', flyer: Color(0xFF212121),
      flyerWing: Color(0xFFFF5722), meteors: true),
  Biome(
      id: 'cosmic', name: 'Cosmic', sky0: Color(0xFF070320), sky1: Color(0xFF4B1D7A), far: Color(0xFF2C1460), mid: Color(0xFF1F0E48),
      near: Color(0xFF150933), ground: Color(0xFF1D0D42), groundTop: Color(0xFFB388FF), pebble: Color(0xFF7C4DFF),
      sun: Color(0xFFFFD1FF), decor: 'crystal', weather: 'star', obstacle: 'crystal', flyer: Color(0xFFB0BEC5), meteors: true),
];

// ---- helpers --------------------------------------------------------------------
Color lerpColor(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

double hash(num n) {
  final s = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return s - s.floorToDouble();
}

class BiomePalette {
  BiomePalette({
    required this.id,
    required this.decor,
    required this.sky0,
    required this.sky1,
    required this.far,
    required this.mid,
    required this.near,
    required this.ground,
    required this.groundTop,
    required this.pebble,
    required this.sun,
  });
  final String id, decor;
  final Color sky0, sky1, far, mid, near, ground, groundTop, pebble, sun;
}

BiomePalette biomePalette(Biome from, Biome to, double t) {
  final src = t < 0.5 ? from : to;
  return BiomePalette(
    id: src.id,
    decor: src.decor,
    sky0: lerpColor(from.sky0, to.sky0, t),
    sky1: lerpColor(from.sky1, to.sky1, t),
    far: lerpColor(from.far, to.far, t),
    mid: lerpColor(from.mid, to.mid, t),
    near: lerpColor(from.near, to.near, t),
    ground: lerpColor(from.ground, to.ground, t),
    groundTop: lerpColor(from.groundTop, to.groundTop, t),
    pebble: lerpColor(from.pebble, to.pebble, t),
    sun: lerpColor(from.sun, to.sun, t),
  );
}

double _hill(double x, double seed, double amp) =>
    amp * (math.sin(x * 0.004 + seed) * 0.6 + math.sin(x * 0.011 + seed * 2.3) * 0.3 + math.sin(x * 0.027 + seed * 3.7) * 0.1);

double _mod(double a, double b) => ((a % b) + b) % b;

const _pi = math.pi;

// ---- decor silhouettes ------------------------------------------------------------
void _decor(Ctx ctx, String type, double x, double y, double s, Color color, Color? accent) {
  ctx.fillStyle = color;
  switch (type) {
    case 'tree':
      ctx.fillRect(x - 2 * s, y - 18 * s, 4 * s, 18 * s);
      ctx.fillCircle(x, y - 24 * s, 10 * s);
      ctx.fillCircle(x - 8 * s, y - 18 * s, 7 * s);
      ctx.fillCircle(x + 8 * s, y - 18 * s, 7 * s);
    case 'cactus':
      ctx.fillRect(x - 3 * s, y - 26 * s, 6 * s, 26 * s);
      ctx.fillRect(x - 10 * s, y - 16 * s, 4 * s, 9 * s);
      ctx.fillRect(x - 10 * s, y - 10 * s, 8 * s, 3 * s);
      ctx.fillRect(x + 6 * s, y - 20 * s, 4 * s, 10 * s);
      ctx.fillRect(x + 2 * s, y - 13 * s, 8 * s, 3 * s);
    case 'pine':
      for (var i = 0; i < 3; i++) {
        final ty = y - (8 + i * 9) * s;
        ctx.beginPath();
        ctx.moveTo(x, ty - 12 * s);
        ctx.lineTo(x - (12 - i * 3) * s, ty + 4 * s);
        ctx.lineTo(x + (12 - i * 3) * s, ty + 4 * s);
        ctx.fill();
      }
      if (accent != null) {
        ctx.fillStyle = accent;
        ctx.beginPath();
        ctx.moveTo(x, y - 38 * s);
        ctx.lineTo(x - 3 * s, y - 33 * s);
        ctx.lineTo(x + 3 * s, y - 33 * s);
        ctx.fill();
      }
    case 'volcano':
      ctx.beginPath();
      ctx.moveTo(x - 9 * s, y);
      ctx.lineTo(x - 2 * s, y - 20 * s);
      ctx.lineTo(x + 1 * s, y - 14 * s);
      ctx.lineTo(x + 4 * s, y - 24 * s);
      ctx.lineTo(x + 9 * s, y);
      ctx.fill();
    case 'crystal':
      for (final c in const [
        [-6.0, 20.0, 5.0],
        [0.0, 30.0, 6.0],
        [7.0, 16.0, 5.0]
      ]) {
        ctx.beginPath();
        ctx.moveTo(x + (c[0] - c[2]) * s, y);
        ctx.lineTo(x + c[0] * s, y - c[1] * s);
        ctx.lineTo(x + (c[0] + c[2]) * s, y);
        ctx.fill();
      }
  }
}

// ---- colorful background ------------------------------------------------------------
void drawColorBackground(Ctx ctx, double W, double H, double gy, double scroll, double time, BiomePalette pal) {
  final sky = Grad.linear(0, 0, 0, gy)
    ..addColorStop(0, pal.sky0)
    ..addColorStop(1, pal.sky1);
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, W, gy + 2);

  final dark = pal.id == 'cosmic' || pal.id == 'volcano';
  if (dark) {
    ctx.fillStyle = const Color(0xFFFFFFFF);
    for (var i = 0; i < 70; i++) {
      final x = (hash(i) * W * 1.5 - scroll * 0.01) % W;
      final y = hash(i + 99) * gy * 0.75;
      final tw = 0.5 + 0.5 * math.sin(time * 3 + i);
      ctx.globalAlpha = (pal.id == 'cosmic' ? 0.9 : 0.35) * tw;
      ctx.fillRect((x + W) % W, y, 1.5, 1.5);
    }
    ctx.globalAlpha = 1;
  }

  // sun / planet
  final sx = W * 0.78, sy = gy * 0.28;
  if (pal.id == 'cosmic') {
    ctx.fillStyle = const Color(0xFFFF9FF3);
    ctx.fillCircle(sx, sy, 22);
    ctx.fillStyle = const Color(0x40FFFFFF);
    ctx.fillCircle(sx - 6, sy - 6, 9);
    ctx.strokeStyle = const Color(0xFFFFD1FF);
    ctx.lineWidth = 3;
    ctx.strokeEllipse(sx, sy, 38, 9, -0.35);
  } else {
    final glow = Grad.radial(sx, sy, 4, sx, sy, 60)
      ..addColorStop(0, pal.sun)
      ..addColorStop(0.35, pal.sun.withValues(alpha: 0.67))
      ..addColorStop(1, pal.sun.withValues(alpha: 0));
    ctx.fillStyle = glow;
    ctx.fillCircle(sx, sy, 60);
    ctx.fillStyle = pal.sun;
    ctx.fillCircle(sx, sy, 18);
  }

  // clouds
  if (!dark) {
    ctx.fillStyle = const Color(0xD9FFFFFF);
    for (var i = 0; i < 6; i++) {
      final span = W + 200;
      final x = _mod(hash(i + 5) * span - scroll * (0.05 + hash(i) * 0.05) - time * 6, span) - 100;
      final y = 18 + hash(i + 50) * gy * 0.35;
      final s = 0.7 + hash(i + 7) * 0.8;
      ctx.fillCircle(x, y, 12 * s);
      ctx.fillCircle(x + 14 * s, y - 6 * s, 15 * s);
      ctx.fillCircle(x + 30 * s, y, 11 * s);
      ctx.fillRect(x, y, 30 * s, 11 * s);
    }
  }

  // parallax hills
  final layers = <_Layer>[
    _Layer(0.08, 34, gy - 62, pal.far, pal.decor == 'volcano' ? 'volcano' : null, big: true),
    _Layer(0.22, 20, gy - 32, pal.mid, pal.decor, spacing: 95),
    _Layer(0.5, 8, gy - 10, pal.near, pal.decor == 'volcano' ? 'crystal' : pal.decor, spacing: 170, small: true),
  ];
  for (var li = 0; li < layers.length; li++) {
    final L = layers[li];
    final off = scroll * L.f;
    ctx.fillStyle = L.color;
    ctx.beginPath();
    ctx.moveTo(0, gy + 1);
    for (double x = 0; x <= W + 8; x += 8) {
      ctx.lineTo(x, L.base + _hill(x + off, li * 3.1, L.amp));
    }
    ctx.lineTo(W, gy + 1);
    ctx.closePath();
    ctx.fill();

    if (L.big && L.decor == 'volcano') {
      final span = W + 400;
      final vx = _mod(W * 0.35 - off * 0.6, span) - 150;
      final vy = gy - 18;
      _decor(ctx, 'volcano', vx, vy, 5, L.color, null);
      final g = Grad.radial(vx + 15, vy - 120, 2, vx + 15, vy - 120, 40)
        ..addColorStop(0, const Color(0xE6FF8C00))
        ..addColorStop(1, const Color(0x00FF3C00));
      ctx.fillStyle = g;
      ctx.fillCircle(vx + 15, vy - 120, 40);
    }
    if (L.spacing != null && L.decor != null) {
      final sp = L.spacing!;
      final start = (off / sp).floor() - 1;
      final n = (W / sp + 3).floor();
      for (var i = start; i < start + n; i++) {
        if (hash(i * 3.3 + li) < 0.45) continue;
        final x = i * sp - off + hash(i) * sp * 0.6;
        final y = L.base + _hill(x + off, li * 3.1, L.amp) + 2;
        final s = (L.small ? 0.8 : 0.65) * (0.7 + hash(i + 1) * 0.6);
        _decor(ctx, L.decor!, x, y, s, L.color, pal.id == 'glacier' ? const Color(0xFFFFFFFF) : null);
      }
    }
  }

  // ground
  ctx.fillStyle = pal.ground;
  ctx.fillRect(0, gy, W, H - gy);
  ctx.fillStyle = pal.groundTop;
  ctx.fillRect(0, gy - 1, W, 5);
  // underground strata + fossils (visible on tall / portrait screens)
  if (H - gy > 80) {
    for (var i = 1; gy + 40 + (i - 1) * 70 < H; i++) {
      final by = gy + 40 + (i - 1) * 70;
      ctx.fillStyle = lerpColor(pal.ground, const Color(0xFF000000), math.min(0.5, i * 0.09));
      ctx.beginPath();
      ctx.moveTo(0, H);
      for (double x = 0; x <= W + 10; x += 10) {
        ctx.lineTo(x, by + math.sin((x + scroll * 0.9) * 0.03 + i) * 4);
      }
      ctx.lineTo(W, H);
      ctx.fill();
    }
    ctx.globalAlpha = 0.25;
    ctx.fillStyle = const Color(0xFFFFFFFF);
    const fs = 260.0;
    final f0 = (scroll / fs).floor();
    final fn = (W / fs + 2).floor();
    for (var i = f0; i < f0 + fn; i++) {
      final fx = i * fs - scroll + hash(i + 400) * 100;
      final fy = gy + 60 + hash(i + 401) * (H - gy - 80);
      if (hash(i + 402) < 0.5) {
        ctx.fillRect(fx - 10, fy - 1.5, 20, 3);
        ctx.fillCircle(fx - 10, fy, 3.5);
        ctx.fillCircle(fx + 10, fy, 3.5);
      } else {
        ctx.strokeStyle = const Color(0xFFFFFFFF);
        ctx.lineWidth = 2;
        ctx.beginPath();
        for (double a = 0; a < _pi * 5; a += 0.3) {
          ctx.lineTo(fx + math.cos(a) * a * 1.4, fy + math.sin(a) * a * 1.4);
        }
        ctx.stroke();
      }
    }
    ctx.globalAlpha = 1;
  }
  // pebbles / texture
  ctx.fillStyle = pal.pebble;
  const sp = 23.0;
  final start = (scroll / sp).floor();
  final cnt = (W / sp + 2).floor();
  for (var i = start; i < start + cnt; i++) {
    final x = i * sp - scroll + hash(i) * 10;
    final y = gy + 8 + hash(i + 3) * math.min(28, H - gy - 10);
    ctx.fillRect(x, y, 2 + hash(i + 9) * 4, 2);
  }
  if (pal.id == 'jungle') {
    ctx.fillStyle = const Color(0xFF3E9B2F);
    for (var i = start; i < start + cnt; i++) {
      if (hash(i + 21) < 0.5) continue;
      final x = i * sp - scroll + hash(i + 2) * 12;
      ctx.fillRect(x, gy - 4, 2, 4);
      ctx.fillRect(x + 3, gy - 6, 2, 6);
      ctx.fillRect(x + 6, gy - 3, 2, 3);
    }
  }
  if (pal.id == 'volcano') {
    for (var i = start; i < start + cnt; i++) {
      if (hash(i + 77) < 0.6) continue;
      final x = i * sp - scroll;
      ctx.fillStyle = Color.fromRGBO(255, 90 + (60 * math.sin(time * 4 + i)).floor().clamp(0, 255), 0, 0.8);
      ctx.fillRect(x, gy + 12 + hash(i) * 10, 10, 2);
    }
  }
}

class _Layer {
  _Layer(this.f, this.amp, this.base, this.color, this.decor, {this.spacing, this.big = false, this.small = false});
  final double f, amp, base;
  final Color color;
  final String? decor;
  final double? spacing;
  final bool big, small;
}

// ---- classic background ---------------------------------------------------------------
class ClassicPalette {
  const ClassicPalette(this.bg, this.fg, this.cloud);
  final Color bg, fg, cloud;
}

void drawClassicBackground(Ctx ctx, double W, double H, double gy, double scroll, double time, ClassicPalette pal, double nightT) {
  ctx.fillStyle = pal.bg;
  ctx.fillRect(0, 0, W, H);

  if (nightT > 0.01) {
    ctx.globalAlpha = nightT;
    ctx.fillStyle = pal.fg;
    final mx = W * 0.75 - ((scroll * 0.01) % (W * 0.5)), my = gy * 0.3;
    ctx.fillCircle(mx, my, 12);
    ctx.fillStyle = pal.bg;
    ctx.fillCircle(mx + 6, my - 3, 11);
    ctx.fillStyle = pal.fg;
    for (var i = 0; i < 14; i++) {
      final x = _mod(hash(i) * W * 2 - scroll * 0.02, W);
      ctx.fillRect(x, hash(i + 40) * gy * 0.6, 1.5, 1.5);
    }
    ctx.globalAlpha = 1;
  }

  // clouds (outlined, like the original game)
  ctx.strokeStyle = pal.cloud;
  ctx.lineWidth = 1.5;
  for (var i = 0; i < 4; i++) {
    final span = W + 120;
    final x = _mod(hash(i + 13) * span - scroll * 0.18, span) - 60;
    final y = 24 + hash(i + 31) * gy * 0.4;
    ctx.beginPath();
    ctx.moveTo(x, y + 8);
    ctx.lineTo(x + 42, y + 8);
    ctx.arc(x + 34, y + 3, 6, _pi * 0.5, -_pi * 0.4, true);
    ctx.arc(x + 22, y, 9, -0.2, _pi * 1.1, true);
    ctx.arc(x + 8, y + 3, 6, -_pi * 0.6, _pi * 0.5, true);
    ctx.stroke();
  }

  // horizon line with bumps
  ctx.fillStyle = pal.fg;
  final lineY = gy - 3;
  ctx.fillRect(0, lineY, W, 1.5);
  const seg = 40.0;
  final s0 = (scroll / seg).floor();
  final cnt = (W / seg + 2).floor();
  for (var i = s0; i < s0 + cnt; i++) {
    final x = i * seg - scroll;
    final r = hash(i);
    if (r > 0.82) {
      ctx.fillRect(x, lineY - 2, 6, 2);
      ctx.fillRect(x + 6, lineY - 1, 3, 1);
    }
    ctx.fillRect(x + r * 20, gy + 3 + hash(i + 5) * 8, 2 + hash(i + 2) * 4, 1);
    if (r < 0.3) ctx.fillRect(x + 25, gy + 6, 1.5, 1.5);
  }
}

// ---- obstacles ------------------------------------------------------------------------
void _classicCactus(Ctx ctx, double x, double y, double w, double h, double seed, Color fg) {
  ctx.fillStyle = fg;
  final tw = math.max(5.0, (w * 0.36).roundToDouble());
  final tx = x + ((w - tw) / 2).roundToDouble();
  ctx.fillRect(tx, y + 2, tw, h - 2);
  ctx.fillRect(tx + 1, y, tw - 2, 2);
  final armW = math.max(3.0, (tw * 0.6).roundToDouble());
  final lA = y + h * (0.25 + seed * 0.15);
  ctx.fillRect(x, lA, armW, h * 0.3);
  ctx.fillRect(x, lA + h * 0.3 - 3, tx - x, 3);
  final rA = y + h * (0.18 + (1 - seed) * 0.18);
  ctx.fillRect(x + w - armW, rA, armW, h * 0.28);
  ctx.fillRect(tx + tw, rA + h * 0.28 - 3, x + w - armW - tx - tw + armW, 3);
}

void _rr(Ctx ctx, double x, double y, double w, double h, double r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}

void _colorCactus(Ctx ctx, double x, double y, double w, double h, double seed) {
  final tw = math.max(6.0, (w * 0.4).roundToDouble());
  final tx = x + (w - tw) / 2;
  ctx.fillStyle = const Color(0xFF1F7A3A);
  _rr(ctx, tx - 1, y - 1, tw + 2, h + 1, tw / 2);
  ctx.fill();
  final armW = math.max(4.0, (tw * 0.6).roundToDouble());
  final lA = y + h * (0.25 + seed * 0.15);
  _rr(ctx, x - 1, lA - 1, armW + 2, h * 0.32 + 2, armW / 2);
  ctx.fill();
  ctx.fillRect(x, lA + h * 0.3 - 4, tx - x + 2, 5);
  final rA = y + h * (0.18 + (1 - seed) * 0.18);
  _rr(ctx, x + w - armW - 1, rA - 1, armW + 2, h * 0.3 + 2, armW / 2);
  ctx.fill();
  ctx.fillRect(tx + tw - 2, rA + h * 0.28 - 4, x + w - armW - tx - tw + 4, 5);
  ctx.fillStyle = const Color(0xFF34B257);
  _rr(ctx, tx, y, tw, h, tw / 2);
  ctx.fill();
  _rr(ctx, x, lA, armW, h * 0.3, armW / 2);
  ctx.fill();
  _rr(ctx, x + w - armW, rA, armW, h * 0.28, armW / 2);
  ctx.fill();
  ctx.fillStyle = const Color(0xFF7FE08F);
  ctx.fillRect(tx + tw * 0.3, y + 4, 1.5, h - 8);
  ctx.fillStyle = const Color(0xFFFF6FA8);
  ctx.fillCircle(tx + tw / 2, y + 1, 3);
}

void _colorStump(Ctx ctx, double x, double y, double w, double h, double seed) {
  final sw = w * 0.82, sx = x + (w - sw) / 2;
  final g = Grad.linear(sx, 0, sx + sw, 0)
    ..addColorStop(0, const Color(0xFF5A3618))
    ..addColorStop(0.5, const Color(0xFF8B5A2B))
    ..addColorStop(1, const Color(0xFF5A3618));
  ctx.fillStyle = g;
  ctx.fillRect(sx, y + 4, sw, h - 4);
  ctx.fillStyle = const Color(0xFFD9A066);
  ctx.fillEllipse(sx + sw / 2, y + 4, sw / 2, 4);
  ctx.strokeStyle = const Color(0xFFA8703D);
  ctx.lineWidth = 1;
  ctx.strokeEllipse(sx + sw / 2, y + 4, sw / 4, 2);
  ctx.fillStyle = const Color(0xFF4CAF50);
  ctx.fillRect(sx, y + 5, sw, 3);
  ctx.fillRect(sx + sw * 0.2, y + 7, 3, 5 + seed * 6);
  ctx.fillRect(sx + sw * 0.7, y + 7, 3, 3 + seed * 8);
  if (h > 40) {
    ctx.fillStyle = const Color(0xFFE53935);
    ctx.beginPath();
    ctx.arc(sx + sw, y + h * 0.55, 5, _pi, 0);
    ctx.fill();
    ctx.fillStyle = const Color(0xFFFFFFFF);
    ctx.fillRect(sx + sw - 2, y + h * 0.55 - 3, 2, 2);
  }
}

void _colorSpikes(Ctx ctx, double x, double y, double w, double h, double seed, Color c1, Color c2, Color edge) {
  for (final s in const [
    [0.15, 0.6, 0.3],
    [0.5, 1.0, 0.38],
    [0.85, 0.7, 0.3]
  ]) {
    final px = x + w * s[0], top = y + h * (1 - s[1] * (0.85 + seed * 0.15)), ww = s[2];
    final g = Grad.linear(px, top, px, y + h)
      ..addColorStop(0, c1)
      ..addColorStop(1, c2);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(px - w * ww, y + h);
    ctx.lineTo(px, top);
    ctx.lineTo(px + w * ww, y + h);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = edge;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(px, top + 2);
    ctx.lineTo(px - w * ww * 0.4, y + h - 2);
    ctx.stroke();
  }
}

void _colorLava(Ctx ctx, double x, double y, double w, double h, double seed, double time) {
  ctx.fillStyle = const Color(0xFF2B2020);
  ctx.beginPath();
  ctx.moveTo(x, y + h);
  ctx.lineTo(x + w * 0.1, y + h * 0.35);
  ctx.lineTo(x + w * 0.4, y);
  ctx.lineTo(x + w * 0.75, y + h * 0.15);
  ctx.lineTo(x + w, y + h * 0.5);
  ctx.lineTo(x + w, y + h);
  ctx.closePath();
  ctx.fill();
  final glow = 0.6 + 0.4 * math.sin(time * 6 + seed * 10);
  ctx.strokeStyle = Color.fromRGBO(255, (100 + 80 * glow).floor(), 0, glow);
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(x + w * 0.3, y + h * 0.2);
  ctx.lineTo(x + w * 0.45, y + h * 0.55);
  ctx.lineTo(x + w * 0.35, y + h * 0.9);
  ctx.moveTo(x + w * 0.45, y + h * 0.55);
  ctx.lineTo(x + w * 0.75, y + h * 0.7);
  ctx.stroke();
}

void _drawGround(Ctx ctx, Obstacle o, bool colorful, double time, Color fg) {
  final n = o.n;
  final uw = o.w / n;
  for (var i = 0; i < n; i++) {
    final seed = hash(o.seed + i);
    final ux = o.x + i * uw;
    final uh = o.h * (i == 1 || n == 1 ? 1 : 0.86);
    final uy = o.y + (o.h - uh);
    if (!colorful) {
      _classicCactus(ctx, ux, uy, uw, uh, seed, fg);
      continue;
    }
    switch (o.skin) {
      case 'stump':
        _colorStump(ctx, ux, uy, uw, uh, seed);
      case 'ice':
        _colorSpikes(ctx, ux, uy, uw, uh, seed, const Color(0xFFFFFFFF), const Color(0xFF6EC6FF), const Color(0xFFE3F6FF));
      case 'lava':
      case 'meteorite':
        _colorLava(ctx, ux, uy, uw, uh, seed, time);
      case 'crystal':
        _colorSpikes(ctx, ux, uy, uw, uh, seed, const Color(0xFFEA80FC), const Color(0xFF651FFF), const Color(0xFFFFD1FF));
      default:
        _colorCactus(ctx, ux, uy, uw, uh, seed);
    }
  }
}

void _drawFlyer(Ctx ctx, Obstacle o, bool colorful, double time, Color fg) {
  final flap = ((time * 6 + o.seed).floor() % 2) == 1;
  final x = o.x, y = o.y, w = o.w, h = o.h;
  if (!colorful) {
    ctx.fillStyle = fg;
    ctx.fillRect(x, y + 12, 6, 3);
    ctx.fillRect(x + 6, y + 9, 8, 8);
    ctx.fillRect(x + 14, y + 12, 22, 6);
    ctx.fillRect(x + 36, y + 10, 6, 3);
    ctx.fillStyle = const Color(0xFFFFFFFF);
    ctx.fillRect(x + 9, y + 11, 2, 2);
    ctx.fillStyle = fg;
    if (flap) {
      ctx.fillRect(x + 18, y, 5, 12);
      ctx.fillRect(x + 23, y + 4, 4, 8);
    } else {
      ctx.fillRect(x + 18, y + 18, 5, 12);
      ctx.fillRect(x + 23, y + 18, 4, 8);
    }
    return;
  }
  final b = o.biome ?? kBiomes[0];
  if (b.ufo) {
    final cx = x + w / 2, cy = y + h / 2 + math.sin(time * 5 + o.seed) * 2;
    ctx.fillStyle = const Color(0xB3A0FFF0);
    ctx.beginPath();
    ctx.ellipse(cx, cy - 4, 9, 8, 0, _pi, 0);
    ctx.fill();
    ctx.fillStyle = const Color(0xFFB0BEC5);
    ctx.fillEllipse(cx, cy, w / 2, 6);
    ctx.fillStyle = const Color(0xFF78909C);
    ctx.fillRect(cx - w / 2 + 4, cy + 1, w - 8, 2);
    for (var i = 0; i < 4; i++) {
      ctx.fillStyle = ((time * 8).floor() + i) % 2 == 1 ? const Color(0xFFFFEB3B) : const Color(0xFFFF4081);
      ctx.fillCircle(cx - 13 + i * 9, cy, 1.8);
    }
    return;
  }
  // pterosaur facing left
  final cy = y + h / 2;
  ctx.fillStyle = b.flyerWing;
  ctx.beginPath();
  if (flap) {
    ctx.moveTo(x + 16, cy);
    ctx.lineTo(x + 30, y - 4);
    ctx.lineTo(x + 34, cy);
  } else {
    ctx.moveTo(x + 16, cy);
    ctx.lineTo(x + 30, y + h + 6);
    ctx.lineTo(x + 34, cy);
  }
  ctx.fill();
  ctx.fillStyle = b.flyer;
  ctx.fillEllipse(x + 26, cy, 13, 5);
  ctx.fillCircle(x + 12, cy - 3, 6);
  ctx.beginPath();
  ctx.moveTo(x + 8, cy - 5);
  ctx.lineTo(x - 4, cy - 1);
  ctx.lineTo(x + 8, cy);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(x + 14, cy - 7);
  ctx.lineTo(x + 24, cy - 12);
  ctx.lineTo(x + 17, cy - 3);
  ctx.fill();
  ctx.fillStyle = const Color(0xFFFFFFFF);
  ctx.fillCircle(x + 11, cy - 4, 1.8);
  ctx.fillStyle = const Color(0xFF000000);
  ctx.fillRect(x + 10, cy - 5, 1.2, 1.2);
}

void _drawMeteor(Ctx ctx, Obstacle o, double time, double gy) {
  final pulse = 0.5 + 0.5 * math.sin(time * 18);
  ctx.strokeStyle = Color.fromRGBO(255, 60, 40, 0.4 + pulse * 0.6);
  ctx.lineWidth = 2;
  ctx.strokeEllipse(o.x + o.w / 2, gy, 16, 4);
  final cx = o.x + o.w / 2, cy = o.y + o.h / 2;
  final g = Grad.linear(cx, cy, cx + 30, cy - 60)
    ..addColorStop(0, const Color(0xE6FFC83C))
    ..addColorStop(1, const Color(0x00FF3C00));
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.moveTo(cx - 9, cy);
  ctx.lineTo(cx + 34, cy - 70);
  ctx.lineTo(cx + 9, cy);
  ctx.fill();
  ctx.fillStyle = const Color(0xFF4E342E);
  ctx.fillCircle(cx, cy, 10);
  ctx.fillStyle = const Color(0xFFFF7043);
  ctx.fillCircle(cx - 3, cy + 2, 4);
}

void drawObstacle(Ctx ctx, Obstacle o, bool colorful, double time, Color fg, double gy) {
  switch (o.kind) {
    case ObstacleKind.ground:
      _drawGround(ctx, o, colorful, time, fg);
    case ObstacleKind.flyer:
      _drawFlyer(ctx, o, colorful, time, fg);
    case ObstacleKind.meteor:
      _drawMeteor(ctx, o, time, gy);
  }
}

// ---- pickups ---------------------------------------------------------------------------
void drawCoin(Ctx ctx, double x, double y, double time) {
  final sx = math.cos(time * 4 + x * 0.05).abs();
  ctx.fillStyle = const Color(0xFFB8860B);
  ctx.fillEllipse(x, y, 6 * sx + 1, 6);
  ctx.fillStyle = const Color(0xFFFFD54F);
  ctx.fillEllipse(x, y, 4.6 * sx + 0.5, 4.6);
  ctx.fillStyle = const Color(0xFFFFF8E1);
  ctx.fillRect(x - 1.5 * sx, y - 3, 1.5, 3);
}

class PowerupDef {
  const PowerupDef(this.icon, this.color, this.name);
  final String icon, name;
  final Color color;
}

const Map<String, PowerupDef> kPowerups = {
  'shield': PowerupDef('🛡️', Color(0xFF4FC3F7), 'Shield'),
  'magnet': PowerupDef('🧲', Color(0xFFEF5350), 'Magnet'),
  'double': PowerupDef('×2', Color(0xFFFFD54F), 'Double Coins'),
  'rocket': PowerupDef('🚀', Color(0xFFAB47BC), 'Rocket'),
};

void drawPowerup(Ctx ctx, Powerup p, double time) {
  final def = kPowerups[p.type]!;
  final y = p.y + math.sin(time * 4 + p.x * 0.02) * 4;
  final g = Grad.radial(p.x, y, 2, p.x, y, 16)
    ..addColorStop(0, const Color(0xF2FFFFFF))
    ..addColorStop(1, def.color.withValues(alpha: 0.4));
  ctx.fillStyle = g;
  ctx.fillCircle(p.x, y, 14);
  ctx.strokeStyle = def.color;
  ctx.lineWidth = 2;
  ctx.strokeCircle(p.x, y, 14);
  ctx.text(def.icon, p.x, y + 1,
      size: p.type == 'double' ? 12 : 14, weight: p.type == 'double' ? FontWeight.w800 : FontWeight.w400, color: const Color(0xFF5D4037));
}

void drawBone(Ctx ctx, Bone b, Color fg) {
  ctx.fillStyle = fg;
  final x = b.x, y = b.y;
  ctx.fillRect(x - 8, y - 2, 16, 4);
  ctx.fillCircle(x - 8, y - 2.5, 3);
  ctx.fillCircle(x - 8, y + 2.5, 3);
  ctx.fillCircle(x + 8, y - 2.5, 3);
  ctx.fillCircle(x + 8, y + 2.5, 3);
}
