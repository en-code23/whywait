import SpriteKit

final class FishingBobber: SKNode {
    private let waterShadow = SKShapeNode(ellipseOf: CGSize(width: 27, height: 8))
    private let waterline = SKShapeNode(ellipseOf: CGSize(width: 23, height: 6))
    private let bodyShadow = SKShapeNode(ellipseOf: CGSize(width: 17, height: 22))
    private let body = SKShapeNode(ellipseOf: CGSize(width: 15, height: 20))
    private let redCap = SKShapeNode()
    private let seam = SKShapeNode()
    private let highlight = SKShapeNode(ellipseOf: CGSize(width: 3.2, height: 6.5))
    private let stem = SKShapeNode(rectOf: CGSize(width: 2.4, height: 15), cornerRadius: 1.2)
    private let stemTip = SKShapeNode(rectOf: CGSize(width: 3.4, height: 5), cornerRadius: 1.4)
    private let keel = SKShapeNode(rectOf: CGSize(width: 1.5, height: 7), cornerRadius: 0.75)
    private let eyelet = SKShapeNode(circleOfRadius: 1.6)

    override init() {
        super.init()
        name = "fishing-bobber"
        zPosition = 90
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FishingBobber does not support NSCoding")
    }

    func prepareForFlight() {
        removeAllActions()
        waterline.removeAllActions()
        waterline.setScale(1)
        isHidden = false
        alpha = 1
        setScale(0.84)
        zRotation = -0.24
        waterShadow.alpha = 0
        waterline.alpha = 0
    }

    func updateFlight(progress: CGFloat) {
        zRotation = -0.24 + (progress * .pi * 1.55)
        setScale(0.84 + (sin(progress * .pi) * 0.17))
    }

    func land() {
        removeAllActions()
        waterline.removeAllActions()
        waterline.setScale(1)
        setScale(1)
        zRotation = 0
        waterShadow.alpha = 0.28
        waterline.alpha = 0.56
        runIdleBob()
    }

    func twitch(intensity: CGFloat = 1) {
        removeAction(forKey: "bobber-idle")
        let amount = max(1, min(4, intensity * 3))
        run(
            .sequence([
                .group([
                    .moveBy(x: -amount, y: -2.5, duration: 0.06),
                    .rotate(toAngle: -0.1, duration: 0.06)
                ]),
                .group([
                    .moveBy(x: amount * 1.8, y: 3.5, duration: 0.075),
                    .rotate(toAngle: 0.12, duration: 0.075)
                ]),
                .group([
                    .moveBy(x: -amount * 0.8, y: -1, duration: 0.07),
                    .rotate(toAngle: 0, duration: 0.07)
                ]),
                .run { [weak self] in self?.runIdleBob() }
            ]),
            withKey: "bobber-twitch"
        )
    }

    func bite() {
        removeAllActions()
        run(
            .repeatForever(
                .sequence([
                    .group([
                        .moveBy(x: 0, y: -10, duration: 0.09),
                        .scaleY(to: 0.84, duration: 0.09)
                    ]),
                    .group([
                        .moveBy(x: 0, y: 8, duration: 0.13),
                        .scaleY(to: 1.05, duration: 0.13)
                    ]),
                    .group([
                        .moveBy(x: 0, y: 2, duration: 0.08),
                        .scaleY(to: 1, duration: 0.08)
                    ])
                ])
            ),
            withKey: "bobber-bite"
        )
    }

    func resetVisual() {
        removeAllActions()
        waterline.removeAllActions()
        waterline.setScale(1)
        waterline.alpha = 0
        waterShadow.alpha = 0
        isHidden = true
        alpha = 1
        setScale(1)
        zRotation = 0
    }

