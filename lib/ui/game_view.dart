import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../game/game.dart';
import 'theme.dart';
import 'widgets.dart';

/// Draws the game and handles touch / keyboard input for it.
class GameView extends StatefulWidget {
  const GameView({super.key});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;
  final FocusNode _focus = FocusNode();

  // swipe-down-to-duck tracking
  int? _pointer;
  double _startY = 0;
  bool _ducking = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      if (!mounted) return;
      AppScope.of(context).game.update(dt);
      _frame.value++;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e, AppController app) {
    if (app.screen == AppScreen.menu) {
      app.play();
      return;
    }
    if (!app.isPlaying) return;
    _pointer = e.pointer;
    _startY = e.position.dy;
    _ducking = false;
    app.game.jumpPress();
  }

  void _move(PointerMoveEvent e, AppController app) {
    if (_pointer != e.pointer || _ducking) return;
    if (e.position.dy - _startY > 28) {
      _ducking = true;
      app.game.jumpRelease();
      app.game.duck(true);
    }
  }

  void _up(PointerEvent e, AppController app) {
    if (_pointer != e.pointer) return;
    app.game.jumpRelease();
    if (_ducking) app.game.duck(false);
    _pointer = null;
    _ducking = false;
  }

  KeyEventResult _key(FocusNode node, KeyEvent e, AppController app) {
    final k = e.logicalKey;
    final down = e is KeyDownEvent;
    final up = e is KeyUpEvent;
    final jumpKey = k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW;
    final duckKey = k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS;
    if (up) {
      if (jumpKey) app.game.jumpRelease();
      if (duckKey) app.game.duck(false);
      return KeyEventResult.ignored;
    }
    if (!down) return KeyEventResult.ignored;
    if (jumpKey) {
      if (app.screen == AppScreen.menu) {
        app.play();
      } else if (app.screen == AppScreen.over && app.game.overT > 0.5) {
        app.play();
      } else if (app.isPlaying) {
        app.game.jumpPress();
      }
      return KeyEventResult.handled;
    }
    if (duckKey && app.isPlaying) {
      app.game.duck(true);
      return KeyEventResult.handled;
    }
    if (app.isPlaying && (k == LogicalKeyboardKey.keyX || k == LogicalKeyboardKey.keyE || k == LogicalKeyboardKey.shiftLeft || k == LogicalKeyboardKey.shiftRight)) {
      app.game.useAbility();
      return KeyEventResult.handled;
    }
    if (app.isPlaying && (k == LogicalKeyboardKey.keyC || k == LogicalKeyboardKey.keyZ || k == LogicalKeyboardKey.keyQ)) {
      app.game.useSuper();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.keyP) {
      if (app.isPlaying) {
        app.pauseGame();
      } else if (app.screen == AppScreen.pause) {
        app.resumeGame();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (n, e) => _key(n, e, app),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => _down(e, app),
        onPointerMove: (e) => _move(e, app),
        onPointerUp: (e) => _up(e, app),
        onPointerCancel: (e) => _up(e, app),
        child: SizedBox.expand(
          child: RepaintBoundary(
            child: CustomPaint(painter: _GamePainter(app.game, _frame)),
          ),
        ),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter(this.game, Listenable repaint) : super(repaint: repaint);
  final Game game;

  @override
  void paint(Canvas canvas, Size size) => game.paint(canvas, size);

  @override
  bool shouldRepaint(_GamePainter old) => true;
}

/// Pause / duck / ability / super buttons shown while playing.
class GameControls extends StatelessWidget {
  const GameControls({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);
    final game = app.game;
    return SafeArea(
      minimum: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: RoundButton(
              pal: pal,
              size: 42,
              onDown: app.pauseGame,
              fillAlpha: 0.25,
              child: Text('II', style: pal.style(size: 14, weight: FontWeight.w800, color: pal.classic ? pal.text : Colors.white)),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Opacity(
              opacity: 0.75,
              child: RoundButton(
                pal: pal,
                size: 68,
                onDown: () => game.duck(true),
                onUp: () => game.duck(false),
                child: CustomPaint(size: const Size(26, 18), painter: _ArrowPainter(pal.classic ? pal.text : Colors.white)),
              ),
            ),
          ),
          if (app.colorful)
            ValueListenableBuilder<HudInfo>(
              valueListenable: game.hud,
              builder: (context, h, _) => Stack(
                children: [
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: RoundButton(
                      pal: pal,
                      size: 68,
                      progress: h.abilityPct,
                      glow: h.abilityReady,
                      onDown: game.useAbility,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(h.abilityName.toUpperCase(),
                            textAlign: TextAlign.center, style: pal.style(size: 9, weight: FontWeight.w800, color: Colors.white, height: 1.1)),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 86,
                    bottom: 10,
                    child: RoundButton(
                      pal: pal,
                      size: 60,
                      progress: h.superPct,
                      ringColor: h.superActive ? Colors.white : const Color(0xFFE040FB),
                      glow: h.superFull && !h.superActive,
                      rainbow: h.superFull && !h.superActive,
                      onDown: game.useSuper,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('SUPER', style: pal.style(size: 10, weight: FontWeight.w900, color: Colors.white)),
                          Text(h.superActive ? 'ON!' : h.superFull ? 'READY' : '${(h.superPct * 100).floor()}%',
                              style: pal.style(size: 9, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}
