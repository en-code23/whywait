import AppKit
import SpriteKit

final class SwordEffects: SKNode {
    private var transientNodes: [SKNode] = []
    private let reducesEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        name = "sword-effects"
        zPosition = 70
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("SwordEffects does not support NSCoding")
    }

    func showImpact(result: SwordDamageResult, at point: CGPoint) {
        guard result.damage > 0 else { return }
        purgeExpiredNodes()

        let flash = SKShapeNode(circleOfRadius: result.damage >= 50 ? 10 : 6.5)
        flash.position = point
        flash.fillColor = NSColor(calibratedRed: 1, green: 0.78, blue: 0.27, alpha: 0.4)
        flash.strokeColor = NSColor.white.withAlphaComponent(0.94)
        flash.lineWidth = 1.35
        flash.glowWidth = reducesEffects ? 0 : (result.damage >= 50 ? 4 : 2)
        addTransient(flash)
        flash.run(.sequence([
            .group([
                .scale(to: 1.8, duration: 0.11),
                .fadeOut(withDuration: 0.13)
            ]),
            .removeFromParent()
        ]))

        let sparkCount = reducesEffects ? 2 : (result.damage >= 50 ? 7 : 4)
        let perpendicular = CGVector(
            dx: -result.impactDirection.dy,
            dy: result.impactDirection.dx
        )
        for index in 0..<sparkCount {
            let spread = CGFloat(index - (sparkCount / 2)) * 0.31
            let direction = SwordMath.normalized(
                SwordMath.add(
                    SwordMath.scale(result.impactDirection, by: -0.35),
                    SwordMath.scale(perpendicular, by: spread)
                )
            )
            let sparkPath = CGMutablePath()
            sparkPath.move(to: .zero)
            sparkPath.addLine(to: CGPoint(x: CGFloat(5 + (index % 3) * 2), y: 0))
            let spark = SKShapeNode(path: sparkPath)
            spark.position = point
            spark.zRotation = atan2(direction.dy, direction.dx)
            spark.strokeColor = index.isMultiple(of: 3)
                ? NSColor.white.withAlphaComponent(0.95)
                : NSColor(calibratedRed: 1, green: 0.67, blue: 0.14, alpha: 0.95)
            spark.lineWidth = index.isMultiple(of: 2) ? 1.8 : 1.1
            spark.lineCap = .round
            addTransient(spark)
            spark.run(.sequence([
                .group([
                    .moveBy(
                        x: direction.dx * CGFloat(16 + (index * 2)),
                        y: direction.dy * CGFloat(16 + (index * 2)),
                        duration: 0.2
                    ),
                    .fadeOut(withDuration: 0.2)
                ]),
                .removeFromParent()
            ]))
        }

        if !reducesEffects {
            let slashPath = CGMutablePath()
            slashPath.move(to: CGPoint(x: -14, y: 0))
            slashPath.addQuadCurve(
                to: CGPoint(x: 14, y: 0),
                control: CGPoint(x: 0, y: result.damage >= 50 ? 8 : 5)
            )
            let slash = SKShapeNode(path: slashPath)
            slash.position = point
            slash.zRotation = atan2(result.impactDirection.dy, result.impactDirection.dx) + (.pi / 2)
            slash.strokeColor = NSColor.white.withAlphaComponent(0.72)
            slash.lineWidth = result.damage >= 50 ? 2.4 : 1.5
            slash.glowWidth = result.damage >= 50 ? 2.5 : 1
            addTransient(slash)
            slash.run(.sequence([
                .group([.scale(to: 1.35, duration: 0.1), .fadeOut(withDuration: 0.16)]),
                .removeFromParent()
            ]))
        }

        showFloatingText(
            "\(result.damage)",
            at: CGPoint(x: point.x, y: point.y + 12),
            color: result.damage >= 50 ? .systemYellow : .white,
            fontSize: result.damage >= 50 ? 21 : 16,
            duration: 0.68
        )
        if let style = result.style {
            showFloatingText(
                style.rawValue,
                at: CGPoint(x: point.x, y: point.y + 37),
                color: style == .perfect ? .systemYellow : .systemCyan,
                fontSize: 12,
                duration: 0.7
            )
        }
    }

    func showChallengeComplete(near point: CGPoint) {
        showFloatingText(
            "★  CHALLENGE COMPLETE",
            at: point,
            color: .systemYellow,
            fontSize: 15,
            duration: 1.05
        )
    }

    func showDestroyed(near point: CGPoint, statistics: SwordDummySessionStatistics) {
        showFloatingText(
            "DESTROYED",
            at: CGPoint(x: point.x, y: point.y + 28),
            color: .systemOrange,
            fontSize: 24,
            duration: 1.15
        )
        showFloatingText(
            "STRONGEST \(statistics.strongestHit)   COMBO x\(max(1, statistics.highestCombo))",
            at: point,
            color: .white,
            fontSize: 12,
            duration: 1.1
        )
    }

    func showRecovery(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 13)
        ring.position = point
        ring.strokeColor = NSColor.systemCyan.withAlphaComponent(0.65)
        ring.lineWidth = 1.5
        ring.fillColor = .clear
        addTransient(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 1.65, duration: 0.18),
                .fadeOut(withDuration: 0.18)
            ]),
            .removeFromParent()
        ]))
    }

    func clear() {
        removeAllActions()
        removeAllChildren()
        transientNodes.removeAll(keepingCapacity: true)
    }

    var activeNodeCount: Int {
        transientNodes.filter { $0.parent != nil }.count
    }

    private func showFloatingText(
        _ text: String,
        at point: CGPoint,
        color: NSColor,
        fontSize: CGFloat,
        duration: TimeInterval
    ) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontColor = color
        label.fontSize = fontSize
        label.position = point
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Bold")
        shadow.text = text
        shadow.fontSize = fontSize
        shadow.fontColor = NSColor.black.withAlphaComponent(0.72)
        shadow.position = CGPoint(x: 1.4, y: -1.7)
        shadow.horizontalAlignmentMode = .center
        shadow.verticalAlignmentMode = .center
        shadow.zPosition = -1
        label.addChild(shadow)
        addTransient(label)
        label.run(.sequence([
            .group([
                .moveBy(x: 0, y: 25, duration: duration),
                .fadeOut(withDuration: duration)
            ]),
            .removeFromParent()
        ]))
    }

    private func addTransient(_ node: SKNode) {
        purgeExpiredNodes()
        transientNodes.append(node)
        addChild(node)
        while transientNodes.count > SwordDummyTuning.maximumEffectNodes {
            transientNodes.removeFirst().removeFromParent()
        }
    }

    private func purgeExpiredNodes() {
        transientNodes.removeAll { $0.parent == nil }
    }
}
