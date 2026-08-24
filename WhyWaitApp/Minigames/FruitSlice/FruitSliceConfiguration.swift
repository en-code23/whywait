import CoreGraphics
import Foundation

enum FruitSliceTuning {
    static let gravity = CGVector(dx: 0, dy: -900)

    static let minimumSliceSpeed: CGFloat = 550
    static let perfectSliceMinimumSpeed: CGFloat = 1_050
    static let maximumAcceptedCursorSpeed: CGFloat = 3_600
    static let maximumCursorSegmentLength: CGFloat = 260
    static let minimumCursorSegmentLength: CGFloat = 4
    static let minimumCursorSampleInterval: TimeInterval = 1.0 / 500.0
    static let inputInterruptionInterval: TimeInterval = 0.22
    static let bladeHistoryDuration: TimeInterval = 0.12
    static let bladeTrailDuration: TimeInterval = 0.18
    static let maximumBladeSamples = 16
    static let maximumBladeTrailSegments = 24
    static let bladeCollisionPadding: CGFloat = 3

    static let swipeSessionGap: TimeInterval = 0.13
    static let comboSliceWindow: TimeInterval = 0.2
    static let comboBonusPerAdditionalFruit: CGFloat = 0.25
    static let perfectSliceRadiusRatio: CGFloat = 0.2
    static let perfectSliceBonus = 60

    static let startingLives = 3
    static let initialSpawnInterval: TimeInterval = 1.2
    static let minimumSpawnInterval: TimeInterval = 0.56
    static let initialSpawnDelay: TimeInterval = 0.65
    static let difficultyRampDuration: TimeInterval = 70
    static let relaxedOpeningDuration: TimeInterval = 10
    static let initialBombProbability: CGFloat = 0.035
    static let maximumBombProbability: CGFloat = 0.12
    static let maximumSimultaneousLaunchables = 18

    static let standardLaunchSpeed: ClosedRange<CGFloat> = 1_020...1_270
    static let highLaunchSpeed: ClosedRange<CGFloat> = 1_330...1_500
    static let horizontalLaunchSpeed: ClosedRange<CGFloat> = -245...245
    static let crossHorizontalSpeed: ClosedRange<CGFloat> = 270...390
    static let maximumDifficultyVelocityVariation: CGFloat = 135
    static let angularVelocity: ClosedRange<CGFloat> = -2.8...2.8

    static let offscreenCleanupMargin: CGFloat = 150
    static let gameOverDuration: TimeInterval = 1.55
    static let updateDiscontinuityThreshold: TimeInterval = 0.24

    static let halfBaseSeparationSpeed: CGFloat = 115
    static let halfMaximumSwipeImpulse: CGFloat = 250
    static let halfForwardInfluence: CGFloat = 0.055
    static let standardParticleCount = 7
    static let perfectParticleCount = 11
    static let bombParticleCount = 12
}

enum FruitSlicePhysicsCategory {
    static let fruit: UInt32 = 1 << 16
    static let bomb: UInt32 = 1 << 17
    static let fruitHalf: UInt32 = 1 << 18
}

