import CoreGraphics
import Foundation

enum FishingEquipmentCategory: String, Codable, CaseIterable, Hashable {
    case rod
    case reel
    case line
    case hook
    case baitKit = "bait-kit"

    var displayName: String {
        switch self {
        case .rod: return "ROD"
        case .reel: return "REEL"
        case .line: return "LINE"
        case .hook: return "HOOK"
        case .baitKit: return "BAIT KIT"
        }
    }
}

struct FishingEquipmentLevels: Codable, Equatable {
    static let maximumLevel = 5

    var rod = 1
    var reel = 1
    var line = 1
    var hook = 1
    var baitKit = 1

    func level(for category: FishingEquipmentCategory) -> Int {
        switch category {
        case .rod: return rod
        case .reel: return reel
        case .line: return line
        case .hook: return hook
        case .baitKit: return baitKit
        }
    }

    mutating func setLevel(_ level: Int, for category: FishingEquipmentCategory) {
        let value = min(Self.maximumLevel, max(1, level))
        switch category {
        case .rod: rod = value
        case .reel: reel = value
        case .line: line = value
        case .hook: hook = value
        case .baitKit: baitKit = value
        }
    }

    mutating func normalize() {
        for category in FishingEquipmentCategory.allCases {
            setLevel(level(for: category), for: category)
        }
    }

    func upgradeCost(for category: FishingEquipmentCategory) -> Int? {
        let current = level(for: category)
        guard current < Self.maximumLevel else {
            return nil
        }
        return FishingTuning.upgradeCosts[current - 1]
    }

    func stats(worldMaximumCastDistance: CGFloat) -> FishingEquipmentStats {
        FishingEquipmentStats(
            levels: self,
            worldMaximumCastDistance: worldMaximumCastDistance
        )
    }
}

struct FishingEquipmentStats {
    let maximumCastDistance: CGFloat
    let castControl: CGFloat
    let reelRate: CGFloat
    let runRecovery: CGFloat
    let lineBreakThreshold: CGFloat
    let overloadGrace: TimeInterval
    let hookWindowBonus: TimeInterval
    let slackGrace: TimeInterval
    let biteWaitMultiplier: Double
    let rareWeightBonus: Double
    let treasureProbability: Double

    init(levels: FishingEquipmentLevels, worldMaximumCastDistance: CGFloat) {
        let rodStep = CGFloat(levels.rod - 1)
        let reelStep = CGFloat(levels.reel - 1)
        let lineStep = CGFloat(levels.line - 1)
        let hookStep = Double(levels.hook - 1)
        let baitStep = Double(levels.baitKit - 1)

        maximumCastDistance = worldMaximumCastDistance * (0.62 + (rodStep * 0.095))
        castControl = 0.82 + (rodStep * 0.045)
        reelRate = FishingTuning.baseReelRate + (reelStep * 22)
        runRecovery = 1 + (reelStep * 0.075)
        lineBreakThreshold = FishingTuning.baseLineBreakThreshold + (lineStep * 0.055)
        overloadGrace = FishingTuning.baseOverloadGrace + (Double(lineStep) * 0.075)
        hookWindowBonus = hookStep * 0.075
        slackGrace = FishingTuning.baseSlackGrace + (hookStep * 0.19)
        biteWaitMultiplier = max(0.7, 1 - (baitStep * 0.065))
        rareWeightBonus = baitStep * 0.035
        treasureProbability = max(
            FishingTuning.minimumTreasureProbability,
            FishingTuning.baseTreasureProbability - (baitStep * 0.006)
        )
    }
}

extension FishingEquipmentCategory {
    func effectDescription(level: Int) -> String {
        let clamped = min(FishingEquipmentLevels.maximumLevel, max(1, level))
        switch self {
        case .rod:
            return "+\((clamped - 1) * 10)% cast range"
        case .reel:
            return "+\((clamped - 1) * 20) reel speed"
        case .line:
            return "+\((clamped - 1) * 6)% tension limit"
        case .hook:
            return "+\((clamped - 1) * 75)ms hook window"
        case .baitKit:
            return "-\((clamped - 1) * 7)% bite wait"
        }
    }
}

