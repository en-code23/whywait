import CoreGraphics

/// Input events are expressed independently of a particular minigame.
enum InputEvent {
    case mouseMoved(screenLocation: CGPoint)
    case leftMouseDown(screenLocation: CGPoint)
    case leftMouseDragged(screenLocation: CGPoint)
    case leftMouseUp(screenLocation: CGPoint)
    case rightMouseDown(screenLocation: CGPoint)
    case keyDown(keyCode: UInt16, isRepeat: Bool)
    case escapePressed
}
