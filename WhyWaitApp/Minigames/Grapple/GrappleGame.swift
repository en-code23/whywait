import AppKit
import SpriteKit

final class GrappleGame: Minigame {
    let id = "grapple"
    let name = "Grapple"

    private weak var scene: GrappleScene?
    private var isRunning = false

    func makeScene(size: CGSize) -> SKScene {
        let scene = GrappleScene(size: size)
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
        case let .leftMouseDown(screenLocation):
            scene?.leftMouseDown(atScreenLocation: screenLocation)
        case let .leftMouseUp(screenLocation):
            scene?.leftMouseUp(atScreenLocation: screenLocation)
        case let .keyDown(keyCode, isRepeat) where keyCode == 15 && !isRepeat:
            scene?.generateNewCourse()
        case .rightMouseDown, .keyDown, .escapePressed:
            break
        }
    }
}
