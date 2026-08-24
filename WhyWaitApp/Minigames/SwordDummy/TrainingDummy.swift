import AppKit
import SpriteKit

final class TrainingDummy: SKNode {
    private let bodyAssembly = SKNode()
    private let torsoBack = SKShapeNode()
    private let torso = SKShapeNode()
    private let torsoHighlight = SKShapeNode()
    private let torsoTarget = SKNode()
    private let head = SKShapeNode()
    private let headHighlight = SKShapeNode()
    private let leftArm = SKShapeNode()
    private let rightArm = SKShapeNode()
    private let pole = SKShapeNode(rectOf: CGSize(width: 10, height: 84), cornerRadius: 4)
    private let poleHighlight = SKShapeNode()
    private let base = SKShapeNode()
    private let baseShadow = SKShapeNode(ellipseOf: CGSize(width: 112, height: 20))
    private var idlePhase: CGFloat = 0

    private(set) var health = SwordDummyTuning.dummyMaximumHealth
    private(set) var maximumHealth = SwordDummyTuning.dummyMaximumHealth
    private(set) var leanAngle: CGFloat = 0
    private var rockingVelocity: CGFloat = 0
    private var compression: CGFloat = 0
    private var headJolt = CGVector.zero
    private var leftArmKick: CGFloat = 0
    private var rightArmKick: CGFloat = 0
    private var leftArmVelocity: CGFloat = 0
    private var rightArmVelocity: CGFloat = 0
    private var isBroken = false
    private var isIndestructible = false
    private var reactionMultiplier: CGFloat = 1
    private var rockingStiffness = SwordDummyTuning.dummyRockingStiffness
    private var rockingDamping = SwordDummyTuning.dummyRockingDamping

    override init() {
        super.init()
        name = "training-dummy"
        zPosition = 20
        buildVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("TrainingDummy does not support NSCoding")
    }

    func configure(
        reaction: DummyReactionPreset,
        durability: DummyDurabilityPreset
    ) {
        reactionMultiplier = reaction.impulseMultiplier
        rockingStiffness = reaction.rockingStiffness
        rockingDamping = reaction.rockingDamping
        isIndestructible = durability.maximumHealth == nil
        maximumHealth = durability.maximumHealth ?? Int.max
        health = maximumHealth
    }

    func reset(at basePosition: CGPoint) {
        removeAllActions()
        position = basePosition
        health = maximumHealth
        leanAngle = 0
        rockingVelocity = 0
        compression = 0
        headJolt = .zero
        leftArmKick = 0
        rightArmKick = 0
        leftArmVelocity = 0
        rightArmVelocity = 0
        idlePhase = 0
        isBroken = false
        alpha = 1
        setScale(1)
        restorePartVisuals()
        applyPose()
    }

    @discardableResult
    func applyDamage(_ result: SwordDamageResult, at point: CGPoint) -> Int {
        guard result.damage > 0, health > 0 else { return health }
        if !isIndestructible {
            health = max(0, health - result.damage)
        }

        let impulse = SwordMath.scale(
            result.impactDirection,
            by: CGFloat(result.damage) * reactionMultiplier
        )
        let lever = SwordMath.vector(from: position, to: point)
        rockingVelocity += SwordMath.clamp(
            SwordMath.cross(lever, impulse) * SwordDummyTuning.dummyImpulseScale,
            minimum: -3.2,
            maximum: 3.2
        )
        compression = min(8, compression + max(0, -result.impactDirection.dy) * CGFloat(result.damage) * 0.045)

        switch result.region {
        case .head:
            headJolt = SwordMath.add(
                headJolt,
                SwordMath.scale(result.impactDirection, by: min(10, CGFloat(result.damage) * 0.11))
            )
            pulse(head, strength: result.damage)
        case .leftArm:
            leftArmVelocity += result.impactDirection.dx * min(4, CGFloat(result.damage) * 0.045)
            pulse(leftArm, strength: result.damage)
        case .rightArm:
            rightArmVelocity += result.impactDirection.dx * min(4, CGFloat(result.damage) * 0.045)
            pulse(rightArm, strength: result.damage)
        case .torso:
            pulse(torso, strength: result.damage)
            pulse(torsoTarget, strength: result.damage)
        }
        return health
    }

    func applyWeakHandleReaction(direction: CGVector) {
        rockingVelocity += SwordMath.clamp(
            direction.dx * 0.08 * reactionMultiplier,
            minimum: -0.24,
            maximum: 0.24
        )
    }

