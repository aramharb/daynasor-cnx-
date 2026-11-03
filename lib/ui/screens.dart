import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../game/dinos.dart';
import 'theme.dart';
import 'widgets.dart';

/// Wraps a panel in a centered, scrollable, safe-area-aware full-screen layer.
class _Layer extends StatelessWidget {
  const _Layer({required this.pal, required this.child, this.scrim = true});
  final Pal pal;
  final Widget child;
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 40, 12, 12),
      child: Center(child: SingleChildScrollView(child: child)),
    );
    return scrim ? ColoredBox(color: pal.scrim, child: SizedBox.expand(child: body)) : body;
  }
}

bool _compact(BuildContext c) => MediaQuery.sizeOf(c).height < 420;

// ====================================================================== MENU
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);
    final def = app.selected;
    final compact = _compact(context);
    final eggs = app.store.getInt('eggs');
    final modeLine = app.colorful
        ? 'Online · Jurassic mode — colors, coins & powers!'
        : app.online
            ? 'Classic mode (forced in settings)'
            : 'Offline · Classic mode — connect for Jurassic mode';
    final hint = app.colorful
        ? 'Tap to jump · Swipe down to duck · ⚡ ability · 🌟 SUPER when the meter is full'
        : 'Tap to jump · Swipe down or hold ▼ to duck';
    final titleStyle = pal.style(size: compact ? 30 : 38, weight: FontWeight.w900, letterSpacing: 2, height: 1);

    final title = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (pal.classic) ...[
        Text('DINO', style: titleStyle),
        const SizedBox(width: 10),
        Text('DASH', style: titleStyle),
      ] else ...[
        GradientText('DINO', style: titleStyle, colors: const [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
        const SizedBox(width: 10),
        GradientText('DASH', style: titleStyle, colors: const [Color(0xFF42E695), Color(0xFF3BB2B8)]),
      ],
    ]);
    final hero = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      title,
      const SizedBox(height: 6),
      Text(modeLine, textAlign: TextAlign.center, style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted)),
      const SizedBox(height: 6),
      Center(child: DinoPreview(def: def, width: compact ? 110 : 130, height: compact ? 70 : 90, classic: pal.classic, animate: true)),
      Text(def.name, textAlign: TextAlign.center, style: pal.style(size: 15, weight: FontWeight.w800)),
      Text(app.colorful ? '⚡ ${def.ability.name} · 🌟 SUPER: ${def.superPower.name}' : def.era,
          textAlign: TextAlign.center, style: pal.style(size: 11, weight: FontWeight.w400, color: pal.muted)),
    ]);
    final actions = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GameButton(pal: pal, kind: BtnKind.primary, label: const Text('▶ PLAY'), onTap: app.play),
      if (eggs > 0) ...[
        const SizedBox(height: 8),
        GameButton(pal: pal, kind: BtnKind.egg, label: Text(eggs > 1 ? '🥚 Hatch egg ×$eggs' : '🥚 Hatch egg'), onTap: app.openHatch),
      ],
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: GameButton(pal: pal, label: Text('🦖 Dinos  ${app.store.unlocked.length}/${kDinos.length}'), onTap: () => app.go(AppScreen.dinos)),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 52, child: GameButton(pal: pal, label: const Text('⚙'), onTap: () => app.go(AppScreen.settings))),
      ]),
      const SizedBox(height: 8),
      Text(hint, textAlign: TextAlign.center, style: pal.style(size: 11, weight: FontWeight.w400, color: pal.muted)),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('🪙 ${app.store.getInt('coins')}', style: pal.style(size: 13)),
        const SizedBox(width: 18),
        Text('🏆 ${app.colorful ? app.store.getInt('hiColor') : app.store.getInt('hiClassic')}', style: pal.style(size: 13)),
      ]),
    ]);

    return _Layer(
      pal: pal,
      scrim: false,
      child: compact
          ? Panel(
              pal: pal,
              width: 640,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(child: hero),
                const SizedBox(width: 18),
                Expanded(child: actions),
              ]),
            )
          : Panel(
              pal: pal,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                hero,
                const SizedBox(height: 10),
                actions,
              ]),
            ),
    );
  }
}

