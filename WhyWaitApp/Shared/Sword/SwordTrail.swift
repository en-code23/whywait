import AppKit
import SpriteKit

final class SwordTrail: SKNode {
    private var trailNodes: [SKShapeNode] = []
    private let trailsEnabled = WhyWaitPresentationPreferences.cursorTrailsEnabled
    private let reducesEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        name = "sword-blade-trail"
        zPosition = 31
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("SwordTrail does not support NSCoding")
    }

    func update(
        previous: SwordTransformSnapshot,
        current: SwordTransformSnapshot,
        speed: CGFloat
    ) {
        purgeExpiredNodes()
        guard trailsEnabled,
              speed >= SwordEngineTuning.trailMinimumSpeed,
              SwordMath.isFinite(previous.bladeStart),
              SwordMath.isFinite(current.bladeTip) else {
            return
        }

        let strength = SwordMath.clamp(
            (speed - SwordEngineTuning.trailMinimumSpeed) / 1_500,
            minimum: 0,
            maximum: 1
        )
        let path = CGMutablePath()
        path.move(to: previous.bladeStart)
        path.addLine(to: previous.bladeTip)
        path.addLine(to: current.bladeTip)
        path.addLine(to: current.bladeStart)
        path.closeSubpath()

        let trail = SKShapeNode(path: path)
        trail.fillColor = NSColor(
            calibratedRed: 0.46,
            green: 0.77,
            blue: 0.96,
            alpha: 0.045 + (strength * (reducesEffects ? 0.08 : 0.17))
        )
        trail.strokeColor = NSColor(
            calibratedRed: 0.78,
            green: 0.92,
            blue: 1,
            alpha: 0.16 + (strength * 0.34)
        )
        trail.lineWidth = 0.8 + (strength * 1.2)

        // A thin specular line makes the ribbon read as the blade's edge rather
        // than a cursor trail, especially on bright desktop backgrounds.
        let edgePath = CGMutablePath()
        edgePath.move(to: previous.bladeTip)
        edgePath.addQuadCurve(
            to: current.bladeTip,
            control: SwordMath.lerp(previous.bladeTip, current.bladeTip, progress: 0.46)
        )
        let edge = SKShapeNode(path: edgePath)
        edge.strokeColor = NSColor.white.withAlphaComponent(0.18 + (strength * 0.48))
        edge.lineWidth = 0.7 + (strength * 0.85)
        edge.glowWidth = reducesEffects ? 0 : strength * 2.2
        trail.addChild(edge)
        trailNodes.append(trail)
        addChild(trail)
        trail.run(.sequence([
            .fadeOut(withDuration: SwordEngineTuning.trailLifetime),
            .removeFromParent()
        ]))

        if !reducesEffects, strength > 0.62 {
            let tipPath = CGMutablePath()
            tipPath.move(to: previous.bladeTip)
            tipPath.addLine(to: current.bladeTip)
            let tipTrail = SKShapeNode(path: tipPath)
            tipTrail.strokeColor = NSColor(
                calibratedRed: 0.82,
                green: 0.94,
                blue: 1,
                alpha: 0.3 + (strength * 0.42)
            )
            tipTrail.lineWidth = 1.15 + (strength * 0.5)
            tipTrail.glowWidth = strength * 1.5
            trailNodes.append(tipTrail)
            addChild(tipTrail)
            tipTrail.run(.sequence([
                .fadeOut(withDuration: SwordEngineTuning.trailLifetime * 0.82),
                .removeFromParent()
            ]))
        }
        trimIfNeeded()
    }

    func reset() {
        removeAllActions()
        removeAllChildren()
        trailNodes.removeAll(keepingCapacity: true)
    }

    var activeNodeCount: Int {
        trailNodes.filter { $0.parent != nil }.count
    }

    private func purgeExpiredNodes() {
        trailNodes.removeAll { $0.parent == nil }
    }

    private func trimIfNeeded() {
        purgeExpiredNodes()
        while trailNodes.count > SwordEngineTuning.maximumTrailNodes {
            trailNodes.removeFirst().removeFromParent()
        }
    }
}
