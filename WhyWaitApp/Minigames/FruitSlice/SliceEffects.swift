import SpriteKit

enum SliceEffects {
    private static let reduceVisualEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    static func makeHalves(
        from fruit: FruitNode,
        blade: CuttingBladeSegment
    ) -> [FruitHalfNode] {
        let normal = CGVector(dx: -blade.direction.dy, dy: blade.direction.dx)
        let speedRatio = min(1, blade.speed / FruitSliceTuning.maximumAcceptedCursorSpeed)
        let separationSpeed = FruitSliceTuning.halfBaseSeparationSpeed
            + (FruitSliceTuning.halfMaximumSwipeImpulse * speedRatio)
        let forwardSpeed = min(
            FruitSliceTuning.halfMaximumSwipeImpulse,
            blade.speed * FruitSliceTuning.halfForwardInfluence
        )
        let inherited = fruit.launchVelocity
        let cutAngle = atan2(blade.direction.dy, blade.direction.dx)

        return [-1, 1].map { rawSign in
            let sign = CGFloat(rawSign)
            let velocity = CGVector(
                dx: (inherited.dx * 0.82)
                    + (blade.direction.dx * forwardSpeed)
                    + (normal.dx * separationSpeed * sign),
                dy: (inherited.dy * 0.82)
                    + (blade.direction.dy * forwardSpeed)
                    + (normal.dy * separationSpeed * sign)
            )
            let half = FruitHalfNode(
                type: fruit.fruitType,
                halfSign: sign,
                cutAngle: cutAngle,
                velocity: velocity,
                angularVelocity: sign * (2.8 + (speedRatio * 4.2))
            )
            half.position = CGPoint(
                x: fruit.position.x + (normal.dx * sign * 4),
                y: fruit.position.y + (normal.dy * sign * 4)
            )
            return half
        }
    }

    static func addJuiceBurst(
        to parent: SKNode,
        at position: CGPoint,
        color: SKColor,
        blade: CuttingBladeSegment,
        isPerfect: Bool
    ) {
        let requestedCount = isPerfect
            ? FruitSliceTuning.perfectParticleCount
            : FruitSliceTuning.standardParticleCount
        let count = reduceVisualEffects ? max(3, requestedCount / 2) : requestedCount
        let speedRatio = min(1, blade.speed / FruitSliceTuning.maximumAcceptedCursorSpeed)
        let normal = CGVector(dx: -blade.direction.dy, dy: blade.direction.dx)

        for index in 0..<count {
            let sign: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let spread = CGFloat.random(in: 28...70) * (0.75 + speedRatio)
            let forward = CGFloat.random(in: 15...55) * speedRatio
            let movement = CGVector(
                dx: (normal.dx * spread * sign)
                    + (blade.direction.dx * forward)
                    + CGFloat.random(in: -18...18),
                dy: (normal.dy * spread * sign)
                    + (blade.direction.dy * forward)
                    + CGFloat.random(in: -18...28)
            )
            let particle = SKShapeNode(path: dropletPath(size: CGFloat.random(in: 2.2...4.2)))
            particle.fillColor = color.withAlphaComponent(0.86)
            particle.strokeColor = SKColor.white.withAlphaComponent(0.16)
            particle.lineWidth = 0.4
            particle.position = position
            particle.zRotation = atan2(movement.dy, movement.dx) - (.pi / 2)
            particle.zPosition = 80
            parent.addChild(particle)
            let duration = TimeInterval.random(in: 0.3...0.46)
            particle.run(
                .sequence([
                    .group([
                        .move(by: movement, duration: duration),
                        .fadeOut(withDuration: duration),
                        .scale(to: 0.35, duration: duration)
                    ]),
                    .removeFromParent()
                ])
            )
        }

        guard isPerfect, !reduceVisualEffects else { return }
        let glint = SKShapeNode(path: slashGlintPath(length: 34))
        glint.position = position
        glint.zRotation = atan2(blade.direction.dy, blade.direction.dx)
        glint.strokeColor = SKColor.white.withAlphaComponent(0.82)
        glint.lineWidth = 1.3
        glint.lineCap = .round
        glint.zPosition = 84
        parent.addChild(glint)
        glint.run(
            .sequence([
                .group([
                    .scaleX(to: 1.45, duration: 0.18),
                    .fadeOut(withDuration: 0.22)
                ]),
                .removeFromParent()
            ])
        )
    }

