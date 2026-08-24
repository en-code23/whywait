import CoreGraphics

enum DummyReactionPreset: String, CaseIterable {
    case subtle = "SUBTLE"
    case balanced = "BALANCED"
    case lively = "LIVELY"

    var impulseMultiplier: CGFloat {
        switch self {
        case .subtle: return 0.58
        case .balanced: return 1
        case .lively: return 1.48
        }
    }

    var rockingStiffness: CGFloat {
        switch self {
        case .subtle: return 22
        case .balanced: return SwordDummyTuning.dummyRockingStiffness
        case .lively: return 12.5
        }
    }

    var rockingDamping: CGFloat {
        switch self {
        case .subtle: return 6.4
        case .balanced: return SwordDummyTuning.dummyRockingDamping
        case .lively: return 3.7
        }
    }
}

enum DummyDurabilityPreset: String, CaseIterable {
    case standard = "STANDARD"
    case tough = "TOUGH"
    case endless = "ENDLESS"

    var maximumHealth: Int? {
        switch self {
        case .standard: return SwordDummyTuning.dummyMaximumHealth
        case .tough: return 2_000
        case .endless: return nil
        }
    }
}

enum DummyPlacementPreset: String, CaseIterable {
    case fixed = "FIXED"
    case varied = "VARIED"
}

struct SwordDummySettings {
    var controlMode: SwordControlMode = .spring
    var swordWeight: SwordWeightPreset = .medium
    var springResponse: SwordSpringPreset = .balanced
    var dummyReaction: DummyReactionPreset = .balanced
    var dummyDurability: DummyDurabilityPreset = .standard
    var dummyPlacement: DummyPlacementPreset = .varied

    var physicsParameters: SwordPhysicsParameters {
        SwordPhysicsParameters(
            controlMode: controlMode,
            mass: swordWeight.mass,
            momentOfInertia: swordWeight.momentOfInertia,
            springStiffness: springResponse.stiffness,
            springDamping: springResponse.damping,
            maximumForce: SwordEngineTuning.maximumSpringForce,
            maximumLinearSpeed: swordWeight.maximumSpeed,
            maximumAngularSpeed: SwordEngineTuning.maximumAngularSpeed
        )
    }
}

enum SwordDummySettingKind: CaseIterable, Hashable {
    case controlMode
    case swordWeight
    case springResponse
    case dummyReaction
    case dummyDurability
    case dummyPlacement

    var title: String {
        switch self {
        case .controlMode: return "CONTROL"
        case .swordWeight: return "WEIGHT"
        case .springResponse: return "RESPONSE"
        case .dummyReaction: return "REACTION"
        case .dummyDurability: return "DURABILITY"
        case .dummyPlacement: return "PLACEMENT"
        }
    }
}

extension SwordDummySettings {
    mutating func cycle(_ kind: SwordDummySettingKind) {
        switch kind {
        case .controlMode:
            controlMode = controlMode.next
        case .swordWeight:
            swordWeight = swordWeight.next
        case .springResponse:
            springResponse = springResponse.next
        case .dummyReaction:
            dummyReaction = dummyReaction.next
        case .dummyDurability:
            dummyDurability = dummyDurability.next
        case .dummyPlacement:
            dummyPlacement = dummyPlacement.next
        }
    }

    func value(for kind: SwordDummySettingKind) -> String {
        switch kind {
        case .controlMode: return controlMode.rawValue
        case .swordWeight: return swordWeight.rawValue
        case .springResponse: return springResponse.rawValue
        case .dummyReaction: return dummyReaction.rawValue
        case .dummyDurability: return dummyDurability.rawValue
        case .dummyPlacement: return dummyPlacement.rawValue
        }
    }
}

private extension CaseIterable where Self: Equatable, AllCases: RandomAccessCollection {
    var next: Self {
        let values = Array(Self.allCases)
        guard let index = values.firstIndex(of: self) else { return self }
        return values[(index + 1) % values.count]
    }
}
