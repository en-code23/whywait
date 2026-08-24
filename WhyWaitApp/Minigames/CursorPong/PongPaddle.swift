import SpriteKit

final class PongPaddle: SKNode {
    let side: PongSide
    let paddleSize: CGSize
    var verticalVelocity: CGFloat = 0

    private let appearanceNode = SKNode()
    private let impactGlow = SKShapeNode()
    private let visualEffectsReduced = WhyWaitPresentationPreferences.reduceVisualEffects

    init(side: PongSide, size: CGSize = CursorPongTuning.paddleSize) {
        self.side = side
        self.paddleSize = size
        super.init()
        configureAppearance()
        configurePhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PongPaddle does not support NSCoding")
    }

    func playImpact(strong: Bool) {
        appearanceNode.removeAction(forKey: "impact")
        impactGlow.removeAction(forKey: "impact-glow")

        let squash = SKAction.group([
            .scaleX(to: visualEffectsReduced ? 1.08 : (strong ? 1.24 : 1.15), duration: 0.04),
            .scaleY(to: visualEffectsReduced ? 0.96 : (strong ? 0.86 : 0.92), duration: 0.04)
        ])
        let settle = SKAction.group([
            .scaleX(to: 1, duration: 0.1),
            .scaleY(to: 1, duration: 0.1)
        ])
        settle.timingMode = .easeOut
        appearanceNode.run(.sequence([squash, settle]), withKey: "impact")

        impactGlow.alpha = strong ? 0.82 : 0.54
        impactGlow.setScale(0.88)
        let duration = visualEffectsReduced ? 0.08 : (strong ? 0.22 : 0.15)
        let glowEffect = SKAction.group([
            .fadeOut(withDuration: duration),
            .scaleX(to: visualEffectsReduced ? 1.05 : 1.55, duration: duration),
            .scaleY(to: visualEffectsReduced ? 1.02 : 1.12, duration: duration)
        ])
        glowEffect.timingMode = .easeOut
        impactGlow.run(glowEffect, withKey: "impact-glow")
    }

    private func configureAppearance() {
        name = side == .player ? "cursor-pong-player-paddle" : "cursor-pong-cpu-paddle"
        zPosition = 15

        let shadow = SKShapeNode(
            rectOf: CGSize(width: paddleSize.width + 4, height: paddleSize.height + 4),
            cornerRadius: (paddleSize.width + 4) / 2
        )
        shadow.fillColor = SKColor.black.withAlphaComponent(0.28)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2.2, y: -2.6)
        shadow.zPosition = -2
        appearanceNode.addChild(shadow)

        let accentColor = side == .player
            ? SKColor(calibratedRed: 0.28, green: 0.82, blue: 1, alpha: 1)
            : SKColor(calibratedRed: 1, green: 0.49, blue: 0.22, alpha: 1)
        let darkColor = side == .player
            ? SKColor(calibratedRed: 0.055, green: 0.24, blue: 0.32, alpha: 0.98)
            : SKColor(calibratedRed: 0.35, green: 0.105, blue: 0.035, alpha: 0.98)

        let chassis = SKShapeNode(rectOf: paddleSize, cornerRadius: paddleSize.width / 2)
        chassis.fillColor = darkColor
        chassis.strokeColor = SKColor.white.withAlphaComponent(0.5)
        chassis.lineWidth = 1.2
        appearanceNode.addChild(chassis)

        let faceSize = CGSize(width: paddleSize.width - 4, height: paddleSize.height - 7)
        let face = SKShapeNode(rectOf: faceSize, cornerRadius: faceSize.width / 2)
        face.fillColor = accentColor.withAlphaComponent(0.84)
        face.strokeColor = accentColor.withAlphaComponent(0.9)
        face.lineWidth = 0.8
        face.position.x = side == .player ? -0.8 : 0.8
        face.zPosition = 1
        appearanceNode.addChild(face)

        let innerEdgeX = side == .player
            ? -(paddleSize.width / 2 - 2.4)
            : paddleSize.width / 2 - 2.4
        let edge = SKShapeNode(
            rectOf: CGSize(width: 2.4, height: paddleSize.height - 14),
            cornerRadius: 1.2
        )
        edge.fillColor = SKColor.white.withAlphaComponent(0.74)
        edge.strokeColor = .clear
        edge.position.x = innerEdgeX
        edge.zPosition = 2
        appearanceNode.addChild(edge)

        let sheen = SKShapeNode(
            rectOf: CGSize(width: 2.1, height: paddleSize.height * 0.62),
            cornerRadius: 1
        )
        sheen.fillColor = SKColor.white.withAlphaComponent(0.24)
        sheen.strokeColor = .clear
        sheen.position = CGPoint(x: side == .player ? -3.6 : 3.6, y: 8)
        sheen.zPosition = 2
        appearanceNode.addChild(sheen)

        for y: CGFloat in [-24, 0, 24] {
            let gripBand = SKShapeNode(
                rectOf: CGSize(width: paddleSize.width - 8, height: 1.1),
                cornerRadius: 0.55
            )
            gripBand.fillColor = SKColor.black.withAlphaComponent(0.22)
            gripBand.strokeColor = SKColor.white.withAlphaComponent(0.12)
            gripBand.lineWidth = 0.35
            gripBand.position.y = y
            gripBand.zPosition = 2.2
            appearanceNode.addChild(gripBand)
        }

        impactGlow.path = CGPath(
            roundedRect: CGRect(
                x: -paddleSize.width / 2 - 3,
                y: -paddleSize.height / 2 - 3,
                width: paddleSize.width + 6,
                height: paddleSize.height + 6
            ),
            cornerWidth: (paddleSize.width + 6) / 2,
            cornerHeight: (paddleSize.width + 6) / 2,
            transform: nil
        )
        impactGlow.fillColor = .clear
        impactGlow.strokeColor = accentColor.withAlphaComponent(0.94)
        impactGlow.lineWidth = 2
        impactGlow.alpha = 0
        impactGlow.zPosition = 3
        appearanceNode.addChild(impactGlow)

        addChild(appearanceNode)
    }

    private func configurePhysics() {
        let body = SKPhysicsBody(rectangleOf: paddleSize)
        body.isDynamic = false
        body.affectedByGravity = false
        body.friction = 0
        body.restitution = 1
        body.categoryBitMask = side == .player
            ? PongPhysicsCategory.playerPaddle
            : PongPhysicsCategory.cpuPaddle
        body.collisionBitMask = 0
        body.contactTestBitMask = PongPhysicsCategory.ball
        physicsBody = body
    }
}
