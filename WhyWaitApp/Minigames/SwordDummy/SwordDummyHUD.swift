import AppKit
import SpriteKit

final class SwordDummyHUD: SKNode {
    private let comboLabel = WhyWaitLabelNode(fontNamed: "AvenirNext-Bold")
    private let challengeLabel = WhyWaitLabelNode(fontNamed: "AvenirNext-Medium")
    private let settingsLabel = WhyWaitLabelNode(fontNamed: "AvenirNext-Medium")
    private var dummyPosition = CGPoint.zero
    private var sceneSize = CGSize.zero

    override init() {
        super.init()
        name = "sword-dummy-hud"
        zPosition = 90
        configure(comboLabel, size: 17, color: .systemYellow)
        configure(challengeLabel, size: 12, color: NSColor.white.withAlphaComponent(0.72))
        configure(settingsLabel, size: 10, color: NSColor.white.withAlphaComponent(0.42))
        settingsLabel.text = "S  SETTINGS"
        comboLabel.alpha = 0
        addChild(comboLabel)
        addChild(challengeLabel)
        addChild(settingsLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("SwordDummyHUD does not support NSCoding")
    }

    func layout(in size: CGSize, dummyPosition: CGPoint) {
        sceneSize = size
        self.dummyPosition = dummyPosition
        comboLabel.position = CGPoint(x: dummyPosition.x + 76, y: min(size.height - 30, dummyPosition.y + 190))
        challengeLabel.position = CGPoint(x: size.width * 0.5, y: size.height - 30)
        settingsLabel.position = CGPoint(x: 24, y: 22)
        settingsLabel.horizontalAlignmentMode = .left
    }

    func setCombo(_ combo: Int) {
        comboLabel.removeAllActions()
        guard combo >= 2 else {
            comboLabel.alpha = 0
            return
        }
        comboLabel.text = "x\(combo)"
        comboLabel.alpha = 1
        comboLabel.setScale(1.18)
        comboLabel.run(.scale(to: 1, duration: 0.12))
    }

    func setChallenge(_ progress: SwordChallengeProgress) {
        challengeLabel.text = progress.isComplete
            ? "★  COMPLETE"
            : "CHALLENGE  •  \(progress.displayText)"
    }

    func reset(challenge: SwordChallengeProgress) {
        setCombo(0)
        setChallenge(challenge)
        layout(in: sceneSize, dummyPosition: dummyPosition)
    }

    private func configure(_ label: SKLabelNode, size: CGFloat, color: NSColor) {
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.addDropShadow()
    }
}

private extension SKLabelNode {
    func addDropShadow() {
        let shadow = WhyWaitLabelNode(fontNamed: fontName)
        shadow.text = text
        shadow.fontSize = fontSize
        shadow.fontColor = NSColor.black.withAlphaComponent(0.65)
        shadow.position = CGPoint(x: 1.5, y: -1.5)
        shadow.zPosition = -1
        shadow.horizontalAlignmentMode = horizontalAlignmentMode
        shadow.verticalAlignmentMode = verticalAlignmentMode
        addChild(shadow)
    }
}
