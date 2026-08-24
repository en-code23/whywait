import CoreGraphics
import Foundation

enum CursorPongTuning {
    static let paddleSize = CGSize(width: 18, height: 118)
    static let paddleEdgeInset: CGFloat = 58
    static let paddleVerticalPadding: CGFloat = 18
    static let ballRadius: CGFloat = 9

    static let initialBallSpeed: CGFloat = 465
    static let minimumBallSpeed: CGFloat = 440
    static let speedIncreasePerHit: CGFloat = 1.045
    static let maximumBallSpeed: CGFloat = 920
    static let maximumBounceAngleDegrees: CGFloat = 56

    static let playerSwipeInfluence: CGFloat = 0.18
    static let cpuPaddleInfluence: CGFloat = 0.035
    static let maximumSwipeContribution: CGFloat = 220
    static let maximumTrackedPaddleVelocity: CGFloat = 1_500
    static let playerFollowRate: CGFloat = 36
    static let inputVelocityResetInterval: TimeInterval = 0.22
    static let swipeSuppressionAfterInputGap: TimeInterval = 0.12

    static let cpuBaseMaximumSpeed: CGFloat = 360
    static let cpuMaximumSpeed: CGFloat = 465
    static let cpuSpeedIncreasePerRallyHit: CGFloat = 5
    static let cpuMinimumReactionDelay: TimeInterval = 0.13
    static let cpuMaximumReactionDelay: TimeInterval = 0.22
    static let cpuBasePredictionError: CGFloat = 96
    static let cpuMinimumPredictionError: CGFloat = 80
    static let cpuPredictionImprovementPerRallyHit: CGFloat = 1.15

    static let rallyDisplayThreshold = 5
    static let winningScore = 5
    static let pointDisplayDuration: TimeInterval = 0.68
    static let serveDelay: TimeInterval = 0.22
    static let initialServeDelay: TimeInterval = 0.52
    static let matchResultDuration: TimeInterval = 1.45

    static let paddleContactCooldown: TimeInterval = 0.055
    static let updateDiscontinuityThreshold: TimeInterval = 0.2

    static func paddleCenterRange(for sceneHeight: CGFloat) -> ClosedRange<CGFloat> {
        let halfHeight = paddleSize.height / 2
        let lower = paddleVerticalPadding + halfHeight
        let upper = max(lower, sceneHeight - paddleVerticalPadding - halfHeight)
        return lower...upper
    }
}

enum PongPhysicsCategory {
    static let ball: UInt32 = 1 << 8
    static let horizontalBoundary: UInt32 = 1 << 9
    static let cpuPaddle: UInt32 = 1 << 10
    static let playerPaddle: UInt32 = 1 << 11
    static let paddles = cpuPaddle | playerPaddle
}
