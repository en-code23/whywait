# WhyWait

WhyWait is a native macOS desktop-overlay collection of seven lightweight minigames built with Swift, AppKit, and SpriteKit.

Download the latest macOS build from the [WhyWait website](https://en-code23.github.io/whywait/).

Requires macOS 13 or later.

## Play

Normal launch opens the compact launcher. Choose Cursor Golf, Cursor Pong, Fruit Slice,
Grapple, Fishing, Sword Dummy, or Zombie Sword. Games run on the transparent desktop overlay.
Escape returns to the launcher; closing the launcher keeps the menu-bar utility running.
Opening WhyWait again reopens the launcher. Command-Q quits.

Preferences includes an English / Deutsch switch, object size, and reduced-effects options.
Developer direct launch remains available with `--minigame=fishing` (or any registered game ID).

## Fishing

- Hold and release to cast. The rod follows your aim with spring lag; a small mouse flick influences the release.
- Click on a bite; hold to reel and move the rod to manage line tension. Fish must reach the rod before landing.
- **D**: FishDex (36 species). **B**: Tidevault specimen collection. **U**: tackle room, rod shop, lures and upgrades.
- Four permanent rods: Willow, Tideglass (650 coins), Carbon (1,800), Abyss (4,200).
- Coins, equipment, rod ownership and catches live in `Application Support/WhyWait/fishing-profile.json` (version 3, backwards-compatible migration).
- Atomic saves reject stale writers; failed saves show feedback rather than silently confirming a purchase.

## Build and verify

```sh
xcodebuild -project WhyWait.xcodeproj -scheme WhyWait -configuration Debug -derivedDataPath /tmp/whywait-debug CODE_SIGNING_ALLOWED=NO build
WHYWAIT_APP_SHELL_TESTS=1 /tmp/whywait-debug/Build/Products/Debug/WhyWait.app/Contents/MacOS/WhyWait
xcodebuild -project WhyWait.xcodeproj -scheme WhyWait -configuration Release -derivedDataPath /tmp/whywait-release CODE_SIGNING_ALLOWED=NO build analyze
```

The Debug diagnostics use an isolated temporary Fishing profile. They cover shop/save/reopen,
stale writers, corrupt saves, catalog/economy, rod stability, physical landing, localization,
all game routes, and a live SpriteKit Grapple fall test. A graphical macOS session is required.
`WHYWAIT_VISUAL_EXPORT_DIRECTORY=/tmp/whywait-art` also exports a fish atlas and rod-shop render.
`WHYWAIT_FISHING_PROFILE_DIRECTORY` overrides the save directory for Debug-only manual smoke tests.

The download is ad-hoc signed, not Apple-notarized. macOS may require explicit approval in
Privacy & Security on first launch. Only approve releases you trust; do not disable Gatekeeper globally.

The bilingual, dependency-free website is served by GitHub Pages from `docs/`.
