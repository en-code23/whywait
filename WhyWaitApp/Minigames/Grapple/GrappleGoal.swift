import SpriteKit

final class GrappleGoal: SKNode {
    let radius: CGFloat = GrappleTuning.goalRadius

    private let glow = SKShapeNode(circleOfRadius: GrappleTuning.goalRadius + 7)
    private let outerRing = SKShapeNode(circleOfRadius: GrappleTuning.goalRadius)
    private let innerRing = SKShapeNode(circleOfRadius: GrappleTuning.goalRadius - 8)
    private let rays = SKShapeNode(path: GrappleGoal.makeRayPath())
    private let star = SKShapeNode(path: GrappleGoal.makeStarPath())
    private let reduceVisualEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GrappleGoal does not support NSCoding")
    }

    func setActive(_ isActive: Bool) {
        removeAction(forKey: "goal-pulse")
        rays.removeAction(forKey: "goal-orbit")
        alpha = isActive ? 1 : 0.28
        outerRing.strokeColor = isActive
            ? SKColor(calibratedRed: 1, green: 0.82, blue: 0.22, alpha: 0.98)
            : SKColor.white.withAlphaComponent(0.45)
        innerRing.strokeColor = isActive
            ? SKColor(calibratedRed: 1, green: 0.91, blue: 0.5, alpha: 0.68)
            : SKColor.white.withAlphaComponent(0.24)
        star.fillColor = isActive
            ? SKColor(calibratedRed: 1, green: 0.82, blue: 0.22, alpha: 0.98)
            : SKColor.white.withAlphaComponent(0.5)
        glow.alpha = isActive ? 0.16 : 0.03
        rays.strokeColor = isActive
            ? SKColor(calibratedRed: 1, green: 0.85, blue: 0.3, alpha: 0.58)
            : SKColor.white.withAlphaComponent(0.18)

        if isActive, !reduceVisualEffects {
            run(
                .repeatForever(
                    .sequence([
                        .scale(to: 1.07, duration: 0.48),
                        .scale(to: 0.98, duration: 0.48)
                    ])
                ),
                withKey: "goal-pulse"
            )
            rays.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 7)), withKey: "goal-orbit")
        } else {
            setScale(1)
        }
    }

    func playCompletion() {
        removeAction(forKey: "goal-pulse")
        rays.removeAction(forKey: "goal-orbit")
        run(
            .sequence([
                .scale(to: reduceVisualEffects ? 1.16 : 1.38, duration: 0.12),
                .scale(to: 1, duration: 0.26)
            ])
        )
    }

    private func configure() {
        name = "grapple-goal"
        zPosition = 26

        glow.fillColor = SKColor(calibratedRed: 1, green: 0.75, blue: 0.14, alpha: 1)
        glow.strokeColor = .clear
        glow.zPosition = -2
        addChild(glow)

        let shadow = SKShapeNode(circleOfRadius: GrappleTuning.goalRadius + 1)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.12)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2.5, y: -2.5)
        shadow.zPosition = -1
        addChild(shadow)

        outerRing.fillColor = SKColor.black.withAlphaComponent(0.07)
        outerRing.lineWidth = 3
        addChild(outerRing)

        innerRing.fillColor = SKColor(calibratedWhite: 0.1, alpha: 0.18)
        innerRing.lineWidth = 1
        addChild(innerRing)

        rays.fillColor = .clear
        rays.lineWidth = 1.5
        rays.lineCap = .round
        addChild(rays)

        star.strokeColor = SKColor.white.withAlphaComponent(0.78)
        star.lineWidth = 0.9
        star.lineJoin = .round
        star.position.y = 0.5
        addChild(star)

        setActive(false)
    }

    private static func makeStarPath() -> CGPath {
        let path = CGMutablePath()
        let outer: CGFloat = 13
        let inner: CGFloat = 6
        for index in 0..<10 {
            let angle = (.pi / 2) + CGFloat(index) * (.pi / 5)
            let currentRadius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(
                x: cos(angle) * currentRadius,
                y: sin(angle) * currentRadius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func makeRayPath() -> CGPath {
        let path = CGMutablePath()
        for angle in stride(from: CGFloat(0), to: .pi * 2, by: .pi / 4) {
            path.move(to: CGPoint(x: cos(angle) * 25, y: sin(angle) * 25))
            path.addLine(to: CGPoint(x: cos(angle) * 29, y: sin(angle) * 29))
        }
        return path
    }
}