    private func runIdleBob() {
        removeAction(forKey: "bobber-idle")
        run(
            .repeatForever(
                .sequence([
                    .group([
                        .moveBy(x: 0, y: 1.7, duration: 0.56),
                        .rotate(toAngle: 0.025, duration: 0.56)
                    ]),
                    .group([
                        .moveBy(x: 0, y: -1.7, duration: 0.56),
                        .rotate(toAngle: -0.025, duration: 0.56)
                    ])
                ])
            ),
            withKey: "bobber-idle"
        )
        guard !WhyWaitPresentationPreferences.reduceVisualEffects else { return }
        waterline.removeAllActions()
        waterline.run(
            .repeatForever(
                .sequence([
                    .group([.scale(to: 1.16, duration: 0.75), .fadeAlpha(to: 0.22, duration: 0.75)]),
                    .group([.scale(to: 1, duration: 0), .fadeAlpha(to: 0.56, duration: 0)])
                ])
            )
        )
    }

    private func configure() {
        waterShadow.position = CGPoint(x: 0, y: -9)
        waterShadow.fillColor = SKColor.black.withAlphaComponent(0.24)
        waterShadow.strokeColor = .clear
        addChild(waterShadow)

        waterline.position = CGPoint(x: 0, y: -7)
        waterline.fillColor = .clear
        waterline.strokeColor = SKColor(calibratedRed: 0.57, green: 0.9, blue: 1, alpha: 0.62)
        waterline.lineWidth = 0.9
        addChild(waterline)

        bodyShadow.position = CGPoint(x: 1, y: -1.2)
        bodyShadow.fillColor = SKColor.black.withAlphaComponent(0.36)
        bodyShadow.strokeColor = .clear
        addChild(bodyShadow)

        body.fillColor = SKColor(calibratedWhite: 0.96, alpha: 1)
        body.strokeColor = SKColor.black.withAlphaComponent(0.55)
        body.lineWidth = 1
        addChild(body)

        let capPath = CGMutablePath()
        capPath.move(to: CGPoint(x: -7.1, y: 1.1))
        capPath.addCurve(
            to: CGPoint(x: 7.1, y: 1.1),
            control1: CGPoint(x: -6.5, y: 8.5),
            control2: CGPoint(x: 6.5, y: 8.5)
        )
        capPath.addQuadCurve(to: CGPoint(x: -7.1, y: 1.1), control: CGPoint(x: 0, y: -0.2))
        redCap.path = capPath
        redCap.fillColor = SKColor(calibratedRed: 0.93, green: 0.13, blue: 0.1, alpha: 1)
        redCap.strokeColor = .clear
        addChild(redCap)

        let seamPath = CGMutablePath()
        seamPath.move(to: CGPoint(x: -7.2, y: 1))
        seamPath.addQuadCurve(to: CGPoint(x: 7.2, y: 1), control: CGPoint(x: 0, y: -0.2))
        seam.path = seamPath
        seam.strokeColor = SKColor.black.withAlphaComponent(0.35)
        seam.lineWidth = 0.8
        addChild(seam)

        highlight.position = CGPoint(x: -3.4, y: 3.4)
        highlight.fillColor = SKColor.white.withAlphaComponent(0.72)
        highlight.strokeColor = .clear
        highlight.zRotation = -0.24
        addChild(highlight)

        stem.position = CGPoint(x: 0, y: 16)
        stem.fillColor = SKColor(calibratedWhite: 0.92, alpha: 1)
        stem.strokeColor = SKColor.black.withAlphaComponent(0.42)
        stem.lineWidth = 0.65
        addChild(stem)

        stemTip.position = CGPoint(x: 0, y: 22.5)
        stemTip.fillColor = SKColor(calibratedRed: 0.95, green: 0.18, blue: 0.13, alpha: 1)
        stemTip.strokeColor = SKColor.black.withAlphaComponent(0.36)
        stemTip.lineWidth = 0.6
        addChild(stemTip)

        keel.position = CGPoint(x: 0, y: -13)
        keel.fillColor = SKColor(calibratedWhite: 0.74, alpha: 0.92)
        keel.strokeColor = .clear
        addChild(keel)

        eyelet.position = CGPoint(x: 0, y: -17)
        eyelet.fillColor = .clear
        eyelet.strokeColor = SKColor(calibratedWhite: 0.75, alpha: 0.9)
        eyelet.lineWidth = 0.8
        addChild(eyelet)
        isHidden = true
    }
}
