#if DEBUG
import AppKit
import Foundation
import SpriteKit

private struct DiagnosticSupplementalStats: GameSupplementalStatsProviding {
    func stats(for gameID: String) -> SupplementalGameStats { .empty }
}

private final class DiagnosticLaunchAtLoginController: LaunchAtLoginControlling {
    var status = LaunchAtLoginStatus(isEnabled: false, message: nil)
    private(set) var changes: [Bool] = []

    func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus {
        changes.append(enabled)
        status = LaunchAtLoginStatus(isEnabled: enabled, message: nil)
        return status
    }
}

enum AppShellDiagnostics {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func runAll() throws -> [String] {
        var reports: [String] = []
        try verifyRegistry()
        reports.append("registry: 7 metadata-rich games and CLI routes")

        try verifyPresentationAssets()
        reports.append("presentation: 24 fish, 9 archetypes, articulated rod, fruit cuts, zombie silhouettes")

        try verifyPreferences()
        reports.append("preferences: last-played and v2 settings round trip")

        try verifyStats()
        reports.append("stats: launches, duration, persistence, crash recovery, clamps")

        try verifyLauncher()
        reports.append("launcher: details, quick actions, settings, keyboard navigation")

        try verifyMenuBar()
        reports.append("menu bar: launcher, last-game, 7 games, quit")

        try verifyShortcut()
        reports.append("shortcut: registration and callback")

        try verifyCoordinator()
        reports.append("coordinator: switching, sessions, random/last play, settings, CLI")
        return reports
    }

    private static func verifyRegistry() throws {
        let expectedIDs = [
            "cursor-golf", "cursor-pong", "fruit-slice", "grapple",
            "fishing", "sword-dummy", "zombie-sword"
        ]
        let games = MinigameRegistry.allGames
        try require(games.map(\.id) == expectedIDs, "Registry game order or membership changed")
        try require(Set(games.map(\.id)).count == games.count, "Registry contains duplicate IDs")
        try require(games.allSatisfy {
            !$0.name.isEmpty && !$0.summary.isEmpty && !$0.detail.isEmpty
                && !$0.controls.isEmpty && !$0.symbolName.isEmpty && $0.isAvailable
        }, "Registry metadata is incomplete")

        for id in expectedIDs {
            try require(MinigameRegistry.makeMinigame(id: id)?.id == id, "Factory failed for \(id)")
            let parsed = MinigameRegistry.requestedMinigameID(
                arguments: ["WhyWait", "--minigame=\(id)"]
            )
            try require(parsed == id, "CLI route failed for \(id)")
        }
        try require(
            MinigameRegistry.requestedMinigameID(arguments: ["WhyWait"]) == nil,
            "Normal launch must not choose a minigame"
        )
        try require(
            MinigameRegistry.requestedMinigameID(
                arguments: ["WhyWait", "--minigame=not-a-game"]
            ) == nil,
            "Unknown CLI game must be rejected"
        )
    }

