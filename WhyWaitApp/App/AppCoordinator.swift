import AppKit

/// Owns launcher/playing/hidden state, exclusive game switching, and app-wide sessions.
final class AppCoordinator {
    var onExitRequested: (() -> Void)?

    private let overlayController: OverlayWindowController
    private let inputManager: InputManager
    private let preferences: AppPreferences
    private let statsStore: WhyWaitStatsStore
    private let launcherController: LauncherWindowController
    private let menuBarController: MenuBarController
    private let shortcutController: GlobalShortcutController
    private let launchAtLoginController: LaunchAtLoginControlling
    private let launcherViewModelBuilder: LauncherViewModelBuilder

    private(set) var state: WhyWaitAppState = .hidden
    private(set) var activeMinigame: Minigame?
    private var settings: WhyWaitSettings
    private var settingsMessage: String?
    private var sessionHeartbeat: Timer?
    private var gameGeneration = 0
    private var isRunning = false

    init(
        overlayController: OverlayWindowController = OverlayWindowController(),
        inputManager: InputManager = InputManager(),
        preferences: AppPreferences = AppPreferences(),
        statsStore: WhyWaitStatsStore = WhyWaitStatsStore(),
        launcherController: LauncherWindowController = LauncherWindowController(
            games: MinigameRegistry.allGames
        ),
        menuBarController: MenuBarController = MenuBarController(),
        shortcutController: GlobalShortcutController = GlobalShortcutController(),
        launchAtLoginController: LaunchAtLoginControlling = LaunchAtLoginController(),
        launcherViewModelBuilder: LauncherViewModelBuilder = LauncherViewModelBuilder()
    ) {
        self.overlayController = overlayController
        self.inputManager = inputManager
        self.preferences = preferences
        self.statsStore = statsStore
        self.launcherController = launcherController
        self.menuBarController = menuBarController
        self.shortcutController = shortcutController
        self.launchAtLoginController = launchAtLoginController
        self.launcherViewModelBuilder = launcherViewModelBuilder
        settings = preferences.settings
        connectControllers()
    }

    func start(arguments: [String] = CommandLine.arguments) {
        guard !isRunning else { return }
        isRunning = true
        _ = statsStore.recoverInterruptedSession()
        inputManager.eventHandler = { [weak self] event in self?.handle(event) }
        inputManager.quitHandler = { [weak self] in self?.requestQuit() }
        inputManager.escapeHandler = { [weak self] in self?.handleEscape() == true }
        inputManager.start()
        applyUtilitySettings()

        if let requestedID = MinigameRegistry.requestedMinigameID(arguments: arguments) {
            playGame(id: requestedID)
        } else {
            showLauncher()
        }
    }

    func showLauncher() {
        guard isRunning else { return }
        stopActiveMinigame()
        state = .launcher
        launcherController.show(viewModel: makeLauncherViewModel())
        updateMenuBar()
    }

    func showSettings() {
        guard isRunning else { return }
        if case .playing = state { stopActiveMinigame() }
        state = .launcher
        launcherController.show(viewModel: makeLauncherViewModel())
        launcherController.showSettings()
    }

    func hideLauncher() {
        guard state == .launcher else { return }
        launcherController.hide()
        state = .hidden
    }

