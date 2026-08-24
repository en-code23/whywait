import AppKit
import SpriteKit

final class FruitSliceGame: Minigame {
    let id = "fruit-slice"
    let name = "Fruit Slice"

    private weak var scene: FruitSliceScene?
    private var isRunning = false

    func makeScene(size: CGSize) -> SKScene {
        let scene = FruitSliceScene(size: size)
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
            scene?.resetRun()
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .keyDown, .escapePressed:
            break
        }
    }
}
