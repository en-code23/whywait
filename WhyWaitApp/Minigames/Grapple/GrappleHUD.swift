import SpriteKit

final class GrappleHUD: SKNode {
    private let timerLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let timerShadow = SKLabelNode(fontNamed: "Menlo-Bold")
    private let progressLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let progressShadow = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let feedbackContainer = SKNode()
    private let feedbackTitle = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let feedbackSubtitle = SKLabelNode(fontNamed: "Menlo-Bold")
    private let transientLayer = SKNode()

    override init() {
        super.init()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GrappleHUD does not support NSCoding")
    }

    func setTime(_ time: TimeInterval) {
        let text = String(format: "%.2fs", max(0, time))
        timerLabel.text = text
        timerShadow.text = text
    }

    func setCheckpointProgress(completed: Int, total: Int) {
        let text = "\(completed) / \(total)"
        progressLabel.text = text
        progressShadow.text = text
    }

    func showMissed() {
        feedbackTitle.text = "MISSED"
        feedbackSubtitle.text = nil
        revealFeedback()
    }

    func showFinish(time: TimeInterval, praise: String) {
        feedbackTitle.text = "FINISH"
        feedbackSubtitle.text = "\(String(format: "%.2f", time))s  ·  \(praise)"
        revealFeedback()
    }

    func hideFeedback() {
        feedbackContainer.removeAllActions()
        feedbackContainer.isHidden = true
        feedbackContainer.alpha = 0
    }

    func showClean(at position: CGPoint) {
        showTransient(
            "CLEAN",
            at: CGPoint(x: position.x, y: position.y + 28),
            color: SKColor(calibratedRed: 0.54, green: 0.98, blue: 0.74, alpha: 0.96),
            fontSize: 12
        )
    }

    func showSpeed(at position: CGPoint) {
        showTransient(
            "SPEED",
            at: CGPoint(x: position.x, y: position.y - 28),
            color: SKColor(calibratedRed: 0.48, green: 0.9, blue: 1, alpha: 0.92),
            fontSize: 10
        )
    }

    func reset(checkpointCount: Int) {
        setTime(0)
        setCheckpointProgress(completed: 0, total: checkpointCount)
        hideFeedback()
        transientLayer.removeAllChildren()
    }

    func layout(in size: CGSize) {
        let topY = max(30, size.height - 42)
        timerLabel.position = CGPoint(x: max(52, size.width - 38), y: topY)
        timerShadow.position = CGPoint(x: timerLabel.position.x + 1.2, y: topY - 1.2)
        progressLabel.position = CGPoint(x: size.width / 2, y: topY)
        progressShadow.position = CGPoint(x: progressLabel.position.x + 1, y: topY - 1)
        feedbackContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
    }

    private func configure() {
        name = "grapple-hud"
        zPosition = 300

        configureLabel(timerShadow, size: 17, color: SKColor.black.withAlphaComponent(0.72))
        timerShadow.horizontalAlignmentMode = .right
        addChild(timerShadow)
        configureLabel(timerLabel, size: 17, color: SKColor.white.withAlphaComponent(0.95))
        timerLabel.horizontalAlignmentMode = .right
        addChild(timerLabel)

        configureLabel(progressShadow, size: 13, color: SKColor.black.withAlphaComponent(0.72))
        addChild(progressShadow)
        configureLabel(progressLabel, size: 13, color: SKColor.white.withAlphaComponent(0.86))
        addChild(progressLabel)

        configureLabel(feedbackTitle, size: 24, color: SKColor.white)
        feedbackTitle.position.y = 11
        feedbackContainer.addChild(feedbackTitle)
        configureLabel(
            feedbackSubtitle,
            size: 11,
            color: SKColor.white.withAlphaComponent(0.82)
        )
        feedbackSubtitle.position.y = -19
        feedbackContainer.addChild(feedbackSubtitle)
        feedbackContainer.isHidden = true
        addChild(feedbackContainer)

        addChild(transientLayer)
    }

    private func revealFeedback() {
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

    private func showTransient(
        _ text: String,
        at position: CGPoint,
        color: SKColor,
        fontSize: CGFloat
    ) {
        while transientLayer.children.count >= 10 {
            transientLayer.children.first?.removeFromParent()
        }

        let label = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = position
        transientLayer.addChild(label)
        label.run(
            .sequence([
                .group([
                    .moveBy(x: 0, y: 18, duration: 0.48),
                    .sequence([
                        .wait(forDuration: 0.18),
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

