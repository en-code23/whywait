import AppKit

final class LauncherWindowController: NSWindowController, NSWindowDelegate {
    var onPlayGame: ((String) -> Void)? {
        didSet { launcherViewController.onPlayGame = onPlayGame }
    }
    var onPlayLastGame: (() -> Void)? {
        didSet { launcherViewController.onPlayLastGame = onPlayLastGame }
    }
    var onRandomGame: (() -> Void)? {
        didSet { launcherViewController.onRandomGame = onRandomGame }
    }
    var onHideLauncher: (() -> Void)? {
        didSet { launcherViewController.onHideLauncher = onHideLauncher }
    }
    var onSettingChanged: ((WhyWaitSettingKey, Bool) -> Void)? {
        didSet { launcherViewController.onSettingChanged = onSettingChanged }
    }
    var onObjectScaleChanged: ((Double) -> Void)? {
        didSet { launcherViewController.onObjectScaleChanged = onObjectScaleChanged }
    }
    var onWindowClosed: (() -> Void)?

    private let launcherViewController: LauncherViewController

    init(games: [MinigameMetadata]) {
        launcherViewController = LauncherViewController(games: games)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: LauncherTheme.windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "WhyWait"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = LauncherTheme.canvas
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.animationBehavior = .documentWindow
        window.contentMinSize = LauncherTheme.windowSize
        window.contentMaxSize = LauncherTheme.windowSize
        window.contentViewController = launcherViewController
        super.init(window: window)
        window.delegate = self
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("LauncherWindowController does not support NSCoding")
    }

    var isVisible: Bool { window?.isVisible == true }

    func show(viewModel: LauncherViewModel) {
        launcherViewController.refresh(viewModel)
        guard let window else { return }
        if !window.isVisible { window.center() }
        present(window)
    }

    func refresh(viewModel: LauncherViewModel) {
        launcherViewController.refresh(viewModel)
    }

    func showSettings() {
        launcherViewController.showSettings()
        guard let window else { return }
        present(window)
    }

    /// Generic header slot for small status/actions. Automatic-update UI can
    /// attach here without coupling the launcher to an update implementation.
    func installQuickActionAccessory(_ accessory: NSView?) {
        _ = launcherViewController.view
        launcherViewController.installQuickActionAccessory(accessory)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onWindowClosed?()
    }

    private func present(_ window: NSWindow) {
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(launcherViewController.preferredFirstResponder)
    }

#if DEBUG
    var diagnosticCardIDs: [String] {
        _ = launcherViewController.view
        return launcherViewController.diagnosticCardIDs
    }

    var diagnosticFooterText: String {
        _ = launcherViewController.view
        return launcherViewController.diagnosticFooterText
    }

    var diagnosticSelectedGameID: String? {
        _ = launcherViewController.view
        return launcherViewController.diagnosticSelectedGameID
    }

    var diagnosticSettingsVisible: Bool {
        _ = launcherViewController.view
        return launcherViewController.diagnosticSettingsVisible
    }

    func selectCardForDiagnostics(id: String) {
        _ = launcherViewController.view
        launcherViewController.selectCardForDiagnostics(id: id)
    }

    func playCardForDiagnostics(id: String) {
        launcherViewController.playCardForDiagnostics(id: id)
    }

    func playLastForDiagnostics() {
        launcherViewController.playLastForDiagnostics()
    }

    func playRandomForDiagnostics() {
        launcherViewController.playRandomForDiagnostics()
    }

    func changeSettingForDiagnostics(_ key: WhyWaitSettingKey, enabled: Bool) {
        launcherViewController.changeSettingForDiagnostics(key, enabled: enabled)
    }

    func changeObjectScaleForDiagnostics(_ value: Double) {
        launcherViewController.changeObjectScaleForDiagnostics(value)
    }

    func keyEventForDiagnostics(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) {
        launcherViewController.keyEventForDiagnostics(keyCode: keyCode, modifiers: modifiers)
    }

    func closeForDiagnostics() {
        window?.close()
    }
#endif
}
