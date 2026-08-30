import Foundation

struct MinigameMetadata: Equatable, Identifiable {
    let id: String
    let name: String
    let summary: String
    let detail: String
    let controls: String
    let symbolName: String
    let isAvailable: Bool
}

enum MinigameRegistry {
    static let allGames: [MinigameMetadata] = [
        MinigameMetadata(
            id: "cursor-golf",
            name: "Cursor Golf",
            summary: "Bank shots across your desktop.",
            detail: "Pull back from the ball, read the desktop course, and sink each procedural hole in as few strokes as possible.",
            controls: "Drag from ball to shoot  ·  R reset  ·  Esc launcher",
            symbolName: "circle.circle",
            isAvailable: true
        ),
        MinigameMetadata(
            id: "cursor-pong",
            name: "Cursor Pong",
            summary: "Cursor-control a paddle against the CPU.",
            detail: "Move the right paddle with the cursor and use fast vertical swipes to shape skill-based returns against the CPU.",
            controls: "Move mouse to paddle  ·  R reset  ·  Esc launcher",
            symbolName: "rectangle.split.3x1",
            isAvailable: true
        ),
        MinigameMetadata(
            id: "fruit-slice",
            name: "Fruit Slice",
            summary: "Swipe through fruit—avoid the bombs.",
            detail: "Turn quick cursor movement into a blade, build swipe combos, and preserve three lives while the pace climbs.",
            controls: "Swipe quickly to slice  ·  R reset  ·  Esc launcher",
            symbolName: "leaf.fill",
            isAvailable: true
        ),
        MinigameMetadata(
            id: "grapple",
            name: "Grapple",
            summary: "Swing through a momentum course.",
            detail: "Attach to open desktop space, preserve momentum, and thread checkpoints through a compact procedural course.",
            controls: "Hold left to grapple  ·  Release to detach  ·  R new course",
            symbolName: "link",
            isAvailable: true
        ),
        MinigameMetadata(
            id: "fishing",
            name: "Fishing",
            summary: "Cast, collect rare variants, and stock your Tidevault.",
            detail: "Cast into depth zones, manage line tension, archive prized catches, discover ocean species, and outfit your tackle room.",
            controls: "Hold/release to cast  ·  D FishDex  ·  B Tidevault  ·  U shop",
            symbolName: "fish.fill",
            isAvailable: true
        ),
        MinigameMetadata(
            id: "sword-dummy",
            name: "Sword Dummy",
            summary: "Master a physical blade on a dummy.",
            detail: "Guide a weighted sword through spring physics and learn how speed, alignment, and contact point shape each strike.",
            controls: "Move mouse to swing  ·  Right-click recover  ·  R reset",
            symbolName: "shield.lefthalf.filled",
            isAvailable: true
        ),
        MinigameMetadata(
            id: "zombie-sword",
            name: "Zombie Sword",
            summary: "Survive waves with physics-based slashes.",
            detail: "Defend a fixed position from escalating waves using the same inertial sword—without attack buttons or canned swings.",
            controls: "Move mouse to swing  ·  Right-click recover  ·  R restart",
            symbolName: "bolt.shield.fill",
            isAvailable: true
        )
    ]

    private static let factories: [String: () -> Minigame] = [
        "cursor-golf": { CursorGolfGame() },
        "cursor-pong": { CursorPongGame() },
        "fruit-slice": { FruitSliceGame() },
        "grapple": { GrappleGame() },
        "fishing": { FishingGame() },
        "sword-dummy": { SwordDummyGame() },
        "zombie-sword": { ZombieSwordGame() }
    ]

    static func metadata(for id: String) -> MinigameMetadata? {
        allGames.first { $0.id == id }
    }

    static func makeMinigame(id: String) -> Minigame? {
        guard metadata(for: id)?.isAvailable == true else { return nil }
        return factories[id]?()
    }

    static func requestedMinigameID(arguments: [String] = CommandLine.arguments) -> String? {
        guard let rawID = arguments
            .first(where: { $0.hasPrefix("--minigame=") })?
            .dropFirst("--minigame=".count)
            .lowercased(),
              factories[rawID] != nil else {
            return nil
        }
        return rawID
    }

    /// Retained for developer tooling that wants to instantiate a direct-launch game.
    static func makeLaunchMinigame(arguments: [String] = CommandLine.arguments) -> Minigame? {
        requestedMinigameID(arguments: arguments).flatMap(makeMinigame(id:))
    }
}
