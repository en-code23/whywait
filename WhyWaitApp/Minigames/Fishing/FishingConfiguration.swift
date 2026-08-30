import CoreGraphics
import Foundation

enum FishingTuning {
    // Casting
    static let fullChargeDuration: TimeInterval = 1.25
    static let minimumCastDistance: CGFloat = 95
    static let minimumCastPower: CGFloat = 0.16
    static let minimumCastUpwardComponent: CGFloat = 0.16
    static let maximumWorldCastDistance: CGFloat = 780
    static let bobberFlightDurationRange: ClosedRange<TimeInterval> = 0.48...0.82
    static let bobberArcHeightRange: ClosedRange<CGFloat> = 54...126
    static let waterInset: CGFloat = 38

    // Waiting and bites
    static let biteWaitRange: ClosedRange<TimeInterval> = 1.5...6.0
    static let baseHookWindow: TimeInterval = 0.88
    static let minimumHookWindow: TimeInterval = 0.62
    static let maximumHookWindow: TimeInterval = 1.42
    static let ambientMovementInterval: ClosedRange<TimeInterval> = 0.65...1.45

    // Fight
    static let minimumFightDeltaTime: TimeInterval = 1.0 / 240.0
    static let maximumFightDeltaTime: TimeInterval = 1.0 / 30.0
    static let updateInterruptionThreshold: TimeInterval = 0.28
    static let catchDistance: CGFloat = 48
    static let fishVisualMaximumSpeed: CGFloat = 460
    static let tensionResponse: CGFloat = 5.8
    static let tensionReelGain: CGFloat = 0.31
    static let tensionPullGain: CGFloat = 0.48
    static let tensionDistanceGain: CGFloat = 0.16
    static let tensionControlRelief: CGFloat = 0.31
    static let tensionRestRelief: CGFloat = 0.19
    static let criticalTensionVisualThreshold: CGFloat = 0.82
    static let slackTensionThreshold: CGFloat = 0.085
    static let baseSlackGrace: TimeInterval = 1.05
    static let baseOverloadGrace: TimeInterval = 0.34
    static let baseLineBreakThreshold: CGFloat = 0.91
    static let baseReelRate: CGFloat = 108
    static let maximumLineDistanceMultiplier: CGFloat = 1.22
    static let staminaDrainWhileReeling: CGFloat = 8.4
    static let staminaNaturalDrain: CGFloat = 1.25
    static let fishPullOutRate: CGFloat = 76

    // Catalog and economy
    static let baseTreasureProbability: Double = 0.075
    static let minimumTreasureProbability: Double = 0.042
    static let recordValueBonus: Double = 0.12
    static let startingCoins = 250
    static let maximumRecentTransactions = 64
    static let upgradeCosts = [500, 1_500, 4_000, 10_000]
    static let rareVariantBaseProbability = 0.022
    static let maximumRareVariantProbability = 0.085
    static let maximumLureQuantity = 24
    static let baseVaultCapacity = 24
    static let vaultCapacities = [24, 40, 64, 96]
    static let maximumVaultLevel = 3
    static let vaultUpgradeCosts = [900, 2_400, 5_800]

    // Presentation and cleanup
    static let catchPresentationDuration: TimeInterval = 1.7
    static let failurePresentationDuration: TimeInterval = 0.82
    static let treasureReelDuration: TimeInterval = 0.58
    static let fightBurstRippleInterval: TimeInterval = 0.22
    static let maximumEffectNodes = 48
    static let panelMaximumSize = CGSize(width: 790, height: 540)
    static let rodBottomInset: CGFloat = 54
    static let rodHorizontalFraction: CGFloat = 0.16
}

extension CGFloat {
    static func fishingClamp(_ value: CGFloat, _ range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, value))
    }
}
