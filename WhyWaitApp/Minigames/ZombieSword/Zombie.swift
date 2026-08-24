import AppKit
import Foundation
import SpriteKit

struct ZombieAttackEvent: Equatable {
    let zombieID: UUID
    let damage: Int
}

final class Zombie: SKNode {
    let id: UUID
    let type: ZombieType
    let stats: ZombieStats

    private(set) var state: ZombieState = .spawning
    private(set) var health: Int
    private(set) var velocity = CGVector.zero
    private(set) var hasAwardedDeath = false
    private(set) var lastImpactDirection = CGVector.zero

    private let bodyRoot = SKNode()
    private let groundShadow = SKShapeNode()
    private let spawnAura = SKShapeNode()
    private let torso = SKShapeNode()
    private let torsoHighlight = SKShapeNode()
    private let head = SKShapeNode()
    private let leftArm = SKShapeNode()
    private let rightArm = SKShapeNode()
    private let leftLeg = SKShapeNode()
    private let rightLeg = SKShapeNode()
    private let eyes = SKNode()
    private let attackTelegraph = SKNode()
    private let armorRoot = SKNode()
    private var stateTimer: TimeInterval = 0.18
    private var attackCooldownRemaining: TimeInterval = 0
    private var driftPhase: CGFloat
    private var gaitPhase: CGFloat = 0
    private var visualTime: CGFloat = 0
    private var headBasePosition = CGPoint.zero
    private var bodyVisualScale: CGFloat = 1

    init(type: ZombieType, wave: Int, position: CGPoint, identifier: UUID = UUID()) {
        id = identifier
        self.type = type
        stats = type.stats.scaled(forWave: wave)
        health = stats.health
        driftPhase = CGFloat(identifier.uuidString.hashValue % 628) / 100
        super.init()
        self.position = position
        name = "zombie-\(type.rawValue.lowercased())"
        zPosition = 22
        buildVisuals()
        alpha = 0
        setScale(0.78)
        playSpawnAura()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Zombie does not support NSCoding")
    }

    var isAlive: Bool { state != .dead }
    var isAttacking: Bool { state == .attacking }
    var collisionRadius: CGFloat { stats.radius }

    func update(
        deltaTime rawDeltaTime: TimeInterval,
        playerPosition: CGPoint,
        separation: CGVector
    ) -> ZombieAttackEvent? {
        guard state != .dead else { return nil }
        let deltaTime = min(max(rawDeltaTime, 0), 0.05)
        guard deltaTime > 0 else { return nil }
        let delta = CGFloat(deltaTime)
        attackCooldownRemaining = max(0, attackCooldownRemaining - deltaTime)
        driftPhase += delta * 2.2
        visualTime += delta

        switch state {
        case .spawning:
            stateTimer -= deltaTime
            alpha = min(1, alpha + delta * 6)
            setScale(min(1, xScale + delta * 1.4))
            updateIdleVisual(deltaTime: delta)
            if stateTimer <= 0 {
                state = .approaching
                alpha = 1
                setScale(1)
            }
        case .staggered:
            stateTimer -= deltaTime
            integrateVelocity(deltaTime: deltaTime, damping: 3.8)
            bodyRoot.zRotation *= CGFloat(exp(-5.8 * deltaTime))
            updateStaggerVisual(deltaTime: delta)
            if stateTimer <= 0 {
                state = .approaching
                setAttackPose(false)
            }
        case .attacking:
            stateTimer -= deltaTime
            velocity = SwordMath.scale(velocity, by: CGFloat(exp(-7 * deltaTime)))
            integrateVelocity(deltaTime: deltaTime, damping: 2)
            updateAttackVisual()
            guard stateTimer <= 0 else { return nil }
            state = .approaching
            setAttackPose(false)
            attackCooldownRemaining = stats.attackCooldown
            let distance = hypot(position.x - playerPosition.x, position.y - playerPosition.y)
            guard distance <= ZombieSwordTuning.playerAttackRadius + stats.radius + 8 else {
                return nil
            }
            return ZombieAttackEvent(zombieID: id, damage: stats.attackDamage)
        case .approaching:
            let toPlayer = SwordMath.vector(from: position, to: playerPosition)
            let distance = SwordMath.magnitude(toPlayer)
            if distance <= ZombieSwordTuning.playerAttackRadius + stats.radius,
               attackCooldownRemaining <= 0 {
                state = .attacking
                stateTimer = ZombieSwordTuning.attackWindup
                velocity = SwordMath.scale(velocity, by: 0.2)
                setAttackPose(true)
                return nil
            }

            var direction = SwordMath.normalized(toPlayer, fallback: .zero)
            if type == .shambler {
                let perpendicular = CGVector(dx: -direction.dy, dy: direction.dx)
                direction = SwordMath.normalized(
                    SwordMath.add(direction, SwordMath.scale(perpendicular, by: sin(driftPhase) * 0.42)),
                    fallback: direction
                )
            }
            let desired = SwordMath.add(
                SwordMath.scale(direction, by: stats.speed),
                SwordMath.clampedMagnitude(separation, maximum: stats.speed * 0.72)
            )
            let blend = CGFloat(1 - exp(-6.5 * deltaTime))
            velocity = CGVector(
                dx: velocity.dx + ((desired.dx - velocity.dx) * blend),
                dy: velocity.dy + ((desired.dy - velocity.dy) * blend)
            )
            velocity = SwordMath.clampedMagnitude(velocity, maximum: min(190, stats.speed * 1.45))
            integrateVelocity(deltaTime: deltaTime, damping: 0.2)
            bodyRoot.zRotation = SwordMath.clamp(-velocity.dx / 1_100, minimum: -0.13, maximum: 0.13)
            updateWalkVisual(deltaTime: delta)
        case .dead:
            break
        }
        return nil
    }

