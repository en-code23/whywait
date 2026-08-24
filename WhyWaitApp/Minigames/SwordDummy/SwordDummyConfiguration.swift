import CoreGraphics
import Foundation

enum SwordDummyTuning {
    // Combat tuning.
    static let minimumDamagingSpeed: CGFloat = 410
    static let referenceImpactSpeed: CGFloat = 2_350
    static let maximumHitDamage = 112
    static let minimumEdgeMultiplier: CGFloat = 0.34
    static let maximumEdgeMultiplier: CGFloat = 1.18
    static let tipModifier: CGFloat = 1.08
    static let thrustModifier: CGFloat = 1.16
    static let headModifier: CGFloat = 1.28
    static let torsoModifier: CGFloat = 1
    static let armModifier: CGFloat = 0.78
    static let contactCooldown: TimeInterval = 0.13

    // Dummy response.
    static let dummyMaximumHealth = 1_000
    static let dummyRockingStiffness: CGFloat = 17
    static let dummyRockingDamping: CGFloat = 5.1
    static let dummyImpulseScale: CGFloat = 0.00052
    static let dummyMaximumLean: CGFloat = 0.36
    static let dummyResetDelay: TimeInterval = 1.35

    // Swing, combo, and presentation.
    static let comboMinimumDamage = 6
    static let comboTimeout: TimeInterval = 1.25
    static let maximumEffectNodes = 64

    // Challenge thresholds.
    static let challengeHeadHits = 3
    static let challengeHeavyDamage = 50
    static let challengeCombo = 5
    static let perfectSpeed: CGFloat = 1_500
    static let perfectAlignment: CGFloat = 0.88
}
