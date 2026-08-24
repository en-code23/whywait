import AppKit
import Foundation
import SpriteKit

final class ZombieSwordPlayer: SKNode {
    private let groundShadow = SKShapeNode(ellipseOf: CGSize(width: 54, height: 17))
    private let aura = SKShapeNode(circleOfRadius: ZombieSwordTuning.playerRadius + 3)
    private let shield = SKShapeNode()
    private let innerRim = SKShapeNode()
    private let core = SKShapeNode()
    private(set) var health = ZombieSwordTuning.playerHealth

    override init() {
        super.init()
        name = "zombie-sword-player"
        zPosition = 18
        buildVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ZombieSwordPlayer does not support NSCoding")
    }

    @discardableResult
    func takeDamage(_ damage: Int) -> Int {
        guard health > 0, damage > 0 else { return health }
        health = max(0, health - damage)
        shield.removeAction(forKey: "damage")
        shield.run(.sequence([
            .group([
                .scale(to: 1.18, duration: 0.07),
                .colorize(with: .systemRed, colorBlendFactor: 0.75, duration: 0.07)
            ]),
            .group([
                .scale(to: 1, duration: 0.15),
                .colorize(withColorBlendFactor: 0, duration: 0.15)
            ])
        ]), withKey: "damage")
        core.removeAction(forKey: "damage-core")
        core.run(.sequence([
            .fadeAlpha(to: 0.2, duration: 0.04),
            .fadeAlpha(to: 1, duration: 0.15)
        ]), withKey: "damage-core")
        setLowHealthPulse(health <= 25)
        return health
    }

    func heal(_ amount: Int) {
        health = min(ZombieSwordTuning.playerHealth, health + max(0, amount))
        setLowHealthPulse(health <= 25)
    }

    func reset(at position: CGPoint) {
        removeAllActions()
        shield.removeAllActions()
        core.removeAllActions()
        aura.removeAllActions()
        self.position = position
        health = ZombieSwordTuning.playerHealth
        alpha = 1
        setScale(1)
        shield.alpha = 1
        shield.setScale(1)
        core.alpha = 1
        setLowHealthPulse(false)
        startIdleAura()
    }

