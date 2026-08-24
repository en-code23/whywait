import CoreGraphics

enum SwordControlState: Equatable {
    case normal
    case recovering
}

enum SwordControlMode: String, CaseIterable {
    case spring = "SPRING"
    case stick = "STICK"
}

enum SwordWeightPreset: String, CaseIterable {
    case light = "LIGHT"
    case medium = "MEDIUM"
    case heavy = "HEAVY"

    var mass: CGFloat {
        switch self {
        case .light: return 2.05
        case .medium: return SwordEngineTuning.swordMass
        case .heavy: return 3.75
        }
    }

    var momentOfInertia: CGFloat {
        switch self {
        case .light: return 5_300
        case .medium: return SwordEngineTuning.swordMomentOfInertia
        case .heavy: return 9_700
        }
    }

    var maximumSpeed: CGFloat {
        switch self {
        case .light: return 2_750
        case .medium: return SwordEngineTuning.maximumLinearSpeed
        case .heavy: return 2_300
        }
    }
}

enum SwordSpringPreset: String, CaseIterable {
    case soft = "SOFT"
    case balanced = "BALANCED"
    case firm = "FIRM"

    var stiffness: CGFloat {
        switch self {
        case .soft: return 64
        case .balanced: return SwordEngineTuning.positionSpringStiffness
        case .firm: return 132
        }
    }

    var damping: CGFloat {
        switch self {
        case .soft: return 17
        case .balanced: return SwordEngineTuning.positionSpringDamping
        case .firm: return 30
        }
    }
}

struct SwordPhysicsParameters {
    var controlMode: SwordControlMode
    var mass: CGFloat
    var momentOfInertia: CGFloat
    var springStiffness: CGFloat
    var springDamping: CGFloat
    var maximumForce: CGFloat
    var maximumLinearSpeed: CGFloat
    var maximumAngularSpeed: CGFloat

    static let standard = SwordPhysicsParameters(
        controlMode: .spring,
        mass: SwordEngineTuning.swordMass,
        momentOfInertia: SwordEngineTuning.swordMomentOfInertia,
        springStiffness: SwordEngineTuning.positionSpringStiffness,
        springDamping: SwordEngineTuning.positionSpringDamping,
        maximumForce: SwordEngineTuning.maximumSpringForce,
        maximumLinearSpeed: SwordEngineTuning.maximumLinearSpeed,
        maximumAngularSpeed: SwordEngineTuning.maximumAngularSpeed
    )
}
