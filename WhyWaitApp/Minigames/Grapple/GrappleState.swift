import CoreGraphics

enum GrappleSceneState: Equatable {
    case playing
    case respawning
    case roundComplete
    case resetting

    func canTransition(to newState: GrappleSceneState) -> Bool {
        switch (self, newState) {
        case (.playing, .respawning),
             (.playing, .roundComplete),
             (.playing, .resetting),
             (.respawning, .playing),
             (.respawning, .resetting),
             (.roundComplete, .resetting),
             (.resetting, .playing):
            return true
        default:
            return false
        }
    }
}

enum GrappleAttachmentState: Equatable {
    case detached
    case attached(anchor: CGPoint, ropeLength: CGFloat)
}

enum GrappleFailureReason: Equatable {
    case hazard
    case outOfBounds
}

