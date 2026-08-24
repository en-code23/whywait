import CoreGraphics

enum PongPhysics {
    static func reboundVelocity(
        incomingVelocity: CGVector,
        ballY: CGFloat,
        paddleY: CGFloat,
        paddleHeight: CGFloat,
        outgoingDirection: CGFloat,
        paddleVerticalVelocity: CGFloat,
        paddleInfluence: CGFloat
    ) -> CGVector {
        let incomingSpeed = max(
            CursorPongTuning.minimumBallSpeed,
            magnitude(of: incomingVelocity)
        )
        let outgoingSpeed = min(
            incomingSpeed * CursorPongTuning.speedIncreasePerHit,
            CursorPongTuning.maximumBallSpeed
        )

        let normalizedImpact = clamp(
            (ballY - paddleY) / (paddleHeight / 2),
            minimum: -1,
            maximum: 1
        )
        let maximumAngle = CursorPongTuning.maximumBounceAngleDegrees * .pi / 180
        let impactVerticalVelocity = sin(normalizedImpact * maximumAngle) * outgoingSpeed
        let safePaddleVelocity = clamp(
            paddleVerticalVelocity,
            minimum: -CursorPongTuning.maximumTrackedPaddleVelocity,
            maximum: CursorPongTuning.maximumTrackedPaddleVelocity
        )
        let swipeContribution = clamp(
            safePaddleVelocity * paddleInfluence,
            minimum: -CursorPongTuning.maximumSwipeContribution,
            maximum: CursorPongTuning.maximumSwipeContribution
        )
        let maximumVerticalVelocity = sin(maximumAngle) * outgoingSpeed
        let outgoingY = clamp(
            impactVerticalVelocity + swipeContribution,
            minimum: -maximumVerticalVelocity,
            maximum: maximumVerticalVelocity
        )
        let outgoingX = sqrt(max(0, (outgoingSpeed * outgoingSpeed) - (outgoingY * outgoingY)))

        return CGVector(
            dx: outgoingX * (outgoingDirection >= 0 ? 1 : -1),
            dy: outgoingY
        )
    }

    static func serveVelocity(toward side: PongSide, angleDegrees: CGFloat) -> CGVector {
        let clampedAngle = clamp(angleDegrees, minimum: -18, maximum: 18) * .pi / 180

        return CGVector(
            dx: cos(clampedAngle) * CursorPongTuning.initialBallSpeed
                * side.horizontalDirection,
            dy: sin(clampedAngle) * CursorPongTuning.initialBallSpeed
        )
    }

    static func magnitude(of vector: CGVector) -> CGFloat {
        hypot(vector.dx, vector.dy)
    }

    static func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }
}
