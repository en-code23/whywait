import CoreGraphics

enum CursorPongState: Equatable {
    case serving
    case playing
    case pointScored
    case matchComplete

    func canTransition(to newState: CursorPongState) -> Bool {
        switch (self, newState) {
        case (.serving, .playing),
             (.playing, .pointScored),
             (.pointScored, .serving),
             (.pointScored, .matchComplete),
             (.matchComplete, .serving):
            return true
        default:
            return false
        }
    }
}

enum PongSide: Equatable {
    case cpu
    case player

    var opponent: PongSide {
        self == .player ? .cpu : .player
    }

    /// Horizontal direction from screen center toward this side.
    var horizontalDirection: CGFloat {
        self == .player ? 1 : -1
    }
}
