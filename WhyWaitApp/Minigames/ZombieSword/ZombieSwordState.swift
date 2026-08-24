import Foundation

enum ZombieSwordSceneState: Equatable {
    case resetting
    case waveTransition
    case playing
    case playerDead

    func canTransition(to next: ZombieSwordSceneState) -> Bool {
        switch (self, next) {
        case (.resetting, .waveTransition),
             (.waveTransition, .playing),
             (.playing, .waveTransition),
             (.playing, .playerDead),
             (.waveTransition, .playerDead),
             (.playerDead, .resetting),
             (.playing, .resetting),
             (.waveTransition, .resetting):
            return true
        default:
            return self == next
        }
    }
}

enum ZombieState: Equatable {
    case spawning
    case approaching
    case staggered
    case attacking
    case dead
}

enum ZombieBodyRegion: String, CaseIterable, Hashable {
    case head
    case torso
    case leftArm
    case rightArm
}

struct ZombieHitRegionID: Hashable {
    let zombieID: UUID
    let bodyRegion: ZombieBodyRegion
}

enum ZombieStrikeStyle: String, Equatable {
    case slash = "SLASH"
    case heavy = "HEAVY"
    case headshot = "HEADSHOT"
    case perfect = "PERFECT"
    case armor = "BLOCKED"
}

enum ZombieWaveArchetype: String, CaseIterable {
    case swarm
    case heavy
    case armored
    case rush
    case mixed
    case encircle
}

enum ZombieSpawnEdge: CaseIterable {
    case top
    case bottom
    case left
    case right
}
