import SpriteKit

final class BombNode: SKNode {
    private static let reduceVisualEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    let collisionRadius: CGFloat = 28
    private(set) var hasTriggered = false

    init(velocity: CGVector, angularVelocity: CGFloat) {
        super.init()
        configureAppearance()
        configurePhysics(velocity: velocity, angularVelocity: angularVelocity)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("BombNode does not support NSCoding")
    }

    func trigger() -> Bool {
        guard !hasTriggered else {
            return false
        }

        hasTriggered = true
        return true
    }

    private func configureAppearance() {
        name = "fruit-slice-bomb"
        zPosition = 32

        let shadow = SKShapeNode(circleOfRadius: collisionRadius)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.24)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2.5, y: -3)
        shadow.zPosition = -1
        addChild(shadow)

        let body = SKShapeNode(circleOfRadius: collisionRadius)
        body.fillColor = SKColor(calibratedWhite: 0.075, alpha: 0.98)
        body.strokeColor = SKColor(calibratedWhite: 0.32, alpha: 0.92)
        body.lineWidth = 1.8
        addChild(body)

        let lowerShade = SKShapeNode(ellipseOf: CGSize(width: 47, height: 20))
        lowerShade.fillColor = SKColor.black.withAlphaComponent(0.32)
        lowerShade.strokeColor = .clear
        lowerShade.position = CGPoint(x: 3, y: -13)
        lowerShade.zRotation = -0.1
        addChild(lowerShade)

        let seam = SKShapeNode(circleOfRadius: collisionRadius - 4)
        seam.fillColor = .clear
        seam.strokeColor = SKColor.white.withAlphaComponent(0.1)
        seam.lineWidth = 1
        addChild(seam)

        let highlight = SKShapeNode(ellipseOf: CGSize(width: 12, height: 7))
        highlight.fillColor = SKColor.white.withAlphaComponent(0.2)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -8, y: 10)
        highlight.zRotation = -0.5
        addChild(highlight)

        let collar = SKShapeNode(rectOf: CGSize(width: 16, height: 8), cornerRadius: 2.5)
        collar.fillColor = SKColor(calibratedWhite: 0.18, alpha: 1)
        collar.strokeColor = SKColor(calibratedWhite: 0.48, alpha: 0.9)
        collar.lineWidth = 1
        collar.position = CGPoint(x: 8, y: 24)
        collar.zRotation = -0.42
        addChild(collar)

        let fusePath = CGMutablePath()
        fusePath.move(to: CGPoint(x: 10, y: 27))
        fusePath.addCurve(
            to: CGPoint(x: 21, y: 39),
            control1: CGPoint(x: 12, y: 35),
            control2: CGPoint(x: 21, y: 29)
        )
        let fuseShadow = SKShapeNode(path: fusePath)
        fuseShadow.strokeColor = SKColor.black.withAlphaComponent(0.55)
        fuseShadow.lineWidth = 6
        fuseShadow.lineCap = .round
        fuseShadow.zPosition = -0.2
        addChild(fuseShadow)

        let fuse = SKShapeNode(path: fusePath)
        fuse.strokeColor = SKColor(calibratedRed: 0.66, green: 0.45, blue: 0.22, alpha: 1)
        fuse.lineWidth = 3.5
        fuse.lineCap = .round
        addChild(fuse)

        let sparkAssembly = makeSparkAssembly()
        sparkAssembly.position = CGPoint(x: 21, y: 39)
        if !Self.reduceVisualEffects {
            sparkAssembly.run(.repeatForever(.rotate(byAngle: .pi, duration: 0.24)))
        }
        addChild(sparkAssembly)
    }

    private func makeSparkAssembly() -> SKNode {
        let assembly = SKNode()
        let ember = SKShapeNode(circleOfRadius: 3.5)
        ember.fillColor = SKColor(calibratedRed: 1, green: 0.69, blue: 0.1, alpha: 1)
        ember.strokeColor = SKColor.white.withAlphaComponent(0.82)
        ember.lineWidth = 0.8
        assembly.addChild(ember)

        for index in 0..<6 {
            let angle = CGFloat(index) * (.pi / 3)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: cos(angle) * 5, y: sin(angle) * 5))
            path.addLine(to: CGPoint(x: cos(angle) * 9, y: sin(angle) * 9))
            let ray = SKShapeNode(path: path)
            ray.strokeColor = index.isMultiple(of: 2)
                ? SKColor(calibratedRed: 1, green: 0.88, blue: 0.3, alpha: 0.9)
                : SKColor(calibratedRed: 1, green: 0.36, blue: 0.12, alpha: 0.82)
            ray.lineWidth = 1.4
            ray.lineCap = .round
            assembly.addChild(ray)
        }
        if !Self.reduceVisualEffects {
            ember.run(
                .repeatForever(
                    .sequence([
                        .scale(to: 1.18, duration: 0.12),
                        .scale(to: 0.8, duration: 0.12)
                    ])
                )
            )
        }
        return assembly
    }

    private func configurePhysics(velocity: CGVector, angularVelocity: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: collisionRadius * 0.92)
        body.isDynamic = true
        body.affectedByGravity = true
        body.allowsRotation = true
        body.linearDamping = 0.015
        body.angularDamping = 0.025
        body.categoryBitMask = FruitSlicePhysicsCategory.bomb
        body.collisionBitMask = 0
        body.contactTestBitMask = 0
        body.velocity = velocity
        body.angularVelocity = angularVelocity
        physicsBody = body
    }
}
