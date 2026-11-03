import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'game/audio.dart';
import 'game/dinos.dart';
import 'game/game.dart';
import 'services/network.dart';
import 'services/store.dart';

enum AppScreen { menu, dinos, settings, hatch, pause, over, playing }

const Duration kEggCooldown = Duration(minutes: 5); // one free egg per connection, at most every 5 min
const int kEggPrice = 250;
const int kAllDupesCoins = 150;

class HatchState {
  HatchState(this.result);
  final DinoDef? result;
  int taps = 0;
  bool done = false; // egg burst
  bool revealed = false;
}

/// Holds all app-level state: screens, save data, connectivity and the game.
class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController(this.store, {NetworkMonitor? network, bool autoStartNetwork = true})
      : net = network ?? NetworkMonitor() {
    game = Game(onGameOver: _onGameOver);
    game.setDino(store.get<String>('selected'));
    game.setBest(store.getInt('hiClassic'), store.getInt('hiColor'));
    sfx.setEnabled(store.getBool('sound'));
    net.addListener(_onNetwork);
    if (autoStartNetwork) net.start();
    WidgetsBinding.instance.addObserver(this);
  }

  final Store store;
  final NetworkMonitor net;
  late final Game game;

  AppScreen screen = AppScreen.menu;
  bool online = false;
  bool colorful = false;
  String? detailId;
  HatchState? hatch;
  GameOverInfo? over;

  String? toastMsg;
  int _toastId = 0;
  Timer? _toastTimer, _overTimer;

  DinoDef get selected => getDino(store.get<String>('selected'));
  bool get isPlaying => screen == AppScreen.playing;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    net.dispose();
    _toastTimer?.cancel();
    _overTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      pauseGame();
    } else if (state == AppLifecycleState.resumed) {
      net.check();
    }
  }

  // ------------------------------------------------------------------ navigation
  void go(AppScreen s) {
    screen = s;
    notifyListeners();
  }

  void toast(String msg, {Duration duration = const Duration(milliseconds: 2600)}) {
    toastMsg = msg;
    final id = ++_toastId;
    _toastTimer?.cancel();
    _toastTimer = Timer(duration, () {
      if (id == _toastId) {
        toastMsg = null;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  // ------------------------------------------------------------------ connection / modes
  void _onNetwork(bool isOnline, bool? prev) {
    online = isOnline;
    applyMode(animate: true);
    if (isOnline) {
      grantEgg();
    } else if (prev == true) {
      toast('📴 No internet — Classic mode');
    }
  }

  void applyMode({bool animate = true}) {
    final next = online && !store.getBool('forceClassic');
    final changed = next != colorful;
    colorful = next;
    game.setColorful(colorful, animate: animate);
    if (changed && animate) sfx.play(colorful ? 'online' : 'offline', colorful: colorful);
    notifyListeners();
  }

  void grantEgg() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - store.getInt('lastEggAt') < kEggCooldown.inMilliseconds) return;
    store.update((s) {
      s['eggs'] = (s['eggs'] as num).toInt() + 1;
      s['lastEggAt'] = now;
    });
    sfx.play('egg', colorful: true);
    toast('📶 Connected! You found a 🥚 mystery egg!');
  }

  // ------------------------------------------------------------------ game flow
  void play() {
    game.setDino(store.get<String>('selected'));
    game.setBest(store.getInt('hiClassic'), store.getInt('hiColor'));
    game.start();
    _overTimer?.cancel();
    go(AppScreen.playing);
  }

  void pauseGame() {
    if (game.state != GameState.running) return;
    game.pause();
    go(AppScreen.pause);
  }

  void resumeGame() {
    go(AppScreen.playing);
    game.resume();
  }

  void quitToMenu() {
    _overTimer?.cancel();
    game.toMenu();
    go(AppScreen.menu);
  }

  void _onGameOver(GameOverInfo info) {
    store.update((s) {
      s['runs'] = (s['runs'] as num).toInt() + 1;
      if (info.colorful) {
        s['hiColor'] = math.max((s['hiColor'] as num).toInt(), info.score);
        s['coins'] = (s['coins'] as num).toInt() + info.coins;
      } else {
        s['hiClassic'] = math.max((s['hiClassic'] as num).toInt(), info.score);
      }
    });
    over = info;
    _overTimer?.cancel();
    _overTimer = Timer(const Duration(milliseconds: 650), () {
      if (game.state == GameState.over) go(AppScreen.over);
    });
  }

  // ------------------------------------------------------------------ settings
  void setSound(bool v) {
    store.set('sound', v);
    sfx.setEnabled(v);
    notifyListeners();
  }

  void setForceClassic(bool v) {
    store.set('forceClassic', v);
    applyMode(animate: true);
  }

  void resetProgress() {
    store.reset();
    game.setDino('rex');
    game.setBest(0, 0);
    detailId = null;
    toast('Progress reset');
    go(AppScreen.menu);
  }

  // ------------------------------------------------------------------ collection
  void selectDino(String id) {
    detailId = id;
    if (store.unlocked.contains(id)) {
      store.set('selected', id);
      game.setDino(id);
      sfx.play('point', colorful: colorful);
    }
    notifyListeners();
  }

  bool buyEgg() {
    if (!colorful || store.getInt('coins') < kEggPrice) return false;
    store.update((s) {
      s['coins'] = (s['coins'] as num).toInt() - kEggPrice;
      s['eggs'] = (s['eggs'] as num).toInt() + 1;
    });
    openHatch();
    return true;
  }

  // ------------------------------------------------------------------ hatching
  DinoDef? rollDino([math.Random? rng]) {
    final unlocked = store.unlocked;
    final locked = kDinos.where((d) => !unlocked.contains(d.id)).toList();
    if (locked.isEmpty) return null;
    final total = locked.fold<int>(0, (s, d) => s + d.rar.weight);
    var r = (rng ?? math.Random()).nextDouble() * total;
    for (final d in locked) {
      r -= d.rar.weight;
      if (r <= 0) return d;
    }
    return locked.last;
  }

  void openHatch() {
    if (store.getInt('eggs') <= 0) return;
    hatch = HatchState(rollDino());
    go(AppScreen.hatch);
  }

  void tapEgg() {
    final h = hatch;
    if (h == null || h.done) return;
    h.taps++;
    sfx.play('crack');
    if (h.taps >= 3) {
      h.done = true;
      Timer(const Duration(milliseconds: 450), _revealHatch);
    }
    notifyListeners();
  }

  void _revealHatch() {
    final h = hatch;
    if (h == null) return;
    final d = h.result;
    store.update((s) {
      s['eggs'] = math.max(0, (s['eggs'] as num).toInt() - 1);
      if (d != null) {
        (s['unlocked'] as List).add(d.id);
        s['selected'] = d.id;
      } else {
        s['coins'] = (s['coins'] as num).toInt() + kAllDupesCoins;
      }
    });
    if (d != null) game.setDino(d.id);
    h.revealed = true;
    sfx.play('egg', colorful: true);
    notifyListeners();
  }

  void finishHatch() {
    if (store.getInt('eggs') > 0) {
      openHatch();
    } else {
      hatch = null;
      go(AppScreen.menu);
    }
  }
}

/// Makes the controller available to the whole widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  static AppController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
