import SpriteKit

final class GrappleHazard: SKNode {
    let descriptor: GrappleHazardDescriptor
    private let reduceVisualEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    init(descriptor: GrappleHazardDescriptor) {
        self.descriptor = descriptor
        super.init()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GrappleHazard does not support NSCoding")
    }

    func sweptContact(from start: CGPoint, to end: CGPoint) -> Bool {
        switch descriptor.shape {
        case let .orb(radius):
            GrapplePhysics.segmentIntersectsCircle(
                from: start,
                to: end,
                center: descriptor.center,
                radius: radius + GrappleTuning.playerRadius
            )
        case .block, .spikes:
            GrapplePhysics.segmentIntersectsRect(
                from: start,
                to: end,
                rect: descriptor.boundingFrame,
                padding: GrappleTuning.playerRadius
            )
        }
    }

    private func configure() {
        name = "grapple-hazard"
        position = descriptor.center
        zPosition = 22

        switch descriptor.shape {
        case let .orb(radius):
            configureOrb(radius: radius)
            physicsBody = SKPhysicsBody(circleOfRadius: radius)
        case let .block(size):
            configureBlock(size: size)
            physicsBody = SKPhysicsBody(rectangleOf: size)
        case let .spikes(size):
            configureSpikes(size: size)
            physicsBody = SKPhysicsBody(rectangleOf: size)
        }

        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = GrapplePhysicsCategory.hazard
        physicsBody?.collisionBitMask = 0
        physicsBody?.contactTestBitMask = GrapplePhysicsCategory.player
    }

    private func configureOrb(radius: CGFloat) {
        let glow = SKShapeNode(circleOfRadius: radius + 5)
        glow.fillColor = SKColor(calibratedRed: 1, green: 0.18, blue: 0.16, alpha: 0.13)
        glow.strokeColor = .clear
        addChild(glow)

        let outerRing = SKShapeNode(circleOfRadius: radius + 1)
        outerRing.fillColor = .clear
        outerRing.strokeColor = SKColor(calibratedRed: 1, green: 0.2, blue: 0.18, alpha: 0.45)
        outerRing.lineWidth = 1
        outerRing.path = makeOrbRingPath(radius: radius + 2)
        if !reduceVisualEffects {
            outerRing.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3.4)))
        }
        addChild(outerRing)

        let orb = SKShapeNode(circleOfRadius: radius)
        orb.fillColor = SKColor(calibratedRed: 0.42, green: 0.035, blue: 0.055, alpha: 0.94)
        orb.strokeColor = SKColor(calibratedRed: 1, green: 0.3, blue: 0.22, alpha: 0.96)
        orb.lineWidth = 2
        addChild(orb)

        let iris = SKShapeNode(circleOfRadius: radius * 0.55)
        iris.fillColor = SKColor(calibratedRed: 0.12, green: 0.025, blue: 0.035, alpha: 0.82)
        iris.strokeColor = SKColor(calibratedRed: 0.9, green: 0.16, blue: 0.12, alpha: 0.7)
        iris.lineWidth = 1
        addChild(iris)

        let center = SKShapeNode(circleOfRadius: max(3, radius * 0.2))
        center.fillColor = SKColor(calibratedRed: 1, green: 0.55, blue: 0.18, alpha: 0.9)
        center.strokeColor = .clear
        addChild(center)

        let glint = SKShapeNode(ellipseOf: CGSize(width: radius * 0.55, height: radius * 0.2))
        glint.fillColor = SKColor.white.withAlphaComponent(0.22)
        glint.strokeColor = .clear
        glint.position = CGPoint(x: -radius * 0.26, y: radius * 0.34)
        glint.zRotation = -0.55
        addChild(glint)
    }

    private func configureBlock(size: CGSize) {
        let shadow = SKShapeNode(rectOf: size, cornerRadius: 5)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.26)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2.5, y: -2.5)
        shadow.zPosition = -1
        addChild(shadow)

        let block = SKShapeNode(rectOf: size, cornerRadius: 5)
        block.fillColor = SKColor(calibratedRed: 0.34, green: 0.035, blue: 0.05, alpha: 0.93)
        block.strokeColor = SKColor(calibratedRed: 1, green: 0.28, blue: 0.2, alpha: 0.94)
        block.lineWidth = 2
        addChild(block)

        let inset = SKShapeNode(
            rectOf: CGSize(width: max(4, size.width - 8), height: max(4, size.height - 8)),
            cornerRadius: 3
        )
        inset.fillColor = .clear
        inset.strokeColor = SKColor.white.withAlphaComponent(0.12)
        inset.lineWidth = 0.8
        addChild(inset)

        let stripeWidth = min(10, size.width / 5)
        let availableHalfWidth = max(0, size.width / 2 - 8)
        var x = -availableHalfWidth
        while x <= availableHalfWidth {
            let stripe = SKShapeNode(rectOf: CGSize(width: stripeWidth, height: 3), cornerRadius: 1.5)
            stripe.fillColor = SKColor(calibratedRed: 1, green: 0.44, blue: 0.16, alpha: 0.42)
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: x, y: -size.height / 2 + 5)
            addChild(stripe)
            x += stripeWidth * 1.8
        }

        let warning = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        warning.text = "!"
        warning.fontSize = min(18, size.height * 0.65)
        warning.fontColor = SKColor(calibratedRed: 1, green: 0.7, blue: 0.2, alpha: 0.94)
        warning.horizontalAlignmentMode = .center
        warning.verticalAlignmentMode = .center
        addChild(warning)
    }

    private func configureSpikes(size: CGSize) {
        let spikeCount = max(3, Int(size.width / 18))
        let spikeWidth = size.width / CGFloat(spikeCount)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size.width / 2, y: -size.height / 2))
        for index in 0..<spikeCount {
            let left = -size.width / 2 + (CGFloat(index) * spikeWidth)
            path.addLine(to: CGPoint(x: left + (spikeWidth / 2), y: size.height / 2))
            path.addLine(to: CGPoint(x: left + spikeWidth, y: -size.height / 2))
        }
        path.closeSubpath()

        let spikes = SKShapeNode(path: path)
        spikes.fillColor = SKColor(calibratedRed: 0.65, green: 0.06, blue: 0.08, alpha: 0.9)
        spikes.strokeColor = SKColor(calibratedRed: 1, green: 0.3, blue: 0.22, alpha: 0.96)
        spikes.lineWidth = 1.5
        addChild(spikes)

        let base = SKShapeNode(rectOf: CGSize(width: size.width + 4, height: 6), cornerRadius: 2)
        base.fillColor = SKColor(calibratedRed: 0.28, green: 0.03, blue: 0.045, alpha: 0.96)
        base.strokeColor = SKColor(calibratedRed: 1, green: 0.24, blue: 0.18, alpha: 0.7)
        base.lineWidth = 1
        base.position.y = -size.height / 2 + 1
        addChild(base)

        for index in 0..<spikeCount {
            let highlight = SKShapeNode(circleOfRadius: 1.3)
            highlight.fillColor = SKColor(calibratedRed: 1, green: 0.62, blue: 0.24, alpha: 0.8)
            highlight.strokeColor = .clear
            highlight.position = CGPoint(
                x: -size.width / 2 + (CGFloat(index) + 0.5) * spikeWidth,
                y: size.height / 2 - 2
            )
            addChild(highlight)
        }
    }

    private func makeOrbRingPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for angle in stride(from: CGFloat(0), to: .pi * 2, by: .pi / 3) {
            let start = angle - 0.28
            let end = angle + 0.28
            path.addArc(center: .zero, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        }
        return path
    }
}
