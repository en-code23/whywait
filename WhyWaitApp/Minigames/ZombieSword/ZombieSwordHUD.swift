import AppKit
import SpriteKit

final class ZombieSwordHUD: SKNode {
    private let healthLabel = WhyWaitLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let waveLabel = WhyWaitLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let scoreLabel = WhyWaitLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let comboLabel = WhyWaitLabelNode(fontNamed: "AvenirNext-Bold")
    private let challengeLabel = WhyWaitLabelNode(fontNamed: "AvenirNext-Medium")

    override init() {
        super.init()
        name = "zombie-sword-hud"
        zPosition = 90
        configure(healthLabel, size: 14, color: .white)
        configure(waveLabel, size: 14, color: .white)
        configure(scoreLabel, size: 14, color: .white)
        configure(comboLabel, size: 18, color: .systemYellow)
        configure(challengeLabel, size: 11, color: NSColor.white.withAlphaComponent(0.72))
        addChild(healthLabel)
        addChild(waveLabel)
        addChild(scoreLabel)
        addChild(comboLabel)
        addChild(challengeLabel)
        comboLabel.alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ZombieSwordHUD does not support NSCoding")
    }

    func layout(in size: CGSize) {
        healthLabel.position = CGPoint(x: 24, y: size.height - 52)
        healthLabel.horizontalAlignmentMode = .left
        waveLabel.position = CGPoint(x: size.width * 0.5, y: size.height - 52)
        scoreLabel.position = CGPoint(x: size.width - 24, y: size.height - 52)
        scoreLabel.horizontalAlignmentMode = .right
        comboLabel.position = CGPoint(x: size.width - 26, y: size.height - 79)
        comboLabel.horizontalAlignmentMode = .right
        challengeLabel.position = CGPoint(x: size.width * 0.5, y: 24)
    }

    func update(health: Int, wave: Int, score: Int, combo: Int) {
        healthLabel.text = "HP  \(health)"
        healthLabel.fontColor = health <= 25 ? .systemRed : .white
        waveLabel.text = "WAVE  \(wave)"
        scoreLabel.text = "SCORE  \(score)"
        guard combo >= 2 else {
            comboLabel.alpha = 0
            return
        }
        comboLabel.text = "x\(combo)"
        comboLabel.alpha = 1
    }

    func setChallenge(_ progress: ZombieSwordChallengeProgress) {
        challengeLabel.text = progress.isComplete
            ? "★  CHALLENGE COMPLETE"
            : "CHALLENGE  •  \(progress.displayText)"
    }

    private func configure(_ label: SKLabelNode, size: CGFloat, color: NSColor) {
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
    }
}
