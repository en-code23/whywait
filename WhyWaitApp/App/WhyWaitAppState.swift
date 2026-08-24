import Foundation

enum WhyWaitAppState: Equatable {
    case launcher
    case playing(gameID: String)
    case hidden
}
