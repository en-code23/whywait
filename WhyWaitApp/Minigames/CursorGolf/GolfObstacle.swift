import SpriteKit

enum GolfObstacleShape {
    case wall(size: CGSize)
    case bumper(radius: CGFloat)
}

struct GolfObstacleDescriptor {
    let shape: GolfObstacleShape
    let position: CGPoint
    let rotation: CGFloat

    var clearanceRadius: CGFloat {
        switch shape {
        case let .wall(size):
            return hypot(size.width, size.height) / 2
        case let .bumper(radius):
            return radius
        }
    }
}

final class GolfObstacle: SKNode {
    let descriptor: GolfObstacleDescriptor
    private let appearanceNode = SKNode()
    private let impactGlow = SKShapeNode()
    private let visualEffectsReduced = WhyWaitPresentationPreferences.reduceVisualEffects

    init(descriptor: GolfObstacleDescriptor) {
        self.descriptor = descriptor
        super.init()

        position = descriptor.position
        zRotation = descriptor.rotation
        configureAppearance()
        configurePhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GolfObstacle does not support NSCoding")
    }

    func playImpactFeedback() {
        appearanceNode.removeAction(forKey: "impact")
        impactGlow.removeAction(forKey: "impact-glow")

        let brighten = SKAction.fadeAlpha(to: 1, duration: 0.035)
        let settle = SKAction.fadeAlpha(to: 0.96, duration: 0.11)
        appearanceNode.run(.sequence([brighten, settle]), withKey: "impact")

        impactGlow.alpha = visualEffectsReduced ? 0.22 : 0.68
        impactGlow.setScale(1)
        let glow = SKAction.group([
            .fadeOut(withDuration: visualEffectsReduced ? 0.08 : 0.17),
            .scale(to: visualEffectsReduced ? 1.03 : 1.14, duration: visualEffectsReduced ? 0.08 : 0.17)
        ])
        glow.timingMode = .easeOut
        impactGlow.run(glow, withKey: "impact-glow")
    }

