import SpriteKit

final class GolfBall: SKNode {
    let radius = CursorGolfTuning.ballRadius

    private let appearanceNode = SKNode()
    private let impactHalo = SKShapeNode()
    private let visualEffectsReduced = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        configureAppearance()
        configurePhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GolfBall does not support NSCoding")
    }

    func prepareForSinking() {
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        physicsBody = nil
    }

    func playImpactFeedback() {
        appearanceNode.removeAction(forKey: "impact")
        impactHalo.removeAction(forKey: "impact-halo")

        let expand = SKAction.scale(to: visualEffectsReduced ? 1.035 : 1.08, duration: 0.045)
        expand.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.07)
        settle.timingMode = .easeInEaseOut
        appearanceNode.run(.sequence([expand, settle]), withKey: "impact")

        impactHalo.alpha = visualEffectsReduced ? 0.22 : 0.48
        impactHalo.setScale(0.72)
        let haloMotion = SKAction.group([
            .fadeOut(withDuration: visualEffectsReduced ? 0.09 : 0.18),
            .scale(to: visualEffectsReduced ? 1.15 : 1.65, duration: visualEffectsReduced ? 0.09 : 0.18)
        ])
        haloMotion.timingMode = .easeOut
        impactHalo.run(haloMotion, withKey: "impact-halo")
    }

    private func configureAppearance() {
        name = "cursor-golf-ball"
        zPosition = 20

        let shadow = SKShapeNode(circleOfRadius: radius + 1.5)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.28)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 1.5, y: -2.5)
        shadow.zPosition = -1
        appearanceNode.addChild(shadow)

        let surface = SKShapeNode(circleOfRadius: radius)
        surface.fillColor = SKColor(calibratedWhite: 0.965, alpha: 1)
        surface.strokeColor = SKColor(calibratedWhite: 0.38, alpha: 0.9)
        surface.lineWidth = 1.15
        appearanceNode.addChild(surface)

        let coolShade = SKShapeNode(ellipseOf: CGSize(width: radius * 1.5, height: radius * 0.72))
        coolShade.fillColor = SKColor(calibratedRed: 0.69, green: 0.76, blue: 0.8, alpha: 0.2)
        coolShade.strokeColor = .clear
        coolShade.position = CGPoint(x: 2.3, y: -5)
        coolShade.zPosition = 0.2
        appearanceNode.addChild(coolShade)

        // Paired light and shade marks give the small ball readable golf-ball dimples.
        let dimplePositions = [
            CGPoint(x: -5.8, y: 1.6), CGPoint(x: -1.8, y: 5.7),
            CGPoint(x: 3.6, y: 4.1), CGPoint(x: 6.6, y: -0.5),
            CGPoint(x: 2.2, y: -4.4), CGPoint(x: -3.4, y: -5.4),
            CGPoint(x: -0.2, y: 0.4), CGPoint(x: -7.2, y: -2.7)
        ]
        for point in dimplePositions {
            let recess = SKShapeNode(circleOfRadius: 1.55)
            recess.fillColor = SKColor(calibratedWhite: 0.35, alpha: 0.23)
            recess.strokeColor = .clear
            recess.position = point
            recess.zPosition = 0.5
            appearanceNode.addChild(recess)

            let dimpleLight = SKShapeNode(circleOfRadius: 0.78)
            dimpleLight.fillColor = SKColor.white.withAlphaComponent(0.62)
            dimpleLight.strokeColor = .clear
            dimpleLight.position = CGPoint(x: point.x - 0.38, y: point.y + 0.42)
            dimpleLight.zPosition = 0.6
            appearanceNode.addChild(dimpleLight)
        }

        let highlight = SKShapeNode(ellipseOf: CGSize(width: 5.3, height: 3.2))
        highlight.fillColor = SKColor.white.withAlphaComponent(0.88)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -4.2, y: 5.5)
        highlight.zRotation = 0.42
        highlight.zPosition = 1
        appearanceNode.addChild(highlight)

        addChild(appearanceNode)

        impactHalo.path = CGPath(
            ellipseIn: CGRect(
                x: -(radius + 3),
                y: -(radius + 3),
                width: (radius + 3) * 2,
                height: (radius + 3) * 2
            ),
            transform: nil
        )
        impactHalo.fillColor = .clear
        impactHalo.strokeColor = SKColor.white.withAlphaComponent(0.72)
        impactHalo.lineWidth = 1.2
        impactHalo.alpha = 0
        impactHalo.zPosition = 2
        addChild(impactHalo)
    }

    private func configurePhysics() {
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.linearDamping = CursorGolfTuning.ballLinearDamping
        body.angularDamping = CursorGolfTuning.ballAngularDamping
        body.restitution = CursorGolfTuning.ballRestitution
        body.friction = CursorGolfTuning.ballFriction
        body.categoryBitMask = GolfPhysicsCategory.ball
        body.collisionBitMask = GolfPhysicsCategory.boundary | GolfPhysicsCategory.obstacle
        body.contactTestBitMask = GolfPhysicsCategory.boundary | GolfPhysicsCategory.obstacle
        physicsBody = body
    }
}
