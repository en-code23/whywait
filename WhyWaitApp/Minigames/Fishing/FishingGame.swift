import AppKit
import SpriteKit

final class FishingGame: Minigame {
    let id = "fishing"
    let name = "Fishing"

    private weak var scene: FishingScene?
    private var isRunning = false

    func makeScene(size: CGSize) -> SKScene {
        let scene = FishingScene(size: size)
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
        case let .leftMouseDown(screenLocation):
            scene?.leftMouseDown(atScreenLocation: screenLocation)
        case let .leftMouseUp(screenLocation):
            scene?.leftMouseUp(atScreenLocation: screenLocation)
        case let .keyDown(keyCode, isRepeat) where !isRepeat:
            switch keyCode {
            case 2:
                scene?.toggleFishDex()
            case 15:
                scene?.resetCurrentInteraction()
            case 32:
                scene?.toggleUpgrades()
            default:
                break
            }
        case .rightMouseDown, .keyDown, .escapePressed:
            break
        }
    }
}