    @discardableResult
    func applyHit(_ result: ZombieDamageResult) -> Bool {
        guard state != .dead, result.damage > 0 else { return false }
        health = max(0, health - result.damage)
        lastImpactDirection = result.impactDirection
        let knockback = SwordMath.scale(
            result.knockbackVelocity,
            by: max(0.18, 1 - stats.staggerResistance)
        )
        velocity = SwordMath.clampedMagnitude(
            SwordMath.add(velocity, knockback),
            maximum: ZombieSwordTuning.maximumKnockbackSpeed
        )
        bodyRoot.zRotation += SwordMath.clamp(
            result.impactDirection.dx * CGFloat(result.damage) / 420,
            minimum: -0.34,
            maximum: 0.34
        )
        playHitReaction(region: result.region, armored: result.wasArmorReduced, damage: result.damage)
        if health == 0 {
            state = .dead
            setAttackPose(false)
            return true
        }
        if result.causesStagger {
            state = .staggered
            stateTimer = result.staggerDuration
            setAttackPose(false)
        }
        flash(armored: result.wasArmorReduced)
        return false
    }

    func markDeathAwarded() -> Bool {
        guard state == .dead, !hasAwardedDeath else { return false }
        hasAwardedDeath = true
        return true
    }

    func playDeathAnimation() {
        removeAllActions()
        attackTelegraph.removeAllActions()
        attackTelegraph.alpha = 0
        let direction = SwordMath.normalized(lastImpactDirection, fallback: CGVector(dx: 0, dy: 1))
        let duration: TimeInterval = type == .tank ? 0.48 : 0.38
        run(.sequence([
            .group([
                .moveBy(x: direction.dx * 42, y: direction.dy * 42 - 16, duration: duration),
                .rotate(byAngle: direction.dx * (type == .tank ? 0.48 : 0.8), duration: duration),
                .scale(to: type == .tank ? 0.78 : 0.62, duration: duration),
                .fadeOut(withDuration: duration)
            ]),
            .removeFromParent()
        ]))
        head.run(.group([
            .moveBy(x: direction.dx * 11, y: 11, duration: duration * 0.85),
            .rotate(byAngle: direction.dx * 0.65, duration: duration * 0.85)
        ]))
        leftArm.run(.group([
            .rotate(byAngle: -0.95, duration: duration * 0.8),
            .moveBy(x: -8, y: -5, duration: duration * 0.8)
        ]))
        rightArm.run(.group([
            .rotate(byAngle: 0.95, duration: duration * 0.8),
            .moveBy(x: 8, y: -5, duration: duration * 0.8)
        ]))
        leftLeg.run(.rotate(byAngle: -0.5, duration: duration * 0.78))
        rightLeg.run(.rotate(byAngle: 0.5, duration: duration * 0.78))
        if type == .armored {
            armorRoot.run(.group([
                .moveBy(x: direction.dx * 15, y: 7, duration: duration * 0.8),
                .rotate(byAngle: direction.dx * 0.42, duration: duration * 0.8)
            ]))
        }
    }

    func cancelAttackAndStagger(duration: TimeInterval = 0.25) {
        guard state != .dead else { return }
        state = .staggered
        stateTimer = duration
        setAttackPose(false)
    }

#if DEBUG
    func prepareVisualPreview() {
        state = .approaching
        stateTimer = 0
        velocity = .zero
        alpha = 1
        setScale(1)
        spawnAura.removeFromParent()
        updateIdleVisual(deltaTime: 0)
    }
#endif

