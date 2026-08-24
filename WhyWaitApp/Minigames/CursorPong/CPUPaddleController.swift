import Foundation
import SpriteKit

final class CPUPaddleController {
    private(set) var verticalVelocity: CGFloat = 0

    private var targetY: CGFloat = 0
    private var nextReactionTime: TimeInterval = 0
    private var incomingAimOffset: CGFloat = 0
    private var isTrackingIncomingVolley = false
    private let randomUnit: () -> CGFloat

    init(randomUnit: @escaping () -> CGFloat = { CGFloat.random(in: 0...1) }) {
        self.randomUnit = randomUnit
    }

    func update(
        paddle: PongPaddle,
        ball: PongBall,
        sceneSize: CGSize,
        rallyCount: Int,
        deltaTime: TimeInterval,
        currentTime: TimeInterval
    ) {
        guard deltaTime > 0 else {
            paddle.verticalVelocity = 0
            return
        }

        let bounds = CursorPongTuning.paddleCenterRange(for: sceneSize.height)
        updateIncomingVolleyTracking(ball: ball, rallyCount: rallyCount)
        if currentTime >= nextReactionTime {
            targetY = chooseTarget(
                paddle: paddle,
                ball: ball,
                sceneSize: sceneSize,
                rallyCount: rallyCount
            )
            targetY = PongPhysics.clamp(
                targetY,
                minimum: bounds.lowerBound,
                maximum: bounds.upperBound
            )
            nextReactionTime = currentTime + randomTimeInterval(
                CursorPongTuning.cpuMinimumReactionDelay...CursorPongTuning.cpuMaximumReactionDelay
            )
        }

        let rallySpeedBonus = min(
            CursorPongTuning.cpuMaximumSpeed - CursorPongTuning.cpuBaseMaximumSpeed,
            CGFloat(rallyCount) * CursorPongTuning.cpuSpeedIncreasePerRallyHit
        )
        let maximumSpeed = CursorPongTuning.cpuBaseMaximumSpeed + rallySpeedBonus
        let maximumStep = maximumSpeed * CGFloat(deltaTime)
        let requestedStep = targetY - paddle.position.y
        let step = PongPhysics.clamp(
            requestedStep,
            minimum: -maximumStep,
            maximum: maximumStep
        )
        let oldY = paddle.position.y
        paddle.position.y = PongPhysics.clamp(
            oldY + step,
            minimum: bounds.lowerBound,
            maximum: bounds.upperBound
        )

        let calculatedVelocity = (paddle.position.y - oldY) / CGFloat(deltaTime)
        verticalVelocity = (verticalVelocity * 0.3) + (calculatedVelocity * 0.7)
        paddle.verticalVelocity = verticalVelocity
    }

    func reset(paddleY: CGFloat, currentTime: TimeInterval) {
        targetY = paddleY
        verticalVelocity = 0
        incomingAimOffset = 0
        isTrackingIncomingVolley = false
        nextReactionTime = currentTime + randomTimeInterval(
            CursorPongTuning.cpuMinimumReactionDelay...CursorPongTuning.cpuMaximumReactionDelay
        )
    }

    private func chooseTarget(
        paddle: PongPaddle,
        ball: PongBall,
        sceneSize: CGSize,
        rallyCount: Int
    ) -> CGFloat {
        guard ball.velocity.dx < -1 else {
            let centerY = sceneSize.height / 2
            return centerY + ((ball.position.y - centerY) * 0.14)
        }

        let horizontalDistance = max(0, ball.position.x - paddle.position.x)
        let travelTime = horizontalDistance / abs(ball.velocity.dx)
        let rawPrediction = ball.position.y + (ball.velocity.dy * travelTime)
        let reflectedPrediction = CursorPongCPUModel.reflectedY(
            rawPrediction,
            sceneHeight: sceneSize.height
        )

        // The CPU commits to one imperfect read for the whole incoming volley.
        // Re-rolling every reaction let it continuously correct until every
        // prediction fell inside the paddle's collision coverage.
        return reflectedPrediction + incomingAimOffset
    }

    private func updateIncomingVolleyTracking(ball: PongBall, rallyCount: Int) {
        if ball.velocity.dx < -1 {
            guard !isTrackingIncomingVolley else { return }
            isTrackingIncomingVolley = true
            incomingAimOffset = CursorPongCPUModel.aimOffset(
                rallyCount: rallyCount,
                randomUnit: randomUnit()
            )
        } else {
            isTrackingIncomingVolley = false
            incomingAimOffset = 0
        }
    }

