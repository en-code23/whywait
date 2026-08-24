import SpriteKit

final class FishingEffects: SKNode {
    override init() {
        super.init()
        name = "fishing-effects"
        zPosition = 65
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FishingEffects does not support NSCoding")
    }

    func addRipple(at position: CGPoint, strong: Bool = false) {
        trimIfNeeded(adding: 2)
        let count = strong && !WhyWaitPresentationPreferences.reduceVisualEffects ? 2 : 1
        for index in 0..<count {
            let ring = SKShapeNode(ellipseOf: CGSize(width: 24, height: 9))
            ring.position = position
            ring.fillColor = .clear
            ring.strokeColor = SKColor(
                calibratedRed: 0.48,
                green: 0.84,
                blue: 1,
                alpha: strong ? 0.72 : 0.44
            )
            ring.lineWidth = strong ? 1.5 : 1
            ring.alpha = 0
            addChild(ring)
            ring.run(
                .sequence([
                    .wait(forDuration: Double(index) * 0.08),
                    .group([
                        .fadeAlpha(to: strong ? 0.85 : 0.58, duration: 0.06),
                        .scale(to: strong ? 2.2 : 1.7, duration: strong ? 0.42 : 0.5)
                    ]),
                    .fadeOut(withDuration: 0.18),
                    .removeFromParent()
                ])
            )
        }
    }

    func addSplash(at position: CGPoint, color: SKColor = .white, count: Int = 7) {
        let requestedCount = WhyWaitPresentationPreferences.reduceVisualEffects
            ? max(3, count / 2)
            : count
        let boundedCount = min(12, max(3, requestedCount))
        trimIfNeeded(adding: boundedCount)
        for index in 0..<boundedCount {
            let droplet = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.2...2.3))
            droplet.position = position
            droplet.fillColor = color.withAlphaComponent(0.82)
            droplet.strokeColor = .clear
            addChild(droplet)
            let angle = (CGFloat(index) / CGFloat(boundedCount)) * .pi
                + CGFloat.random(in: -0.22...0.22)
            let distance = CGFloat.random(in: 12...30)
            droplet.run(
                .sequence([
                    .group([
                        .moveBy(
                            x: cos(angle) * distance,
                            y: abs(sin(angle)) * distance - 7,
                            duration: 0.34
                        ),
                        .fadeOut(withDuration: 0.34),
                        .scale(to: 0.35, duration: 0.34)
                    ]),
                    .removeFromParent()
                ])
            )
        }
    }

    func addFishShadow(
        near position: CGPoint,
        definition: FishDefinition,
        legendaryHint: Bool
    ) {
        trimIfNeeded(adding: 1)
        let shadow = FishNode(
            definition: definition,
            sizePercentile: legendaryHint ? 0.85 : 0.45,
            shadowOnly: true
        )
        shadow.position = CGPoint(
            x: position.x + CGFloat.random(in: -54...34),
            y: position.y + CGFloat.random(in: -34 ... -17)
        )
        shadow.alpha = 0
        addChild(shadow)
        let horizontalTravel: CGFloat = legendaryHint ? 72 : 46
        shadow.run(
            .sequence([
                .fadeAlpha(to: legendaryHint ? 0.42 : 0.28, duration: 0.2),
                .group([
                    .moveBy(x: horizontalTravel, y: CGFloat.random(in: -8...8), duration: 0.72),
                    .sequence([
                        .wait(forDuration: 0.38),
                        .fadeOut(withDuration: 0.34)
                    ])
                ]),
                .removeFromParent()
            ])
        )
    }

    func clearTransientEffects() {
        removeAllActions()
        removeAllChildren()
    }

    private func trimIfNeeded(adding count: Int) {
        while children.count + count > FishingTuning.maximumEffectNodes {
            children.first?.removeFromParent()
        }
    }
}