    func update(deltaTime rawDelta: TimeInterval) {
        guard !isBroken else { return }
        let delta = CGFloat(min(max(rawDelta, 0), SwordEngineTuning.maximumFrameDelta))
        guard delta > 0 else { return }

        idlePhase += delta * 1.45
        let angularAcceleration = (-rockingStiffness * leanAngle)
            - (rockingDamping * rockingVelocity)
        rockingVelocity += angularAcceleration * delta
        leanAngle += rockingVelocity * delta
        if abs(leanAngle) > SwordDummyTuning.dummyMaximumLean {
            leanAngle = SwordMath.clamp(
                leanAngle,
                minimum: -SwordDummyTuning.dummyMaximumLean,
                maximum: SwordDummyTuning.dummyMaximumLean
            )
            rockingVelocity *= -0.22
        }

        compression *= exp(-8 * delta)
        headJolt = SwordMath.scale(headJolt, by: exp(-9 * delta))
        updateArm(angle: &leftArmKick, velocity: &leftArmVelocity, delta: delta)
        updateArm(angle: &rightArmKick, velocity: &rightArmVelocity, delta: delta)
        applyPose()
    }

    func hitRegions() -> [DummyHitRegion] {
        let torsoBottom = worldPoint(local: CGPoint(x: 0, y: 66 - compression))
        let torsoTop = worldPoint(local: CGPoint(x: 0, y: 135 - compression))
        let headCenter = SwordMath.point(
            worldPoint(local: CGPoint(x: 0, y: 171 - compression)),
            adding: headJolt
        )
        let leftShoulder = worldPoint(local: CGPoint(x: -19, y: 132 - compression))
        let leftHand = worldPoint(local: rotatedArmEndpoint(isLeft: true))
        let rightShoulder = worldPoint(local: CGPoint(x: 19, y: 132 - compression))
        let rightHand = worldPoint(local: rotatedArmEndpoint(isLeft: false))

        return [
            DummyHitRegion(id: .head, shape: .circle(center: headCenter, radius: 27)),
            DummyHitRegion(id: .torso, shape: .capsule(start: torsoBottom, end: torsoTop, radius: 23)),
            DummyHitRegion(id: .leftArm, shape: .capsule(start: leftShoulder, end: leftHand, radius: 10)),
            DummyHitRegion(id: .rightArm, shape: .capsule(start: rightShoulder, end: rightHand, radius: 10))
        ]
    }

    func breakApart(direction: CGVector) {
        guard !isBroken else { return }
        isBroken = true
        let horizontal = SwordMath.clamp(direction.dx, minimum: -1, maximum: 1)
        let fall = SKAction.group([
            .rotate(byAngle: horizontal * 0.38, duration: 0.3),
            .moveBy(x: horizontal * 20, y: -14, duration: 0.3)
        ])
        fall.timingMode = .easeOut
        bodyAssembly.run(fall, withKey: "dummy-break")
        head.run(.group([
            .moveBy(x: horizontal * 24, y: 20, duration: 0.34),
            .rotate(byAngle: horizontal * 0.9, duration: 0.34),
            .scale(to: 0.92, duration: 0.34)
        ]), withKey: "head-break")
        leftArm.run(.group([
            .rotate(byAngle: -0.95, duration: 0.31),
            .moveBy(x: -10, y: -7, duration: 0.31)
        ]), withKey: "left-break")
        rightArm.run(.group([
            .rotate(byAngle: 0.95, duration: 0.31),
            .moveBy(x: 10, y: -7, duration: 0.31)
        ]), withKey: "right-break")
        torsoTarget.run(.sequence([
            .group([.scale(to: 1.45, duration: 0.12), .fadeAlpha(to: 0.15, duration: 0.18)]),
            .fadeAlpha(to: 1, duration: 0)
        ]), withKey: "target-break")
    }

    private func updateArm(angle: inout CGFloat, velocity: inout CGFloat, delta: CGFloat) {
        velocity += ((-16 * angle) - (5 * velocity)) * delta
        angle += velocity * delta
        angle = SwordMath.clamp(angle, minimum: -0.75, maximum: 0.75)
    }

    private func applyPose() {
        bodyAssembly.zRotation = leanAngle
        bodyAssembly.position = CGPoint(x: 0, y: -compression)
        let idle = sin(idlePhase) * 0.45
        head.position = CGPoint(x: headJolt.dx, y: 171 + headJolt.dy + idle)
        leftArm.zRotation = 0.73 + leftArmKick
        rightArm.zRotation = -0.73 + rightArmKick
        torsoHighlight.alpha = 0.25 + ((sin(idlePhase) + 1) * 0.05)
        baseShadow.xScale = 1 + (abs(leanAngle) * 0.26)
        baseShadow.position.x = 4 + (leanAngle * 10)
    }