    private static func verifyPresentationAssets() throws {
        let scaledSceneSize = OverlayWindowController.sceneSize(
            for: CGSize(width: 1_280, height: 800),
            objectScale: 1.25
        )
        try require(
            abs(scaledSceneSize.width - 1_024) < 0.001
                && abs(scaledSceneSize.height - 640) < 0.001,
            "Game object scale did not produce the expected overlay world size"
        )
        try require(
            WhyWaitGameObjectScale.clamped(.infinity) == WhyWaitGameObjectScale.standard,
            "Invalid object scale was not sanitized"
        )

        try require(FishCatalog.all.count == 24, "Fishing visual roster no longer contains 24 fish")
        let fish = FishCatalog.all.map {
            FishNode(definition: $0, sizePercentile: 0.62)
        }
        try require(
            Set(fish.map(\.visualArchetype)).count == FishBodyArchetype.allCases.count,
            "Not every Fishing body archetype is represented"
        )
        for node in fish {
            try requireVisualFrame(node, named: node.definition.name)
            try require(
                boundedDescendantCount(node) <= 48,
                "\(node.definition.name) visual node count is not bounded"
            )
        }

        let rod = FishingRod()
        rod.layout(in: CGSize(width: 1_280, height: 800))
        rod.setAim(toward: CGPoint(x: 860, y: 620), power: 0.75)
        let relaxedTip = rod.tipPosition
        rod.updateFightVisual(tension: 1, isReeling: true)
        let loadedTip = rod.tipPosition
        try requireVisualFrame(rod, named: "Fishing rod")
        try require(
            hypot(relaxedTip.x - loadedTip.x, relaxedTip.y - loadedTip.y) > 1,
            "Fishing rod does not visibly bend under load"
        )

        for type in FruitType.allCases {
            let whole = FruitNode(type: type, velocity: .zero, angularVelocity: 0)
            let cut = FruitHalfNode(
                type: type,
                halfSign: 1,
                cutAngle: 0,
                velocity: .zero,
                angularVelocity: 0
            )
            try requireVisualFrame(whole, named: "\(type) fruit")
            try requireVisualFrame(cut, named: "\(type) fruit interior")
            try require(
                boundedDescendantCount(cut) >= 6,
                "\(type) cut fruit lost its interior treatment"
            )
        }

        let zombies = ZombieType.allCases.map {
            Zombie(type: $0, wave: 1, position: .zero)
        }
        for zombie in zombies {
            try requireVisualFrame(zombie, named: "\(zombie.type.rawValue) zombie")
            try require(
                boundedDescendantCount(zombie) <= 64,
                "\(zombie.type.rawValue) zombie visual node count is not bounded"
            )
        }
        let silhouetteSizes = Set(zombies.map {
            let frame = $0.calculateAccumulatedFrame()
            return "\(Int(frame.width.rounded()))x\(Int(frame.height.rounded()))"
        })
        try require(
            silhouetteSizes.count >= 4,
            "Zombie type silhouettes are not sufficiently distinct"
        )

        let showcaseNodes: [(String, SKNode)] = [
            ("Grapple player", GrapplePlayer()),
            ("Grapple goal", GrappleGoal()),
            ("Fruit bomb", BombNode(velocity: .zero, angularVelocity: 0)),
            ("Golf ball", GolfBall()),
            ("Golf cup", GolfHole()),
            ("Pong ball", PongBall()),
            ("Pong player paddle", PongPaddle(side: .player)),
            ("Physical sword", PhysicsSword()),
            ("Training dummy", TrainingDummy()),
            ("Zombie Sword player", ZombieSwordPlayer())
        ]
        for (name, node) in showcaseNodes {
            try requireVisualFrame(node, named: name)
            try require(
                boundedDescendantCount(node) <= 96,
                "\(name) visual node count is not bounded"
            )
        }
    }

    private static func requireVisualFrame(_ node: SKNode, named name: String) throws {
        let frame = node.calculateAccumulatedFrame()
        try require(
            frame.origin.x.isFinite && frame.origin.y.isFinite
                && frame.width.isFinite && frame.height.isFinite
                && frame.width > 2 && frame.height > 2,
            "\(name) has invalid visual geometry"
        )
    }

    private static func boundedDescendantCount(_ node: SKNode) -> Int {
        var count = node.children.count
        for child in node.children {
            count += boundedDescendantCount(child)
        }
        return count
    }

