import SpriteKit

final class FishingLineRenderer: SKShapeNode {
    private let depthLine = SKShapeNode()

    override init() {
        super.init()
        name = "fishing-line"
        zPosition = 70
        lineCap = .round
        fillColor = .clear
        isHidden = true
        depthLine.fillColor = .clear
        depthLine.strokeColor = SKColor.black.withAlphaComponent(0.38)
        depthLine.lineCap = .round
        depthLine.zPosition = -1
        addChild(depthLine)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FishingLineRenderer does not support NSCoding")
    }

    func updateWaiting(from start: CGPoint, to end: CGPoint) {
        let path = CGMutablePath()
        path.move(to: start)
        let distance = FishingGeometry.distance(from: start, to: end)
        let sag = min(34, distance * 0.075)
        path.addCurve(
            to: end,
            control1: CGPoint(
                x: start.x + ((end.x - start.x) * 0.28),
                y: start.y + ((end.y - start.y) * 0.25) - (sag * 0.35)
            ),
            control2: CGPoint(
                x: start.x + ((end.x - start.x) * 0.67),
                y: start.y + ((end.y - start.y) * 0.66) - sag
            )
        )
        self.path = path
        depthLine.path = path
        depthLine.lineWidth = 2.45
        strokeColor = SKColor(calibratedRed: 0.83, green: 0.94, blue: 0.97, alpha: 0.73)
        lineWidth = 1.05
        glowWidth = 0
        isHidden = false
    }

    func updateFight(
        from start: CGPoint,
        rodControl: CGPoint,
        to fishPosition: CGPoint,
        tension: CGFloat,
        level: FishingTensionVisualLevel
    ) {
        let directDistance = FishingGeometry.distance(from: start, to: fishPosition)
        let controlVector = FishingGeometry.vector(from: start, to: rodControl)
        let controlLimit = min(190, directDistance * 0.44)
        let boundedControl = FishingGeometry.point(
            start,
            adding: FishingGeometry.scaled(
                FishingGeometry.normalized(controlVector),
                by: min(controlLimit, FishingGeometry.length(controlVector))
            )
        )
        let midpoint = CGPoint(
            x: (start.x + fishPosition.x) * 0.5,
            y: (start.y + fishPosition.y) * 0.5
        )
        let normalizedTension = CGFloat.fishingClamp(tension, 0...1)
        let curveAmount = max(0.06, 1 - normalizedTension)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(
            to: fishPosition,
            control: CGPoint(
                x: midpoint.x + ((boundedControl.x - midpoint.x) * curveAmount),
                y: midpoint.y + ((boundedControl.y - midpoint.y) * curveAmount)
                    - (min(18, directDistance * 0.035) * curveAmount)
            )
        )
        self.path = path
        depthLine.path = path

        switch level {
        case .low:
            strokeColor = SKColor.white.withAlphaComponent(0.38)
            lineWidth = 0.9
            depthLine.lineWidth = 2.1
            glowWidth = 0
        case .normal:
            strokeColor = SKColor(
                calibratedRed: 0.72,
                green: 0.91,
                blue: 1,
                alpha: 0.82
            )
            lineWidth = 1.2
            depthLine.lineWidth = 2.35
            glowWidth = 0
        case .high:
            strokeColor = SKColor(
                calibratedRed: 1,
                green: 0.68,
                blue: 0.28,
                alpha: 0.94
            )
            lineWidth = 1.5
            depthLine.lineWidth = 2.7
            glowWidth = 0.6
        case .critical:
            strokeColor = SKColor(
                calibratedRed: 1,
                green: 0.28,
                blue: 0.22,
                alpha: 1
            )
            lineWidth = 1.8 + (min(1.2, tension) * 0.35)
            depthLine.lineWidth = lineWidth + 1.45
            glowWidth = 1.1
        }
        isHidden = false
    }

    func hide() {
        path = nil
        depthLine.path = nil
        isHidden = true
        glowWidth = 0
    }
}
