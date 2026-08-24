import SpriteKit

enum GrappleCheckpointVisualState {
    case future
    case next
    case completed
}

final class GrappleCheckpoint: SKNode {
    let index: Int
    let radius: CGFloat

    private let outerRing: SKShapeNode
    private let innerRing: SKShapeNode
    private let halo: SKShapeNode
    private let ticks = SKShapeNode()
    private let core = SKShapeNode(circleOfRadius: 3.2)
    private let checkmark = SKShapeNode()
    private let reduceVisualEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    init(index: Int, radius: CGFloat = GrappleTuning.checkpointRadius) {
        self.index = index
        self.radius = radius
        outerRing = SKShapeNode(circleOfRadius: radius)
        innerRing = SKShapeNode(circleOfRadius: radius - 6)
        halo = SKShapeNode(circleOfRadius: radius + 5)
        super.init()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GrappleCheckpoint does not support NSCoding")
    }

    func setVisualState(_ state: GrappleCheckpointVisualState) {
        removeAction(forKey: "pulse")
        ticks.removeAction(forKey: "orbit")
        setScale(1)

        switch state {
        case .future:
            alpha = 0.32
            outerRing.strokeColor = SKColor.white.withAlphaComponent(0.72)
            innerRing.strokeColor = SKColor.white.withAlphaComponent(0.32)
            halo.alpha = 0.05
            ticks.strokeColor = SKColor.white.withAlphaComponent(0.24)
            core.fillColor = SKColor.white.withAlphaComponent(0.32)
            checkmark.isHidden = true
        case .next:
            alpha = 0.95
            outerRing.strokeColor = SKColor(
                calibratedRed: 0.34,
                green: 0.88,
                blue: 1,
                alpha: 0.96
            )
            innerRing.strokeColor = SKColor.white.withAlphaComponent(0.62)
            halo.alpha = 0.16
            ticks.strokeColor = SKColor(
                calibratedRed: 0.45,
                green: 0.92,
                blue: 1,
                alpha: 0.72
            )
            core.fillColor = SKColor(calibratedRed: 0.5, green: 0.96, blue: 1, alpha: 0.9)
            checkmark.isHidden = true
            if !reduceVisualEffects {
                run(
                    .repeatForever(
                        .sequence([
                            .scale(to: 1.06, duration: 0.55),
                            .scale(to: 0.97, duration: 0.55)
                        ])
                    ),
                    withKey: "pulse"
                )
                ticks.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 5)), withKey: "orbit")
            }
        case .completed:
            alpha = 0.68
            outerRing.strokeColor = SKColor(
                calibratedRed: 0.38,
                green: 0.96,
                blue: 0.62,
                alpha: 0.88
            )
            innerRing.strokeColor = SKColor(
                calibratedRed: 0.38,
                green: 0.96,
                blue: 0.62,
                alpha: 0.32
            )
            halo.alpha = 0.08
            ticks.strokeColor = SKColor(
                calibratedRed: 0.38,
                green: 0.96,
                blue: 0.62,
                alpha: 0.45
            )
            core.fillColor = SKColor(calibratedRed: 0.38, green: 0.96, blue: 0.62, alpha: 0.75)
            checkmark.isHidden = false
        }
    }

    func playActivation() {
        removeAction(forKey: "pulse")
        run(
            .sequence([
                .scale(to: 1.32, duration: 0.08),
                .scale(to: 1, duration: 0.2)
            ])
        )
    }

    private func configure() {
        name = "grapple-checkpoint-\(index)"
        zPosition = 24

        halo.fillColor = SKColor(calibratedRed: 0.34, green: 0.88, blue: 1, alpha: 1)
        halo.strokeColor = .clear
        halo.alpha = 0.05
        halo.zPosition = -2
        addChild(halo)

        let shadow = SKShapeNode(circleOfRadius: radius + 1)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.08)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        addChild(shadow)

        outerRing.fillColor = .clear
        outerRing.lineWidth = 2.2
        addChild(outerRing)

        innerRing.fillColor = .clear
        innerRing.lineWidth = 1
        addChild(innerRing)

        let tickPath = CGMutablePath()
        for angle in stride(from: CGFloat(0), to: .pi * 2, by: .pi / 4) {
            tickPath.move(to: CGPoint(x: cos(angle) * (radius - 3), y: sin(angle) * (radius - 3)))
            tickPath.addLine(to: CGPoint(x: cos(angle) * (radius + 1), y: sin(angle) * (radius + 1)))
        }
        ticks.path = tickPath
        ticks.fillColor = .clear
        ticks.lineWidth = 1.25
        ticks.lineCap = .round
        addChild(ticks)

        core.strokeColor = SKColor.white.withAlphaComponent(0.42)
        core.lineWidth = 0.7
        addChild(core)

        let checkPath = CGMutablePath()
        checkPath.move(to: CGPoint(x: -5, y: 0))
        checkPath.addLine(to: CGPoint(x: -1, y: -4))
        checkPath.addLine(to: CGPoint(x: 6, y: 5))
        checkmark.path = checkPath
        checkmark.strokeColor = SKColor(calibratedRed: 0.72, green: 1, blue: 0.82, alpha: 0.94)
        checkmark.lineWidth = 2.2
        checkmark.lineCap = .round
        checkmark.lineJoin = .round
        checkmark.isHidden = true
        addChild(checkmark)

        setVisualState(.future)
    }
}