    func playGame(id: String) {
        guard isRunning,
              let screen = activeDisplay(),
              let minigame = MinigameRegistry.makeMinigame(id: id) else {
            if isRunning { showLauncher() }
            return
        }

        stopActiveMinigame()
        launcherController.hide()
        overlayController.setClickThroughEnabled(false)
        let sceneSize = OverlayWindowController.sceneSize(
            for: screen.frame.size,
            objectScale: settings.gameObjectScale
        )
        let scene = minigame.makeScene(size: sceneSize)
        gameGeneration += 1
        let generation = gameGeneration
        if let completionReporting = minigame as? MinigameCompletionReporting {
            completionReporting.onMinigameEnded = { [weak self] in
                self?.handleGameEnded(id: id, generation: generation)
            }
        }
        activeMinigame = minigame
        state = .playing(gameID: id)
        preferences.lastPlayedMinigameID = id
        statsStore.recordGameStarted(id)
        startSessionHeartbeat()
        updateMenuBar()
        overlayController.show(
            scene: scene,
            on: screen,
            objectScale: settings.gameObjectScale
        )
        minigame.start()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func playLastGame() {
        guard let id = validLastPlayedID else {
            showLauncher()
            return
        }
        playGame(id: id)
    }

    func playRandomGame() {
        guard let game = MinigameRegistry.allGames.filter(\.isAvailable).randomElement() else {
            showLauncher()
            return
        }
        playGame(id: game.id)
    }

    func toggleLauncher() {
        if state == .launcher, launcherController.isVisible {
            hideLauncher()
        } else {
            showLauncher()
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopActiveMinigame()
        launcherController.hide()
        menuBarController.stop()
        shortcutController.stop()
        inputManager.stop()
        inputManager.eventHandler = nil
        inputManager.quitHandler = nil
        inputManager.escapeHandler = nil
        state = .hidden
    }

    private var validLastPlayedID: String? {
        let candidate = preferences.lastPlayedMinigameID ?? statsStore.snapshot.lastPlayedGameID
        guard let candidate,
              MinigameRegistry.metadata(for: candidate)?.isAvailable == true else {
            return nil
        }
        return candidate
    }

    private func connectControllers() {
        launcherController.onPlayGame = { [weak self] id in self?.playGame(id: id) }
        launcherController.onPlayLastGame = { [weak self] in self?.playLastGame() }
        launcherController.onRandomGame = { [weak self] in self?.playRandomGame() }
        launcherController.onHideLauncher = { [weak self] in self?.hideLauncher() }
        launcherController.onSettingChanged = { [weak self] key, value in
            self?.changeSetting(key, enabled: value)
        }
        launcherController.onObjectScaleChanged = { [weak self] value in
            self?.changeObjectScale(value)
        }
        launcherController.onWindowClosed = { [weak self] in
            guard let self, self.state == .launcher else { return }
            self.state = .hidden
        }
        menuBarController.onOpenWhyWait = { [weak self] in self?.showLauncher() }
        menuBarController.onPlayLastGame = { [weak self] in self?.playLastGame() }
        menuBarController.onPlayGame = { [weak self] id in self?.playGame(id: id) }
        menuBarController.onQuit = { [weak self] in self?.requestQuit() }
        shortcutController.onShortcut = { [weak self] in self?.toggleLauncher() }
    }

    private func applyUtilitySettings() {
        if settings.menuBarEnabled {
            menuBarController.start(lastPlayedID: validLastPlayedID)
        } else {
            menuBarController.stop()
        }

        if settings.globalShortcutEnabled {
            if !shortcutController.start() {
                settings.globalShortcutEnabled = false
                preferences.settings = settings
                settingsMessage = "The global shortcut is already in use by another app."
            }
        } else {
            shortcutController.stop()
        }
    }

    private func changeSetting(_ key: WhyWaitSettingKey, enabled: Bool) {
        settingsMessage = nil
        if key == .launchAtLogin {
            let result = launchAtLoginController.setEnabled(enabled)
            settingsMessage = result.message
            refreshLauncher()
            return
        }

        switch key {
        case .menuBarEnabled:
            settings.menuBarEnabled = enabled
        case .globalShortcutEnabled:
            settings.globalShortcutEnabled = enabled
        case .showGameHUD:
            settings.showGameHUD = enabled
        case .reduceVisualEffects:
            settings.reduceVisualEffects = enabled
        case .cursorTrailEffects:
            settings.cursorTrailEffects = enabled
        case .escapeReturnsToLauncher:
            settings.escapeReturnsToLauncher = enabled
        case .automaticallyReopenLauncher:
            settings.automaticallyReopenLauncher = enabled
        case .launchAtLogin:
            break
        }
        preferences.settings = settings
        applyUtilitySettings()
        refreshLauncher()
    }

    private func changeObjectScale(_ value: Double) {
        settings.gameObjectScale = WhyWaitGameObjectScale.clamped(value)
        preferences.settings = settings
        refreshLauncher()
    }

    private func refreshLauncher() {
        guard state == .launcher else { return }
        launcherController.refresh(viewModel: makeLauncherViewModel())
    }

    private func makeLauncherViewModel() -> LauncherViewModel {
        let shortcutDescription = settings.globalShortcutEnabled
            ? shortcutController.shortcutDescription
            : "Shortcut off"
        return launcherViewModelBuilder.make(
            stats: statsStore.snapshot,
            lastPlayedID: validLastPlayedID,
            settings: settings,
            launchAtLogin: launchAtLoginController.status,
            settingsMessage: settingsMessage,
            shortcutDescription: shortcutDescription
        )
    }

    private func updateMenuBar() {
        guard settings.menuBarEnabled else { return }
        menuBarController.update(lastPlayedID: validLastPlayedID)
    }

    private func startSessionHeartbeat() {
        sessionHeartbeat?.invalidate()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.statsStore.checkpointActiveSession()
        }
        RunLoop.main.add(timer, forMode: .common)
        sessionHeartbeat = timer
    }

    private func stopActiveMinigame() {
        sessionHeartbeat?.invalidate()
        sessionHeartbeat = nil
        gameGeneration += 1
        if let completionReporting = activeMinigame as? MinigameCompletionReporting {
            completionReporting.onMinigameEnded = nil
        }
        if let activeMinigame {
            _ = statsStore.recordGameStopped(activeMinigame.id)
            activeMinigame.stop()
        }
        activeMinigame = nil
        overlayController.setClickThroughEnabled(false)
        overlayController.hide()
    }

    private func handleGameEnded(id: String, generation: Int) {
        guard gameGeneration == generation,
              state == .playing(gameID: id),
              activeMinigame?.id == id else { return }
        if settings.automaticallyReopenLauncher {
            showLauncher()
        } else {
            stopActiveMinigame()
            state = .hidden
        }
    }

    private func handleEscape() -> Bool {
        guard case .playing = state else { return false }
        if settings.escapeReturnsToLauncher {
            showLauncher()
        } else {
            stopActiveMinigame()
            state = .hidden
        }
        return true
    }

    private func handle(_ event: InputEvent) {
        guard case .playing = state else { return }
        if case .escapePressed = event {
            _ = handleEscape()
            return
        }
        activeMinigame?.handle(event)
    }

    private func requestQuit() {
        onExitRequested?()
    }

    private func activeDisplay() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(mouseLocation, $0.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

#if DEBUG
    func sendInputForDiagnostics(_ event: InputEvent) {
        handle(event)
    }

    var diagnosticStats: WhyWaitStatsSnapshot { statsStore.snapshot }
    var diagnosticSettings: WhyWaitSettings { settings }
    func changeSettingForDiagnostics(_ key: WhyWaitSettingKey, enabled: Bool) {
        changeSetting(key, enabled: enabled)
    }
    func changeObjectScaleForDiagnostics(_ value: Double) {
        changeObjectScale(value)
    }
#endif
}
