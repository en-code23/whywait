import CoreGraphics
import Foundation

enum CursorGolfTuning {
    static let ballRadius: CGFloat = 12
    static let holeRadius: CGFloat = 20
    static let ballHitSlop: CGFloat = 10

    static let maximumDragDistance: CGFloat = 155
    static let minimumLaunchDrag: CGFloat = 8
    static let shotSpeedPerDragPoint: CGFloat = 6.2
    static let maximumLaunchSpeed: CGFloat = 960

    static let ballLinearDamping: CGFloat = 0.9
    static let ballAngularDamping: CGFloat = 1.1
    static let ballRestitution: CGFloat = 0.62
    static let ballFriction: CGFloat = 0.22
    static let boundaryRestitution: CGFloat = 0.56
    static let obstacleRestitution: CGFloat = 0.66

    static let stoppedSpeed: CGFloat = 16
    static let stoppedDuration: TimeInterval = 0.14

    static let holeCaptureDistance: CGFloat = 13.5
    static let maximumSinkSpeed: CGFloat = 210
    static let attractionRadius: CGFloat = 34
    static let maximumAttractionSpeed: CGFloat = 135
    static let attractionAcceleration: CGFloat = 52

    static let sinkAnimationDuration: TimeInterval = 0.42
    static let roundResultDuration: TimeInterval = 0.95

    static let courseEdgeInset: CGFloat = 68
    static let obstacleClearance: CGFloat = 58
    static let impactFeedbackMinimumSpeed: CGFloat = 180

    static func playableBounds(for size: CGSize) -> CGRect {
        let horizontalInset = min(courseEdgeInset, max(24, size.width * 0.12))
        let verticalInset = min(courseEdgeInset, max(24, size.height * 0.12))

        return CGRect(origin: .zero, size: size).insetBy(
            dx: horizontalInset,
            dy: verticalInset
        )
    }
}

enum GolfPhysicsCategory {
    static let ball: UInt32 = 1 << 0
    static let boundary: UInt32 = 1 << 1
    static let obstacle: UInt32 = 1 << 2
}
