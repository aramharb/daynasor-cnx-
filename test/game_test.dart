import 'dart:math' as math;
import 'dart:ui';

import 'package:dino_dash/app_controller.dart';
import 'package:dino_dash/game/dinos.dart';
import 'package:dino_dash/game/entities.dart';
import 'package:dino_dash/game/game.dart';
import 'package:dino_dash/services/network.dart';
import 'package:dino_dash/services/store.dart';
import 'package:flutter_test/flutter_test.dart';

Game newGame({bool colorful = true, String dino = 'rex'}) {
  final g = Game();
  g.resize(const Size(844, 390));
  g.setColorful(colorful, animate: false);
  g.setDino(dino);
  g.start();
  return g;
}

/// Simple autopilot so runs last a while.
void bot(Game g) {
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

void run(Game g, double seconds, {bool autopilot = true}) {
  const dt = 1 / 60;
  for (var i = 0; i < seconds / dt; i++) {
    if (autopilot) bot(g);
    g.update(dt);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('dinosaurs', () {
    test('there are 11 real species with unique ids, abilities and super powers', () {
      expect(kDinos.length, 11);
      expect(kDinos.map((d) => d.id).toSet().length, 11);
      expect(kDinos.map((d) => d.superPower.id).toSet().length, 11);
      expect(kDinos.map((d) => d.name), containsAll(['Tyrannosaurus rex', 'Velociraptor', 'Stegosaurus', 'Triceratops', 'Spinosaurus', 'Brachiosaurus']));
    });

    test('every dino composes standing/ducking poses with hit boxes inside its sprite', () {
      for (final d in kDinos) {
        for (final pose in ['stand', 'duck']) {
          for (var f = 0; f < 3; f++) {
            final c = compose(d, pose, f);
            expect(c.w, greaterThan(5), reason: '${d.id} $pose');
            expect(c.cells.any((r) => r.contains('K')), isTrue, reason: '${d.id} $pose eye');
          }
          final boxes = dinoHitboxes(d, pose, 0, 100);
          expect(boxes, isNotEmpty, reason: '${d.id} $pose boxes');
          final sz = poseSize(d, pose);
          for (final b in boxes) {
            expect(b.left, greaterThanOrEqualTo(-0.01));
            expect(b.right, lessThanOrEqualTo(sz.width + 0.01));
            expect(b.bottom, lessThanOrEqualTo(100.01));
          }
        }
      }
    });

    test('ducking makes every dino lower than standing', () {
      for (final d in kDinos) {
        expect(poseSize(d, 'duck').height, lessThan(poseSize(d, 'stand').height), reason: d.id);
      }
    });
  });

  group('game', () {
    test('classic mode runs and scores without crashing', () {
      final g = newGame(colorful: false);
      run(g, 20);
      expect(g.state, anyOf(GameState.running, GameState.over));
      expect(g.score, greaterThan(50));
    });

    test('colorful mode runs for every dino and ability without crashing', () {
      for (final d in kDinos) {
        final g = newGame(dino: d.id);
        g.fx.invuln = 999; // test the code paths, not the autopilot
        for (var i = 0; i < 8; i++) {
          g.abilityCd = 0;
          g.useAbility();
          run(g, 1.5);
        }
        expect(g.state, GameState.running, reason: d.id);
      }
    });

    test('every super power can be activated, lasts its duration and ends cleanly', () {
      for (final d in kDinos) {
        final g = newGame(dino: d.id);
        g.fx.invuln = 999;
        g.superMeter = 1;
        run(g, 1);
        expect(g.useSuper(), isTrue, reason: d.id);
        expect(g.superId, d.superPower.id);
        expect(g.fx.superT, greaterThan(0));
        run(g, d.superPower.dur + 1);
        expect(g.fx.superT, 0, reason: '${d.id} ended');
        expect(g.superId, isNull);
        expect(g.allies, isEmpty);
        expect(g.state, GameState.running, reason: d.id);
        expect(g.superMeter, lessThan(1));
      }
    });

    test('super power cannot start until the meter is full', () {
      final g = newGame();
      expect(g.useSuper(), isFalse);
      g.superMeter = 1;
      expect(g.useSuper(), isTrue);
      expect(g.useSuper(), isFalse); // already active
    });

    test('abilities and super powers do nothing in classic (offline) mode', () {
      final g = newGame(colorful: false);
      g.superMeter = 1;
      expect(g.useAbility(), isFalse);
      expect(g.useSuper(), isFalse);
    });

    test('going offline mid-super cancels it', () {
      final g = newGame();
      g.superMeter = 1;
      g.useSuper();
      g.setColorful(false);
      expect(g.fx.superT, 0);
      expect(g.superId, isNull);
    });

    test('T. rex giant super crushes obstacles', () {
      final g = newGame();
      g.superMeter = 1;
      g.useSuper();
      g.obstacles.add(Obstacle(kind: ObstacleKind.ground, x: g.d.x + 20, y: g.gy - 35, w: 17, h: 35));
      run(g, 0.3, autopilot: false);
      expect(g.state, GameState.running);
      expect(g.obstacles.where((o) => !o.dead && o.x < 200), isEmpty);
    });

    test('Ankylosaurus fortress flings obstacles and pays coins', () {
      final g = newGame(dino: 'ankylo');
      g.superMeter = 1;
      g.useSuper();
      final before = g.runCoins;
      g.obstacles.add(Obstacle(kind: ObstacleKind.ground, x: g.d.x + 30, y: g.gy - 35, w: 17, h: 35));
      run(g, 0.2, autopilot: false);
      expect(g.state, GameState.running);
      expect(g.runCoins, greaterThan(before));
    });

    test('Spinosaurus River Dive makes obstacles harmless', () {
      final g = newGame(dino: 'spino');
      g.useAbility();
      g.obstacles.add(Obstacle(kind: ObstacleKind.ground, x: g.d.x + 10, y: g.gy - 35, w: 17, h: 35));
      run(g, 0.5, autopilot: false);
      expect(g.state, GameState.running);
    });

    test('Dilophosaurus venom melts the first obstacle', () {
      final g = newGame(dino: 'dilo');
      g.obstacles.add(Obstacle(kind: ObstacleKind.ground, x: g.d.x + 200, y: g.gy - 35, w: 17, h: 35));
      g.useAbility();
      run(g, 0.7, autopilot: false);
      expect(g.obstacles.where((o) => !o.dead && o.x < 400), isEmpty);
    });

    test('hitting an obstacle ends the run and reports the score', () {
      GameOverInfo? info;
      final g = Game(onGameOver: (i) => info = i);
      g.resize(const Size(844, 390));
      g.start();
      g.obstacles.add(Obstacle(kind: ObstacleKind.ground, x: g.d.x + 5, y: g.gy - 35, w: 17, h: 35));
      run(g, 0.3, autopilot: false);
      expect(g.state, GameState.over);
      expect(info, isNotNull);
      expect(info!.colorful, isFalse);
    });

    test('works at portrait and landscape sizes and survives resizing', () {
      final g = newGame();
      run(g, 2);
      g.resize(const Size(390, 844));
      expect(g.gy, lessThan(g.H));
      run(g, 2);
      g.resize(const Size(1280, 540));
      run(g, 2);
      expect(g.d.y, lessThanOrEqualTo(g.gy + 0.01)); // never below the ground (may be mid-jump)
      expect(g.d.y, greaterThan(0));
    });
  });

  group('storage, eggs and network', () {
    test('old web save migrates Neon Rex to Brachiosaurus', () {
      final s = Store.memory({'unlocked': ['rex', 'neon'], 'selected': 'neon'});
      expect(s.unlocked, ['rex', 'brachio']);
      expect(s.get<String>('selected'), 'brachio');
    });

    test('every connection gives one egg, at most once per cooldown', () {
      final app = AppController(Store.memory(), network: NetworkMonitor()..override = 'online', autoStartNetwork: false);
      app.grantEgg();
      app.grantEgg();
      expect(app.store.getInt('eggs'), 1);
      app.store.set('lastEggAt', DateTime.now().millisecondsSinceEpoch - 6 * 60 * 1000);
      app.grantEgg();
      expect(app.store.getInt('eggs'), 2);
    });

    test('online switches to colorful mode, offline to classic, force-classic respected', () {
      final app = AppController(Store.memory(), network: NetworkMonitor(), autoStartNetwork: false);
      app.online = true;
      app.applyMode(animate: false);
      expect(app.colorful, isTrue);
      expect(app.game.colorful, isTrue);
      app.setForceClassic(true);
      expect(app.colorful, isFalse);
      app.setForceClassic(false);
      app.online = false;
      app.applyMode();
      expect(app.colorful, isFalse);
    });

    test('hatching unlocks a new dino; rarer dinos are rarer', () {
      final app = AppController(Store.memory({'eggs': 1}), network: NetworkMonitor(), autoStartNetwork: false);
      app.openHatch();
      final result = app.hatch!.result!;
      expect(result.id, isNot('rex'));
      app.tapEgg();
      app.tapEgg();
      app.tapEgg();
      expect(app.hatch!.done, isTrue);
      // drive the delayed reveal synchronously
      app.hatch!.revealed = false;
      final rng = math.Random(3);
      final counts = <String, int>{};
      for (var i = 0; i < 4000; i++) {
        final d = app.rollDino(rng)!;
        counts[d.rarity] = (counts[d.rarity] ?? 0) + 1;
      }
      expect(counts['common']!, greaterThan(counts['legendary']!));
    });

    test('buying an egg needs coins and internet', () {
      final app = AppController(Store.memory({'coins': 300}), network: NetworkMonitor(), autoStartNetwork: false);
      expect(app.buyEgg(), isFalse); // offline
      app.online = true;
      app.applyMode(animate: false);
      expect(app.buyEgg(), isTrue);
      expect(app.store.getInt('coins'), 50);
      expect(app.buyEgg(), isFalse);
    });
  });
}