    static func addBombBurst(to parent: SKNode, at position: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 18)
        ring.position = position
        ring.fillColor = .clear
        ring.strokeColor = SKColor(calibratedRed: 1, green: 0.42, blue: 0.15, alpha: 0.9)
        ring.lineWidth = 3
        ring.zPosition = 90
        parent.addChild(ring)
        ring.run(
            .sequence([
                .group([
                    .scale(to: 2.2, duration: 0.28),
                    .fadeOut(withDuration: 0.28)
                ]),
                .removeFromParent()
            ])
        )

        let particleCount = reduceVisualEffects
            ? max(6, FruitSliceTuning.bombParticleCount / 2)
            : FruitSliceTuning.bombParticleCount
        for index in 0..<particleCount {
            let angle = (CGFloat(index) / CGFloat(particleCount))
                * .pi * 2
                + CGFloat.random(in: -0.12...0.12)
            let distance = CGFloat.random(in: 34...76)
            let spark = SKShapeNode(path: sparkPath(length: CGFloat.random(in: 7...13)))
            spark.fillColor = index.isMultiple(of: 2)
                ? SKColor(calibratedRed: 1, green: 0.68, blue: 0.12, alpha: 0.92)
                : SKColor(calibratedRed: 1, green: 0.25, blue: 0.12, alpha: 0.9)
            spark.strokeColor = .clear
            spark.position = position
            spark.zRotation = angle - (.pi / 2)
            spark.zPosition = 91
            parent.addChild(spark)
            let movement = CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance)
            spark.run(
                .sequence([
                    .group([
                        .move(by: movement, duration: 0.34),
                        .fadeOut(withDuration: 0.34),
                        .scale(to: 0.25, duration: 0.34)
                    ]),
                    .removeFromParent()
                ])
            )
        }


        guard !reduceVisualEffects else { return }
        for index in 0..<4 {
            let smoke = SKShapeNode(circleOfRadius: CGFloat(5 + index))
            smoke.fillColor = SKColor(calibratedWhite: 0.1, alpha: 0.34)
            smoke.strokeColor = SKColor.white.withAlphaComponent(0.06)
            smoke.lineWidth = 0.6
            smoke.position = position
            smoke.zPosition = 89
            parent.addChild(smoke)
            let angle = CGFloat(index) * (.pi / 2) + 0.35
            smoke.run(
                .sequence([
                    .group([
                        .move(by: CGVector(dx: cos(angle) * 28, dy: sin(angle) * 28), duration: 0.42),
                        .scale(to: 1.7, duration: 0.42),
                        .fadeOut(withDuration: 0.42)
                    ]),
                    .removeFromParent()
                ])
            )
        }
    }

    private static func dropletPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size * 1.55))
        path.addCurve(
            to: CGPoint(x: 0, y: -size),
            control1: CGPoint(x: size * 1.15, y: size * 0.4),
            control2: CGPoint(x: size, y: -size)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: size * 1.55),
            control1: CGPoint(x: -size, y: -size),
            control2: CGPoint(x: -size * 1.15, y: size * 0.4)
        )
        path.closeSubpath()
        return path
    }

    private static func slashGlintPath(length: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -length / 2, y: 0))
        path.addLine(to: CGPoint(x: length / 2, y: 0))
        path.move(to: CGPoint(x: 0, y: -5))
        path.addLine(to: CGPoint(x: 0, y: 5))
        return path
    }

    private static func sparkPath(length: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -1.2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: length))
        path.addLine(to: CGPoint(x: 1.2, y: 0))
        path.closeSubpath()
        return path
    }
}
