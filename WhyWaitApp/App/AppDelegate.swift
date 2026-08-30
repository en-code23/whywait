import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
#if DEBUG
        if ProcessInfo.processInfo.environment["WHYWAIT_APP_SHELL_TESTS"] == "1" {
            DispatchQueue.main.async {
                do {
                    for report in try AppShellDiagnostics.runAll() {
                        print("APP SHELL TEST PASS — \(report)")
                    }
                    NSApplication.shared.terminate(nil)
                } catch {
                    fatalError("App shell diagnostics failed: \(error)")
                }
            }
            return
        }
#endif
        let coordinator = AppCoordinator()
        coordinator.onExitRequested = {
            NSApplication.shared.terminate(nil)
        }

        self.coordinator = coordinator
        coordinator.start()

        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu(title: "Main Menu")
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "WhyWait")
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        applicationMenu.addItem(settingsItem)
        let updateItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = self
        applicationMenu.addItem(updateItem)
        applicationMenu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit WhyWait",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = NSApplication.shared
        applicationMenu.addItem(quitItem)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApplication.shared.mainMenu = mainMenu
    }

    @objc private func openSettings(_ sender: Any?) {
        coordinator?.showSettings()
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        coordinator?.checkForUpdates()
    }
}
