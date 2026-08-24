import AppKit
import SpriteKit

final class SwordDummyGame: Minigame {
    let id = "sword-dummy"
    let name = "Sword Dummy"

    private weak var scene: SwordDummyScene?
    private var isRunning = false

    func makeScene(size: CGSize) -> SKScene {
        let scene = SwordDummyScene(size: size)
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
        guard isRunning else { return }

        switch input {
        case let .mouseMoved(screenLocation),
             let .leftMouseDragged(screenLocation):
            scene?.mouseMoved(toScreenLocation: screenLocation)
        case let .rightMouseDown(screenLocation):
            scene?.recoverSword(atScreenLocation: screenLocation)
        case let .leftMouseDown(screenLocation):
            scene?.leftMouseDown(atScreenLocation: screenLocation)
        case let .keyDown(keyCode, isRepeat) where !isRepeat:
            switch keyCode {
            case 1:
                scene?.toggleSettings()
            case 15:
                scene?.resetTrainingSetup(resetSessionStatistics: false)
            default:
                break
            }
        case .leftMouseUp, .keyDown, .escapePressed:
            break
        }
    }
}
