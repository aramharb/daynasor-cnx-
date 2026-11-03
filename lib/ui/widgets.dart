import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/dinos.dart';
import 'theme.dart';

/// Rounded translucent card used by all menu screens.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.pal, required this.child, this.width = 360, this.padding});
  final Pal pal;
  final Widget child;
  final double width;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: v, child: child),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: pal.panel,
          borderRadius: BorderRadius.circular(pal.radius),
          border: Border.all(color: pal.border, width: 2),
          boxShadow: pal.classic ? null : const [BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 10))],
        ),
        child: child,
      ),
    );
  }
}

enum BtnKind { normal, primary, egg, danger }

class GameButton extends StatelessWidget {
  const GameButton({super.key, required this.pal, required this.label, required this.onTap, this.kind = BtnKind.normal, this.small = false});
  final Pal pal;
  final Widget label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    Decoration deco;
    Color fg = pal.text;
    final r = BorderRadius.circular(pal.classic ? 2 : 14);
    switch (kind) {
      case BtnKind.primary:
        fg = pal.classic ? const Color(0xFFF7F7F7) : Colors.white;
        deco = pal.classic
            ? BoxDecoration(color: const Color(0xFF535353), borderRadius: r, border: Border.all(color: const Color(0xFF535353), width: 2))
            : BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
                borderRadius: r,
                boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 4))],
              );
      case BtnKind.egg:
        fg = pal.classic ? pal.text : const Color(0xFF3A2160);
        deco = pal.classic
            ? BoxDecoration(borderRadius: r, border: Border.all(color: pal.buttonBorder, width: 2))
            : BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)]), borderRadius: r);
      case BtnKind.danger:
        fg = Colors.white;
        deco = BoxDecoration(color: pal.classic ? const Color(0xFF535353) : const Color(0xFFC62828), borderRadius: r);
      case BtnKind.normal:
        deco = BoxDecoration(color: pal.buttonBg, borderRadius: r, border: Border.all(color: pal.buttonBorder, width: 2));
    }
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Ink(
            decoration: deco,
            padding: EdgeInsets.symmetric(horizontal: small ? 12 : 14, vertical: small ? 6 : 12),
            child: Center(
              child: DefaultTextStyle(
                style: pal.style(size: small ? 14 : (kind == BtnKind.primary ? 18 : 15), weight: FontWeight.w800, color: fg),
                textAlign: TextAlign.center,
                child: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dinosaur sprite on a small canvas; optionally walking.
class DinoPreview extends StatefulWidget {
  const DinoPreview({super.key, required this.def, required this.width, required this.height, this.locked = false, this.classic = false, this.animate = false});
  final DinoDef def;
  final double width, height;
  final bool locked, classic, animate;

  @override
  State<DinoPreview> createState() => _DinoPreviewState();
}

class _DinoPreviewState extends State<DinoPreview> {
  Timer? _t;
  int _frame = 2;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DinoPreview old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.animate && _t == null) {
      _t = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (mounted) setState(() => _frame = _frame == 0 ? 1 : 0);
      });
    } else if (!widget.animate) {
      _t?.cancel();
      _t = null;
      _frame = 2;
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: _PreviewPainter(widget.def, widget.locked, widget.classic, _frame),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.def, this.locked, this.classic, this.frame);
  final DinoDef def;
  final bool locked, classic;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) => paintDinoPreview(canvas, size, def, locked: locked, classic: classic, frame: frame);

  @override
  bool shouldRepaint(_PreviewPainter o) => o.def != def || o.locked != locked || o.classic != classic || o.frame != frame;
}

/// Circular in-game button with a progress ring (ability / super).
class RoundButton extends StatefulWidget {
  const RoundButton({
    super.key,
    required this.pal,
    required this.size,
    required this.onDown,
    required this.child,
    this.onUp,
    this.progress = 1,
    this.ringColor = const Color(0xFFFFD54F),
    this.glow = false,
    this.rainbow = false,
    this.fillAlpha = 0.35,
  });
  final Pal pal;
  final double size, progress, fillAlpha;
  final VoidCallback onDown;
  final VoidCallback? onUp;
  final Widget child;
  final Color ringColor;
  final bool glow, rainbow;

  @override
  State<RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<RoundButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => w.onDown(),
      onPointerUp: (_) => w.onUp?.call(),
      onPointerCancel: (_) => w.onUp?.call(),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final glow = w.glow ? _pulse.value : 0.0;
          return Transform.scale(
            scale: 1 + glow * 0.07,
            child: Container(
              width: w.size,
              height: w.size,
              decoration: BoxDecoration(
                shape: w.pal.classic ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: w.pal.classic ? BorderRadius.circular(2) : null,
                boxShadow: w.glow ? [BoxShadow(color: w.rainbow ? Color.lerp(const Color(0xFFE040FB), const Color(0xFF40C4FF), glow)! : w.ringColor, blurRadius: 8 + 14 * glow)] : null,
              ),
              child: CustomPaint(
                painter: _RingPainter(w.progress, w.ringColor, w.rainbow, w.fillAlpha, w.pal.classic),
                child: Center(child: w.child),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.rainbow, this.fillAlpha, this.classic);
  final double progress, fillAlpha;
  final Color color;
  final bool rainbow, classic;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = rect.center;
    final r = size.width / 2;
    final bg = Paint()..color = Colors.black.withValues(alpha: fillAlpha);
    if (classic) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFFF7F7F7));
      canvas.drawRect(rect.deflate(1), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF535353));
      return;
    }
    if (rainbow) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = const SweepGradient(colors: [Color(0xFFFF5252), Color(0xFFFFD740), Color(0xFF69F0AE), Color(0xFF40C4FF), Color(0xFFE040FB), Color(0xFFFF5252)])
                .createShader(rect));
    } else {
      canvas.drawCircle(c, r, bg);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.95);
      canvas.drawArc(rect.deflate(3), -math.pi / 2, math.pi * 2 * progress.clamp(0.0, 1.0), false, ring);
    }
    canvas.drawCircle(c, r - 1, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress || o.color != color || o.rainbow != rainbow || o.classic != classic;
}

/// Gradient (rainbow-ish) title text.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style, required this.colors});
  final String text;
  final TextStyle style;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(colors: colors).createShader(r),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
