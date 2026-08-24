import AppKit
import SpriteKit

final class ZombieSwordGame: Minigame {
    let id = "zombie-sword"
    let name = "Zombie Sword"

    private weak var scene: ZombieSwordScene?
    private var isRunning = false

    func makeScene(size: CGSize) -> SKScene {
        let scene = ZombieSwordScene(size: size)
        self.scene = scene
        return scene
    }

    func start() {
        isRunning = true
#if DEBUG
        if ProcessInfo.processInfo.environment["WHYWAIT_ZOMBIE_SWORD_TESTS"] == "1" {
            do {
                let results = try ZombieSwordDiagnostics.runAll()
                print("ZOMBIE_SWORD_DIAGNOSTICS")
                results.forEach { print($0) }
                print("PASS all \(results.count) suites")
                DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
            } catch {
                fatalError("Zombie Sword diagnostics failed: \(error)")
            }
            return
        }
#endif
        scene?.startGame()
        scene?.mouseMoved(toScreenLocation: NSEvent.mouseLocation)
    }

    func stop() {
        isRunning = false
        scene?.stopGame()
        scene = nil
    }

    func handle(_ input: InputEvent) {
        guard isRunning else { return }
        switch input {
        case let .mouseMoved(screenLocation),
             let .leftMouseDragged(screenLocation):
            scene?.mouseMoved(toScreenLocation: screenLocation)
        case let .rightMouseDown(screenLocation):
            scene?.recoverSword(atScreenLocation: screenLocation)
        case let .keyDown(keyCode, isRepeat) where !isRepeat:
            if keyCode == 15 { scene?.resetRun() }
        case .leftMouseDown, .leftMouseUp, .keyDown, .escapePressed:
            break
        }
    }
}
