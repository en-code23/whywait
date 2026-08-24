import Foundation
import SpriteKit

final class PlayerPaddleController {
    private(set) var verticalVelocity: CGFloat = 0

    private var targetY: CGFloat = 0
    private var hasTarget = false
    private var lastInputTime: TimeInterval?
    private var suppressSwipeUntil: TimeInterval = 0

    func receiveCursor(
        y: CGFloat,
        within bounds: ClosedRange<CGFloat>,
        timestamp: TimeInterval
    ) {
        targetY = PongPhysics.clamp(y, minimum: bounds.lowerBound, maximum: bounds.upperBound)
        hasTarget = true

        if lastInputTime.map({
            timestamp - $0 <= 0
                || timestamp - $0 > CursorPongTuning.inputVelocityResetInterval
        }) ?? true {
            verticalVelocity = 0
            suppressSwipeUntil = timestamp
                + CursorPongTuning.swipeSuppressionAfterInputGap
        }

        lastInputTime = timestamp
    }

    func update(
        paddle: PongPaddle,
        within bounds: ClosedRange<CGFloat>,
        deltaTime: TimeInterval,
        currentTime: TimeInterval
    ) {
        guard deltaTime > 0 else {
            paddle.verticalVelocity = 0
            return
        }

        if !hasTarget {
            targetY = paddle.position.y
            hasTarget = true
        }

        targetY = PongPhysics.clamp(
            targetY,
            minimum: bounds.lowerBound,
            maximum: bounds.upperBound
        )

        let oldY = paddle.position.y
        let exponent = -CursorPongTuning.playerFollowRate * CGFloat(deltaTime)
        let interpolation = 1 - CGFloat(Foundation.exp(Double(exponent)))
        let newY = oldY + ((targetY - oldY) * interpolation)
        paddle.position.y = PongPhysics.clamp(
            newY,
            minimum: bounds.lowerBound,
            maximum: bounds.upperBound
        )

        let calculatedVelocity = (paddle.position.y - oldY) / CGFloat(deltaTime)
        let safeVelocity = PongPhysics.clamp(
            calculatedVelocity,
            minimum: -CursorPongTuning.maximumTrackedPaddleVelocity,
            maximum: CursorPongTuning.maximumTrackedPaddleVelocity
        )
        let inputIsStale = lastInputTime.map {
            currentTime - $0 > CursorPongTuning.inputVelocityResetInterval
        } ?? true

        if currentTime < suppressSwipeUntil || inputIsStale {
            verticalVelocity = 0
        } else {
            verticalVelocity = (verticalVelocity * 0.22) + (safeVelocity * 0.78)
        }
        paddle.verticalVelocity = verticalVelocity
    }

    func reset(paddleY: CGFloat, currentTime: TimeInterval? = nil) {
        targetY = paddleY
        hasTarget = true
        lastInputTime = nil
        verticalVelocity = 0
        suppressSwipeUntil = (currentTime ?? 0)
            + CursorPongTuning.swipeSuppressionAfterInputGap
    }
}
