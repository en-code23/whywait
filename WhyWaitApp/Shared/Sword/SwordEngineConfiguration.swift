import CoreGraphics
import Foundation

enum SwordEngineTuning {
    static let swordLength: CGFloat = 178
    static let gripLength: CGFloat = 36
    static let bladeLength: CGFloat = 132
    static let bladeHalfWidth: CGFloat = 5.5
    static let guardHeight: CGFloat = 31
    static let handleLocalX: CGFloat = -74
    static let bladeStartLocalX: CGFloat = -38
    static let bladeTipLocalX: CGFloat = 94
    static let swordMass: CGFloat = 2.8
    static let swordMomentOfInertia: CGFloat = 7_250

    static let positionSpringStiffness: CGFloat = 94
    static let positionSpringDamping: CGFloat = 23
    static let linearAirDamping: CGFloat = 0.46
    static let angularDamping: CGFloat = 1.35
    static let maximumSpringForce: CGFloat = 17_500
    static let maximumLinearSpeed: CGFloat = 2_550
    static let maximumAngularSpeed: CGFloat = 20
    static let maximumCursorTargetStep: CGFloat = 360
    static let maximumFrameDelta: TimeInterval = 1.0 / 30.0
    static let integrationSubstep: TimeInterval = 1.0 / 240.0
    static let interruptionThreshold: TimeInterval = 0.16

    static let trailMinimumSpeed: CGFloat = 430
    static let trailLifetime: TimeInterval = 0.16
    static let maximumTrailNodes = 24
    static let contactCooldown: TimeInterval = 0.13
    static let swingStartSpeed: CGFloat = 330
    static let swingEndSpeed: CGFloat = 190
    static let swingIdleDuration: TimeInterval = 0.19
}
