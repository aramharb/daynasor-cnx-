// Tiny synthesized sound effects (no audio files needed, works offline).
// Sounds are generated once as 16-bit WAV bytes and played via audioplayers.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

const int _sampleRate = 22050;

class _Tone {
  const _Tone(this.f, this.dur, {this.to, this.type = 'square', this.vol = 0.06, this.delay = 0});
  final double f, dur, vol, delay;
  final double? to;
  final String type;
}

class _Noise {
  const _Noise(this.dur, this.vol);
  final double dur, vol;
}

List<Object> _def(String name, bool c) {
  List<_Tone> seq(List<double> fs, double dur, double step, String type, double vol) =>
      [for (var i = 0; i < fs.length; i++) _Tone(fs[i], dur, delay: i * step, type: type, vol: vol)];
  switch (name) {
    case 'jump':
      return c ? [const _Tone(380, 0.12, to: 760, type: 'triangle', vol: 0.08)] : [const _Tone(600, 0.06)];
    case 'point':
      final t = c ? 'triangle' : 'square';
      return [_Tone(880, 0.07, type: t), _Tone(1320, 0.1, delay: 0.08, type: t)];
    case 'hit':
      return [const _Tone(200, 0.3, to: 60, type: 'sawtooth', vol: 0.08), if (c) const _Noise(0.3, 0.1)];
    case 'coin':
      return [const _Tone(988, 0.05, vol: 0.04), const _Tone(1319, 0.12, delay: 0.05, vol: 0.04)];
    case 'power':
      return seq([523, 659, 784, 1047], 0.1, 0.06, 'triangle', 0.07);
    case 'ability':
      return [const _Tone(220, 0.25, to: 880, type: 'sawtooth', vol: 0.05), const _Noise(0.2, 0.05)];
    case 'smash':
      return [const _Noise(0.18, 0.12)];
    case 'bonus':
      return [const _Tone(700, 0.15, to: 1400, vol: 0.05)];
    case 'egg':
      return seq([392, 494, 587, 784, 988], 0.14, 0.08, 'triangle', 0.08);
    case 'crack':
      return [const _Noise(0.08, 0.15)];
    case 'super':
      return [
        ...seq([262, 330, 392, 523, 659, 784, 1047], 0.16, 0.05, 'sawtooth', 0.05),
        const _Tone(80, 0.6, to: 40, type: 'sine', vol: 0.2),
        const _Noise(0.4, 0.08),
      ];
    case 'zap':
      return [const _Noise(0.12, 0.14), const _Tone(1800, 0.15, to: 200, type: 'sawtooth', vol: 0.04)];
    case 'splash':
      return [const _Noise(0.2, 0.08), const _Tone(500, 0.18, to: 150, type: 'sine', vol: 0.06)];
    case 'chomp':
      return [const _Tone(300, 0.08, to: 120, vol: 0.06), const _Tone(260, 0.08, to: 100, delay: 0.09, vol: 0.06)];
    case 'online':
      return seq([262, 330, 392, 523, 659, 784], 0.12, 0.05, 'triangle', 0.06);
    case 'offline':
      return seq([523, 392, 262], 0.12, 0.08, 'square', 0.04);
  }
  return const [];
}

double _wave(String type, double phase) {
  final p = phase - phase.floorToDouble();
  switch (type) {
    case 'sine':
      return math.sin(p * 2 * math.pi);
    case 'triangle':
      return 4 * (p < 0.5 ? p : 1 - p) - 1;
    case 'sawtooth':
      return 2 * p - 1;
    default:
      return p < 0.5 ? 1 : -1;
  }
}

Uint8List _render(List<Object> events) {
  var total = 0.0;
  for (final e in events) {
    if (e is _Tone) total = math.max(total, e.delay + e.dur);
    if (e is _Noise) total = math.max(total, e.dur);
  }
  final n = (total * _sampleRate).ceil() + 64;
  final mix = Float64List(n);
  final rng = math.Random(7);
  for (final e in events) {
    if (e is _Tone) {
      final start = (e.delay * _sampleRate).floor();
      final len = (e.dur * _sampleRate).floor();
      var phase = 0.0;
      for (var i = 0; i < len && start + i < n; i++) {
        final t = i / len;
        final f = e.to == null ? e.f : e.f * math.pow(e.to! / e.f, t);
        phase += f / _sampleRate;
        final env = e.vol * math.pow(0.0001 / e.vol, t);
        mix[start + i] += _wave(e.type, phase) * env;
      }
    } else if (e is _Noise) {
      final len = (e.dur * _sampleRate).floor();
      for (var i = 0; i < len && i < n; i++) {
        mix[i] += (rng.nextDouble() * 2 - 1) * (1 - i / len) * e.vol;
      }
    }
  }
  final data = ByteData(44 + n * 2);
  void str(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, _sampleRate, Endian.little);
  data.setUint32(28, _sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(44 + i * 2, (mix[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

class Sfx {
  bool enabled = true;
  bool _broken = false;
  final Map<String, Uint8List> _cache = {};
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  static const int _poolSize = 6;

  void setEnabled(bool v) => enabled = v;

  /// Plays a named effect. [colorful] picks the juicier variant where one exists.
  void play(String name, {bool colorful = false}) {
    if (!enabled || _broken) return;
    try {
      final key = '$name|$colorful';
      final bytes = _cache.putIfAbsent(key, () => _render(_def(name, colorful)));
      if (bytes.length <= 100) return;
      if (_pool.length < _poolSize) _pool.add(AudioPlayer());
      final p = _pool[_next++ % _pool.length];
      unawaited(Future(() async {
        try {
          await p.stop();
          await p.play(BytesSource(bytes), volume: 0.8);
        } catch (_) {
          _broken = true; // platform without audio support: stay silent
        }
      }));
    } catch (_) {
      _broken = true;
    }
  }
}

final Sfx sfx = Sfx();

/// Short vibration; heavier for big moments.
void buzz({bool heavy = false}) {
  try {
    unawaited(heavy ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact());
  } catch (_) {}
}
