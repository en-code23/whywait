import AppKit
import SpriteKit

final class CursorPongGame: Minigame {
    let id = "cursor-pong"
    let name = "Cursor Pong"

    private weak var scene: CursorPongScene?
    private var isRunning = false

    func makeScene(size: CGSize) -> SKScene {
#if DEBUG
        if ProcessInfo.processInfo.environment["WHYWAIT_CURSOR_PONG_TESTS"] == "1" {
            do {
                let report = try CursorPongDifficultyDiagnostics.run()
                print("CURSOR PONG TEST PASS — \(report.summary)")
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                assertionFailure("Cursor Pong diagnostics failed: \(error)")
            }
        }
#endif
        let scene = CursorPongScene(size: size)
        self.scene = scene
        return scene
    }

    func start() {
        isRunning = true
        scene?.startGame()
        scene?.mouseMoved(toScreenLocation: NSEvent.mouseLocation)
    }

    func stop() {
        isRunning = false
        scene?.stopGame()
        scene = nil
    }

    func handle(_ input: InputEvent) {
        guard isRunning else {
            return
        }

        switch input {
        case let .mouseMoved(screenLocation),
             let .leftMouseDragged(screenLocation):
            scene?.mouseMoved(toScreenLocation: screenLocation)
        case let .keyDown(keyCode, isRepeat) where keyCode == 15 && !isRepeat:
            scene?.resetMatch()
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .keyDown, .escapePressed:
            break
        }
    }
}
