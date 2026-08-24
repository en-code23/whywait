import SpriteKit

final class PongBall: SKNode {
    private let appearanceNode = SKNode()
    private let glowNode = SKShapeNode(circleOfRadius: CursorPongTuning.ballRadius + 4)
    private let impactRing = SKShapeNode(circleOfRadius: CursorPongTuning.ballRadius + 3)
    private let visualEffectsReduced = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        configureAppearance()
        configurePhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PongBall does not support NSCoding")
    }

    var velocity: CGVector {
        get { physicsBody?.velocity ?? .zero }
        set { physicsBody?.velocity = newValue }
    }

    var travelSpeed: CGFloat {
        PongPhysics.magnitude(of: velocity)
    }

    func stop() {
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
    }

    func playImpact(strong: Bool) {
        appearanceNode.removeAction(forKey: "impact")
        glowNode.removeAction(forKey: "flash")
        impactRing.removeAction(forKey: "impact-ring")

        let impactScale: CGFloat = visualEffectsReduced
            ? (strong ? 1.12 : 1.07)
            : (strong ? 1.3 : 1.16)
        let expand = SKAction.scale(to: impactScale, duration: 0.035)
        let settle = SKAction.scale(to: 1, duration: 0.09)
        settle.timingMode = .easeOut
        appearanceNode.run(.sequence([expand, settle]), withKey: "impact")

        glowNode.alpha = strong ? 0.55 : 0.34
        glowNode.run(.fadeAlpha(to: 0.12, duration: 0.14), withKey: "flash")

        impactRing.alpha = strong ? 0.72 : 0.42
        impactRing.setScale(0.76)
        let ringDuration = visualEffectsReduced ? 0.08 : (strong ? 0.2 : 0.14)
        let ringEffect = SKAction.group([
            .fadeOut(withDuration: ringDuration),
            .scale(to: visualEffectsReduced ? 1.12 : (strong ? 1.9 : 1.55), duration: ringDuration)
        ])
        ringEffect.timingMode = .easeOut
        impactRing.run(ringEffect, withKey: "impact-ring")
    }

    private func configureAppearance() {
        name = "cursor-pong-ball"
        zPosition = 20

        glowNode.fillColor = SKColor(calibratedRed: 0.53, green: 0.91, blue: 1, alpha: 0.22)
        glowNode.strokeColor = .clear
        glowNode.alpha = 0.12
        appearanceNode.addChild(glowNode)

        let shadow = SKShapeNode(circleOfRadius: CursorPongTuning.ballRadius + 1)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.3)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 1.5, y: -2)
        shadow.zPosition = -1
        appearanceNode.addChild(shadow)

        let surface = SKShapeNode(circleOfRadius: CursorPongTuning.ballRadius)
        surface.fillColor = SKColor(calibratedRed: 0.8, green: 0.93, blue: 0.97, alpha: 0.99)
        surface.strokeColor = SKColor(calibratedRed: 0.38, green: 0.75, blue: 0.85, alpha: 0.96)
        surface.lineWidth = 1.1
        appearanceNode.addChild(surface)

        let lowerShade = SKShapeNode(
            ellipseOf: CGSize(
                width: CursorPongTuning.ballRadius * 1.55,
                height: CursorPongTuning.ballRadius * 0.72
            )
        )
        lowerShade.fillColor = SKColor(calibratedRed: 0.12, green: 0.48, blue: 0.62, alpha: 0.24)
        lowerShade.strokeColor = .clear
        lowerShade.position = CGPoint(x: 1.3, y: -3.2)
        lowerShade.zPosition = 1
        appearanceNode.addChild(lowerShade)

        let core = SKShapeNode(circleOfRadius: CursorPongTuning.ballRadius * 0.58)
        core.fillColor = SKColor.white.withAlphaComponent(0.24)
        core.strokeColor = .clear
        core.position = CGPoint(x: -1, y: 1.2)
        core.zPosition = 1.2
        appearanceNode.addChild(core)

        let highlight = SKShapeNode(
            ellipseOf: CGSize(
                width: CursorPongTuning.ballRadius * 0.62,
                height: CursorPongTuning.ballRadius * 0.32
            )
        )
        highlight.fillColor = SKColor.white.withAlphaComponent(0.88)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -2.9, y: 3.8)
        highlight.zRotation = 0.45
        highlight.zPosition = 2
        appearanceNode.addChild(highlight)

        addChild(appearanceNode)

        impactRing.fillColor = .clear
        impactRing.strokeColor = SKColor(calibratedRed: 0.62, green: 0.95, blue: 1, alpha: 0.92)
        impactRing.lineWidth = 1.15
        impactRing.alpha = 0
        impactRing.zPosition = 3
        addChild(impactRing)
    }

    private func configurePhysics() {
        let body = SKPhysicsBody(circleOfRadius: CursorPongTuning.ballRadius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true
        body.linearDamping = 0
        body.angularDamping = 0
        body.friction = 0
        body.restitution = 1
        body.categoryBitMask = PongPhysicsCategory.ball
        body.collisionBitMask = PongPhysicsCategory.horizontalBoundary
        body.contactTestBitMask = PongPhysicsCategory.horizontalBoundary
            | PongPhysicsCategory.paddles
        physicsBody = body
    }
}