// ====================================================================== COLLECTION
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);
    final unlocked = app.store.unlocked;
    final selected = app.store.get<String>('selected');
    final d = getDino(app.detailId ?? selected);
    final has = unlocked.contains(d.id);
    final coins = app.store.getInt('coins');
    final allDone = unlocked.length >= kDinos.length;

    Widget line(String label, String text, {Color? labelColor}) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$label ', style: pal.style(size: 13, weight: FontWeight.w800, color: labelColor ?? pal.accent)),
            TextSpan(text: text, style: pal.style(size: 13, weight: FontWeight.w400)),
          ])),
        );

    final header = Row(children: [
      SizedBox(width: 52, child: GameButton(pal: pal, small: true, label: const Text('←'), onTap: () => app.go(AppScreen.menu))),
      Expanded(child: Text('Dino Collection', textAlign: TextAlign.center, style: pal.style(size: 20, weight: FontWeight.w800))),
      SizedBox(width: 52, child: Text('🪙 $coins', textAlign: TextAlign.right, style: pal.style(size: 14, weight: FontWeight.w800))),
    ]);
    final detail = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.classic ? Colors.transparent : const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(pal.classic ? 2 : 12),
        border: pal.classic ? Border.all(color: pal.border) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: has ? d.name : '??? (locked)', style: pal.style(size: 15, weight: FontWeight.w800)),
          TextSpan(text: '  ·  ', style: pal.style(size: 13, weight: FontWeight.w400)),
          TextSpan(text: d.rar.label, style: pal.style(size: 13, color: app.colorful ? d.rar.color : pal.text)),
        ])),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('🦴 ${d.era}', style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted)),
        ),
        if (has) ...[
          line('⚡ ${d.ability.name}:', d.ability.desc),
          line('🌟 SUPER · ${d.superPower.name}:', d.superPower.desc, labelColor: pal.classic ? pal.text : const Color(0xFFE040FB)),
          if (d.passiveDesc != null) line('✨ Passive:', d.passiveDesc!),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('📖 Real fact: ${d.fact}', style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted).copyWith(fontStyle: FontStyle.italic)),
          ),
        ] else
          line('🔒', 'Hatch eggs to discover this dinosaur, its ability and its SUPER power.'),
        if (!app.colorful)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('📴 Abilities, coins and colors only work in Jurassic mode (online).',
                style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted)),
          ),
      ]),
    );

    Widget card(DinoDef dino) {
      final own = unlocked.contains(dino.id);
      final isSel = dino.id == selected;
      return InkWell(
        borderRadius: BorderRadius.circular(pal.classic ? 2 : 12),
        onTap: () => app.selectDino(dino.id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: pal.classic ? Colors.transparent : (isSel ? const Color(0x26FFD54F) : const Color(0x14FFFFFF)),
            borderRadius: BorderRadius.circular(pal.classic ? 2 : 12),
            border: Border.all(color: isSel ? pal.accent : (pal.classic ? const Color(0xFFCCCCCC) : Colors.transparent), width: 2),
          ),
          child: Stack(children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              DinoPreview(def: dino, width: 80, height: 56, locked: !own, classic: own && pal.classic),
              const SizedBox(height: 2),
              Text(own ? dino.name : '???',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: pal.style(size: 10, weight: FontWeight.w800, height: 1.15)),
              Text(dino.rar.label.toUpperCase(),
                  style: pal.style(size: 9, weight: FontWeight.w800, color: app.colorful ? dino.rar.color : pal.muted, letterSpacing: 1)),
            ]),
            if (!own) const Positioned(right: 2, top: 0, child: Text('🔒', style: TextStyle(fontSize: 12))),
          ]),
        ),
      );
    }

    Widget grid({required bool scroll, required double maxExtent}) => GridView.builder(
          shrinkWrap: !scroll,
          physics: scroll ? null : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: maxExtent, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 124),
          itemCount: kDinos.length,
          itemBuilder: (context, i) => card(kDinos[i]),
        );

    final buy = GameButton(
      pal: pal,
      kind: BtnKind.egg,
      small: _compact(context),
      onTap: !app.colorful || coins < kEggPrice ? null : app.buyEgg,
      label: Text(!app.colorful
          ? '🔌 Go online to buy eggs'
          : allDone
              ? '🥚 Buy egg (bonus coins) · 🪙 $kEggPrice'
              : '🥚 Buy egg · 🪙 $kEggPrice'),
    );

    if (_compact(context)) {
      // landscape phone: details on the left, scrollable grid on the right
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 36, 12, 8),
        child: Center(
          child: Panel(
            pal: pal,
            width: 820,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              header,
              const SizedBox(height: 6),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 5, child: SingleChildScrollView(child: detail)),
                  const SizedBox(width: 10),
                  Expanded(flex: 6, child: grid(scroll: true, maxExtent: 110)),
                ]),
              ),
              const SizedBox(height: 6),
              buy,
            ]),
          ),
        ),
      );
    }

    return _Layer(
      pal: pal,
      child: Panel(
        pal: pal,
        width: 640,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          const SizedBox(height: 6),
          Text('Every time your phone connects to the internet you get a 🥚 egg. Hatch it to unlock a random dino!',
              textAlign: TextAlign.center, style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted, height: 1.3)),
          const SizedBox(height: 8),
          detail,
          const SizedBox(height: 8),
          grid(scroll: false, maxExtent: 110),
          const SizedBox(height: 8),
          buy,
        ]),
      ),
    );
  }
}