    private func randomTimeInterval(_ range: ClosedRange<TimeInterval>) -> TimeInterval {
        let unit = Double(PongPhysics.clamp(randomUnit(), minimum: 0, maximum: 1))
        return range.lowerBound + ((range.upperBound - range.lowerBound) * unit)
    }
}

fileprivate enum CursorPongCPUModel {
    static func predictionUncertainty(rallyCount: Int) -> CGFloat {
        max(
            CursorPongTuning.cpuMinimumPredictionError,
            CursorPongTuning.cpuBasePredictionError
                - (CGFloat(max(0, rallyCount))
                    * CursorPongTuning.cpuPredictionImprovementPerRallyHit)
        )
    }

    static func aimOffset(rallyCount: Int, randomUnit: CGFloat) -> CGFloat {
        let unit = PongPhysics.clamp(randomUnit, minimum: 0, maximum: 1)
        return ((unit * 2) - 1) * predictionUncertainty(rallyCount: rallyCount)
    }

    static func reflectedY(_ value: CGFloat, sceneHeight: CGFloat) -> CGFloat {
        let lower = CursorPongTuning.ballRadius + 2
        let upper = max(lower + 1, sceneHeight - CursorPongTuning.ballRadius - 2)
        let span = upper - lower
        let cycle = span * 2
        var offset = (value - lower).truncatingRemainder(dividingBy: cycle)

        if offset < 0 {
            offset += cycle
        }

        return offset <= span ? lower + offset : upper - (offset - span)
    }
}

#if DEBUG
enum CursorPongDifficultyDiagnostics {
    struct Report {
        let openingReturnRate: CGFloat
        let longRallyReturnRate: CGFloat

        var summary: String {
            String(
                format: "CPU opening return %.1f%% · long-rally return %.1f%%",
                Double(openingReturnRate * 100),
                Double(longRallyReturnRate * 100)
            )
        }
    }

    enum Failure: Error, CustomStringConvertible {
        case invariant(String)

        var description: String {
            switch self {
            case let .invariant(message): return message
            }
        }
    }

    static func run(sampleCount: Int = 12_000) throws -> Report {
        var generator = DeterministicGenerator(seed: 0x57575954)
        let openingRate = simulatedReturnRate(
            rallyCount: 0,
            sampleCount: sampleCount,
            generator: &generator
        )
        let longRallyRate = simulatedReturnRate(
            rallyCount: 18,
            sampleCount: sampleCount,
            generator: &generator
        )

        guard openingRate >= 0.68, openingRate <= 0.8 else {
            throw Failure.invariant("Opening CPU return rate out of target range: \(openingRate)")
        }
        guard longRallyRate >= 0.78, longRallyRate <= 0.9 else {
            throw Failure.invariant("Long-rally CPU return rate out of target range: \(longRallyRate)")
        }
        guard longRallyRate > openingRate else {
            throw Failure.invariant("CPU did not become modestly stronger during a rally")
        }
        guard CursorPongTuning.cpuBaseMaximumSpeed < CursorPongTuning.initialBallSpeed,
              CursorPongTuning.cpuMaximumSpeed < CursorPongTuning.maximumBallSpeed else {
            throw Failure.invariant("CPU speed caps no longer leave room for difficult shots")
        }

        return Report(openingReturnRate: openingRate, longRallyReturnRate: longRallyRate)
    }

    private static func simulatedReturnRate(
        rallyCount: Int,
        sampleCount: Int,
        generator: inout DeterministicGenerator
    ) -> CGFloat {
        let sceneHeight: CGFloat = 900
        let bounds = CursorPongTuning.paddleCenterRange(for: sceneHeight)
        let ballLower = CursorPongTuning.ballRadius + 2
        let ballUpper = sceneHeight - CursorPongTuning.ballRadius - 2
        let collisionCoverage = (CursorPongTuning.paddleSize.height / 2)
            + CursorPongTuning.ballRadius
        var returns = 0

        for _ in 0..<max(1, sampleCount) {
            let intercept = ballLower
                + ((ballUpper - ballLower) * generator.nextUnit())
            let offset = CursorPongCPUModel.aimOffset(
                rallyCount: rallyCount,
                randomUnit: generator.nextUnit()
            )
            let paddleY = PongPhysics.clamp(
                intercept + offset,
                minimum: bounds.lowerBound,
                maximum: bounds.upperBound
            )
            if abs(paddleY - intercept) <= collisionCoverage {
                returns += 1
            }
        }

        return CGFloat(returns) / CGFloat(max(1, sampleCount))
    }

    private struct DeterministicGenerator {
        var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func nextUnit() -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let upper = UInt32(truncatingIfNeeded: state >> 32)
            return CGFloat(Double(upper) / Double(UInt32.max))
        }
    }
}
#endif