    private func configureAppearance() {
        name = "cursor-golf-obstacle"
        zPosition = 8
        appearanceNode.alpha = 0.96
        addChild(appearanceNode)

        switch descriptor.shape {
        case let .wall(size):
            let shadow = SKShapeNode(
                rectOf: CGSize(width: size.width + 4, height: size.height + 5),
                cornerRadius: 5
            )
            shadow.fillColor = SKColor.black.withAlphaComponent(0.24)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 2.5, y: -3.5)
            shadow.zPosition = -2
            appearanceNode.addChild(shadow)

            let sideFace = SKShapeNode(
                rectOf: CGSize(width: size.width, height: size.height + 3),
                cornerRadius: 4
            )
            sideFace.fillColor = SKColor(calibratedRed: 0.075, green: 0.15, blue: 0.19, alpha: 0.95)
            sideFace.strokeColor = .clear
            sideFace.position.y = -2.2
            sideFace.zPosition = -1
            appearanceNode.addChild(sideFace)

            let wall = SKShapeNode(rectOf: size, cornerRadius: 4)
            wall.fillColor = SKColor(calibratedRed: 0.16, green: 0.34, blue: 0.43, alpha: 0.96)
            wall.strokeColor = SKColor(calibratedRed: 0.6, green: 0.82, blue: 0.86, alpha: 0.8)
            wall.lineWidth = 1.05
            appearanceNode.addChild(wall)

            let railHighlight = SKShapeNode(
                rectOf: CGSize(width: max(12, size.width - 14), height: max(1.2, size.height * 0.16)),
                cornerRadius: 1
            )
            railHighlight.fillColor = SKColor.white.withAlphaComponent(0.34)
            railHighlight.strokeColor = .clear
            railHighlight.position.y = max(1, size.height * 0.21)
            railHighlight.zPosition = 1
            appearanceNode.addChild(railHighlight)

            for side: CGFloat in [-1, 1] {
                let cap = SKShapeNode(
                    rectOf: CGSize(width: 4.5, height: max(4, size.height - 4)),
                    cornerRadius: 1.8
                )
                cap.fillColor = SKColor(calibratedWhite: 0.75, alpha: 0.32)
                cap.strokeColor = .clear
                cap.position.x = side * (size.width / 2 - 5)
                cap.zPosition = 1.2
                appearanceNode.addChild(cap)

                let fastener = SKShapeNode(circleOfRadius: 1.25)
                fastener.fillColor = SKColor(calibratedWhite: 0.12, alpha: 0.78)
                fastener.strokeColor = SKColor.white.withAlphaComponent(0.4)
                fastener.lineWidth = 0.45
                fastener.position.x = side * (size.width / 2 - 7)
                fastener.zPosition = 2
                appearanceNode.addChild(fastener)
            }

            impactGlow.path = CGPath(
                roundedRect: CGRect(
                    x: -size.width / 2 - 2,
                    y: -size.height / 2 - 2,
                    width: size.width + 4,
                    height: size.height + 4
                ),
                cornerWidth: 5,
                cornerHeight: 5,
                transform: nil
            )

        case let .bumper(radius):
            let shadow = SKShapeNode(circleOfRadius: radius + 2)
            shadow.fillColor = SKColor.black.withAlphaComponent(0.25)
            shadow.strokeColor = .clear
            shadow.position = CGPoint(x: 2.5, y: -3.2)
            shadow.zPosition = -1
            appearanceNode.addChild(shadow)

            let base = SKShapeNode(circleOfRadius: radius + 1)
            base.fillColor = SKColor(calibratedRed: 0.35, green: 0.08, blue: 0.04, alpha: 0.96)
            base.strokeColor = SKColor.black.withAlphaComponent(0.52)
            base.lineWidth = 1.2
            appearanceNode.addChild(base)

            let bumper = SKShapeNode(circleOfRadius: radius)
            bumper.fillColor = SKColor(calibratedRed: 0.96, green: 0.31, blue: 0.12, alpha: 0.98)
            bumper.strokeColor = SKColor(calibratedRed: 1, green: 0.73, blue: 0.42, alpha: 0.92)
            bumper.lineWidth = 1.6
            appearanceNode.addChild(bumper)

            let innerRing = SKShapeNode(circleOfRadius: radius * 0.7)
            innerRing.fillColor = SKColor(calibratedRed: 0.72, green: 0.13, blue: 0.05, alpha: 0.48)
            innerRing.strokeColor = SKColor.white.withAlphaComponent(0.24)
            innerRing.lineWidth = 1
            innerRing.position.y = -0.7
            appearanceNode.addChild(innerRing)

            let dome = SKShapeNode(ellipseOf: CGSize(width: radius * 1.08, height: radius * 0.58))
            dome.fillColor = SKColor(calibratedRed: 1, green: 0.59, blue: 0.26, alpha: 0.78)
            dome.strokeColor = .clear
            dome.position = CGPoint(x: -radius * 0.12, y: radius * 0.26)
            appearanceNode.addChild(dome)

            let center = SKShapeNode(circleOfRadius: max(3, radius * 0.2))
            center.fillColor = SKColor(calibratedWhite: 0.93, alpha: 0.82)
            center.strokeColor = SKColor(calibratedRed: 0.4, green: 0.08, blue: 0.03, alpha: 0.55)
            center.lineWidth = 0.8
            appearanceNode.addChild(center)

            let glint = SKShapeNode(ellipseOf: CGSize(width: radius * 0.42, height: radius * 0.2))
            glint.fillColor = SKColor.white.withAlphaComponent(0.58)
            glint.strokeColor = .clear
            glint.position = CGPoint(x: -radius * 0.3, y: radius * 0.5)
            glint.zRotation = 0.45
            appearanceNode.addChild(glint)

            impactGlow.path = CGPath(
                ellipseIn: CGRect(
                    x: -radius - 3,
                    y: -radius - 3,
                    width: (radius + 3) * 2,
                    height: (radius + 3) * 2
                ),
                transform: nil
            )
        }

        impactGlow.fillColor = .clear
        impactGlow.strokeColor = SKColor.white.withAlphaComponent(0.9)
        impactGlow.lineWidth = 1.5
        impactGlow.alpha = 0
        impactGlow.zPosition = 4
        appearanceNode.addChild(impactGlow)
    }

    private func configurePhysics() {
        let body: SKPhysicsBody

        switch descriptor.shape {
        case let .wall(size):
            body = SKPhysicsBody(rectangleOf: size)
        case let .bumper(radius):
            body = SKPhysicsBody(circleOfRadius: radius)
        }

        body.isDynamic = false
        body.affectedByGravity = false
        body.friction = 0.18
        body.restitution = CursorGolfTuning.obstacleRestitution
        body.categoryBitMask = GolfPhysicsCategory.obstacle
        body.collisionBitMask = GolfPhysicsCategory.ball
        body.contactTestBitMask = GolfPhysicsCategory.ball
        physicsBody = body
    }
}
