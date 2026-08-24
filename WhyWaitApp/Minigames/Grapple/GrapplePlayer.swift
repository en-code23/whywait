import SpriteKit

final class GrapplePlayer: SKNode {
    private let appearance = SKNode()
    private let bodyAssembly = SKNode()
    private let glow = SKShapeNode(circleOfRadius: GrappleTuning.playerRadius + 5)
    private let speedLight = SKShapeNode(circleOfRadius: 2.2)
    private let reduceVisualEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        configureAppearance()
        configurePhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GrapplePlayer does not support NSCoding")
    }

    var velocity: CGVector {
        get { physicsBody?.velocity ?? .zero }
        set { physicsBody?.velocity = newValue }
    }

    var travelSpeed: CGFloat {
        GrapplePhysics.magnitude(of: velocity)
    }

    func apply(force: CGVector) {
        guard force.dx.isFinite, force.dy.isFinite else {
            return
        }
        physicsBody?.applyForce(force)
    }

    func reset(at position: CGPoint) {
        removeAction(forKey: "failure")
        self.position = position
        zRotation = 0
        alpha = 1
        setScale(1)
        appearance.setScale(1)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = true
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
    }

    func prepareForRespawn() {
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        physicsBody?.affectedByGravity = false
        physicsBody?.isDynamic = false
        removeAction(forKey: "failure")
        run(
            .sequence([
                .group([
                    .fadeAlpha(to: 0.25, duration: 0.12),
                    .scale(to: 0.72, duration: 0.12)
                ]),
                .wait(forDuration: 0.18)
            ]),
            withKey: "failure"
        )
    }

    func freezeForRoundCompletion() {
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
        physicsBody?.affectedByGravity = false
        physicsBody?.isDynamic = false
    }

    func updateAppearance() {
        let speedRatio = min(1, travelSpeed / GrappleTuning.maximumPlayerSpeed)
        let velocity = self.velocity
        if travelSpeed > 30 {
            appearance.zRotation = atan2(velocity.dy, velocity.dx) * 0.09
        }
        appearance.xScale = 1 + (speedRatio * 0.1)
        appearance.yScale = 1 - (speedRatio * 0.055)
        glow.alpha = 0.08 + (speedRatio * 0.24)
        speedLight.alpha = 0.5 + (speedRatio * 0.5)
        speedLight.glowWidth = reduceVisualEffects ? 0 : speedRatio * 2.5
    }

    func playImpact() {
        appearance.removeAction(forKey: "impact")
        appearance.run(
            .sequence([
                .group([
                    .scaleX(to: 1.16, duration: 0.035),
                    .scaleY(to: 0.84, duration: 0.035)
                ]),
                .group([
                    .scaleX(to: 1, duration: 0.1),
                    .scaleY(to: 1, duration: 0.1)
                ])
            ]),
            withKey: "impact"
        )
    }

    private func configureAppearance() {
        name = "grapple-player"
        zPosition = 60

        glow.fillColor = SKColor(calibratedRed: 0.36, green: 0.88, blue: 1, alpha: 1)
        glow.strokeColor = .clear
        glow.alpha = 0.08
        appearance.addChild(glow)

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 34, height: 28))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.28)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2.8, y: -3.6)
        shadow.zPosition = -1
        appearance.addChild(shadow)

        configureRobotBody()
        appearance.addChild(bodyAssembly)
        if !reduceVisualEffects {
            bodyAssembly.run(
                .repeatForever(
                    .sequence([
                        .moveTo(y: 0.6, duration: 0.62),
                        .moveTo(y: -0.4, duration: 0.62)
                    ])
                ),
                withKey: "idle"
            )
        }

        addChild(appearance)
    }

    private func configureRobotBody() {
        let backpack = SKShapeNode(rectOf: CGSize(width: 10, height: 22), cornerRadius: 4)
        backpack.fillColor = SKColor(calibratedWhite: 0.13, alpha: 0.98)
        backpack.strokeColor = SKColor(calibratedRed: 0.3, green: 0.72, blue: 0.85, alpha: 0.65)
        backpack.lineWidth = 1
        backpack.position = CGPoint(x: -10.5, y: -1)
        backpack.zPosition = -0.5
        bodyAssembly.addChild(backpack)

        for side in [-1, 1] as [CGFloat] {
            let arm = SKShapeNode(rectOf: CGSize(width: 6, height: 15), cornerRadius: 3)
            arm.fillColor = SKColor(calibratedWhite: 0.25, alpha: 1)
            arm.strokeColor = SKColor.white.withAlphaComponent(0.45)
            arm.lineWidth = 0.8
            arm.position = CGPoint(x: side * 13.5, y: -1)
            arm.zRotation = side * -0.13
            arm.zPosition = -0.2
            bodyAssembly.addChild(arm)

            let boot = SKShapeNode(rectOf: CGSize(width: 7, height: 7), cornerRadius: 2.4)
            boot.fillColor = SKColor(calibratedWhite: 0.12, alpha: 1)
            boot.strokeColor = SKColor.white.withAlphaComponent(0.32)
            boot.lineWidth = 0.7
            boot.position = CGPoint(x: side * 6.5, y: -15)
            boot.zRotation = side * 0.08
            bodyAssembly.addChild(boot)
        }

        let torso = SKShapeNode(rectOf: CGSize(width: 25, height: 24), cornerRadius: 7)
        torso.fillColor = SKColor(calibratedRed: 0.18, green: 0.55, blue: 0.67, alpha: 1)
        torso.strokeColor = SKColor(calibratedRed: 0.68, green: 0.94, blue: 1, alpha: 0.9)
        torso.lineWidth = 1.4
        torso.position.y = -3
        bodyAssembly.addChild(torso)

        let lowerPlate = SKShapeNode(rectOf: CGSize(width: 21, height: 7), cornerRadius: 2.5)
        lowerPlate.fillColor = SKColor(calibratedWhite: 0.13, alpha: 0.92)
        lowerPlate.strokeColor = SKColor.white.withAlphaComponent(0.2)
        lowerPlate.lineWidth = 0.7
        lowerPlate.position.y = -10.5
        bodyAssembly.addChild(lowerPlate)

        let helmetPath = CGMutablePath()
        helmetPath.move(to: CGPoint(x: -12, y: 2))
        helmetPath.addLine(to: CGPoint(x: -11, y: 8))
        helmetPath.addQuadCurve(to: CGPoint(x: 0, y: 15), control: CGPoint(x: -9, y: 15))
        helmetPath.addQuadCurve(to: CGPoint(x: 11, y: 8), control: CGPoint(x: 9, y: 15))
        helmetPath.addLine(to: CGPoint(x: 12, y: 2))
        helmetPath.closeSubpath()
        let helmet = SKShapeNode(path: helmetPath)
        helmet.fillColor = SKColor(calibratedWhite: 0.27, alpha: 1)
        helmet.strokeColor = SKColor.white.withAlphaComponent(0.72)
        helmet.lineWidth = 1.2
        bodyAssembly.addChild(helmet)

        let helmetHighlight = SKShapeNode(path: helmetPath)
        helmetHighlight.fillColor = .clear
        helmetHighlight.strokeColor = SKColor.white.withAlphaComponent(0.18)
        helmetHighlight.lineWidth = 1
        helmetHighlight.xScale = 0.83
        helmetHighlight.yScale = 0.8
        helmetHighlight.position = CGPoint(x: -1.1, y: 2)
        bodyAssembly.addChild(helmetHighlight)

        let visor = SKShapeNode(rectOf: CGSize(width: 18, height: 7.5), cornerRadius: 3.6)
        visor.fillColor = SKColor(calibratedRed: 0.055, green: 0.15, blue: 0.18, alpha: 0.98)
        visor.strokeColor = SKColor(calibratedRed: 0.38, green: 0.9, blue: 1, alpha: 0.9)
        visor.lineWidth = 1
        visor.position.y = 7.5
        bodyAssembly.addChild(visor)

        let visorGlint = SKShapeNode(rectOf: CGSize(width: 7, height: 1.2), cornerRadius: 0.6)
        visorGlint.fillColor = SKColor.white.withAlphaComponent(0.5)
        visorGlint.strokeColor = .clear
        visorGlint.position = CGPoint(x: -3.2, y: 9)
        bodyAssembly.addChild(visorGlint)

        let harnessPath = CGMutablePath()
        harnessPath.move(to: CGPoint(x: -8, y: 1))
        harnessPath.addLine(to: CGPoint(x: 7, y: -9))
        harnessPath.move(to: CGPoint(x: 8, y: 1))
        harnessPath.addLine(to: CGPoint(x: -7, y: -9))
        let harness = SKShapeNode(path: harnessPath)
        harness.strokeColor = SKColor(calibratedRed: 0.08, green: 0.23, blue: 0.27, alpha: 0.8)
        harness.lineWidth = 2
        harness.lineCap = .round
        bodyAssembly.addChild(harness)

        let port = SKShapeNode(circleOfRadius: 4.1)
        port.fillColor = SKColor(calibratedWhite: 0.1, alpha: 1)
        port.strokeColor = SKColor(calibratedRed: 0.55, green: 0.95, blue: 1, alpha: 0.85)
        port.lineWidth = 1
        port.position.y = -3
        bodyAssembly.addChild(port)

        speedLight.fillColor = SKColor(calibratedRed: 0.58, green: 1, blue: 0.88, alpha: 1)
        speedLight.strokeColor = .clear
        speedLight.position.y = -3
        bodyAssembly.addChild(speedLight)

        let antennaPath = CGMutablePath()
        antennaPath.move(to: CGPoint(x: 5, y: 14))
        antennaPath.addLine(to: CGPoint(x: 8, y: 19))
        let antenna = SKShapeNode(path: antennaPath)
        antenna.strokeColor = SKColor.white.withAlphaComponent(0.62)
        antenna.lineWidth = 1.2
        antenna.lineCap = .round
        bodyAssembly.addChild(antenna)

        let antennaTip = SKShapeNode(circleOfRadius: 1.7)
        antennaTip.fillColor = SKColor(calibratedRed: 1, green: 0.68, blue: 0.25, alpha: 1)
        antennaTip.strokeColor = .clear
        antennaTip.position = CGPoint(x: 8, y: 19)
        bodyAssembly.addChild(antennaTip)
    }

    private func configurePhysics() {
        let body = SKPhysicsBody(circleOfRadius: GrappleTuning.playerRadius)
        body.isDynamic = true
        body.affectedByGravity = true
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = true
        body.mass = GrappleTuning.playerMass
        body.linearDamping = GrappleTuning.airDamping
        body.angularDamping = 0
        body.friction = GrappleTuning.collisionFriction
        body.restitution = GrappleTuning.collisionRestitution
        body.categoryBitMask = GrapplePhysicsCategory.player
        body.collisionBitMask = GrapplePhysicsCategory.obstacle
        body.contactTestBitMask = GrapplePhysicsCategory.obstacle
            | GrapplePhysicsCategory.hazard
        physicsBody = body
    }
}
