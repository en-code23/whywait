import AppKit

final class MenuBarController: NSObject {
    var onOpenWhyWait: (() -> Void)?
    var onPlayLastGame: (() -> Void)?
    var onPlayGame: ((String) -> Void)?
    var onCheckForUpdates: (() -> Void)?
    var onQuit: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var lastPlayedID: String?

    func start(lastPlayedID: String?) {
        guard statusItem == nil else {
            update(lastPlayedID: lastPlayedID)
            return
        }
        self.lastPlayedID = lastPlayedID
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "hourglass.circle.fill",
                accessibilityDescription: "WhyWait"
            ) ?? NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "WhyWait")
            button.image?.isTemplate = true
            button.toolTip = "WhyWait"
        }
        statusItem = item
        rebuildMenu()
    }

    func update(lastPlayedID: String?) {
        self.lastPlayedID = lastPlayedID
        rebuildMenu()
    }

    func stop() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func rebuildMenu() {
        guard let statusItem else { return }
        let menu = NSMenu(title: "WhyWait")
        menu.autoenablesItems = false

        let openItem = NSMenuItem(title: "Open WhyWait", action: #selector(openWhyWait), keyEquivalent: "")
        openItem.target = self
        openItem.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil)
        menu.addItem(openItem)

        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        menu.addItem(updateItem)

        let lastName = lastPlayedID.flatMap { MinigameRegistry.metadata(for: $0)?.name }
        let lastItem = NSMenuItem(
            title: lastName.map { "Play Last Game — \($0)" } ?? "Play Last Game",
            action: #selector(playLastGame),
            keyEquivalent: ""
        )
        lastItem.target = self
        lastItem.isEnabled = lastName != nil
        lastItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: nil)
        menu.addItem(lastItem)
        menu.addItem(.separator())

        for game in MinigameRegistry.allGames {
            let item = NSMenuItem(title: game.name, action: #selector(playGame(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = game.id
            item.isEnabled = game.isAvailable
            item.image = NSImage(systemSymbolName: game.symbolName, accessibilityDescription: nil)
                ?? NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: nil)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit WhyWait", action: #selector(quit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        WWText.localize(menu)
    }

    @objc private func openWhyWait() { onOpenWhyWait?() }
    @objc private func checkForUpdates() { onCheckForUpdates?() }
    @objc private func playLastGame() { onPlayLastGame?() }

    @objc private func playGame(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onPlayGame?(id)
    }

    @objc private func quit() { onQuit?() }

#if DEBUG
    var diagnosticMenuTitles: [String] {
        statusItem?.menu?.items.filter { !$0.isSeparatorItem }.map(\.title) ?? []
    }

    func activateGameForDiagnostics(id: String) {
        guard let item = statusItem?.menu?.items.first(where: {
            $0.representedObject as? String == id
        }) else { return }
        playGame(item)
    }

    func activateLastGameForDiagnostics() {
        playLastGame()
    }
#endif
}