    private static func verifyPreferences() throws {
        let suite = "WhyWait.AppShellDiagnostics.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw Failure(description: "Could not create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = AppPreferences(defaults: defaults)
        try require(first.lastPlayedMinigameID == nil, "Fresh preferences were not empty")
        first.lastPlayedMinigameID = "fishing"
        var settings = first.settings
        settings.menuBarEnabled = false
        settings.reduceVisualEffects = true
        settings.cursorTrailEffects = false
        settings.gameObjectScale = 1.22
        settings.automaticallyReopenLauncher = false
        first.settings = settings

        let reloaded = AppPreferences(defaults: defaults)
        try require(reloaded.lastPlayedMinigameID == "fishing", "Last game did not persist")
        try require(reloaded.settings == settings, "WhyWait settings did not persist")
        reloaded.lastPlayedMinigameID = nil
        try require(first.lastPlayedMinigameID == nil, "Last game did not clear")
    }

    private static func verifyStats() throws {
        let suite = "WhyWait.StatsDiagnostics.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw Failure(description: "Could not create stats UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 10_000)
        let store = WhyWaitStatsStore(defaults: defaults)
        store.recordGameStarted("cursor-golf", at: start)
        store.checkpointActiveSession(at: start.addingTimeInterval(45))
        let duration = store.recordGameStopped(
            "cursor-golf",
            at: start.addingTimeInterval(90)
        )
        try require(abs(duration - 90) < 0.001, "Normal session duration was incorrect")

        let interruptedStart = start.addingTimeInterval(1_000)
        store.recordGameStarted("cursor-pong", at: interruptedStart)
        store.checkpointActiveSession(at: interruptedStart.addingTimeInterval(60))
        let reloaded = WhyWaitStatsStore(defaults: defaults)
        let recovered = reloaded.recoverInterruptedSession(
            at: interruptedStart.addingTimeInterval(10_000)
        )
        try require(abs(recovered - 60) < 0.001, "Crash recovery exceeded its checkpoint")

        let longStart = start.addingTimeInterval(20_000)
        reloaded.recordGameStarted("cursor-golf", at: longStart)
        let clamped = reloaded.recordGameStopped(
            "cursor-golf",
            at: longStart.addingTimeInterval(999_999)
        )
        try require(
            abs(clamped - WhyWaitStatsStore.maximumRecordedSession) < 0.001,
            "Absurd session duration was not clamped"
        )

