import CoreGraphics
import Foundation

enum ZombieSwordTuning {
    static let playerHealth = 100
    static let playerRadius: CGFloat = 24
    static let playerAttackRadius: CGFloat = 57
    static let waveHealAmount = 5

    static let minimumDamagingSpeed: CGFloat = 410
    static let referenceImpactSpeed: CGFloat = 2_350
    static let maximumHitDamage = 125
    static let headModifier: CGFloat = 1.35
    static let torsoModifier: CGFloat = 1
    static let armModifier: CGFloat = 0.75
    static let armoredTorsoModifier: CGFloat = 0.48
    static let alignedArmorModifier: CGFloat = 0.7
    static let maximumKnockbackSpeed: CGFloat = 560
    static let staggerDamageThreshold = 24

    static let attackWindup: TimeInterval = 0.38
    static let spawnWarningDuration: TimeInterval = 0.58
    static let initialSpawnInterval: TimeInterval = 0.72
    static let minimumSpawnInterval: TimeInterval = 0.34
    static let wavePause: TimeInterval = 1.4
    static let playerDeathPause: TimeInterval = 1.55
    static let maximumActiveZombies = 16
    static let maximumSimultaneousAttackResolutions = 2
    static let separationRadius: CGFloat = 82
    static let separationStrength: CGFloat = 75

    static let comboTimeout: TimeInterval = 1.35
    static let challengeAdvanceDelay: TimeInterval = 1.15
    static let maximumEffectNodes = 80
}