    func hitRegions() -> [SwordHitRegion<ZombieHitRegionID>] {
        guard state != .dead else { return [] }
        let scale = stats.radius / 23
        let headCenter = worldPoint(CGPoint(x: 0, y: 23 * scale))
        let torsoStart = worldPoint(CGPoint(x: 0, y: -20 * scale))
        let torsoEnd = worldPoint(CGPoint(x: 0, y: 10 * scale))
        let leftStart = worldPoint(CGPoint(x: -9 * scale, y: 7 * scale))
        let leftEnd = worldPoint(CGPoint(x: -23 * scale, y: -9 * scale))
        let rightStart = worldPoint(CGPoint(x: 9 * scale, y: 7 * scale))
        let rightEnd = worldPoint(CGPoint(x: 23 * scale, y: -9 * scale))
        return [
            SwordHitRegion(
                id: ZombieHitRegionID(zombieID: id, bodyRegion: .head),
                shape: .circle(center: headCenter, radius: 10.5 * scale)
            ),
            SwordHitRegion(
                id: ZombieHitRegionID(zombieID: id, bodyRegion: .torso),
                shape: .capsule(start: torsoStart, end: torsoEnd, radius: 12 * scale)
            ),
            SwordHitRegion(
                id: ZombieHitRegionID(zombieID: id, bodyRegion: .leftArm),
                shape: .capsule(start: leftStart, end: leftEnd, radius: 5.4 * scale)
            ),
            SwordHitRegion(
                id: ZombieHitRegionID(zombieID: id, bodyRegion: .rightArm),
                shape: .capsule(start: rightStart, end: rightEnd, radius: 5.4 * scale)
            )
        ]
    }

    private func integrateVelocity(deltaTime: TimeInterval, damping: CGFloat) {
        let decay = CGFloat(exp(-Double(damping) * deltaTime))
        velocity = SwordMath.scale(velocity, by: decay)
        position = SwordMath.point(position, adding: SwordMath.scale(velocity, by: CGFloat(deltaTime)))
    }

