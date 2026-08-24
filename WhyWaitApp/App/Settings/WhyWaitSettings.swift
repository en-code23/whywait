import Foundation

struct WhyWaitSettings: Codable, Equatable {
    var menuBarEnabled: Bool
    var globalShortcutEnabled: Bool
    var showGameHUD: Bool
    var reduceVisualEffects: Bool
    var cursorTrailEffects: Bool
    var gameObjectScale: Double
    var escapeReturnsToLauncher: Bool
    var automaticallyReopenLauncher: Bool

    init(
        menuBarEnabled: Bool = true,
        globalShortcutEnabled: Bool = true,
        showGameHUD: Bool = true,
        reduceVisualEffects: Bool = false,
        cursorTrailEffects: Bool = true,
        gameObjectScale: Double = 1,
        escapeReturnsToLauncher: Bool = true,
        automaticallyReopenLauncher: Bool = true
    ) {
        self.menuBarEnabled = menuBarEnabled
        self.globalShortcutEnabled = globalShortcutEnabled
        self.showGameHUD = showGameHUD
        self.reduceVisualEffects = reduceVisualEffects
        self.cursorTrailEffects = cursorTrailEffects
        self.gameObjectScale = WhyWaitGameObjectScale.clamped(gameObjectScale)
        self.escapeReturnsToLauncher = escapeReturnsToLauncher
        self.automaticallyReopenLauncher = automaticallyReopenLauncher
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        menuBarEnabled = try container.decodeIfPresent(Bool.self, forKey: .menuBarEnabled) ?? true
        globalShortcutEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .globalShortcutEnabled
        ) ?? true
        showGameHUD = try container.decodeIfPresent(Bool.self, forKey: .showGameHUD) ?? true
        reduceVisualEffects = try container.decodeIfPresent(
            Bool.self,
            forKey: .reduceVisualEffects
        ) ?? false
        cursorTrailEffects = try container.decodeIfPresent(
            Bool.self,
            forKey: .cursorTrailEffects
        ) ?? true
        gameObjectScale = WhyWaitGameObjectScale.clamped(
            try container.decodeIfPresent(Double.self, forKey: .gameObjectScale) ?? 1
        )
        escapeReturnsToLauncher = try container.decodeIfPresent(
            Bool.self,
            forKey: .escapeReturnsToLauncher
        ) ?? true
        automaticallyReopenLauncher = try container.decodeIfPresent(
            Bool.self,
            forKey: .automaticallyReopenLauncher
        ) ?? true
    }
}

enum WhyWaitSettingKey: String, CaseIterable {
    case launchAtLogin
    case menuBarEnabled
    case globalShortcutEnabled
    case showGameHUD
    case reduceVisualEffects
    case cursorTrailEffects
    case escapeReturnsToLauncher
    case automaticallyReopenLauncher
}

enum WhyWaitGameObjectScale {
    static let minimum = 0.8
    static let maximum = 1.35
    static let standard = 1.0

    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return standard }
        return min(maximum, max(minimum, value))
    }
}

/// Read-only presentation preferences for lightweight game renderers.
/// Values are sampled when a scene/node is created so no per-frame defaults reads are needed.
enum WhyWaitPresentationPreferences {
    static var reduceVisualEffects: Bool { AppPreferences().settings.reduceVisualEffects }
    static var cursorTrailsEnabled: Bool { AppPreferences().settings.cursorTrailEffects }
    static var showGameHUD: Bool { AppPreferences().settings.showGameHUD }
    static var gameObjectScale: CGFloat {
        CGFloat(WhyWaitGameObjectScale.clamped(AppPreferences().settings.gameObjectScale))
    }
}
