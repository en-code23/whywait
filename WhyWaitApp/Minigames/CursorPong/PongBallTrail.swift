import SpriteKit

final class PongBallTrail: SKNode {
    private let sampleCount = 8
    private var history: [CGPoint] = []
    private var dots: [SKShapeNode] = []
    private let visualEffectsReduced = WhyWaitPresentationPreferences.reduceVisualEffects
    private let trailsEnabled = WhyWaitPresentationPreferences.cursorTrailsEnabled

    override init() {
        super.init()
        configureDots()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PongBallTrail does not support NSCoding")
    }

    func update(ballPosition: CGPoint, speed: CGFloat) {
        guard trailsEnabled else {
            dots.forEach { $0.isHidden = true }
            return
        }

        history.insert(ballPosition, at: 0)
        let maximumHistoryCount = (sampleCount * 2) + 1
        if history.count > maximumHistoryCount {
            history.removeLast(history.count - maximumHistoryCount)
        }

        let speedRatio = min(1, speed / CursorPongTuning.maximumBallSpeed)
        for (index, dot) in dots.enumerated() {
            guard !visualEffectsReduced || index < 4 else {
                dot.isHidden = true
                continue
            }

            let historyIndex = (index + 1) * 2
            guard history.indices.contains(historyIndex) else {
                dot.isHidden = true
                continue
            }

            let age = CGFloat(index + 1) / CGFloat(sampleCount + 1)
            let sample = history[historyIndex]
            let precedingIndex = max(0, historyIndex - 1)
            let preceding = history[precedingIndex]
            let segment = CGVector(dx: preceding.x - sample.x, dy: preceding.y - sample.y)
            let segmentLength = hypot(segment.dx, segment.dy)
            let baseScale = (1 - (age * 0.58)) * (0.68 + (speedRatio * 0.32))

            dot.position = sample
            dot.zRotation = atan2(segment.dy, segment.dx)
            dot.xScale = baseScale * (1.05 + min(0.9, segmentLength / 24) * speedRatio)
            dot.yScale = baseScale * 0.68
            dot.alpha = (0.52 - (age * 0.43)) * (0.5 + (speedRatio * 0.5))
            dot.fillColor = SKColor(
                calibratedRed: 0.52 + age * 0.18,
                green: 0.9 + age * 0.06,
                blue: 1,
                alpha: 1
            )
            dot.isHidden = false
        }
    }

    func reset(at position: CGPoint? = nil) {
        history.removeAll(keepingCapacity: true)
        if let position {
            history.append(position)
        }
        dots.forEach { $0.isHidden = true }
    }

    private func configureDots() {
        name = "cursor-pong-ball-trail"
        zPosition = 10

        for _ in 0..<sampleCount {
            let dot = SKShapeNode(circleOfRadius: CursorPongTuning.ballRadius * 0.66)
            dot.fillColor = SKColor(calibratedRed: 0.55, green: 0.9, blue: 1, alpha: 1)
            dot.strokeColor = SKColor.white.withAlphaComponent(0.26)
            dot.lineWidth = 0.65
            dot.isHidden = true
            addChild(dot)
            dots.append(dot)
        }
    }
}
