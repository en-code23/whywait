import SpriteKit

final class FruitSliceHUD: SKNode {
    private let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let scoreShadow = SKLabelNode(fontNamed: "Menlo-Bold")
    private let livesLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let livesShadow = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let feedbackContainer = SKNode()
    private let feedbackTitle = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let feedbackSubtitle = SKLabelNode(fontNamed: "Menlo-Bold")
    private let transientLayer = SKNode()

    override init() {
        super.init()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FruitSliceHUD does not support NSCoding")
    }

    func setScore(_ score: Int) {
        let text = "\(score)"
        scoreLabel.text = text
        scoreShadow.text = text
    }

    func setLives(_ lives: Int) {
        let text = Array(repeating: "♥", count: max(0, lives)).joined(separator: "  ")
        livesLabel.text = text
        livesShadow.text = text
    }

    func showCombo(_ count: Int, at position: CGPoint) {
        guard count >= 2 else {
            return
        }

        showTransient(
            count >= 4 ? "×\(count)!" : "×\(count)",
            at: CGPoint(x: position.x, y: position.y + 24),
            color: SKColor(calibratedRed: 1, green: 0.82, blue: 0.24, alpha: 0.96),
            fontSize: 17
        )
    }

    func showPerfect(at position: CGPoint) {
        showTransient(
            "PERFECT",
            at: CGPoint(x: position.x, y: position.y - 25),
            color: SKColor(calibratedRed: 0.62, green: 0.94, blue: 1, alpha: 0.96),
            fontSize: 11
        )
    }

    func showGameOver(score: Int, reason: FruitSliceGameOverReason) {
        feedbackTitle.text = reason == .bomb ? "BOOM" : "GAME OVER"
        feedbackSubtitle.text = reason == .bomb
            ? "GAME OVER  ·  SCORE \(score)"
            : "SCORE \(score)"
        feedbackContainer.removeAllActions()
        feedbackContainer.isHidden = false
        feedbackContainer.alpha = 0
        feedbackContainer.setScale(0.9)
        let reveal = SKAction.group([
            .fadeIn(withDuration: 0.1),
            .scale(to: 1, duration: 0.16)
        ])
        reveal.timingMode = .easeOut
        feedbackContainer.run(reveal)
    }

    func hideGameOver() {
        feedbackContainer.removeAllActions()
        feedbackContainer.isHidden = true
        feedbackContainer.alpha = 0
    }

    func reset(score: Int, lives: Int) {
        setScore(score)
        setLives(lives)
        hideGameOver()
        transientLayer.removeAllChildren()
    }

    func layout(in size: CGSize) {
        let topY = max(30, size.height - 42)
        scoreLabel.position = CGPoint(x: max(42, size.width - 38), y: topY)
        scoreShadow.position = CGPoint(x: scoreLabel.position.x + 1.2, y: topY - 1.2)
        livesLabel.position = CGPoint(x: 38, y: topY)
        livesShadow.position = CGPoint(x: 39.2, y: topY - 1.2)
        feedbackContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
    }

    private func configure() {
        name = "fruit-slice-hud"
        zPosition = 300

        configureLabel(scoreShadow, size: 20, color: SKColor.black.withAlphaComponent(0.7))
        scoreShadow.horizontalAlignmentMode = .right
        addChild(scoreShadow)
        configureLabel(scoreLabel, size: 20, color: SKColor.white.withAlphaComponent(0.96))
        scoreLabel.horizontalAlignmentMode = .right
        addChild(scoreLabel)

        configureLabel(livesShadow, size: 16, color: SKColor.black.withAlphaComponent(0.72))
        livesShadow.horizontalAlignmentMode = .left
        addChild(livesShadow)
        configureLabel(
            livesLabel,
            size: 16,
            color: SKColor(calibratedRed: 1, green: 0.31, blue: 0.38, alpha: 0.96)
        )
        livesLabel.horizontalAlignmentMode = .left
        addChild(livesLabel)

        configureLabel(feedbackTitle, size: 25, color: SKColor.white)
        feedbackTitle.position.y = 12
        feedbackContainer.addChild(feedbackTitle)
        configureLabel(
            feedbackSubtitle,
            size: 12,
            color: SKColor.white.withAlphaComponent(0.82)
        )
        feedbackSubtitle.position.y = -19
        feedbackContainer.addChild(feedbackSubtitle)
        feedbackContainer.isHidden = true
        addChild(feedbackContainer)

        addChild(transientLayer)
        reset(score: 0, lives: FruitSliceTuning.startingLives)
    }

    private func showTransient(
        _ text: String,
        at position: CGPoint,
        color: SKColor,
        fontSize: CGFloat
    ) {
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 1
        transientLayer.addChild(label)
        label.run(
            .sequence([
                .group([
                    .moveBy(x: 0, y: 18, duration: 0.5),
                    .sequence([
                        .wait(forDuration: 0.2),
                        .fadeOut(withDuration: 0.3)
                    ])
                ]),
                .removeFromParent()
            ])
        )
    }

    private func configureLabel(_ label: SKLabelNode, size: CGFloat, color: SKColor) {
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
    }
}

