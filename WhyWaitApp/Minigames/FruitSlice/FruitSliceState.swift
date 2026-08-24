enum FruitSliceState: Equatable {
    case ready
    case playing
    case gameOver
    case resetting

    func canTransition(to newState: FruitSliceState) -> Bool {
        switch (self, newState) {
        case (.ready, .playing),
             (.ready, .resetting),
             (.playing, .gameOver),
             (.playing, .resetting),
             (.gameOver, .resetting),
             (.resetting, .ready):
            return true
        default:
            return false
        }
    }
}

enum FruitSliceGameOverReason: Equatable {
    case misses
    case bomb
}

