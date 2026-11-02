# 🦖 Dino Dash

An endless dino runner for phones that **changes with your internet connection**:

| No internet 📴 | Internet on 📶 |
|---|---|
| **Classic mode**: a minimal black-and-white runner with a day/night cycle | **Jurassic mode**: colors, 5 biomes, coins, power-ups and dino abilities |
| Jump, duck, high score | Everything from Classic mode, plus: |
| Small extras: 🦴 fossil bonus (+50), **HI flag** at your best distance, milestone blink | 10 dinos, each with its own **ability** |
| | 🥚 **A free mystery egg every time you connect**, which hatches a random dino |

If the connection drops or comes back during a run, the game **changes live** with a rainbow wipe. You also get a short grace period so the change can't kill you.

## Features

### Online / Jurassic mode
- **10 dinosaurs** in 4 rarities (Common, Rare, Epic, Legendary), each with its own pixel art and ability:

| Dino | Rarity | Ability |
|---|---|---|
| Rexy | Common (starter) | **Roar**: blasts away every obstacle in front of you |
| Zip (raptor) | Common | **Dash**: invincible speed burst |
| Plato (stego) | Common | **Plate Armor**: a shield that absorbs one hit |
| Bonk (pachy) | Common | **Super Jump**: very high jump, invincible while rising |
| Trike (tricera) | Rare | **Charge**: rams through ground obstacles for 3s |
| Echo (parasaur) | Rare | **Echo Call**: coin magnet + double coins |
| Tank (ankylo) | Rare | **Quake**: tail slam that clears the ground |
| Skye (ptero) | Epic | **Soar**: flies for 3s · passive: double jump + glide |
| Sail (spino) | Epic | **Time Warp**: slows the world |
| Neon Rex | Legendary | **Hyper Mode**: invincible + magnet + x2 coins · passive: double jump |

- **Egg unlocks**: each time the phone goes online you get a free 🥚 (at most once every 5 minutes, so toggling Wi-Fi can't be farmed). You can also buy eggs for 250 coins. Rarer dinos are less likely to hatch.
- **5 biomes** that change every 600 points: Jungle → Desert → Glacier → Volcano (meteors!) → Cosmic (UFOs + meteors). Each has its own parallax scenery, weather (leaves, dust, snow, embers, shooting stars) and obstacles.
- **Power-ups**: 🛡️ Shield, 🧲 Magnet, ×2 Coins, 🚀 Rocket.
- Coins, a separate best score, particles, screen shake and synthesized sound effects.

### Offline / Classic mode
- A minimal monochrome runner with a day/night cycle, ducking, flying enemies, and a variable jump height (hold to jump higher).
- Small extras: 🦴 fossil bonus, a "HI" flag at your record distance, and a score blink at every 100 points.

### Controls
| Action | Touch | Keyboard |
|---|---|---|
| Jump (hold = higher) | tap anywhere | Space / ↑ |
| Duck / fast-fall | swipe down or the ▼ button | ↓ |
| Dino ability | ⚡ button (bottom right) | X / Shift |
| Pause | II button | P / Esc |

## Project structure
```
www/                 ← the whole game (plain HTML5 canvas + ES modules, no build step)
  index.html
  css/style.css      ← two UI themes: .classic (offline) and colorful (online)
  js/main.js         ← UI screens, eggs/unlocks, input, mode switching
  js/game.js         ← game loop, physics, spawning, abilities, power-ups, rendering
  js/dinos.js        ← dino roster + procedural pixel-art sprites
  js/world.js        ← biomes, backgrounds, obstacles, pickups
  js/network.js      ← real internet detection (Capacitor Network plugin + probe requests)
  js/audio.js        ← synthesized sound effects (no audio files)
  js/store.js        ← save data (localStorage)
  sw.js, manifest.webmanifest  ← installable PWA that also works offline
capacitor.config.json ← native Android/iOS wrapper config
tools/make-icons.mjs  ← regenerates the app icons from the game's sprite code
```

## Run it in a browser
```bash
npm run serve          # http://localhost:8123
```
Debug overrides: `?net=offline` or `?net=online` force a mode. `?debug` exposes `window.__dino`.

## Build the mobile app (Android / iOS) with Capacitor
Requirements: Node 18+, **Android Studio** (for Android) or **Xcode** on macOS (for iOS).

```bash
npm install
npx cap add android        # creates the android/ project (once)
npm run android            # syncs www/ and opens Android Studio → Run ▶ or Build APK
# iOS (macOS only)
npx cap add ios
npm run ios
```
Optional: to lock the game to landscape on Android, add `android:screenOrientation="sensorLandscape"` to the `<activity>` in `android/app/src/main/AndroidManifest.xml`.

### How internet detection works
`navigator.onLine` only says whether there is a network link, not whether the internet actually works. So `network.js`:
1. listens to the Capacitor **Network** plugin (on device) and the browser `online`/`offline` events,
2. confirms with a tiny `no-cors` request to a well-known URL (`gstatic.com/generate_204`, with fallbacks),
3. re-checks every 12 seconds and whenever the app comes back to the foreground.
