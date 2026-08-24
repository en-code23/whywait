import SpriteKit

private enum FruitLifecycle {
    case active
    case sliced
    case missed
}

private enum FruitArtwork {
    static func bodyPath(for type: FruitType) -> CGPath {
        let size = type.bodySize
        switch type.shapeArchetype {
        case .lobed:
            let width = size.width / 2
            let height = size.height / 2
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: height * 0.72))
            path.addCurve(
                to: CGPoint(x: -width, y: height * 0.2),
                control1: CGPoint(x: -width * 0.18, y: height * 1.02),
                control2: CGPoint(x: -width * 0.88, y: height * 0.88)
            )
            path.addCurve(
                to: CGPoint(x: -width * 0.48, y: -height * 0.78),
                control1: CGPoint(x: -width * 1.02, y: -height * 0.2),
                control2: CGPoint(x: -width * 0.82, y: -height * 0.73)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: -height * 0.9),
                control1: CGPoint(x: -width * 0.32, y: -height * 0.96),
                control2: CGPoint(x: -width * 0.12, y: -height * 0.82)
            )
            path.addCurve(
                to: CGPoint(x: width * 0.52, y: -height * 0.78),
                control1: CGPoint(x: width * 0.13, y: -height * 0.82),
                control2: CGPoint(x: width * 0.32, y: -height * 0.96)
            )
            path.addCurve(
                to: CGPoint(x: width, y: height * 0.2),
                control1: CGPoint(x: width * 0.84, y: -height * 0.7),
                control2: CGPoint(x: width * 1.03, y: -height * 0.18)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: height * 0.72),
                control1: CGPoint(x: width * 0.87, y: height * 0.88),
                control2: CGPoint(x: width * 0.18, y: height * 1.02)
            )
            path.closeSubpath()
            return path
        case .citrus:
            let width = size.width / 2
            let height = size.height / 2
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -width, y: 0))
            path.addCurve(
                to: CGPoint(x: 0, y: height),
                control1: CGPoint(x: -width * 0.72, y: height * 0.08),
                control2: CGPoint(x: -width * 0.55, y: height)
            )
            path.addCurve(
                to: CGPoint(x: width, y: 0),
                control1: CGPoint(x: width * 0.55, y: height),
                control2: CGPoint(x: width * 0.72, y: height * 0.08)
            )
            path.addCurve(
                to: CGPoint(x: 0, y: -height),
                control1: CGPoint(x: width * 0.72, y: -height * 0.08),
                control2: CGPoint(x: width * 0.55, y: -height)
            )
            path.addCurve(
                to: CGPoint(x: -width, y: 0),
                control1: CGPoint(x: -width * 0.55, y: -height),
                control2: CGPoint(x: -width * 0.72, y: -height * 0.08)
            )
            path.closeSubpath()
            return path
        case .round, .oblong, .fuzzy:
            return CGPath(
                ellipseIn: CGRect(
                    x: -size.width / 2,
                    y: -size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                transform: nil
            )
        }
    }

    static func halfPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -radius))
        path.addArc(
            center: .zero,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: .pi / 2,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }

    static func leafPath(size: CGSize) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size.width / 2, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: size.width / 2, y: 0),
            control: CGPoint(x: 0, y: size.height / 2)
        )
        path.addQuadCurve(
            to: CGPoint(x: -size.width / 2, y: 0),
            control: CGPoint(x: 0, y: -size.height / 2)
        )
        path.closeSubpath()
        return path
    }
}

final class FruitNode: SKNode {
    let fruitType: FruitType
    let collisionRadius: CGFloat

    private var lifecycle: FruitLifecycle = .active

    init(type: FruitType, velocity: CGVector, angularVelocity: CGFloat) {
        fruitType = type
        collisionRadius = type.radius
        super.init()
        configureAppearance()
        configurePhysics(velocity: velocity, angularVelocity: angularVelocity)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FruitNode does not support NSCoding")
    }

    var launchVelocity: CGVector {
        physicsBody?.velocity ?? .zero
    }

    func markSliced() -> Bool {
        guard lifecycle == .active else {
            return false
        }
        lifecycle = .sliced
        return true
    }

    func markMissed() -> Bool {
        guard lifecycle == .active else {
            return false
        }
        lifecycle = .missed
        return true
    }

    private func configureAppearance() {
        name = "fruit-slice-fruit"
        zPosition = 30

        let bodyPath = FruitArtwork.bodyPath(for: fruitType)
        let shadow = SKShapeNode(path: bodyPath)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 3, y: -3.5)
        shadow.zPosition = -2
        addChild(shadow)

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = fruitType.primaryColor
        body.strokeColor = fruitType.accentColor.withAlphaComponent(0.92)
        body.lineWidth = 1.8
        addChild(body)