    private func setLowHealthPulse(_ active: Bool) {
        shield.removeAction(forKey: "low-health")
        aura.removeAction(forKey: "idle-aura")
        guard active else {
            shield.alpha = 1
            shield.setScale(1)
            startIdleAura()
            return
        }
        shield.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.62, duration: 0.38), .scale(to: 1.06, duration: 0.38)]),
            .group([.fadeAlpha(to: 1, duration: 0.38), .scale(to: 1, duration: 0.38)])
        ])), withKey: "low-health")
        aura.strokeColor = NSColor.systemRed.withAlphaComponent(0.72)
        aura.run(.repeatForever(.sequence([
            .group([.scale(to: 1.12, duration: 0.35), .fadeAlpha(to: 0.2, duration: 0.35)]),
            .group([.scale(to: 0.96, duration: 0), .fadeAlpha(to: 0.72, duration: 0)])
        ])), withKey: "idle-aura")
    }

    private func buildVisuals() {
        groundShadow.position = CGPoint(x: 3, y: -27)
        groundShadow.fillColor = NSColor.black.withAlphaComponent(0.22)
        groundShadow.strokeColor = .clear
        groundShadow.zPosition = -2

        aura.strokeColor = NSColor.systemCyan.withAlphaComponent(0.52)
        aura.fillColor = NSColor.systemCyan.withAlphaComponent(0.025)
        aura.lineWidth = 1.2
        aura.zPosition = -1

        let shieldPath = CGMutablePath()
        shieldPath.move(to: CGPoint(x: 0, y: 25))
        shieldPath.addCurve(
            to: CGPoint(x: -21, y: 8),
            control1: CGPoint(x: -9, y: 23),
            control2: CGPoint(x: -18, y: 18)
        )
        shieldPath.addCurve(
            to: CGPoint(x: -13, y: -17),
            control1: CGPoint(x: -22, y: -3),
            control2: CGPoint(x: -19, y: -12)
        )
        shieldPath.addQuadCurve(to: CGPoint(x: 0, y: -27), control: CGPoint(x: -7, y: -24))
        shieldPath.addQuadCurve(to: CGPoint(x: 13, y: -17), control: CGPoint(x: 7, y: -24))
        shieldPath.addCurve(
            to: CGPoint(x: 21, y: 8),
            control1: CGPoint(x: 19, y: -12),
            control2: CGPoint(x: 22, y: -3)
        )
        shieldPath.addCurve(
            to: CGPoint(x: 0, y: 25),
            control1: CGPoint(x: 18, y: 18),
            control2: CGPoint(x: 9, y: 23)
        )
        shieldPath.closeSubpath()
        shield.path = shieldPath
        shield.fillColor = NSColor(calibratedRed: 0.10, green: 0.25, blue: 0.32, alpha: 0.82)
        shield.strokeColor = NSColor.systemCyan.withAlphaComponent(0.9)
        shield.lineWidth = 2

        let rimPath = CGMutablePath()
        rimPath.move(to: CGPoint(x: 0, y: 18))
        rimPath.addCurve(to: CGPoint(x: -14, y: 6), control1: CGPoint(x: -7, y: 17), control2: CGPoint(x: -12, y: 12))
        rimPath.addCurve(to: CGPoint(x: 0, y: -18), control1: CGPoint(x: -14, y: -5), control2: CGPoint(x: -8, y: -13))
        rimPath.addCurve(to: CGPoint(x: 14, y: 6), control1: CGPoint(x: 8, y: -13), control2: CGPoint(x: 14, y: -5))
        rimPath.addCurve(to: CGPoint(x: 0, y: 18), control1: CGPoint(x: 12, y: 12), control2: CGPoint(x: 7, y: 17))
        innerRim.path = rimPath
        innerRim.strokeColor = NSColor.white.withAlphaComponent(0.28)
        innerRim.lineWidth = 1.1
        innerRim.fillColor = .clear
        innerRim.zPosition = 1

        let corePath = CGMutablePath()
        corePath.move(to: CGPoint(x: 0, y: 9))
        corePath.addLine(to: CGPoint(x: 8, y: 0))
        corePath.addLine(to: CGPoint(x: 0, y: -9))
        corePath.addLine(to: CGPoint(x: -8, y: 0))
        corePath.closeSubpath()
        core.path = corePath
        core.fillColor = NSColor.white.withAlphaComponent(0.9)
        core.strokeColor = NSColor.systemCyan.withAlphaComponent(0.88)
        core.lineWidth = 1.3
        core.glowWidth = WhyWaitPresentationPreferences.reduceVisualEffects ? 0 : 1.5
        core.zPosition = 2

        let coreInset = SKShapeNode(circleOfRadius: 2.1)
        coreInset.fillColor = NSColor.systemCyan.withAlphaComponent(0.95)
        coreInset.strokeColor = .clear
        core.addChild(coreInset)

        addChild(groundShadow)
        addChild(aura)
        addChild(shield)
        shield.addChild(innerRim)
        shield.addChild(core)
        startIdleAura()
    }

    private func startIdleAura() {
        aura.removeAction(forKey: "idle-aura")
        aura.strokeColor = NSColor.systemCyan.withAlphaComponent(0.52)
        guard !WhyWaitPresentationPreferences.reduceVisualEffects else {
            aura.alpha = 0.45
            aura.setScale(1)
            return
        }
        aura.run(.repeatForever(.sequence([
            .group([.scale(to: 1.07, duration: 0.75), .fadeAlpha(to: 0.25, duration: 0.75)]),
            .group([.scale(to: 0.98, duration: 0.75), .fadeAlpha(to: 0.62, duration: 0.75)])
        ])), withKey: "idle-aura")
    }
}
