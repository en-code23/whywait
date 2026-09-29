import SpriteKit

final class PongHUD: SKNode {
    private let scoreContainer = SKNode()
    private let scoreLabel = WhyWaitLabelNode()
    private let scoreShadow = WhyWaitLabelNode()
    private let scoreCaption = WhyWaitLabelNode()
    private let rallyContainer = SKNode()
    private let rallyLabel = WhyWaitLabelNode()
    private let rallyShadow = WhyWaitLabelNode()
    private let feedbackContainer = SKNode()
    private let feedbackLabel = WhyWaitLabelNode()
    private let feedbackShadow = WhyWaitLabelNode()
    private let visualEffectsReduced = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        configureLabels()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PongHUD does not support NSCoding")
    }

    func setScores(player: Int, cpu: Int) {
        let text = "\(cpu)  :  \(player)"
        scoreLabel.text = text
        scoreShadow.text = text
    }

    func setRally(_ count: Int) {
        guard count >= CursorPongTuning.rallyDisplayThreshold else {
            rallyContainer.isHidden = true
            return
        }

        let text = count >= 10 ? "RALLY \(count)!" : "RALLY \(count)"
        rallyLabel.text = text
        rallyShadow.text = text
        rallyContainer.isHidden = false
        rallyContainer.removeAllActions()
        rallyContainer.setScale(visualEffectsReduced ? 1.02 : 1.1)
        rallyContainer.run(.scale(to: 1, duration: visualEffectsReduced ? 0.05 : 0.1))
    }

    func showPointScored(by side: PongSide) {
        showFeedback(side == .player ? "PLAYER SCORES" : "CPU SCORES")
    }

    func showMatchResult(winner: PongSide) {
        showFeedback(winner == .player ? "YOU WIN" : "CPU WINS")
    }

    func hideFeedback() {
        feedbackContainer.removeAllActions()
        feedbackContainer.isHidden = true
        feedbackContainer.alpha = 0
    }

    func layout(in size: CGSize) {
        scoreContainer.position = CGPoint(x: size.width / 2, y: max(38, size.height - 43))
        rallyContainer.position = CGPoint(x: size.width / 2, y: max(24, size.height - 82))
        feedbackContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
    }

    private func configureLabels() {
        name = "cursor-pong-hud"
        zPosition = 100
        isHidden = !WhyWaitPresentationPreferences.showGameHUD

        let scoreFont = "Menlo-Bold"
        configure(
            scoreShadow,
            fontName: scoreFont,
            fontSize: 26,
            color: SKColor.black.withAlphaComponent(0.7)
        )
        scoreShadow.position = CGPoint(x: 1.25, y: -1.5)
        scoreContainer.addChild(scoreShadow)

        configure(
            scoreLabel,
            fontName: scoreFont,
            fontSize: 26,
            color: SKColor.white.withAlphaComponent(0.96)
        )
        scoreContainer.addChild(scoreLabel)

        let cpuRule = SKShapeNode(
            rectOf: CGSize(width: 23, height: 2),
            cornerRadius: 1
        )
        cpuRule.fillColor = SKColor(calibratedRed: 1, green: 0.49, blue: 0.22, alpha: 0.84)
        cpuRule.strokeColor = .clear
        cpuRule.position = CGPoint(x: -34, y: -19)
        scoreContainer.addChild(cpuRule)

        let playerRule = SKShapeNode(
            rectOf: CGSize(width: 23, height: 2),
            cornerRadius: 1
        )
        playerRule.fillColor = SKColor(calibratedRed: 0.28, green: 0.82, blue: 1, alpha: 0.88)
        playerRule.strokeColor = .clear
        playerRule.position = CGPoint(x: 34, y: -19)
        scoreContainer.addChild(playerRule)

        configure(
            scoreCaption,
            fontName: "AvenirNext-DemiBold",
            fontSize: 9,
            color: SKColor.white.withAlphaComponent(0.64)
        )
        scoreCaption.text = "CPU              YOU"
        scoreCaption.position = CGPoint(x: 0, y: 23)
        scoreContainer.addChild(scoreCaption)
        addChild(scoreContainer)

        let rallyFont = "AvenirNext-DemiBold"
        configure(
            rallyShadow,
            fontName: rallyFont,
            fontSize: 11,
            color: SKColor.black.withAlphaComponent(0.68)
        )
        rallyShadow.position = CGPoint(x: 1, y: -1)
        rallyContainer.addChild(rallyShadow)

        configure(
            rallyLabel,
            fontName: rallyFont,
            fontSize: 11,
            color: SKColor(calibratedRed: 0.58, green: 0.92, blue: 1, alpha: 0.94)
        )
        rallyContainer.addChild(rallyLabel)
        rallyContainer.isHidden = true
        addChild(rallyContainer)

        let feedbackFont = "AvenirNext-Bold"
        configure(
            feedbackShadow,
            fontName: feedbackFont,
            fontSize: 21,
            color: SKColor.black.withAlphaComponent(0.7)
        )
        feedbackShadow.position = CGPoint(x: 1.5, y: -1.5)
        feedbackContainer.addChild(feedbackShadow)

        configure(
            feedbackLabel,
            fontName: feedbackFont,
            fontSize: 21,
            color: SKColor.white
        )
        feedbackContainer.addChild(feedbackLabel)
        feedbackContainer.isHidden = true
        addChild(feedbackContainer)

        setScores(player: 0, cpu: 0)
    }

    private func showFeedback(_ text: String) {
        feedbackLabel.text = text
        feedbackShadow.text = text
        feedbackContainer.removeAllActions()
        feedbackContainer.isHidden = false
        feedbackContainer.alpha = 0
        feedbackContainer.setScale(visualEffectsReduced ? 0.98 : 0.9)

        let appearance = SKAction.group([
            .fadeIn(withDuration: visualEffectsReduced ? 0.05 : 0.1),
            .scale(to: 1, duration: visualEffectsReduced ? 0.06 : 0.16)
        ])
        appearance.timingMode = .easeOut
        feedbackContainer.run(appearance)
    }

    private func configure(
        _ label: SKLabelNode,
        fontName: String,
        fontSize: CGFloat,
        color: SKColor
    ) {
        label.fontName = fontName
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
    }
}
