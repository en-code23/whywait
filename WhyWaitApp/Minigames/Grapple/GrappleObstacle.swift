import SpriteKit

final class GrappleObstacle: SKNode {
    let descriptor: GrappleObstacleDescriptor
    private(set) var isActiveLaunchPlatform = false

    init(descriptor: GrappleObstacleDescriptor) {
        self.descriptor = descriptor
        super.init()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GrappleObstacle does not support NSCoding")
    }

    /// The launch perch is a staging surface rather than a bank-shot obstacle.
    /// Removing bounce here keeps the player available for the first grapple
    /// without changing collision behavior elsewhere in the course.
    func configureAsLaunchPlatform() {
        physicsBody?.restitution = 0
        physicsBody?.friction = 0.55
        setLaunchPlatformActive(true)
    }

    func setLaunchPlatformActive(_ isActive: Bool) {
        removeAction(forKey: "launch-platform-visibility")
        isActiveLaunchPlatform = isActive
        if isActive {
            isHidden = false
            alpha = 1
            physicsBody?.categoryBitMask = GrapplePhysicsCategory.obstacle
            physicsBody?.collisionBitMask = GrapplePhysicsCategory.player
            physicsBody?.contactTestBitMask = GrapplePhysicsCategory.player
        } else {
            physicsBody?.categoryBitMask = 0
            physicsBody?.collisionBitMask = 0
            physicsBody?.contactTestBitMask = 0
            run(
                .sequence([
                    .fadeOut(withDuration: 0.12),
                    .hide()
                ]),
                withKey: "launch-platform-visibility"
            )
        }
    }

    private func configure() {
        name = "grapple-obstacle"
        position = descriptor.center
        zRotation = descriptor.rotation
        zPosition = 18

        let shadow = SKShapeNode(
            rectOf: descriptor.size,
            cornerRadius: min(7, descriptor.size.height * 0.28)
        )
        shadow.fillColor = SKColor.black.withAlphaComponent(0.24)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -2.5)
        shadow.zPosition = -1
        addChild(shadow)

        let surface = SKShapeNode(
            rectOf: descriptor.size,
            cornerRadius: min(7, descriptor.size.height * 0.28)
        )
        surface.fillColor = SKColor(calibratedWhite: 0.21, alpha: 0.9)
        surface.strokeColor = SKColor(calibratedRed: 0.66, green: 0.8, blue: 0.85, alpha: 0.66)
        surface.lineWidth = 1.2
        addChild(surface)

        let insetSize = CGSize(
            width: max(3, descriptor.size.width - 7),
            height: max(3, descriptor.size.height - 7)
        )
        let inset = SKShapeNode(
            rectOf: insetSize,
            cornerRadius: min(5, insetSize.height * 0.24)
        )
        inset.fillColor = SKColor(calibratedWhite: 0.3, alpha: 0.18)
        inset.strokeColor = SKColor.white.withAlphaComponent(0.16)
        inset.lineWidth = 0.8
        addChild(inset)

        let highlight = SKShapeNode(
            rectOf: CGSize(width: max(2, descriptor.size.width - 11), height: 1.2),
            cornerRadius: 0.6
        )
        highlight.fillColor = SKColor.white.withAlphaComponent(0.28)
        highlight.strokeColor = .clear
        highlight.position.y = descriptor.size.height / 2 - 4
        addChild(highlight)

        let rivetInset = min(8, descriptor.size.width * 0.15)
        for x in [-descriptor.size.width / 2 + rivetInset, descriptor.size.width / 2 - rivetInset] {
            for y in [-descriptor.size.height / 2 + 4, descriptor.size.height / 2 - 4] {
                let rivet = SKShapeNode(circleOfRadius: 1.5)
                rivet.fillColor = SKColor(calibratedWhite: 0.12, alpha: 0.9)
                rivet.strokeColor = SKColor.white.withAlphaComponent(0.32)
                rivet.lineWidth = 0.5
                rivet.position = CGPoint(x: x, y: y)
                addChild(rivet)
            }
        }

        let body = SKPhysicsBody(rectangleOf: descriptor.size)
        body.isDynamic = false
        body.friction = GrappleTuning.collisionFriction
        body.restitution = GrappleTuning.collisionRestitution
        body.categoryBitMask = GrapplePhysicsCategory.obstacle
        body.collisionBitMask = GrapplePhysicsCategory.player
        body.contactTestBitMask = GrapplePhysicsCategory.player
        physicsBody = body
    }
}