// ====================================================================== SETTINGS
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);

    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) => InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(label, style: pal.style(size: 15, weight: FontWeight.w700))),
              Switch(value: value, onChanged: onChanged, activeThumbColor: pal.classic ? const Color(0xFF535353) : const Color(0xFFFF7043)),
            ]),
          ),
        );

    return _Layer(
      pal: pal,
      child: Panel(
        pal: pal,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            SizedBox(width: 52, child: GameButton(pal: pal, small: true, label: const Text('←'), onTap: () => app.go(AppScreen.menu))),
            Expanded(child: Text('Settings', textAlign: TextAlign.center, style: pal.style(size: 20, weight: FontWeight.w800))),
            const SizedBox(width: 52),
          ]),
          const SizedBox(height: 8),
          toggle('Sound', app.store.getBool('sound'), app.setSound),
          toggle('Always play Classic mode', app.store.getBool('forceClassic'), app.setForceClassic),
          const SizedBox(height: 6),
          Text(
              'Classic mode is the minimal black & white runner. Jurassic mode (colors, coins, power-ups, dino abilities, super powers, biomes) needs an internet connection.',
              style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted, height: 1.4)),
          const SizedBox(height: 12),
          GameButton(
            pal: pal,
            kind: BtnKind.danger,
            label: const Text('Reset progress'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Reset progress?'),
                  content: const Text('This deletes all dinos, coins and scores.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
                  ],
                ),
              );
              if (ok == true) app.resetProgress();
            },
          ),
        ]),
      ),
    );
  }
}

// ====================================================================== HATCH
class HatchScreen extends StatelessWidget {
  const HatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);
    final h = app.hatch;
    if (h == null) return const SizedBox.shrink();
    final d = h.result;
    final compact = _compact(context);

    Widget content;
    if (!h.revealed) {
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        Text('A mystery egg!', style: pal.style(size: 20, weight: FontWeight.w800)),
        SizedBox(height: compact ? 4 : 12),
        EggWidget(taps: h.taps, burst: h.done, onTap: app.tapEgg, scale: compact ? 0.8 : 1),
        SizedBox(height: compact ? 4 : 12),
        Text(h.done ? '' : 'Tap the egg to crack it!', style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted)),
      ]);
    } else if (d != null) {
      final art = Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.2, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: compact ? 130 : 200,
            height: compact ? 90 : 150,
            decoration: BoxDecoration(gradient: RadialGradient(colors: [d.rar.color.withValues(alpha: 0.5), Colors.transparent], radius: 0.7)),
            child: DinoPreview(def: d, width: compact ? 130 : 200, height: compact ? 90 : 150, classic: pal.classic),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: d.rar.color, borderRadius: BorderRadius.circular(99)),
          child: Text(d.rar.label, style: pal.style(size: 12, weight: FontWeight.w900, color: const Color(0xFF1B1036))),
        ),
      ]);
      final info = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
        Text('⚡ ${d.ability.name}', style: pal.style(size: 14, weight: FontWeight.w800)),
        Text(d.ability.desc, textAlign: compact ? TextAlign.left : TextAlign.center, style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted)),
        const SizedBox(height: 4),
        Text('🌟 SUPER: ${d.superPower.name}', style: pal.style(size: 14, weight: FontWeight.w800, color: pal.classic ? pal.text : const Color(0xFFE040FB))),
        Text(d.superPower.desc, textAlign: compact ? TextAlign.left : TextAlign.center, style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted)),
      ]);
      final heading = Text('You hatched ${d.name}!', textAlign: TextAlign.center, style: pal.style(size: 20, weight: FontWeight.w800));
      content = compact
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              heading,
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [art, const SizedBox(width: 16), Expanded(child: info)]),
            ])
          : Column(mainAxisSize: MainAxisSize.min, children: [heading, const SizedBox(height: 6), art, const SizedBox(height: 6), info]);
    } else {
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        Text('You have every dino!', style: pal.style(size: 20, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('The egg was full of coins: +$kAllDupesCoins 🪙', style: pal.style(size: 13, weight: FontWeight.w400, color: pal.muted)),
      ]);
    }

    return _Layer(
      pal: pal,
      child: Panel(
        pal: pal,
        width: compact && h.revealed ? 560 : 360,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: content),
          if (h.revealed) ...[
            const SizedBox(height: 10),
            GameButton(
                pal: pal,
                kind: BtnKind.primary,
                label: Text(app.store.getInt('eggs') > 0 ? 'Next egg 🥚' : 'Awesome!'),
                onTap: app.finishHatch),
          ],
        ]),
      ),
    );
  }
}