        let rim = SKShapeNode(path: bodyPath)
        rim.fillColor = .clear
        rim.strokeColor = SKColor.white.withAlphaComponent(0.28)
        rim.lineWidth = 1
        rim.xScale = 0.93
        rim.yScale = 0.93
        rim.position = CGPoint(x: -0.8, y: 1)
        addChild(rim)

        addFruitDetails()
        addHighlight()
    }

    private func addFruitDetails() {
        switch fruitType {
        case .apple:
            addStem(at: CGPoint(x: 1, y: collisionRadius * 0.84), rotation: -0.16)
            addLeaf(
                at: CGPoint(x: 8, y: collisionRadius * 0.94),
                size: CGSize(width: 15, height: 8),
                rotation: 0.42
            )
            let cleft = SKShapeNode(circleOfRadius: 3.4)
            cleft.fillColor = fruitType.accentColor.withAlphaComponent(0.42)
            cleft.strokeColor = .clear
            cleft.position = CGPoint(x: 0, y: collisionRadius * 0.7)
            cleft.yScale = 0.45
            addChild(cleft)
        case .orange:
            let navel = SKShapeNode(circleOfRadius: 2.6)
            navel.fillColor = fruitType.accentColor.withAlphaComponent(0.7)
            navel.strokeColor = SKColor.white.withAlphaComponent(0.18)
            navel.lineWidth = 0.6
            navel.position = CGPoint(x: 0, y: collisionRadius * 0.77)
            addChild(navel)
            for index in 0..<12 {
                let angle = CGFloat(index) * (.pi * 2 / 12) + 0.23
                let distance = CGFloat(index.isMultiple(of: 3) ? 13 : 17)
                let pore = SKShapeNode(circleOfRadius: index.isMultiple(of: 2) ? 0.9 : 0.65)
                pore.fillColor = fruitType.accentColor.withAlphaComponent(0.5)
                pore.strokeColor = .clear
                pore.position = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
                addChild(pore)
            }
        case .watermelon:
            for offset in [-16, -8, 0, 8, 16] as [CGFloat] {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: offset * 0.78, y: -collisionRadius * 0.8))
                path.addCurve(
                    to: CGPoint(x: offset * 0.78, y: collisionRadius * 0.8),
                    control1: CGPoint(x: offset * 1.13, y: -collisionRadius * 0.3),
                    control2: CGPoint(x: offset * 0.48, y: collisionRadius * 0.3)
                )
                let stripe = SKShapeNode(path: path)
                stripe.strokeColor = fruitType.accentColor.withAlphaComponent(
                    offset == 0 ? 0.72 : 0.56
                )
                stripe.lineWidth = offset == 0 ? 3.2 : 2.3
                stripe.lineCap = .round
                addChild(stripe)
            }
        case .lemon:
            for x in [-21, 21] as [CGFloat] {
                let nub = SKShapeNode(circleOfRadius: 2.3)
                nub.fillColor = fruitType.accentColor.withAlphaComponent(0.7)
                nub.strokeColor = .clear
                nub.position.x = x
                nub.xScale = 1.35
                addChild(nub)
            }
            for index in 0..<7 {
                let angle = CGFloat(index) * (.pi * 2 / 7)
                let pore = SKShapeNode(circleOfRadius: 0.7)
                pore.fillColor = fruitType.accentColor.withAlphaComponent(0.45)
                pore.strokeColor = .clear
                pore.position = CGPoint(x: cos(angle) * 14, y: sin(angle) * 8)
                addChild(pore)
            }
        case .kiwi:
            for index in 0..<18 {
                let angle = CGFloat(index) * (.pi * 2 / 18) + 0.17
                let distance = CGFloat(7 + ((index * 7) % 13))
                let fleck = SKShapeNode(circleOfRadius: index.isMultiple(of: 3) ? 0.8 : 0.55)
                fleck.fillColor = SKColor(
                    calibratedRed: 0.9,
                    green: 0.7,
                    blue: 0.42,
                    alpha: 0.45
                )
                fleck.strokeColor = .clear
                fleck.position = CGPoint(
                    x: cos(angle) * distance * 0.78,
                    y: sin(angle) * distance
                )
                addChild(fleck)
            }
            let crown = SKShapeNode(circleOfRadius: 3.2)
            crown.fillColor = fruitType.accentColor.withAlphaComponent(0.9)
            crown.strokeColor = .clear
            crown.position.y = collisionRadius * 0.82
            crown.yScale = 0.45
            addChild(crown)
        }
    }

    private func addHighlight() {
        let highlightSize: CGSize
        let highlightPosition: CGPoint
        switch fruitType {
        case .watermelon:
            highlightSize = CGSize(width: 9, height: 26)
            highlightPosition = CGPoint(x: -12, y: 10)
        case .lemon:
            highlightSize = CGSize(width: 23, height: 7)
            highlightPosition = CGPoint(x: -6, y: 7)
        default:
            highlightSize = CGSize(width: 10, height: 19)
            highlightPosition = CGPoint(x: -10, y: 10)
        }
        let highlight = SKShapeNode(ellipseOf: highlightSize)
        highlight.fillColor = SKColor.white.withAlphaComponent(0.24)
        highlight.strokeColor = .clear
        highlight.position = highlightPosition
        highlight.zRotation = fruitType == .lemon ? 0.18 : -0.42
        addChild(highlight)

        let glint = SKShapeNode(circleOfRadius: 1.5)
        glint.fillColor = SKColor.white.withAlphaComponent(0.58)
        glint.strokeColor = .clear
        glint.position = CGPoint(x: highlightPosition.x - 1.5, y: highlightPosition.y + 7)
        addChild(glint)
    }

    private func addStem(at position: CGPoint, rotation: CGFloat) {
        let stem = SKShapeNode(rectOf: CGSize(width: 3.2, height: 11), cornerRadius: 1.5)
        stem.fillColor = SKColor(calibratedRed: 0.27, green: 0.15, blue: 0.07, alpha: 1)
        stem.strokeColor = SKColor.white.withAlphaComponent(0.16)
        stem.lineWidth = 0.6
        stem.position = position
        stem.zRotation = rotation
        addChild(stem)
    }

    private func addLeaf(at position: CGPoint, size: CGSize, rotation: CGFloat) {
        let leaf = SKShapeNode(path: FruitArtwork.leafPath(size: size))
        leaf.fillColor = fruitType.accentColor
        leaf.strokeColor = SKColor.white.withAlphaComponent(0.24)
        leaf.lineWidth = 0.7
        leaf.position = position
        leaf.zRotation = rotation
        addChild(leaf)
    }

    private func configurePhysics(velocity: CGVector, angularVelocity: CGFloat) {
        let body = SKPhysicsBody(circleOfRadius: collisionRadius * 0.9)
        body.isDynamic = true
        body.affectedByGravity = true
        body.allowsRotation = true
        body.linearDamping = 0.015
        body.angularDamping = 0.02
        body.friction = 0
        body.restitution = 0
        body.categoryBitMask = FruitSlicePhysicsCategory.fruit
        body.collisionBitMask = 0
        body.contactTestBitMask = 0
        body.velocity = velocity
        body.angularVelocity = angularVelocity
        physicsBody = body
    }
}

