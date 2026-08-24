import CoreGraphics
import Foundation

enum GrappleTuning {
    static let gravity = CGVector(dx: 0, dy: -1_080)
    static let playerRadius: CGFloat = 16
    static let playerMass: CGFloat = 1
    static let maximumPlayerSpeed: CGFloat = 1_650
    static let airDamping: CGFloat = 0.065
    static let collisionRestitution: CGFloat = 0.52
    static let collisionFriction: CGFloat = 0.08
    static let launchPlatformSize = CGSize(width: 72, height: 12)

    static let minimumGrappleDistance: CGFloat = 65
    static let maximumGrappleDistance: CGFloat = 520
    static let ropeStiffness: CGFloat = 38
    static let ropeDamping: CGFloat = 7.5
    static let maximumRopeForce: CGFloat = 8_200
    static let maximumRopeStretchRatio: CGFloat = 0.12
    static let ropeRetractionSpeed: CGFloat = 13
    static let maximumPhysicsDeltaTime: TimeInterval = 1.0 / 30.0
    static let updateInterruptionThreshold: TimeInterval = 0.24

    static let minimumCheckpointCount = 3
    static let maximumCheckpointCount = 6
    static let checkpointRadius: CGFloat = 25
    static let goalRadius: CGFloat = 31
    static let courseHorizontalInset: CGFloat = 78
    static let courseVerticalInset: CGFloat = 72
    static let maximumProgressionSpacing: CGFloat = 735
    static let minimumProgressionSpacing: CGFloat = 70
    static let courseGenerationAttempts = 32
    static let minimumObstacleCount = 3
    static let maximumObstacleCount = 6
    static let minimumHazardCount = 1
    static let maximumHazardCount = 3
    static let protectedPointPadding: CGFloat = 36

    static let respawnDelay: TimeInterval = 0.52
    static let roundCompletionPause: TimeInterval = 1.28
    static let outOfBoundsMargin: CGFloat = 165
    static let highSpeedThreshold: CGFloat = 1_000
    static let cleanCheckpointCollisionGrace: TimeInterval = 0.48

    static let trailMinimumSpeed: CGFloat = 170
    static let trailSampleCount = 10
    static let releaseFeedbackMinimumSpeed: CGFloat = 760
    static let releaseFeedbackMinimumTension: CGFloat = 0.38
}

enum GrapplePhysicsCategory {
    static let player: UInt32 = 1 << 20
    static let obstacle: UInt32 = 1 << 21
    static let hazard: UInt32 = 1 << 22
}