class EggWidget extends StatefulWidget {
  const EggWidget({super.key, required this.taps, required this.burst, required this.onTap, this.scale = 1});
  final int taps;
  final bool burst;
  final VoidCallback onTap;
  final double scale;

  @override
  State<EggWidget> createState() => _EggWidgetState();
}

/// Tap area of the egg (separate type so tests can find it).
class EggTapTarget extends StatelessWidget {
  const EggTapTarget({super.key, required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
}

class _EggWidgetState extends State<EggWidget> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  @override
  void didUpdateWidget(covariant EggWidget old) {
    super.didUpdateWidget(old);
    if (widget.taps != old.taps) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _idle.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EggTapTarget(
      onTap: widget.onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.burst ? 1 : 0),
        duration: const Duration(milliseconds: 450),
        builder: (context, burst, child) => Opacity(
          opacity: (1 - burst).clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: widget.scale * (1 + 0.8 * burst), child: child),
        ),
        child: SizedBox(
          width: 110,
          height: 150,
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _shake]),
            builder: (context, _) {
              final s = _shake.isAnimating ? math.sin(_shake.value * math.pi * 4) * 0.25 * (1 - _shake.value) : 0.0;
              final idle = (_idle.value - 0.5) * 0.14;
              return Transform.rotate(
                angle: s + idle,
                alignment: Alignment.bottomCenter,
                child: CustomPaint(painter: _EggPainter(widget.taps)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EggPainter extends CustomPainter {
  _EggPainter(this.taps);
  final int taps;

  @override
  void paint(Canvas canvas, Size size) {
    final w = 96.0, h = 124.0;
    final ox = (size.width - w) / 2, oy = size.height - h - 4;
    final path = Path()
      ..moveTo(ox + w / 2, oy)
      ..cubicTo(ox + w * 0.95, oy, ox + w, oy + h * 0.55, ox + w, oy + h * 0.68)
      ..cubicTo(ox + w, oy + h * 0.9, ox + w * 0.75, oy + h, ox + w / 2, oy + h)
      ..cubicTo(ox + w * 0.25, oy + h, ox, oy + h * 0.9, ox, oy + h * 0.68)
      ..cubicTo(ox, oy + h * 0.55, ox + w * 0.05, oy, ox + w / 2, oy)
      ..close();
    canvas.drawShadow(path, Colors.black, 6, true);
    final rect = Rect.fromLTWH(ox, oy, w, h);
    canvas.drawPath(
        path,
        Paint()
          ..shader = const RadialGradient(center: Alignment(-0.3, -0.4), radius: 1, colors: [Colors.white, Color(0xFFFFE0B2), Color(0xFFFFAB91)], stops: [0, 0.4, 1])
              .createShader(rect));
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(Rect.fromLTWH(ox + 18, oy + 40, 20, 16), Paint()..color = const Color(0xFF81C784));
    canvas.drawOval(Rect.fromLTWH(ox + 58, oy + 26, 14, 12), Paint()..color = const Color(0xFF64B5F6));
    canvas.drawOval(Rect.fromLTWH(ox + 50, oy + 78, 24, 18), Paint()..color = const Color(0xFFBA68C8));
    // shading
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 14..color = const Color(0x1F000000));
    canvas.restore();
    final crack = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    if (taps >= 1) {
      canvas.drawPath(
          Path()
            ..moveTo(ox + w * 0.2, oy + h * 0.25)
            ..lineTo(ox + w * 0.42, oy + h * 0.42)
            ..lineTo(ox + w * 0.34, oy + h * 0.55)
            ..lineTo(ox + w * 0.6, oy + h * 0.7),
          crack);
    }
    if (taps >= 2) {
      canvas.drawPath(
          Path()
            ..moveTo(ox + w * 0.82, oy + h * 0.3)
            ..lineTo(ox + w * 0.62, oy + h * 0.45)
            ..lineTo(ox + w * 0.7, oy + h * 0.6)
            ..lineTo(ox + w * 0.5, oy + h * 0.78),
          crack);
    }
  }

  @override
  bool shouldRepaint(_EggPainter o) => o.taps != taps;
}

// ====================================================================== PAUSE / OVER
class PauseScreen extends StatelessWidget {
  const PauseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);
    return _Layer(
      pal: pal,
      child: Panel(
        pal: pal,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Paused', textAlign: TextAlign.center, style: pal.style(size: 20, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          GameButton(pal: pal, kind: BtnKind.primary, label: const Text('▶ Resume'), onTap: app.resumeGame),
          const SizedBox(height: 8),
          GameButton(pal: pal, label: const Text('Menu'), onTap: app.quitToMenu),
        ]),
      ),
    );
  }
}

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);
    final o = app.over;
    if (o == null) return const SizedBox.shrink();

    Widget stat(String label, String value) => Column(children: [
          Text(label.toUpperCase(), style: pal.style(size: 11, weight: FontWeight.w400, color: pal.muted)),
          Text(value, style: pal.style(size: 26, weight: FontWeight.w800)),
        ]);

    final note = o.colorful
        ? 'Total coins: ${app.store.getInt('coins')} 🪙 · eggs cost $kEggPrice'
        : app.online
            ? 'Tip: turn off "Always play Classic" in settings for Jurassic mode.'
            : 'Connect to the internet to unlock Jurassic mode, coins, eggs & super powers!';

    return _Layer(
      pal: pal,
      child: Panel(
        pal: pal,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(o.newBest ? 'NEW BEST!' : 'GAME OVER', textAlign: TextAlign.center, style: pal.style(size: 26, weight: FontWeight.w800, letterSpacing: 3)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            stat('Score', '${o.score}'),
            const SizedBox(width: 18),
            stat('Best', '${o.best}'),
            if (o.colorful) ...[const SizedBox(width: 18), stat('Coins', '+${o.coins}')],
          ]),
          const SizedBox(height: 8),
          Text(note, textAlign: TextAlign.center, style: pal.style(size: 12, weight: FontWeight.w400, color: pal.muted, height: 1.4)),
          const SizedBox(height: 10),
          GameButton(pal: pal, kind: BtnKind.primary, label: const Text('↻ Retry'), onTap: app.play),
          const SizedBox(height: 8),
          GameButton(pal: pal, label: const Text('Menu'), onTap: app.quitToMenu),
        ]),
      ),
    );
  }
}

