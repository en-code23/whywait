import CoreGraphics
import Foundation

enum FishingTensionOutcome: Equatable {
    case none
    case lineBroke
    case hookLost
}

enum FishingTensionVisualLevel: Equatable {
    case low
    case normal
    case high
    case critical
}

final class FishingTensionSystem {
    private(set) var tension: CGFloat = 0.24
    private(set) var overloadDuration: TimeInterval = 0
    private(set) var slackDuration: TimeInterval = 0
    private var slackEscapeThreshold: TimeInterval = FishingTuning.baseSlackGrace + 0.6

    var visualLevel: FishingTensionVisualLevel {
        switch tension {
        case ..<0.17: return .low
        case ..<0.62: return .normal
        case ..<FishingTuning.criticalTensionVisualThreshold: return .high
        default: return .critical
        }
    }

    func reset(equipment: FishingEquipmentStats, random: FishingRandomSource) {
        tension = 0.24
        overloadDuration = 0
        slackDuration = 0
        slackEscapeThreshold = equipment.slackGrace + random.value(in: 0.36...0.95)
    }

    func update(
        targetTension: CGFloat,
        fishIsActivelyPulling: Bool,
        isReeling: Bool,
        deltaTime: TimeInterval,
        equipment: FishingEquipmentStats
    ) -> FishingTensionOutcome {
        let delta = min(
            FishingTuning.maximumFightDeltaTime,
            max(FishingTuning.minimumFightDeltaTime, deltaTime)
        )
        let target = CGFloat.fishingClamp(targetTension, 0...1.38)
        let response = min(1, CGFloat(delta) * FishingTuning.tensionResponse)
        tension += (target - tension) * response
        if !tension.isFinite {
            tension = 0.24
            overloadDuration = 0
            slackDuration = 0
            return .none
        }

        if tension > equipment.lineBreakThreshold {
            overloadDuration += delta
        } else {
            overloadDuration = max(0, overloadDuration - (delta * 2.2))
        }
        if overloadDuration >= equipment.overloadGrace {
            return .lineBroke
        }

        if tension < FishingTuning.slackTensionThreshold,
           fishIsActivelyPulling,
           !isReeling {
            slackDuration += delta
        } else {
            slackDuration = max(0, slackDuration - (delta * 1.6))
        }
        if slackDuration >= slackEscapeThreshold {
            return .hookLost
        }
        return .none
    }
}