    private func worldPoint(local: CGPoint) -> CGPoint {
        let compressedLocal = CGVector(dx: local.x, dy: local.y)
        return SwordMath.point(position, adding: SwordMath.rotated(compressedLocal, by: leanAngle))
    }

    private func rotatedArmEndpoint(isLeft: Bool) -> CGPoint {
        let shoulder = CGPoint(x: isLeft ? -19 : 19, y: 132 - compression)
        let baseDirection = isLeft ? CGFloat(-2.30) : CGFloat(-0.84)
        let kick = isLeft ? leftArmKick : rightArmKick
        let direction = baseDirection + kick
        return CGPoint(
            x: shoulder.x + (cos(direction) * 54),
            y: shoulder.y + (sin(direction) * 54)
        )
    }

    private func buildVisuals() {
        baseShadow.position = CGPoint(x: 4, y: -7)
        baseShadow.fillColor = NSColor.black.withAlphaComponent(0.22)
        baseShadow.strokeColor = .clear

        let basePath = CGMutablePath()
        basePath.move(to: CGPoint(x: -49, y: -6))
        basePath.addLine(to: CGPoint(x: 49, y: -6))
        basePath.addCurve(to: CGPoint(x: 42, y: 7), control1: CGPoint(x: 50, y: 1), control2: CGPoint(x: 47, y: 6))
        basePath.addLine(to: CGPoint(x: -42, y: 7))
        basePath.addCurve(to: CGPoint(x: -49, y: -6), control1: CGPoint(x: -47, y: 6), control2: CGPoint(x: -50, y: 1))
        basePath.closeSubpath()
        base.path = basePath
        base.fillColor = NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.19, alpha: 0.98)
        base.strokeColor = NSColor(calibratedRed: 0.58, green: 0.62, blue: 0.64, alpha: 0.72)
        base.lineWidth = 1.3
        addBaseDetails()

        pole.position = CGPoint(x: 0, y: 43)
        pole.fillColor = NSColor(calibratedRed: 0.34, green: 0.22, blue: 0.11, alpha: 1)
        pole.strokeColor = NSColor(calibratedRed: 0.70, green: 0.49, blue: 0.24, alpha: 0.9)
        pole.lineWidth = 1.4
        let polePath = CGMutablePath()
        polePath.move(to: CGPoint(x: -2, y: 7))
        polePath.addLine(to: CGPoint(x: -2, y: 78))
        poleHighlight.path = polePath
        poleHighlight.strokeColor = NSColor.white.withAlphaComponent(0.2)
        poleHighlight.lineWidth = 1.1
        pole.addChild(poleHighlight)

        let padding = NSColor(calibratedRed: 0.69, green: 0.43, blue: 0.20, alpha: 0.98)
        let paddingLight = NSColor(calibratedRed: 0.91, green: 0.67, blue: 0.33, alpha: 0.96)
        let seam = NSColor(calibratedRed: 0.98, green: 0.76, blue: 0.40, alpha: 0.82)

        let torsoPath = makeTorsoPath(inset: 0)
        torsoBack.path = makeTorsoPath(inset: -3)
        torsoBack.position = CGPoint(x: 3, y: 98)
        torsoBack.fillColor = NSColor.black.withAlphaComponent(0.24)
        torsoBack.strokeColor = .clear
        torsoBack.zPosition = 0

        torso.path = torsoPath
        torso.position = CGPoint(x: 0, y: 102)
        torso.fillColor = padding
        torso.strokeColor = seam
        torso.lineWidth = 2.1
        torso.zPosition = 2

        let torsoShinePath = CGMutablePath()
        torsoShinePath.move(to: CGPoint(x: -13, y: 30))
        torsoShinePath.addCurve(to: CGPoint(x: -18, y: -21), control1: CGPoint(x: -20, y: 15), control2: CGPoint(x: -21, y: -7))
        torsoHighlight.path = torsoShinePath
        torsoHighlight.strokeColor = NSColor.white.withAlphaComponent(0.28)
        torsoHighlight.lineWidth = 3.2
        torsoHighlight.lineCap = .round
        torsoHighlight.zPosition = 4
        torso.addChild(torsoHighlight)
        addTorsoTarget(seam: seam)
        torso.addChild(torsoTarget)

