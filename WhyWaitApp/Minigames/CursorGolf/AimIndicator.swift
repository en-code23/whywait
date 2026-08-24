import SpriteKit

final class AimIndicator: SKNode {
    private let pullShadowLine = SKShapeNode()
    private let pullLine = SKShapeNode()
    private let projectedShadowLine = SKShapeNode()
    private let projectedLine = SKShapeNode()
    private let pullHandle = SKShapeNode(circleOfRadius: 4.5)
    private let powerHalo = SKShapeNode(circleOfRadius: CursorGolfTuning.ballRadius + 5)
    private var trajectoryDots: [SKShapeNode] = []
    private var smoothedPullVector = CGVector.zero
    private var hasSmoothedPosition = false
    private let visualEffectsReduced = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        configureAppearance()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("AimIndicator does not support NSCoding")
    }

    func begin(ballPosition: CGPoint, aim: CursorGolfAimSnapshot) {
        position = ballPosition
        hasSmoothedPosition = false
        isHidden = false
        alpha = 1
        update(ballPosition: ballPosition, aim: aim)
    }

    func update(ballPosition: CGPoint, aim: CursorGolfAimSnapshot) {
        position = ballPosition

        let targetPullVector = GolfGeometry.vector(
            from: ballPosition,
            to: aim.cursorPosition
        )

        if hasSmoothedPosition {
            let smoothing: CGFloat = visualEffectsReduced ? 0.74 : 0.48
            smoothedPullVector.dx += (targetPullVector.dx - smoothedPullVector.dx) * smoothing
            smoothedPullVector.dy += (targetPullVector.dy - smoothedPullVector.dy) * smoothing
        } else {
            smoothedPullVector = targetPullVector
            hasSmoothedPosition = true
        }

        redraw(power: aim.power)
    }

    func hideImmediately() {
        removeAllActions()
        isHidden = true
        alpha = 0
        pullHandle.isHidden = true
        powerHalo.isHidden = true
        hasSmoothedPosition = false
        smoothedPullVector = .zero
    }

    private func configureAppearance() {
        name = "cursor-golf-aim-indicator"
        zPosition = 15
        isHidden = true

        for line in [pullShadowLine, pullLine, projectedShadowLine, projectedLine] {
            line.lineCap = .round
        }
        addChild(pullShadowLine)
        addChild(pullLine)
        addChild(projectedShadowLine)
        addChild(projectedLine)

        pullHandle.fillColor = SKColor.black.withAlphaComponent(0.26)
        pullHandle.strokeColor = SKColor.white.withAlphaComponent(0.9)
        pullHandle.lineWidth = 1.2
        pullHandle.isHidden = true
        addChild(pullHandle)

        powerHalo.fillColor = .clear
        powerHalo.strokeColor = SKColor.white.withAlphaComponent(0.5)
        powerHalo.lineWidth = 1
        powerHalo.isHidden = true
        addChild(powerHalo)

        for _ in 0..<8 {
            let dot = SKShapeNode(circleOfRadius: 2.35)
            dot.strokeColor = SKColor.white.withAlphaComponent(0.62)
            dot.lineWidth = 0.7
            dot.isHidden = true
            addChild(dot)
            trajectoryDots.append(dot)
        }
    }

    private func redraw(power: CGFloat) {
        let pullDistance = GolfGeometry.magnitude(of: smoothedPullVector)

        let pullPath = CGMutablePath()
        pullPath.move(to: .zero)
        pullPath.addLine(to: CGPoint(x: smoothedPullVector.dx, y: smoothedPullVector.dy))
        pullShadowLine.path = pullPath
        pullShadowLine.strokeColor = SKColor.black.withAlphaComponent(0.34)
        pullShadowLine.lineWidth = 3.4 + (power * 1.2)
        pullLine.path = pullPath
        pullLine.strokeColor = SKColor.white.withAlphaComponent(0.55 + (power * 0.3))
        pullLine.lineWidth = 1.5 + (power * 1.2)

        pullHandle.position = CGPoint(x: smoothedPullVector.dx, y: smoothedPullVector.dy)
        pullHandle.fillColor = powerColor(power).withAlphaComponent(0.22 + power * 0.2)
        pullHandle.setScale(0.78 + power * 0.36)
        pullHandle.isHidden = pullDistance <= 0.5

        powerHalo.strokeColor = powerColor(power).withAlphaComponent(0.28 + power * 0.4)
        powerHalo.lineWidth = 0.8 + power * 1.4
        powerHalo.setScale(0.82 + power * 0.42)
        powerHalo.isHidden = pullDistance <= 0.5

        guard pullDistance > 0.5 else {
            pullShadowLine.path = nil
            projectedLine.path = nil
            projectedShadowLine.path = nil
            trajectoryDots.forEach { $0.isHidden = true }
            return
        }

        let shotDirection = GolfGeometry.normalized(
            CGVector(dx: -smoothedPullVector.dx, dy: -smoothedPullVector.dy)
        )
        let projectedLength = 52 + (power * 128)
        let projectedVector = GolfGeometry.scaled(shotDirection, by: projectedLength)

        let projectedPath = CGMutablePath()
        projectedPath.move(to: .zero)
        projectedPath.addLine(to: CGPoint(x: projectedVector.dx, y: projectedVector.dy))
        projectedShadowLine.path = projectedPath
        projectedShadowLine.strokeColor = SKColor.black.withAlphaComponent(0.25)
        projectedShadowLine.lineWidth = 2.8
        projectedLine.path = projectedPath
        projectedLine.strokeColor = powerColor(power).withAlphaComponent(0.32 + (power * 0.22))
        projectedLine.lineWidth = 1.15

        let dotColor = powerColor(power)
        for (index, dot) in trajectoryDots.enumerated() {
            let fraction = CGFloat(index + 1) / CGFloat(trajectoryDots.count + 1)
            dot.position = CGPoint(
                x: projectedVector.dx * fraction,
                y: projectedVector.dy * fraction
            )
            dot.fillColor = dotColor.withAlphaComponent(0.88 - (fraction * 0.42))
            dot.alpha = 0.92 - fraction * 0.35
            dot.setScale((0.74 + (power * 0.5)) * (1 - fraction * 0.16))
            dot.isHidden = false
        }
    }

    private func powerColor(_ power: CGFloat) -> SKColor {
        if power > 0.72 {
            return SKColor(calibratedRed: 1, green: 0.58, blue: 0.24, alpha: 1)
        }

        if power > 0.38 {
            return SKColor(calibratedRed: 0.72, green: 0.94, blue: 0.48, alpha: 1)
        }

        return SKColor(calibratedRed: 0.46, green: 0.88, blue: 1, alpha: 1)
    }
}