        let persisted = WhyWaitStatsStore(defaults: defaults).snapshot
        try require(persisted.stats(for: "cursor-golf").launches == 2, "Launch count did not persist")
        try require(persisted.stats(for: "cursor-pong").launches == 1, "Second game launch missing")
        try require(persisted.favoriteGameID == "cursor-golf", "Favorite game was incorrect")
        try require(persisted.totalLaunches == 3, "Global launch total was incorrect")
        try require(persisted.totalPlayTime.isFinite, "Global play time became non-finite")
    }

    private static func verifyLauncher() throws {
        let launcher = LauncherWindowController(games: MinigameRegistry.allGames)
        let viewModel = diagnosticViewModel(lastPlayedID: "grapple")
        launcher.show(viewModel: viewModel)
        try require(
            launcher.diagnosticCardIDs == MinigameRegistry.allGames.map(\.id),
            "Launcher cards were not generated from the registry"
        )
        try require(launcher.diagnosticSelectedGameID == "grapple", "Last game was not selected")
        try require(launcher.isVisible, "Launcher did not become visible")
        try require(
            launcher.diagnosticFooterText.contains("⌃⌥ SPACE"),
            "Launcher did not reflect the registered shortcut"
        )

        launcher.selectCardForDiagnostics(id: "fruit-slice")
        try require(launcher.diagnosticSelectedGameID == "fruit-slice", "Card selection failed")
        var playedID: String?
        launcher.onPlayGame = { playedID = $0 }
        launcher.playCardForDiagnostics(id: "fruit-slice")
        try require(playedID == "fruit-slice", "Card Play action failed")

        launcher.selectCardForDiagnostics(id: "fruit-slice")
        launcher.keyEventForDiagnostics(keyCode: 124)
        try require(launcher.diagnosticSelectedGameID == "grapple", "Right-arrow navigation failed")
        launcher.keyEventForDiagnostics(keyCode: 36)
        try require(playedID == "grapple", "Return did not play the selection")

        var playedLast = false
        var playedRandom = false
        launcher.onPlayLastGame = { playedLast = true }
        launcher.onRandomGame = { playedRandom = true }
        launcher.playLastForDiagnostics()
        launcher.playRandomForDiagnostics()
        try require(playedLast && playedRandom, "Quick actions did not fire")

        launcher.keyEventForDiagnostics(keyCode: 43, modifiers: .command)
        try require(launcher.diagnosticSettingsVisible, "Command-comma did not open Settings")
        var changedSetting: (WhyWaitSettingKey, Bool)?
        launcher.onSettingChanged = { changedSetting = ($0, $1) }
        launcher.changeSettingForDiagnostics(.showGameHUD, enabled: false)
        try require(
            changedSetting?.0 == .showGameHUD && changedSetting?.1 == false,
            "Settings action did not propagate"
        )
        var changedScale: Double?
        launcher.onObjectScaleChanged = { changedScale = $0 }
        launcher.changeObjectScaleForDiagnostics(1.24)
        try require(abs((changedScale ?? 0) - 1.24) < 0.001, "Object scale action failed")

        var hidden = false
        launcher.onHideLauncher = { hidden = true }
        launcher.keyEventForDiagnostics(keyCode: 53)
        try require(hidden, "Launcher Escape action did not fire")
        launcher.hide()
        try require(!launcher.isVisible, "Launcher did not hide")

        var closed = false
        launcher.onWindowClosed = { closed = true }
        launcher.show(viewModel: diagnosticViewModel(lastPlayedID: nil))
        launcher.closeForDiagnostics()
        try require(closed, "Closing launcher did not report its hidden state")
    }

    private static func verifyMenuBar() throws {
        let menuBar = MenuBarController()
        defer { menuBar.stop() }
        menuBar.start(lastPlayedID: nil)
        let expectedTitles = ["Open WhyWait", "Play Last Game"]
            + MinigameRegistry.allGames.map(\.name)
            + ["Quit WhyWait"]
        try require(menuBar.diagnosticMenuTitles == expectedTitles, "Menu bar entries are incomplete")

        var selectedID: String?
        menuBar.onPlayGame = { selectedID = $0 }
        menuBar.activateGameForDiagnostics(id: "fruit-slice")
        try require(selectedID == "fruit-slice", "Menu bar game action failed")

        var playedLast = false
        menuBar.onPlayLastGame = { playedLast = true }
        menuBar.update(lastPlayedID: "fruit-slice")
        try require(
            menuBar.diagnosticMenuTitles.contains("Play Last Game — Fruit Slice"),
            "Menu bar did not display the last game"
        )
        menuBar.activateLastGameForDiagnostics()
        try require(playedLast, "Play Last Game action failed")
    }

    private static func verifyShortcut() throws {
        let shortcut = GlobalShortcutController()
        var callbackCount = 0
        shortcut.onShortcut = { callbackCount += 1 }
        try require(shortcut.start(), "Neither global shortcut could be registered")
        defer { shortcut.stop() }
        try require(shortcut.isRegistered, "Shortcut registration has no active hot key")
        shortcut.performShortcutForDiagnostics()
        try require(callbackCount == 1, "Shortcut callback did not fire exactly once")
    }

    private static func verifyCoordinator() throws {
        let suite = "WhyWait.CoordinatorDiagnostics.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw Failure(description: "Could not create coordinator preferences")
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        let stats = WhyWaitStatsStore(defaults: defaults)
        let login = DiagnosticLaunchAtLoginController()
        let builder = LauncherViewModelBuilder(supplementalStats: DiagnosticSupplementalStats())
        let coordinator = AppCoordinator(
            preferences: preferences,
            statsStore: stats,
            launchAtLoginController: login,
            launcherViewModelBuilder: builder
        )
        defer { coordinator.stop() }

        coordinator.start(arguments: ["WhyWait"])
        try require(coordinator.state == .launcher, "Normal launch did not open launcher")
        try require(coordinator.activeMinigame == nil, "Launcher retained a minigame")

        for metadata in MinigameRegistry.allGames {
            coordinator.playGame(id: metadata.id)
            try require(
                coordinator.state == .playing(gameID: metadata.id),
                "Coordinator state did not switch to \(metadata.id)"
            )
            try require(coordinator.activeMinigame?.id == metadata.id, "Wrong active game")
        }
        try require(coordinator.diagnosticStats.totalLaunches == 7, "Session launches were not tracked")

        coordinator.sendInputForDiagnostics(.escapePressed)
        try require(coordinator.state == .launcher, "Escape did not return to launcher")
        try require(coordinator.activeMinigame == nil, "Escape did not stop the game")

        coordinator.playLastGame()
        try require(
            coordinator.state == .playing(gameID: "zombie-sword"),
            "Play Last Game did not launch the remembered game"
        )
        coordinator.showLauncher()
        coordinator.playRandomGame()
        guard case let .playing(randomID) = coordinator.state else {
            throw Failure(description: "Random Game did not launch")
        }
        try require(MinigameRegistry.metadata(for: randomID) != nil, "Random Game escaped registry")
        coordinator.showLauncher()

        coordinator.changeSettingForDiagnostics(.menuBarEnabled, enabled: false)
        coordinator.changeSettingForDiagnostics(.globalShortcutEnabled, enabled: false)
        coordinator.changeSettingForDiagnostics(.reduceVisualEffects, enabled: true)
        coordinator.changeObjectScaleForDiagnostics(1.3)
        coordinator.changeSettingForDiagnostics(.launchAtLogin, enabled: true)
        try require(!coordinator.diagnosticSettings.menuBarEnabled, "Menu setting did not apply")
        try require(!coordinator.diagnosticSettings.globalShortcutEnabled, "Shortcut setting did not apply")
        try require(coordinator.diagnosticSettings.reduceVisualEffects, "Gameplay setting did not apply")
        try require(
            abs(coordinator.diagnosticSettings.gameObjectScale - 1.3) < 0.001,
            "Game object scale did not apply"
        )
        try require(login.changes == [true], "Launch-at-login controller was not called safely")
        try require(preferences.settings == coordinator.diagnosticSettings, "Settings were not persisted")

        coordinator.toggleLauncher()
        try require(coordinator.state == .hidden, "Launcher toggle did not hide the launcher")
        coordinator.toggleLauncher()
        try require(coordinator.state == .launcher, "Launcher toggle did not reopen the launcher")
        coordinator.stop()

        let direct = AppCoordinator(
            preferences: preferences,
            statsStore: WhyWaitStatsStore(defaults: defaults),
            launchAtLoginController: login,
            launcherViewModelBuilder: builder
        )
        defer { direct.stop() }
        direct.start(arguments: ["WhyWait", "--minigame=cursor-pong"])
        try require(
            direct.state == .playing(gameID: "cursor-pong"),
            "Command-line direct launch did not bypass the launcher"
        )
        try require(direct.activeMinigame?.id == "cursor-pong", "Direct launch chose wrong game")
    }

    private static func diagnosticViewModel(lastPlayedID: String?) -> LauncherViewModel {
        LauncherViewModelBuilder(supplementalStats: DiagnosticSupplementalStats()).make(
            stats: WhyWaitStatsSnapshot(games: [:], lastPlayedGameID: lastPlayedID),
            lastPlayedID: lastPlayedID,
            settings: WhyWaitSettings(),
            launchAtLogin: LaunchAtLoginStatus(isEnabled: false, message: nil),
            settingsMessage: nil,
            shortcutDescription: "⌃⌥ Space"
        )
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        guard condition() else { throw Failure(description: message) }
    }
}
#endif