        head.path = CGPath(
            roundedRect: CGRect(x: -25, y: -27, width: 50, height: 54),
            cornerWidth: 19,
            cornerHeight: 19,
            transform: nil
        )
        head.position = CGPoint(x: 0, y: 171)
        head.fillColor = paddingLight
        head.strokeColor = seam
        head.lineWidth = 2.1
        head.zPosition = 5
        addHeadDetails(seam: seam)

        for (arm, x, rotation, highlightSide) in [
            (leftArm, -33.0, 0.73, -1.0),
            (rightArm, 33.0, -0.73, 1.0)
        ] {
            arm.path = CGPath(
                roundedRect: CGRect(x: -9, y: -31, width: 18, height: 62),
                cornerWidth: 8.5,
                cornerHeight: 8.5,
                transform: nil
            )
            arm.position = CGPoint(x: x, y: 111)
            arm.zRotation = rotation
            arm.fillColor = padding
            arm.strokeColor = seam
            arm.lineWidth = 1.8
            arm.zPosition = 1
            addArmDetails(to: arm, seam: seam, highlightSide: CGFloat(highlightSide))
        }

        addChild(baseShadow)
        addChild(base)
        addChild(bodyAssembly)
        bodyAssembly.addChild(pole)
        bodyAssembly.addChild(torsoBack)
        bodyAssembly.addChild(torso)
        bodyAssembly.addChild(leftArm)
        bodyAssembly.addChild(rightArm)
        bodyAssembly.addChild(head)
    }

    private func makeTorsoPath(inset: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -20 - inset, y: -38 - inset))
        path.addCurve(
            to: CGPoint(x: -25 - inset, y: 25 + inset),
            control1: CGPoint(x: -27 - inset, y: -22),
            control2: CGPoint(x: -29 - inset, y: 12)
        )
        path.addCurve(
            to: CGPoint(x: -16 - inset, y: 39 + inset),
            control1: CGPoint(x: -24, y: 34),
            control2: CGPoint(x: -21, y: 38)
        )
        path.addLine(to: CGPoint(x: 16 + inset, y: 39 + inset))
        path.addCurve(
            to: CGPoint(x: 25 + inset, y: 25 + inset),
            control1: CGPoint(x: 21, y: 38),
            control2: CGPoint(x: 24, y: 34)
        )
        path.addCurve(
            to: CGPoint(x: 20 + inset, y: -38 - inset),
            control1: CGPoint(x: 29 + inset, y: 12),
            control2: CGPoint(x: 27 + inset, y: -22)
        )
        path.closeSubpath()
        return path
    }

    private func addTorsoTarget(seam: NSColor) {
        torsoTarget.position = CGPoint(x: 0, y: 6)
        for (radius, width, alpha) in [(14.0, 2.0, 0.74), (8.0, 1.6, 0.62)] {
            let ring = SKShapeNode(circleOfRadius: CGFloat(radius))
            ring.strokeColor = NSColor(calibratedRed: 0.48, green: 0.12, blue: 0.10, alpha: CGFloat(alpha))
            ring.lineWidth = CGFloat(width)
            ring.fillColor = .clear
            torsoTarget.addChild(ring)
        }
        let bullseye = SKShapeNode(circleOfRadius: 2.7)
        bullseye.fillColor = NSColor(calibratedRed: 0.48, green: 0.12, blue: 0.10, alpha: 0.8)
        bullseye.strokeColor = seam.withAlphaComponent(0.7)
        bullseye.lineWidth = 0.7
        torsoTarget.addChild(bullseye)

        let lowerSeam = SKShapeNode()
        let seamPath = CGMutablePath()
        seamPath.move(to: CGPoint(x: -14, y: -29))
        seamPath.addQuadCurve(to: CGPoint(x: 14, y: -29), control: CGPoint(x: 0, y: -25))
        lowerSeam.path = seamPath
        lowerSeam.strokeColor = seam.withAlphaComponent(0.58)
        lowerSeam.lineWidth = 1
        torso.addChild(lowerSeam)
    }

    private func addHeadDetails(seam: NSColor) {
        let highlightPath = CGMutablePath()
        highlightPath.move(to: CGPoint(x: -13, y: 16))
        highlightPath.addCurve(to: CGPoint(x: -18, y: -9), control1: CGPoint(x: -19, y: 9), control2: CGPoint(x: -20, y: 0))
        headHighlight.path = highlightPath
        headHighlight.strokeColor = NSColor.white.withAlphaComponent(0.3)
        headHighlight.lineWidth = 3
        headHighlight.lineCap = .round
        head.addChild(headHighlight)

        for radius in [11.0, 5.5] {
            let target = SKShapeNode(circleOfRadius: CGFloat(radius))
            target.strokeColor = NSColor(calibratedRed: 0.50, green: 0.12, blue: 0.10, alpha: radius > 8 ? 0.74 : 0.58)
            target.lineWidth = radius > 8 ? 2 : 1.4
            target.fillColor = .clear
            target.zPosition = 2
            head.addChild(target)
        }
        let center = SKShapeNode(circleOfRadius: 2.1)
        center.fillColor = NSColor(calibratedRed: 0.50, green: 0.12, blue: 0.10, alpha: 0.78)
        center.strokeColor = seam.withAlphaComponent(0.55)
        center.lineWidth = 0.6
        center.zPosition = 3
        head.addChild(center)

        let neck = SKShapeNode(rectOf: CGSize(width: 18, height: 10), cornerRadius: 4)
        neck.position = CGPoint(x: 0, y: -30)
        neck.fillColor = NSColor(calibratedRed: 0.42, green: 0.26, blue: 0.12, alpha: 0.98)
        neck.strokeColor = seam.withAlphaComponent(0.65)
        neck.lineWidth = 1
        neck.zPosition = -1
        head.addChild(neck)
    }

    private func addArmDetails(to arm: SKShapeNode, seam: NSColor, highlightSide: CGFloat) {
        let elbow = SKShapeNode(circleOfRadius: 5.4)
        elbow.position = CGPoint(x: 0, y: -3)
        elbow.fillColor = NSColor(calibratedRed: 0.55, green: 0.32, blue: 0.14, alpha: 0.9)
        elbow.strokeColor = seam.withAlphaComponent(0.75)
        elbow.lineWidth = 1.2
        arm.addChild(elbow)

        let seamPath = CGMutablePath()
        seamPath.move(to: CGPoint(x: -6, y: -3))
        seamPath.addLine(to: CGPoint(x: 6, y: -3))
        let elbowSeam = SKShapeNode(path: seamPath)
        elbowSeam.strokeColor = seam.withAlphaComponent(0.75)
        elbowSeam.lineWidth = 1
        arm.addChild(elbowSeam)

        let shinePath = CGMutablePath()
        shinePath.move(to: CGPoint(x: highlightSide * 4, y: 22))
        shinePath.addLine(to: CGPoint(x: highlightSide * 4.5, y: 8))
        let shine = SKShapeNode(path: shinePath)
        shine.strokeColor = NSColor.white.withAlphaComponent(0.22)
        shine.lineWidth = 1.6
        shine.lineCap = .round
        arm.addChild(shine)
    }

    private func addBaseDetails() {
        let top = SKShapeNode(rectOf: CGSize(width: 70, height: 3), cornerRadius: 1.5)
        top.position = CGPoint(x: 0, y: 3)
        top.fillColor = NSColor.white.withAlphaComponent(0.12)
        top.strokeColor = .clear
        base.addChild(top)

        for x in [-34.0, 34.0] {
            let bolt = SKShapeNode(circleOfRadius: 2.3)
            bolt.position = CGPoint(x: x, y: 0)
            bolt.fillColor = NSColor(calibratedWhite: 0.66, alpha: 0.9)
            bolt.strokeColor = NSColor.black.withAlphaComponent(0.6)
            bolt.lineWidth = 0.7
            base.addChild(bolt)
        }
    }

    private func pulse(_ node: SKNode, strength: Int) {
        node.removeAction(forKey: "impact-pulse")
        let amount = min(1.1, 1.025 + (CGFloat(strength) / 900))
        node.run(.sequence([
            .scale(to: amount, duration: 0.045),
            .scale(to: 1, duration: 0.13)
        ]), withKey: "impact-pulse")
    }

    private func restorePartVisuals() {
        bodyAssembly.removeAllActions()
        head.removeAllActions()
        torso.removeAllActions()
        torsoTarget.removeAllActions()
        leftArm.removeAllActions()
        rightArm.removeAllActions()
        bodyAssembly.position = .zero
        bodyAssembly.zRotation = 0
        head.position = CGPoint(x: 0, y: 171)
        head.zRotation = 0
        head.setScale(1)
        torso.setScale(1)
        torsoTarget.setScale(1)
        torsoTarget.alpha = 1
        leftArm.position = CGPoint(x: -33, y: 111)
        rightArm.position = CGPoint(x: 33, y: 111)
        leftArm.zRotation = 0.73
        rightArm.zRotation = -0.73
        leftArm.setScale(1)
        rightArm.setScale(1)
    }
}
