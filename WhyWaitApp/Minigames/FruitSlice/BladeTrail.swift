import SpriteKit

final class BladeTrail: SKNode {
    private let trailsEnabled = WhyWaitPresentationPreferences.cursorTrailsEnabled
    private let reduceVisualEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        name = "fruit-slice-blade-trail"
        zPosition = 220
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("BladeTrail does not support NSCoding")
    }

    func add(segment: CuttingBladeSegment) {
        guard trailsEnabled else {
            return
        }
        while children.count >= FruitSliceTuning.maximumBladeTrailSegments {
            children.first?.removeFromParent()
        }

        let path = CGMutablePath()
        path.move(to: segment.start)
        path.addLine(to: segment.end)

        let segmentNode = SKNode()
        let speedRatio = min(1, segment.speed / FruitSliceTuning.maximumAcceptedCursorSpeed)
        let haze = SKShapeNode(path: path)
        haze.strokeColor = SKColor(
            calibratedRed: 0.22,
            green: 0.76,
            blue: 1,
            alpha: 0.16 + (speedRatio * 0.18)
        )
        haze.lineWidth = 4 + (speedRatio * 2.2)
        haze.lineCap = .round
        haze.glowWidth = reduceVisualEffects ? 0 : 2 + speedRatio
        segmentNode.addChild(haze)

        let edge = SKShapeNode(path: path)
        edge.strokeColor = SKColor(
            calibratedRed: 0.72,
            green: 0.94,
            blue: 1,
            alpha: 0.7 + (speedRatio * 0.22)
        )
        edge.lineWidth = 1.3 + (speedRatio * 1.1)
        edge.lineCap = .round
        segmentNode.addChild(edge)

        let core = SKShapeNode(path: path)
        core.strokeColor = SKColor.white.withAlphaComponent(0.62 + speedRatio * 0.25)
        core.lineWidth = 0.55
        core.lineCap = .round
        segmentNode.addChild(core)
        addChild(segmentNode)

        segmentNode.run(
            .sequence([
                .fadeOut(withDuration: FruitSliceTuning.bladeTrailDuration),
                .removeFromParent()
            ])
        )
    }

    func reset() {
        removeAllChildren()
    }
}