final class FruitHalfNode: SKNode {
    let cleanupRadius: CGFloat

    init(
        type: FruitType,
        halfSign: CGFloat,
        cutAngle: CGFloat,
        velocity: CGVector,
        angularVelocity: CGFloat
    ) {
        cleanupRadius = type.radius
        super.init()
        configureAppearance(type: type, halfSign: halfSign, cutAngle: cutAngle)
        configurePhysics(
            radius: type.radius,
            velocity: velocity,
            angularVelocity: angularVelocity
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FruitHalfNode does not support NSCoding")
    }

    private func configureAppearance(type: FruitType, halfSign: CGFloat, cutAngle: CGFloat) {
        name = "fruit-slice-half"
        zPosition = 28
        zRotation = cutAngle - (.pi / 2)

        let content = SKNode()
        content.xScale = halfSign
        addChild(content)

        let shadow = SKShapeNode(path: FruitArtwork.halfPath(radius: type.radius + 1))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2.5, y: -2.5)
        shadow.zPosition = -2
        content.addChild(shadow)

        let peel = SKShapeNode(path: FruitArtwork.halfPath(radius: type.radius))
        peel.fillColor = type.primaryColor
        peel.strokeColor = type.accentColor.withAlphaComponent(0.92)
        peel.lineWidth = 1.5
        content.addChild(peel)

        let inset: CGFloat = type == .watermelon ? 6 : (type == .kiwi ? 4.5 : 3)
        if type == .watermelon {
            let rind = SKShapeNode(path: FruitArtwork.halfPath(radius: type.radius - 3))
            rind.fillColor = SKColor(calibratedRed: 0.64, green: 0.9, blue: 0.48, alpha: 1)
            rind.strokeColor = .clear
            rind.position.x = 1.2
            content.addChild(rind)
        }
        let flesh = SKShapeNode(path: FruitArtwork.halfPath(radius: type.radius - inset))
        flesh.fillColor = type.fleshColor
        flesh.strokeColor = SKColor.white.withAlphaComponent(0.42)
        flesh.lineWidth = 1
        flesh.position.x = inset * 0.45
        content.addChild(flesh)

        addCutDetails(type: type, radius: type.radius - inset, to: content)

        let cutEdge = SKShapeNode(
            rectOf: CGSize(width: 1.5, height: type.radius * 1.62),
            cornerRadius: 0.7
        )
        cutEdge.fillColor = SKColor.white.withAlphaComponent(0.42)
        cutEdge.strokeColor = .clear
        cutEdge.position.x = inset * 0.48
        cutEdge.zPosition = 4
        content.addChild(cutEdge)
    }

