import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'services/store.dart';
import 'ui/game_view.dart';
import 'ui/screens.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final store = await Store.load();
  final app = AppController(store);
  runApp(DinoDashApp(controller: app));
}

class DinoDashApp extends StatelessWidget {
  const DinoDashApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: MaterialApp(
        title: 'Dino Dash',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF42E695), brightness: Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pal = Pal.of(app.colorful);
    final Widget? overlay = switch (app.screen) {
      AppScreen.menu => const MenuScreen(),
      AppScreen.dinos => const CollectionScreen(),
      AppScreen.settings => const SettingsScreen(),
      AppScreen.hatch => const HatchScreen(),
      AppScreen.pause => const PauseScreen(),
      AppScreen.over => const GameOverScreen(),
      AppScreen.playing => null,
    };
    SystemChrome.setSystemUIOverlayStyle(
        pal.classic ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light);

    return PopScope(
      canPop: app.screen == AppScreen.menu,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        switch (app.screen) {
          case AppScreen.playing:
            app.pauseGame();
          case AppScreen.pause:
            app.resumeGame();
          case AppScreen.over:
            app.quitToMenu();
          default:
            app.go(AppScreen.menu);
        }
      },
      child: Scaffold(
        backgroundColor: pal.classic ? const Color(0xFFF7F7F7) : const Color(0xFF1B1036),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const GameView(),
            if (app.isPlaying) const GameControls(),
            const NetPill(),
            ?overlay,
            const ToastView(),
          ],
        ),
      ),
    );
  }
}
