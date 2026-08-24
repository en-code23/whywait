import CoreGraphics
import SpriteKit

/// Cursor Golf's lifecycle and input adapter. Overlay ownership stays in WhyWait.
final class CursorGolfGame: Minigame {
    let id = "cursor-golf"
    let name = "Cursor Golf"

    private weak var scene: CursorGolfScene?
    private var isRunning = false

    func makeScene(size: CGSize) -> SKScene {
        let scene = CursorGolfScene(size: size)
        self.scene = scene
        return scene
    }

    func start() {
        isRunning = true
        scene?.startGame()
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
        case let .mouseMoved(screenLocation):
            scene?.mouseMoved(toScreenLocation: screenLocation)
        case let .leftMouseDown(screenLocation):
            scene?.leftMouseDown(atScreenLocation: screenLocation)
        case let .leftMouseDragged(screenLocation):
            scene?.leftMouseDragged(toScreenLocation: screenLocation)
        case let .leftMouseUp(screenLocation):
            scene?.leftMouseUp(atScreenLocation: screenLocation)
        case let .keyDown(keyCode, isRepeat) where keyCode == 15 && !isRepeat:
            scene?.resetRound()
        case .rightMouseDown, .keyDown, .escapePressed:
            break
        }
    }
}
