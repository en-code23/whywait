import CoreGraphics
import SpriteKit

/// The lifecycle contract implemented by every WhyWait minigame.
protocol Minigame: AnyObject {
    var id: String { get }
    var name: String { get }

    func makeScene(size: CGSize) -> SKScene
    func start()
    func stop()
    func handle(_ input: InputEvent)
}

extension Minigame {
    func handle(_ input: InputEvent) {}
}

/// Optional lifecycle hook for games that later gain a natural terminal state.
protocol MinigameCompletionReporting: AnyObject {
    var onMinigameEnded: (() -> Void)? { get set }
}