// ====================================================================== OVERLAY BITS
class NetPill extends StatelessWidget {
  const NetPill({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);
    final text = app.net.online == null
        ? 'Checking…'
        : app.online
            ? (app.colorful ? 'Online · Jurassic' : 'Online · Classic')
            : 'Offline · Classic';
    final dot = app.online ? const Color(0xFF00E676) : const Color(0xFFBDBDBD);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IgnorePointer(
            child: Opacity(
              opacity: app.isPlaying ? 0.6 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pal.classic ? Colors.transparent : const Color(0x73000000),
                  borderRadius: BorderRadius.circular(pal.classic ? 2 : 99),
                  border: pal.classic ? Border.all(color: pal.border) : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle, boxShadow: app.online ? [BoxShadow(color: dot, blurRadius: 8)] : null),
                  ),
                  const SizedBox(width: 6),
                  Text(text, style: pal.style(size: 11, color: pal.classic ? pal.text : Colors.white)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToastView extends StatelessWidget {
  const ToastView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);
    final msg = app.toastMsg;
    if (msg == null) return const SizedBox.shrink();
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: pal.classic ? const Color(0xFF535353) : const Color(0xCC000000), borderRadius: BorderRadius.circular(pal.classic ? 2 : 12)),
              child: Text(msg, textAlign: TextAlign.center, style: pal.style(size: 14, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
