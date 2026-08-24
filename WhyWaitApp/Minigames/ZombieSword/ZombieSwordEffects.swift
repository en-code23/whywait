import AppKit
import SpriteKit

final class ZombieSwordEffects: SKNode {
    private var transientNodes: [SKNode] = []
    private let reducesEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        name = "zombie-sword-effects"
        zPosition = 75
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ZombieSwordEffects does not support NSCoding")
    }

    func showImpact(_ result: ZombieDamageResult, at point: CGPoint) {
        guard result.damage > 0 else { return }
        let armor = result.wasArmorReduced
        let color: NSColor = armor ? .systemCyan : .systemOrange
        let flash = SKShapeNode(circleOfRadius: result.damage >= 50 ? 9 : 5.5)
        flash.position = point
        flash.fillColor = color.withAlphaComponent(armor ? 0.24 : 0.36)
        flash.strokeColor = NSColor.white.withAlphaComponent(0.9)
        flash.lineWidth = armor ? 1.8 : 1.2
        flash.glowWidth = reducesEffects ? 0 : (armor ? 3.5 : 2)
        addTransient(flash)
        flash.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.11), .fadeOut(withDuration: 0.14)]),
            .removeFromParent()
        ]))

        let sparkCount = reducesEffects ? 2 : (armor ? 7 : 4)
        for index in 0..<sparkCount {
            let angle = CGFloat(index) * ((.pi * 2) / CGFloat(max(1, sparkCount))) + 0.18
            let length = CGFloat(armor ? 9 + (index % 3) * 2 : 6 + (index % 2) * 2)
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: length, y: 0))
            let spark = SKShapeNode(path: path)
            spark.position = point
            spark.zRotation = angle
            spark.strokeColor = armor
                ? (index.isMultiple(of: 2) ? .white : .systemCyan)
                : (index.isMultiple(of: 3) ? .white : .systemYellow)
            spark.lineWidth = armor ? 1.5 : 1.2
            spark.lineCap = .round
            addTransient(spark)
            spark.run(.sequence([
                .group([
                    .moveBy(
                        x: cos(angle) * CGFloat(armor ? 22 : 16),
                        y: sin(angle) * CGFloat(armor ? 22 : 16),
                        duration: 0.18
                    ),
                    .fadeOut(withDuration: 0.18)
                ]),
                .removeFromParent()
            ]))
        }

        if !reducesEffects {
            let accentPath = CGMutablePath()
            if armor {
                accentPath.addArc(
                    center: .zero,
                    radius: result.damage >= 50 ? 14 : 10,
                    startAngle: -.pi * 0.25,
                    endAngle: .pi * 0.65,
                    clockwise: false
                )
            } else {
                accentPath.move(to: CGPoint(x: -13, y: 0))
                accentPath.addQuadCurve(
                    to: CGPoint(x: 13, y: 0),
                    control: CGPoint(x: 0, y: result.damage >= 50 ? 7 : 4)
                )
            }
            let accent = SKShapeNode(path: accentPath)
            accent.position = point
            accent.zRotation = atan2(result.impactDirection.dy, result.impactDirection.dx) + (.pi / 2)
            accent.strokeColor = armor
                ? NSColor.systemCyan.withAlphaComponent(0.86)
                : NSColor.white.withAlphaComponent(0.7)
            accent.lineWidth = armor ? 2 : (result.damage >= 50 ? 2.2 : 1.35)
            accent.glowWidth = armor ? 2 : 1
            addTransient(accent)
            accent.run(.sequence([
                .group([.scale(to: 1.32, duration: 0.11), .fadeOut(withDuration: 0.16)]),
                .removeFromParent()
            ]))
        }
        showText(
            "\(result.damage)",
            at: CGPoint(x: point.x, y: point.y + 13),
            color: result.damage >= 50 ? .systemYellow : .white,
            size: result.damage >= 50 ? 20 : 15,
            duration: 0.62
        )
        if let style = result.style {
            showText(
                style.rawValue,
                at: CGPoint(x: point.x, y: point.y + 34),
                color: style == .armor ? .systemGray : .systemCyan,
                size: 11,
                duration: 0.66
            )
        }
    }

    func showWave(_ wave: Int, at point: CGPoint) {
        showText("WAVE \(wave)", at: point, color: .white, size: 20, duration: 0.82)
    }

    func showWaveClear(at point: CGPoint, healed: Int) {
        let suffix = healed > 0 ? "   +\(healed) HP" : ""
        showText("CLEAR\(suffix)", at: point, color: .systemMint, size: 17, duration: 0.86)
    }

    func showPlayerDamage(_ damage: Int, at point: CGPoint) {
        showText("-\(damage)", at: point, color: .systemRed, size: 16, duration: 0.65)
    }

    func showMultiKill(_ count: Int, at point: CGPoint) {
        guard count >= 2 else { return }
        let text: String
        switch count {
        case 2: text = "DOUBLE"
        case 3: text = "TRIPLE"
        default: text = "MULTI x\(count)"
        }
        showText(text, at: point, color: .systemYellow, size: 17, duration: 0.82)
    }

    func showChallengeComplete(at point: CGPoint) {
        showText("★  CHALLENGE COMPLETE", at: point, color: .systemYellow, size: 15, duration: 1)
    }

    func showDeath(wave: Int, score: Int, at point: CGPoint) {
        showText("YOU DIED", at: CGPoint(x: point.x, y: point.y + 18), color: .systemRed, size: 25, duration: 1.42)
        showText("WAVE \(wave)   SCORE \(score)", at: CGPoint(x: point.x, y: point.y - 13), color: .white, size: 13, duration: 1.42)
    }

    func showRecovery(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 13)
        ring.position = point
        ring.strokeColor = NSColor.systemCyan.withAlphaComponent(0.68)
        ring.lineWidth = 1.5
        ring.fillColor = .clear
        addTransient(ring)
        ring.run(.sequence([
            .group([.scale(to: 1.7, duration: 0.18), .fadeOut(withDuration: 0.18)]),
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

    private func showText(
        _ text: String,
        at point: CGPoint,
        color: NSColor,
        size: CGFloat,
        duration: TimeInterval
    ) {
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.position = point
        label.fontColor = color
        label.fontSize = size
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Bold")
        shadow.text = text
        shadow.fontSize = size
        shadow.fontColor = NSColor.black.withAlphaComponent(0.75)
        shadow.position = CGPoint(x: 1.4, y: -1.6)
        shadow.horizontalAlignmentMode = .center
        shadow.verticalAlignmentMode = .center
        shadow.zPosition = -1
        label.addChild(shadow)
        addTransient(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 24, duration: duration), .fadeOut(withDuration: duration)]),
            .removeFromParent()
        ]))
    }

    private func addTransient(_ node: SKNode) {
        purge()
        transientNodes.append(node)
        addChild(node)
        while transientNodes.count > ZombieSwordTuning.maximumEffectNodes {
            transientNodes.removeFirst().removeFromParent()
        }
    }

    private func purge() {
        transientNodes.removeAll { $0.parent == nil }
    }
}