    private func addCutDetails(type: FruitType, radius: CGFloat, to parent: SKNode) {
        switch type {
        case .apple:
            let core = SKShapeNode(ellipseOf: CGSize(width: 8, height: 17))
            core.fillColor = SKColor(calibratedRed: 1, green: 0.94, blue: 0.78, alpha: 0.9)
            core.strokeColor = SKColor(calibratedRed: 0.68, green: 0.5, blue: 0.2, alpha: 0.35)
            core.lineWidth = 0.7
            core.position.x = 5
            parent.addChild(core)
            for y in [-4, 4] as [CGFloat] {
                let seed = SKShapeNode(ellipseOf: CGSize(width: 2.6, height: 5))
                seed.fillColor = SKColor(calibratedRed: 0.26, green: 0.12, blue: 0.05, alpha: 0.92)
                seed.strokeColor = .clear
                seed.position = CGPoint(x: 7.5, y: y)
                seed.zRotation = y > 0 ? -0.32 : 0.32
                parent.addChild(seed)
            }
        case .orange, .lemon:
            let center = SKShapeNode(circleOfRadius: 3.2)
            center.fillColor = SKColor.white.withAlphaComponent(0.48)
            center.strokeColor = .clear
            center.position.x = 3.2
            parent.addChild(center)
            let segmentColor = type.accentColor.withAlphaComponent(0.45)
            for angle in stride(from: CGFloat(-1.1), through: CGFloat(1.1), by: 0.44) {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 3.5, y: 0))
                path.addLine(to: CGPoint(
                    x: max(4, cos(angle) * radius * 0.9),
                    y: sin(angle) * radius * 0.9
                ))
                let divider = SKShapeNode(path: path)
                divider.strokeColor = segmentColor
                divider.lineWidth = 0.9
                divider.lineCap = .round
                parent.addChild(divider)
            }
        case .watermelon:
            let seedPositions = [
                CGPoint(x: 11, y: -10), CGPoint(x: 17, y: 1),
                CGPoint(x: 10, y: 11), CGPoint(x: 23, y: -7)
            ]
            for (index, position) in seedPositions.enumerated() where position.x < radius + 4 {
                let seed = SKShapeNode(ellipseOf: CGSize(width: 2.4, height: 4.6))
                seed.fillColor = SKColor(calibratedWhite: 0.08, alpha: 0.85)
                seed.strokeColor = SKColor.white.withAlphaComponent(0.18)
                seed.lineWidth = 0.4
                seed.position = position
                seed.zRotation = index.isMultiple(of: 2) ? -0.22 : 0.24
                parent.addChild(seed)
            }
        case .kiwi:
            let core = SKShapeNode(ellipseOf: CGSize(width: 11, height: 18))
            core.fillColor = SKColor(calibratedRed: 0.85, green: 0.95, blue: 0.54, alpha: 0.84)
            core.strokeColor = .clear
            core.position.x = 4.5
            parent.addChild(core)
            for index in 0..<9 {
                let angle = CGFloat(index) * (.pi * 2 / 9)
                let seed = SKShapeNode(ellipseOf: CGSize(width: 1.5, height: 3.2))
                seed.fillColor = SKColor.black.withAlphaComponent(0.76)
                seed.strokeColor = .clear
                seed.position = CGPoint(
                    x: 8 + max(0, cos(angle)) * 8,
                    y: sin(angle) * 9
                )
                seed.zRotation = angle
                parent.addChild(seed)
            }
        }
    }

    private func configurePhysics(
        radius: CGFloat,
        velocity: CGVector,
        angularVelocity: CGFloat
    ) {
        let body = SKPhysicsBody(circleOfRadius: radius * 0.64)
        body.isDynamic = true
        body.affectedByGravity = true
        body.allowsRotation = true
        body.linearDamping = 0.02
        body.angularDamping = 0.02
        body.categoryBitMask = FruitSlicePhysicsCategory.fruitHalf
        body.collisionBitMask = 0
        body.contactTestBitMask = 0
        body.velocity = velocity
        body.angularVelocity = angularVelocity
        physicsBody = body
    }
}
