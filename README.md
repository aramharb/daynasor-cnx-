# 🦖 Dino Dash (Flutter)

A dino runner for **Android & iOS** built with **Flutter**. The game changes with your internet connection:

| No internet 📴 | Internet on 📶 |
|---|---|
| **Classic mode**: a minimal black-and-white runner with a day/night cycle | **Jurassic mode**: colors, 5 biomes, coins, power-ups, **dino abilities** and **SUPER POWERS** |
| Jump, duck, high score | Everything from Classic mode, plus: |
| Small extras: 🦴 fossil bonus (+50), **HI flag** at your best distance, milestone blink | 11 real dinosaurs, each with an **ability** and a **SUPER POWER** |
| | 🥚 **A free mystery egg every time you connect**, which hatches a random dino |

If the connection drops or comes back during a run, the game **changes live** with a rainbow wipe. You also get a short grace period so the change can't kill you.

## Open it in Android Studio

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and, in Android Studio, the **Flutter** and **Dart** plugins (*Settings → Plugins*).
2. *File → Open…* and choose this folder (the one containing `pubspec.yaml`).
3. Run `flutter pub get` (Android Studio offers a **Pub get** banner at the top of `pubspec.yaml`).
4. Pick an emulator or a phone and press ▶ **Run**.

Or from a terminal:

```bash
flutter pub get
flutter run                  # run on the connected device / emulator
flutter build apk --release  # → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle      # for Google Play
```

Needs **Flutter 3.32 or newer** (developed and tested with 3.47). If `flutter pub get` complains that a package needs a newer SDK, delete `pubspec.lock` and run it again so pub picks versions that fit your Flutter.

On an **emulator** the internet is usually on, so you'll see Jurassic mode. To test Classic mode, either turn on airplane mode in the emulator, or force a mode:

```bash
flutter run --dart-define=NET=offline    # or =online
```

Keyboard controls (handy on the emulator / desktop): <kbd>Space</kbd>/<kbd>↑</kbd> jump · <kbd>↓</kbd> duck · <kbd>X</kbd> ability · <kbd>C</kbd> SUPER · <kbd>P</kbd>/<kbd>Esc</kbd> pause.

## The dinosaurs

11 **real species**, each with a pixel sprite of its true shape (two legs or four, plates, frill, sail, armor, crest), its real geological era and a real fact (shown in the collection). Each one has **one ability** (cooldown) and **one SUPER POWER**:

| Dinosaur | Rarity | ⚡ Ability | 🌟 SUPER POWER |
|---|---|---|---|
| Tyrannosaurus rex | Starter | **Roar**: blasts away obstacles ahead | **King of the Dinos**: grows GIANT with a crown, crushes everything, coins rain down |
| Velociraptor | Common | **Dash**: invincible speed burst | **Raptor Pack**: 3 raptor friends run ahead and pounce on every obstacle |
| Pachycephalosaurus | Common | **Super Jump**: huge invincible jump | **Boulder Roll**: rolls into a spinning, bouncing skull-ball |
| Parasaurolophus | Common | **Echo Call**: magnet + ×2 coins | **Golden Song**: its crest plays music that turns every obstacle into gold coins |
| Stegosaurus | Rare | **Plate Armor**: a shield that absorbs one hit | **Plate Cyclone**: its plates orbit it like saw blades |
| Triceratops | Rare | **Charge**: rams through the ground for 3s | **Stampede**: a whole herd runs across the screen |
| Dilophosaurus | Rare | **Venom Spit**: frill + an auto-aimed venom glob that melts an obstacle | **Toxic Fog**: a poison cloud ahead melts everything |
| Ankylosaurus | Epic | **Quake**: tail-slam clears the ground | **Iron Fortress**: turns to steel; obstacles bounce off like pinballs and give coins |
| Pteranodon | Epic | **Soar**: flies for 3s · passive: double jump + glide | **Thunder Wings**: flies through a storm (tap to flap) and strikes obstacles with lightning |
| Spinosaurus | Legendary | **River Dive**: goes underground, only its sail shows | **Tsunami Surf**: surfs a giant wave that washes everything away |
| Brachiosaurus | Legendary | **Neck Sweep**: knocks every flyer and meteor out of the sky | **Meteor Rain**: calls down a meteor shower on the obstacles |

**SUPER meter**: fills over time, and faster when you collect coins, pick up power-ups or smash obstacles. When it's full the rainbow 🌟 button glows: tap it to unleash the super power for 6–8 seconds.

**Eggs**: each time the phone goes online you get a free 🥚 (at most once every 5 minutes, so toggling Wi-Fi can't be farmed). You can also buy eggs for 250 coins. Rarer dinos are less likely to hatch.

**Biomes** change every 600 points: Jungle → Desert → Glacier → Volcano (meteors!) → Cosmic (UFOs + meteors), each with its own scenery, weather and obstacles.

**Power-ups**: 🛡️ Shield · 🧲 Magnet · ×2 Coins · 🚀 Rocket.

### Controls
| Action | Touch |
|---|---|
| Jump (hold = higher) | tap anywhere |
| Duck / fast-fall | swipe down, or hold the ▼ button |
| Dino ability | ⚡ button (bottom right) |
| SUPER power | 🌟 SUPER button (when full) |
| Pause | II button (top left) or the Android back button |

## Project structure

```
lib/
  main.dart               app entry, screen switching
  app_controller.dart     app state: screens, eggs/unlocks, online/offline mode, hatching
  game/
    game.dart             game loop, physics, spawning, abilities, SUPER POWERS, rendering
    dinos.dart            the 11 dinosaurs: data, pixel sprites, hit boxes
    world.dart            biomes, backgrounds, obstacles, pickups
    entities.dart         obstacle / coin / particle / shot data classes
    ctx.dart              tiny HTML-canvas-style wrapper around Flutter's Canvas
    audio.dart            sound effects synthesized in code (no audio files) + haptics
  services/
    network.dart          real internet detection (connectivity_plus + probe request)
    store.dart            save data (shared_preferences)
  ui/
    game_view.dart        game canvas, touch / keyboard input, in-game buttons
    screens.dart          menu, collection, hatching, settings, pause, game over
    widgets.dart, theme.dart
test/
  game_test.dart          logic tests (dinos, abilities, all 11 super powers, eggs, save migration)
  ui_smoke_test.dart      drives every screen; set SHOT_DIR=/some/dir to also save screenshots
web_version/              the original HTML5 prototype this app was ported from
```

Run the tests with `flutter test`.

### How internet detection works
`navigator.onLine`-style checks only say whether there's a network *link*, not whether the internet works. `services/network.dart`:
1. listens to `connectivity_plus` for Wi-Fi / mobile changes,
2. confirms with a tiny request to a well-known URL (`gstatic.com/generate_204`, with fallbacks),
3. re-checks every 12 seconds and whenever the app returns to the foreground.

## Customising
- **Add a dinosaur**: add an entry to `kDinos` in `lib/game/dinos.dart` (a pixel grid, legs, colors, ability, super power). Abilities live in `Game.useAbility`, super powers in `Game.useSuper` / `Game._updateSuper`.
- **Tweak difficulty**: constants at the top of `lib/game/game.dart` (gravity, speeds, SUPER meter gain).
- **App name / icon**: `android/app/src/main/AndroidManifest.xml` (label) and `assets/icon/icon.png` + `dart run flutter_launcher_icons`.
