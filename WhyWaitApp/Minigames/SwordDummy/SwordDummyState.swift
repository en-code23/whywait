import Foundation

enum SwordDummySceneState: Equatable {
    case playing
    case dummyDestroyed
    case resetting

    func canTransition(to next: SwordDummySceneState) -> Bool {
        switch (self, next) {
        case (.resetting, .playing),
             (.playing, .dummyDestroyed),
             (.playing, .resetting),
             (.dummyDestroyed, .resetting):
            return true
        default:
            return self == next
        }
    }
}

enum DummyHitRegionID: String, CaseIterable, Hashable {
    case head
    case torso
    case leftArm
    case rightArm

    var displayName: String {
        switch self {
        case .head: return "HEAD"
        case .torso: return "TORSO"
        case .leftArm, .rightArm: return "ARM"
        }
    }
}

typealias DummyHitShape = SwordHitShape
typealias DummyHitRegion = SwordHitRegion<DummyHitRegionID>
typealias SwordContact = SwordImpact<DummyHitRegionID>

enum SwordStrikeStyle: String, Equatable {
    case slash = "SLASH"
    case heavy = "HEAVY"
    case precision = "PRECISION"
    case thrust = "THRUST"
    case perfect = "PERFECT"
}