    private func setAttackPose(_ active: Bool) {
        let duration = active ? 0.14 : 0.17
        leftArm.removeAction(forKey: "arm-pose")
        rightArm.removeAction(forKey: "arm-pose")
        leftArm.run(
            .rotate(toAngle: active ? -2.18 : -0.34, duration: duration, shortestUnitArc: true),
            withKey: "arm-pose"
        )
        rightArm.run(
            .rotate(toAngle: active ? 2.18 : 0.34, duration: duration, shortestUnitArc: true),
            withKey: "arm-pose"
        )
        attackTelegraph.removeAllActions()
        if active {
            attackTelegraph.alpha = 0
            attackTelegraph.setScale(0.72)
            attackTelegraph.run(.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.92, duration: 0.1), .scale(to: 1.08, duration: 0.18)]),
                .group([.fadeAlpha(to: 0.45, duration: 0.14), .scale(to: 0.9, duration: 0.14)])
            ])))
        } else {
            attackTelegraph.alpha = 0
            attackTelegraph.setScale(1)
            torso.yScale = 1
        }
    }

    private func updateWalkVisual(deltaTime: CGFloat) {
        let speedRatio = SwordMath.clamp(
            SwordMath.magnitude(velocity) / max(1, stats.speed),
            minimum: 0,
            maximum: 1.3
        )
        gaitPhase += deltaTime * (type == .runner ? 10.5 : 6.5) * max(0.35, speedRatio)
        let gait = sin(gaitPhase)
        let stepAmount: CGFloat = type == .tank ? 0.12 : (type == .runner ? 0.32 : 0.22)
        leftLeg.zRotation = gait * stepAmount
        rightLeg.zRotation = -gait * stepAmount

        let armAmount: CGFloat = type == .runner ? 0.22 : 0.12
        leftArm.zRotation = -0.34 - (gait * armAmount)
        rightArm.zRotation = 0.34 + (gait * armAmount)

        let bob = abs(gait) * (type == .tank ? 0.6 : 1.15)
        torso.position.y = bob
        head.position = CGPoint(x: headBasePosition.x, y: headBasePosition.y + bob)
        eyes.position = CGPoint(x: velocity.dx / max(80, stats.speed) * 1.3, y: bob)
        armorRoot.position.y = bob
        groundShadow.xScale = 1 - (bob * 0.012)
    }

    private func updateIdleVisual(deltaTime: CGFloat) {
        gaitPhase += deltaTime * 2.4
        let breathe = sin(gaitPhase) * 0.5
        head.position = CGPoint(x: headBasePosition.x, y: headBasePosition.y + breathe)
        torsoHighlight.alpha = 0.22 + ((sin(gaitPhase) + 1) * 0.06)
    }

    private func updateStaggerVisual(deltaTime: CGFloat) {
        gaitPhase += deltaTime * 12
        let shake = sin(gaitPhase) * min(2.2, CGFloat(stateTimer) * 9)
        head.position = CGPoint(x: headBasePosition.x + shake, y: headBasePosition.y)
        leftLeg.zRotation *= 0.88
        rightLeg.zRotation *= 0.88
    }

    private func updateAttackVisual() {
        let progress = SwordMath.clamp(
            CGFloat(1 - (stateTimer / ZombieSwordTuning.attackWindup)),
            minimum: 0,
            maximum: 1
        )
        torso.yScale = 1 + (sin(progress * .pi) * 0.08)
        head.position.y = headBasePosition.y + (sin(progress * .pi) * 2.2)
    }

    private func flash(armored: Bool) {
        bodyRoot.removeAction(forKey: "hit-flash")
        let original = bodyRoot.alpha
        bodyRoot.run(.sequence([
            .fadeAlpha(to: armored ? 0.55 : 0.72, duration: 0.035),
            .fadeAlpha(to: original, duration: 0.1)
        ]), withKey: "hit-flash")
    }

    private func playHitReaction(region: ZombieBodyRegion, armored: Bool, damage: Int) {
        let node: SKNode
        switch region {
        case .head: node = head
        case .torso: node = armored ? armorRoot : torso
        case .leftArm: node = leftArm
        case .rightArm: node = rightArm
        }
        node.removeAction(forKey: "impact-pulse")
        let scaleAmount = min(1.14, 1.035 + (CGFloat(damage) / 850))
        node.run(.sequence([
            .scale(to: scaleAmount, duration: 0.04),
            .scale(to: 1, duration: 0.12)
        ]), withKey: "impact-pulse")
    }

    private func buildVisuals() {
        let scale = stats.radius / 23
        let bodyColor = type.bodyColor
        let outline = NSColor(calibratedRed: 0.055, green: 0.075, blue: 0.065, alpha: 0.92)
        bodyVisualScale = type == .runner ? 0.94 : 1
        bodyRoot.setScale(bodyVisualScale)

        groundShadow.path = CGPath(
            ellipseIn: CGRect(x: -19 * scale, y: -39 * scale, width: 38 * scale, height: 10 * scale),
            transform: nil
        )
        groundShadow.fillColor = NSColor.black.withAlphaComponent(type == .tank ? 0.3 : 0.23)
        groundShadow.strokeColor = .clear
        groundShadow.zPosition = -4

        spawnAura.path = CGPath(
            ellipseIn: CGRect(x: -25 * scale, y: -41 * scale, width: 50 * scale, height: 14 * scale),
            transform: nil
        )
        spawnAura.fillColor = NSColor.systemOrange.withAlphaComponent(0.08)
        spawnAura.strokeColor = NSColor.systemOrange.withAlphaComponent(0.7)
        spawnAura.lineWidth = 1.4
        spawnAura.zPosition = -3

        let torsoWidth = torsoWidthForType * scale
        let torsoHeight = torsoHeightForType * scale
        torso.path = makeTorsoPath(width: torsoWidth, height: torsoHeight)
        torso.fillColor = bodyColor.blended(withFraction: 0.12, of: .black) ?? bodyColor
        torso.strokeColor = outline
        torso.lineWidth = max(1.4, 1.8 * scale)
        torso.zPosition = 2
        addTorsoDetails(scale: scale, color: bodyColor, outline: outline)

        let shinePath = CGMutablePath()
        shinePath.move(to: CGPoint(x: -torsoWidth * 0.26, y: torsoHeight * 0.26))
        shinePath.addLine(to: CGPoint(x: -torsoWidth * 0.34, y: -torsoHeight * 0.2))
        torsoHighlight.path = shinePath
        torsoHighlight.strokeColor = NSColor.white.withAlphaComponent(0.24)
        torsoHighlight.lineWidth = max(1.1, 1.7 * scale)
        torsoHighlight.lineCap = .round
        torso.addChild(torsoHighlight)

        head.path = makeHeadPath(scale: scale)
        head.fillColor = bodyColor.blended(withFraction: 0.14, of: .white) ?? bodyColor
        head.strokeColor = outline
        head.lineWidth = max(1.4, 1.8 * scale)
        head.zPosition = 5
        headBasePosition = type == .shambler
            ? CGPoint(x: -4 * scale, y: -1 * scale)
            : .zero
        head.position = headBasePosition
        if type == .shambler { head.zRotation = 0.16 }
        addFace(scale: scale, outline: outline)

        let armLength = armLengthForType * scale
        let armWidth = armWidthForType * scale
        leftArm.path = makeLimbPath(length: armLength, width: armWidth)
        rightArm.path = makeLimbPath(length: armLength, width: armWidth)
        for arm in [leftArm, rightArm] {
            arm.fillColor = bodyColor
            arm.strokeColor = outline
            arm.lineWidth = max(1.1, 1.45 * scale)
            arm.zPosition = 1
            addHand(to: arm, scale: scale, color: bodyColor, outline: outline, armLength: armLength)
        }
        leftArm.position = CGPoint(x: -10 * scale, y: 7 * scale)
        rightArm.position = CGPoint(x: 10 * scale, y: 7 * scale)
        leftArm.zRotation = -0.34
        rightArm.zRotation = 0.34

        let legLength = legLengthForType * scale
        let legWidth = legWidthForType * scale
        leftLeg.path = makeLimbPath(length: legLength, width: legWidth)
        rightLeg.path = makeLimbPath(length: legLength, width: legWidth)
        for (leg, x) in [(leftLeg, -6.0), (rightLeg, 6.0)] {
            leg.position = CGPoint(x: CGFloat(x) * scale, y: -17 * scale)
            leg.fillColor = clothingColor
            leg.strokeColor = outline
            leg.lineWidth = max(1, 1.35 * scale)
            leg.zPosition = 0
            addFoot(to: leg, scale: scale, outline: outline, legLength: legLength)
        }
        if type == .shambler {
            leftLeg.zRotation = -0.14
            rightLeg.zRotation = 0.08
            leftArm.position.y -= 4 * scale
        }

        buildAttackTelegraph(scale: scale)
        buildTypeDetails(scale: scale, bodyColor: bodyColor, outline: outline)

        addChild(groundShadow)
        addChild(spawnAura)
        bodyRoot.addChild(leftLeg)
        bodyRoot.addChild(rightLeg)
        bodyRoot.addChild(leftArm)
        bodyRoot.addChild(rightArm)
        bodyRoot.addChild(torso)
        bodyRoot.addChild(head)
        bodyRoot.addChild(eyes)
        bodyRoot.addChild(armorRoot)
        bodyRoot.addChild(attackTelegraph)
        addChild(bodyRoot)
    }

    private var torsoWidthForType: CGFloat {
        switch type {
        case .runner: return 21
        case .tank: return 36
        case .shambler: return 28
        case .armored: return 29
        case .walker: return 26
        }
    }

    private var torsoHeightForType: CGFloat {
        switch type {
        case .runner: return 42
        case .tank: return 42
        case .shambler: return 40
        case .armored: return 40
        case .walker: return 39
        }
    }

    private var armLengthForType: CGFloat {
        switch type {
        case .runner: return 29
        case .tank: return 27
        default: return 25
        }
    }

    private var armWidthForType: CGFloat {
        switch type {
        case .runner: return 6.5
        case .tank: return 12
        case .armored: return 9
        default: return 8
        }
    }

    private var legLengthForType: CGFloat {
        switch type {
        case .runner: return 26
        case .tank: return 19
        default: return 22
        }
    }

    private var legWidthForType: CGFloat {
        switch type {
        case .runner: return 6
        case .tank: return 11
        default: return 7.5
        }
    }

    private var clothingColor: NSColor {
        switch type {
        case .walker: return NSColor(calibratedRed: 0.20, green: 0.31, blue: 0.36, alpha: 0.98)
        case .runner: return NSColor(calibratedRed: 0.37, green: 0.20, blue: 0.18, alpha: 0.98)
        case .tank: return NSColor(calibratedRed: 0.19, green: 0.24, blue: 0.17, alpha: 0.98)
        case .shambler: return NSColor(calibratedRed: 0.29, green: 0.25, blue: 0.16, alpha: 0.98)
        case .armored: return NSColor(calibratedWhite: 0.20, alpha: 0.98)
        }
    }

    private func makeTorsoPath(width: CGFloat, height: CGFloat) -> CGPath {
        let half = width * 0.5
        let top = height * 0.39
        let bottom = -height * 0.61
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -half * 0.68, y: bottom))
        path.addLine(to: CGPoint(x: -half, y: top * 0.64))
        path.addQuadCurve(to: CGPoint(x: -half * 0.62, y: top), control: CGPoint(x: -half, y: top))
        path.addLine(to: CGPoint(x: half * 0.62, y: top))
        path.addQuadCurve(to: CGPoint(x: half, y: top * 0.64), control: CGPoint(x: half, y: top))
        path.addLine(to: CGPoint(x: half * 0.76, y: bottom))
        path.addLine(to: CGPoint(x: half * 0.28, y: bottom + 2))
        path.addLine(to: CGPoint(x: 0, y: bottom - 1.5))
        path.addLine(to: CGPoint(x: -half * 0.28, y: bottom + 2))
        path.closeSubpath()
        return path
    }

    private func makeHeadPath(scale: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let width: CGFloat
        let height: CGFloat
        switch type {
        case .runner:
            width = 18 * scale
            height = 23 * scale
        case .tank:
            width = 26 * scale
            height = 24 * scale
        case .armored:
            width = 23 * scale
            height = 23 * scale
        default:
            width = 22 * scale
            height = 23 * scale
        }
        let half = width * 0.5
        let centerY = 23 * scale
        path.move(to: CGPoint(x: -half * 0.7, y: centerY - (height * 0.48)))
        path.addCurve(
            to: CGPoint(x: -half, y: centerY + (height * 0.12)),
            control1: CGPoint(x: -half, y: centerY - (height * 0.32)),
            control2: CGPoint(x: -half * 1.05, y: centerY - (height * 0.05))
        )
        path.addCurve(
            to: CGPoint(x: 0, y: centerY + (height * 0.52)),
            control1: CGPoint(x: -half * 0.9, y: centerY + (height * 0.43)),
            control2: CGPoint(x: -half * 0.36, y: centerY + (height * 0.55))
        )
        path.addCurve(
            to: CGPoint(x: half, y: centerY + (height * 0.1)),
            control1: CGPoint(x: half * 0.38, y: centerY + (height * 0.55)),
            control2: CGPoint(x: half, y: centerY + (height * 0.4))
        )
        path.addCurve(
            to: CGPoint(x: half * 0.56, y: centerY - (height * 0.5)),
            control1: CGPoint(x: half * 1.02, y: centerY - (height * 0.2)),
            control2: CGPoint(x: half * 0.82, y: centerY - (height * 0.44))
        )
        path.addLine(to: CGPoint(x: -half * 0.7, y: centerY - (height * 0.48)))
        path.closeSubpath()
        return path
    }

    private func makeLimbPath(length: CGFloat, width: CGFloat) -> CGPath {
        CGPath(
            roundedRect: CGRect(x: -width * 0.5, y: -length, width: width, height: length),
            cornerWidth: width * 0.48,
            cornerHeight: width * 0.48,
            transform: nil
        )
    }

    private func addFace(scale: CGFloat, outline: NSColor) {
        let eyeColor = type == .armored
            ? NSColor.systemOrange
            : NSColor(calibratedRed: 0.91, green: 0.79, blue: 0.25, alpha: 0.96)
        let eyeRadius = max(1.2, (type == .tank ? 1.8 : 1.55) * scale)
        for x in [-4.0, 4.0] {
            let socket = SKShapeNode(circleOfRadius: eyeRadius + (0.8 * scale))
            socket.position = CGPoint(x: CGFloat(x) * scale, y: 24 * scale)
            socket.fillColor = NSColor.black.withAlphaComponent(0.62)
            socket.strokeColor = .clear
            eyes.addChild(socket)

            let eye = SKShapeNode(circleOfRadius: eyeRadius)
            eye.fillColor = eyeColor
            eye.strokeColor = .clear
            eye.glowWidth = WhyWaitPresentationPreferences.reduceVisualEffects ? 0 : 0.8
            socket.addChild(eye)
        }
        eyes.zPosition = 7

        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: -5 * scale, y: 17.5 * scale))
        mouthPath.addQuadCurve(
            to: CGPoint(x: 5 * scale, y: 17 * scale),
            control: CGPoint(x: 0, y: 14.5 * scale)
        )
        let mouth = SKShapeNode(path: mouthPath)
        mouth.strokeColor = outline.withAlphaComponent(0.82)
        mouth.lineWidth = max(1, 1.25 * scale)
        mouth.zPosition = 7
        bodyRoot.addChild(mouth)

        for x in [-2.5, 1.0, 4.0] {
            let tooth = SKShapeNode(rectOf: CGSize(width: 1.1 * scale, height: 2.3 * scale), cornerRadius: 0.4)
            tooth.position = CGPoint(x: CGFloat(x) * scale, y: 17 * scale)
            tooth.fillColor = NSColor(calibratedWhite: 0.78, alpha: 0.8)
            tooth.strokeColor = .clear
            tooth.zPosition = 8
            bodyRoot.addChild(tooth)
        }
    }

    private func addTorsoDetails(scale: CGFloat, color: NSColor, outline: NSColor) {
        let shirt = SKShapeNode()
        let shirtPath = CGMutablePath()
        let width = torsoWidthForType * scale
        shirtPath.move(to: CGPoint(x: -width * 0.42, y: 4 * scale))
        shirtPath.addLine(to: CGPoint(x: width * 0.42, y: 4 * scale))
        shirtPath.addLine(to: CGPoint(x: width * 0.32, y: -21 * scale))
        shirtPath.addLine(to: CGPoint(x: width * 0.08, y: -19 * scale))
        shirtPath.addLine(to: CGPoint(x: -width * 0.1, y: -23 * scale))
        shirtPath.addLine(to: CGPoint(x: -width * 0.34, y: -20 * scale))
        shirtPath.closeSubpath()
        shirt.path = shirtPath
        shirt.fillColor = clothingColor
        shirt.strokeColor = outline.withAlphaComponent(0.78)
        shirt.lineWidth = max(1, 1.15 * scale)
        shirt.zPosition = 3
        torso.addChild(shirt)

        let collar = SKShapeNode()
        let collarPath = CGMutablePath()
        collarPath.move(to: CGPoint(x: -7 * scale, y: 12 * scale))
        collarPath.addLine(to: CGPoint(x: 0, y: 5 * scale))
        collarPath.addLine(to: CGPoint(x: 7 * scale, y: 12 * scale))
        collar.path = collarPath
        collar.strokeColor = color.blended(withFraction: 0.28, of: .white) ?? color
        collar.lineWidth = max(1, 1.4 * scale)
        collar.zPosition = 4
        torso.addChild(collar)
    }

    private func addHand(
        to arm: SKShapeNode,
        scale: CGFloat,
        color: NSColor,
        outline: NSColor,
        armLength: CGFloat
    ) {
        let hand = SKShapeNode(circleOfRadius: max(2.4, 3.5 * scale))
        hand.position = CGPoint(x: 0, y: -armLength + (1.2 * scale))
        hand.fillColor = color.blended(withFraction: 0.12, of: .white) ?? color
        hand.strokeColor = outline
        hand.lineWidth = max(0.8, scale)
        arm.addChild(hand)

        for offset in [-2.0, 0.0, 2.0] {
            let finger = SKShapeNode(rectOf: CGSize(width: 1.3 * scale, height: 4 * scale), cornerRadius: 0.6)
            finger.position = CGPoint(x: CGFloat(offset) * scale, y: -armLength - (1.2 * scale))
            finger.fillColor = hand.fillColor
            finger.strokeColor = .clear
            arm.addChild(finger)
        }
    }

    private func addFoot(to leg: SKShapeNode, scale: CGFloat, outline: NSColor, legLength: CGFloat) {
        let foot = SKShapeNode(
            rectOf: CGSize(width: 11 * scale, height: 5.5 * scale),
            cornerRadius: 2.5 * scale
        )
        foot.position = CGPoint(x: 2.5 * scale, y: -legLength + (1.2 * scale))
        foot.fillColor = NSColor(calibratedWhite: 0.12, alpha: 0.98)
        foot.strokeColor = outline
        foot.lineWidth = max(0.8, scale)
        leg.addChild(foot)
    }

    private func buildTypeDetails(scale: CGFloat, bodyColor: NSColor, outline: NSColor) {
        switch type {
        case .walker:
            let hair = makeHairTuft(scale: scale, width: 13)
            hair.position = CGPoint(x: -1 * scale, y: 34 * scale)
            bodyRoot.addChild(hair)
        case .runner:
            bodyRoot.zRotation = -0.08
            let scarf = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -8 * scale, y: 11 * scale))
            path.addCurve(
                to: CGPoint(x: 10 * scale, y: 7 * scale),
                control1: CGPoint(x: 0, y: 6 * scale),
                control2: CGPoint(x: 5 * scale, y: 11 * scale)
            )
            path.addLine(to: CGPoint(x: 15 * scale, y: 1 * scale))
            scarf.path = path
            scarf.strokeColor = NSColor(calibratedRed: 0.76, green: 0.25, blue: 0.18, alpha: 0.95)
            scarf.lineWidth = 3 * scale
            scarf.lineCap = .round
            scarf.zPosition = 6
            bodyRoot.addChild(scarf)
        case .tank:
            for x in [-16.0, 16.0] {
                let shoulder = SKShapeNode(circleOfRadius: 8 * scale)
                shoulder.position = CGPoint(x: CGFloat(x) * scale, y: 8 * scale)
                shoulder.fillColor = bodyColor.blended(withFraction: 0.2, of: .black) ?? bodyColor
                shoulder.strokeColor = outline
                shoulder.lineWidth = 1.5 * scale
                shoulder.zPosition = 3
                bodyRoot.addChild(shoulder)
            }
            let brow = SKShapeNode(rectOf: CGSize(width: 17 * scale, height: 3.5 * scale), cornerRadius: 1.5)
            brow.position = CGPoint(x: 0, y: 27 * scale)
            brow.fillColor = outline
            brow.strokeColor = .clear
            brow.zPosition = 8
            bodyRoot.addChild(brow)
        case .shambler:
            let hair = makeHairTuft(scale: scale, width: 17)
            hair.position = CGPoint(x: -6 * scale, y: 34 * scale)
            hair.zRotation = -0.16
            bodyRoot.addChild(hair)
            let patch = SKShapeNode(rectOf: CGSize(width: 8 * scale, height: 7 * scale), cornerRadius: 1.5)
            patch.position = CGPoint(x: 6 * scale, y: -7 * scale)
            patch.fillColor = NSColor(calibratedRed: 0.42, green: 0.31, blue: 0.15, alpha: 0.85)
            patch.strokeColor = NSColor.black.withAlphaComponent(0.4)
            patch.lineWidth = 0.8
            patch.zRotation = 0.16
            patch.zPosition = 5
            bodyRoot.addChild(patch)
        case .armored:
            buildArmor(scale: scale, outline: outline)
        }
    }

    private func buildArmor(scale: CGFloat, outline: NSColor) {
        let platePath = CGMutablePath()
        platePath.move(to: CGPoint(x: -15 * scale, y: 9 * scale))
        platePath.addLine(to: CGPoint(x: 15 * scale, y: 9 * scale))
        platePath.addLine(to: CGPoint(x: 12 * scale, y: -14 * scale))
        platePath.addLine(to: CGPoint(x: 0, y: -20 * scale))
        platePath.addLine(to: CGPoint(x: -12 * scale, y: -14 * scale))
        platePath.closeSubpath()
        let plate = SKShapeNode(path: platePath)
        plate.fillColor = NSColor(calibratedRed: 0.27, green: 0.31, blue: 0.34, alpha: 0.98)
        plate.strokeColor = NSColor(calibratedRed: 0.73, green: 0.78, blue: 0.81, alpha: 0.94)
        plate.lineWidth = 1.8 * scale
        armorRoot.addChild(plate)

        let ridge = SKShapeNode(rectOf: CGSize(width: 3 * scale, height: 20 * scale), cornerRadius: 1.2)
        ridge.position = CGPoint(x: 0, y: -2 * scale)
        ridge.fillColor = NSColor.white.withAlphaComponent(0.2)
        ridge.strokeColor = .clear
        plate.addChild(ridge)

        let helmetPath = CGMutablePath()
        helmetPath.move(to: CGPoint(x: -13 * scale, y: 23 * scale))
        helmetPath.addCurve(
            to: CGPoint(x: 13 * scale, y: 23 * scale),
            control1: CGPoint(x: -11 * scale, y: 38 * scale),
            control2: CGPoint(x: 11 * scale, y: 38 * scale)
        )
        helmetPath.addLine(to: CGPoint(x: 11 * scale, y: 19 * scale))
        helmetPath.addLine(to: CGPoint(x: -11 * scale, y: 19 * scale))
        helmetPath.closeSubpath()
        let helmet = SKShapeNode(path: helmetPath)
        helmet.fillColor = NSColor(calibratedWhite: 0.31, alpha: 0.99)
        helmet.strokeColor = NSColor(calibratedWhite: 0.78, alpha: 0.95)
        helmet.lineWidth = 1.7 * scale
        armorRoot.addChild(helmet)

        let visorPath = CGMutablePath()
        visorPath.move(to: CGPoint(x: -10 * scale, y: 25 * scale))
        visorPath.addLine(to: CGPoint(x: 10 * scale, y: 25 * scale))
        let visor = SKShapeNode(path: visorPath)
        visor.strokeColor = outline.withAlphaComponent(0.9)
        visor.lineWidth = 2.2 * scale
        armorRoot.addChild(visor)

        for x in [-16.0, 16.0] {
            let shoulder = SKShapeNode(
                rectOf: CGSize(width: 12 * scale, height: 8 * scale),
                cornerRadius: 3 * scale
            )
            shoulder.position = CGPoint(x: CGFloat(x) * scale, y: 8 * scale)
            shoulder.fillColor = NSColor(calibratedWhite: 0.32, alpha: 0.98)
            shoulder.strokeColor = NSColor(calibratedWhite: 0.72, alpha: 0.9)
            shoulder.lineWidth = 1.2 * scale
            armorRoot.addChild(shoulder)
        }
        armorRoot.zPosition = 6
    }

    private func makeHairTuft(scale: CGFloat, width: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width * 0.5 * scale, y: -2 * scale))
        path.addLine(to: CGPoint(x: -width * 0.26 * scale, y: 4 * scale))
        path.addLine(to: CGPoint(x: -2 * scale, y: 1 * scale))
        path.addLine(to: CGPoint(x: 2 * scale, y: 6 * scale))
        path.addLine(to: CGPoint(x: width * 0.25 * scale, y: 1 * scale))
        path.addLine(to: CGPoint(x: width * 0.5 * scale, y: 3 * scale))
        let hair = SKShapeNode(path: path)
        hair.strokeColor = NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.07, alpha: 0.92)
        hair.lineWidth = 3 * scale
        hair.lineCap = .round
        hair.zPosition = 8
        return hair
    }

    private func buildAttackTelegraph(scale: CGFloat) {
        let arcPath = CGMutablePath()
        arcPath.addArc(
            center: CGPoint(x: 0, y: 9 * scale),
            radius: 24 * scale,
            startAngle: .pi * 0.12,
            endAngle: .pi * 0.88,
            clockwise: false
        )
        let arc = SKShapeNode(path: arcPath)
        arc.strokeColor = NSColor.systemOrange.withAlphaComponent(0.9)
        arc.lineWidth = max(1.3, 1.8 * scale)
        arc.lineCap = .round
        arc.glowWidth = WhyWaitPresentationPreferences.reduceVisualEffects ? 0 : 2
        attackTelegraph.addChild(arc)

        let marker = SKShapeNode(circleOfRadius: 3 * scale)
        marker.position = CGPoint(x: 0, y: 36 * scale)
        marker.fillColor = NSColor.systemOrange.withAlphaComponent(0.92)
        marker.strokeColor = NSColor.white.withAlphaComponent(0.72)
        marker.lineWidth = 0.8
        attackTelegraph.addChild(marker)
        attackTelegraph.zPosition = 10
        attackTelegraph.alpha = 0
    }

    private func playSpawnAura() {
        guard !WhyWaitPresentationPreferences.reduceVisualEffects else {
            spawnAura.alpha = 0
            return
        }
        spawnAura.setScale(0.6)
        spawnAura.alpha = 0.9
        spawnAura.run(.sequence([
            .group([.scale(to: 1.35, duration: 0.34), .fadeOut(withDuration: 0.34)]),
            .removeFromParent()
        ]))
    }

    private func worldPoint(_ point: CGPoint) -> CGPoint {
        parent?.convert(point, from: bodyRoot)
            ?? CGPoint(x: position.x + point.x, y: position.y + point.y)
    }
}
