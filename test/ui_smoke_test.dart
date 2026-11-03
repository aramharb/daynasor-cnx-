// Drives the real widget tree through every screen. When SHOT_DIR is set it also
// saves PNG screenshots there (handy for eyeballing the UI without a device).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dino_dash/app_controller.dart';
import 'package:dino_dash/game/dinos.dart';
import 'package:dino_dash/game/entities.dart';
import 'package:dino_dash/game/game.dart';
import 'package:dino_dash/main.dart';
import 'package:dino_dash/ui/screens.dart';
import 'package:dino_dash/services/network.dart';
import 'package:dino_dash/services/store.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final GlobalKey _rootKey = GlobalKey();
final String? _shotDir = Platform.environment['SHOT_DIR'];

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final f = File(path);
    if (!f.existsSync()) return;
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await loader.load();
  }

  // flutter_test falls back to the blocky 'Ahem' font; replace it with a real one so text is readable.
  await load('Ahem', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  await load('Roboto', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  await load('monospace', '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf');
}

Future<void> _shot(WidgetTester t, String name) async {
  final dir = _shotDir;
  if (dir == null) return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_rootKey));
    final ui.Image img = await boundary.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void _bot(Game g) {
  final o = g.obstacles.where((o) => !o.dead && o.x + o.w > g.d.x).toList();
  if (o.isEmpty) {
    g.jumpRelease();
    g.duck(false);
    return;
  }
  final first = o.first;
  final dist = first.x - (g.d.x + 40);
  g.duck(false);
  if (first.kind == ObstacleKind.flyer && first.y < g.gy - 60) return;
  if (first.kind == ObstacleKind.flyer && first.y < g.gy - 45) {
    if (dist < 80) g.duck(true);
    return;
  }
  if (dist < g.speed * 0.17 && g.d.onGround) g.jumpPress();
}

Future<void> _run(WidgetTester t, AppController app, double seconds, {bool bot = true}) async {
  for (var i = 0; i < seconds * 60; i++) {
    if (bot) _bot(app.game);
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<AppController> _boot(WidgetTester t, {Size size = const Size(844, 390), Map<String, dynamic>? save}) async {
  t.view.physicalSize = Size(size.width, size.height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final app = AppController(Store.memory({'sound': false, ...?save}), network: NetworkMonitor(), autoStartNetwork: false);
  addTearDown(app.dispose);
  await t.pumpWidget(RepaintBoundary(key: _rootKey, child: DinoDashApp(controller: app)));
  await t.pump(const Duration(milliseconds: 100));
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('offline: classic menu → play → game over → retry', (t) async {
    final app = await _boot(t);
    app.online = false;
    app.applyMode(animate: false);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('▶ PLAY'), findsOneWidget);
    await _shot(t, '01-offline-menu');

    await t.tap(find.text('▶ PLAY'));
    await t.pump();
    expect(app.screen, AppScreen.playing);
    expect(app.game.colorful, isFalse);
    await _run(t, app, 6);
    await _shot(t, '02-offline-run');
    expect(app.game.score, greaterThan(20));

    app.game.debugDie();
    await t.pump(const Duration(milliseconds: 900));
    expect(app.screen, AppScreen.over);
    await _shot(t, '03-offline-over');
    await t.tap(find.text('↻ Retry'));
    await t.pump();
    expect(app.screen, AppScreen.playing);
    app.pauseGame();
    await t.pump(const Duration(milliseconds: 400));
    expect(app.screen, AppScreen.pause);
    await _shot(t, '04-pause');
    await t.tap(find.text('Menu'));
    await t.pump(const Duration(milliseconds: 400));
    expect(app.screen, AppScreen.menu);
  });

  testWidgets('going online mid-run transforms the game', (t) async {
    final app = await _boot(t);
    app.online = false;
    app.applyMode(animate: false);
    app.play();
    await _run(t, app, 2);
    app.online = true;
    app.applyMode(animate: true);
    await _run(t, app, 0.55);
    await _shot(t, '05-transition');
    await _run(t, app, 1.5);
    expect(app.game.colorful, isTrue);
    expect(app.game.modeT, 1);
    await _shot(t, '06-online-run');
    expect(find.text('SUPER'), findsOneWidget); // new in-game button
  });

  testWidgets('online: every dino super power renders', (t) async {
    final all = kDinos.map((d) => d.id).toList();
    final app = await _boot(t, save: {'unlocked': all, 'selected': 'rex'});
    app.online = true;
    app.applyMode(animate: false);
    app.play();
    app.game.fx.invuln = 9999;
    final scores = [100.0, 700.0, 1300.0, 1900.0, 2500.0];
    for (var i = 0; i < kDinos.length; i++) {
      final d = kDinos[i];
      final g = app.game;
      g.endSuper(silent: true);
      g.setDino(d.id);
      g.dist = scores[i % 5] / 0.025;
      g.bonus = 0;
      g.abilityCd = 0;
      g.useAbility();
      await _run(t, app, 0.7, bot: false);
      await _shot(t, 'a-${d.id}');
      g.superMeter = 1;
      g.fx.dive = 0;
      g.fx.rocket = 0;
      g.useSuper();
      await _run(t, app, 1.5, bot: false);
      if (d.id == 'ptero') g.jumpPress();
      await t.pump(const Duration(milliseconds: 100));
      await _shot(t, 's-${d.id}');
      expect(g.fx.superT, greaterThan(0), reason: d.id);
    }
  });

  testWidgets('online: collection, hatching, settings', (t) async {
    final app = await _boot(t, save: {
      'unlocked': ['rex', 'spino', 'dilo', 'brachio'],
      'selected': 'spino',
      'eggs': 1,
      'coins': 400,
    });
    app.online = true;
    app.applyMode(animate: false);
    await t.pump(const Duration(milliseconds: 300));
    await _shot(t, '07-online-menu');

    await t.tap(find.textContaining('Dinos'));
    await t.pump(const Duration(milliseconds: 400));
    expect(app.screen, AppScreen.dinos);
    await _shot(t, '08-collection');

    app.go(AppScreen.menu);
    await t.pump();
    await t.tap(find.textContaining('Hatch egg'));
    await t.pump(const Duration(milliseconds: 400));
    expect(app.screen, AppScreen.hatch);
    await _shot(t, '09-egg');
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byType(EggTapTarget).first, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 120));
    }
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 900));
    expect(app.hatch!.revealed, isTrue);
    expect(app.store.unlocked.length, 5);
    await _shot(t, '10-hatched');
    await t.tap(find.text('Awesome!'));
    await t.pump(const Duration(milliseconds: 300));
    expect(app.screen, AppScreen.menu);

    await t.tap(find.text('⚙'));
    await t.pump(const Duration(milliseconds: 400));
    expect(app.screen, AppScreen.settings);
    await _shot(t, '11-settings');
  });

  testWidgets('portrait phone layout', (t) async {
    final app = await _boot(t, size: const Size(390, 844));
    app.online = true;
    app.applyMode(animate: false);
    await t.pump(const Duration(milliseconds: 300));
    await _shot(t, '12-portrait-menu');
    app.play();
    await _run(t, app, 3);
    await _shot(t, '13-portrait-run');
  });
}
