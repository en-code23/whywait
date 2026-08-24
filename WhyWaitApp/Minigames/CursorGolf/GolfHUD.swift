import SpriteKit

final class GolfHUD: SKNode {
    private let strokeContainer = SKNode()
    private let strokeLabel = SKLabelNode()
    private let strokeShadow = SKLabelNode()
    private let completionContainer = SKNode()
    private let completionLabel = SKLabelNode()
    private let completionShadow = SKLabelNode()
    private let strokeAccent = SKShapeNode(rectOf: CGSize(width: 3, height: 13), cornerRadius: 1.5)

    override init() {
        super.init()
        configureLabels()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GolfHUD does not support NSCoding")
    }

    func setStrokeCount(_ count: Int) {
        let text = "STROKES \(count)"
        strokeLabel.text = text
        strokeShadow.text = text
    }

    func showCompletion(strokes: Int) {
        let text: String

        switch strokes {
        case 1:
            text = "HOLE IN ONE!"
        case 2:
            text = "NICE!  ·  HOLE IN 2"
        case 3:
            text = "GOOD!  ·  HOLE IN 3"
        default:
            text = "HOLE IN \(strokes)"
        }

        completionLabel.text = text
        completionShadow.text = text
        completionContainer.removeAllActions()
        completionContainer.isHidden = false
        completionContainer.alpha = 0
        completionContainer.setScale(0.9)

        let appear = SKAction.group([
            .fadeIn(withDuration: 0.12),
            .scale(to: 1, duration: 0.18)
        ])
        appear.timingMode = .easeOut
        completionContainer.run(appear)
    }

    func hideCompletion() {
        completionContainer.removeAllActions()
        completionContainer.isHidden = true
        completionContainer.alpha = 0
    }

    func layout(in size: CGSize) {
        strokeContainer.position = CGPoint(x: 22, y: max(28, size.height - 38))
        completionContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
    }

    private func configureLabels() {
        name = "cursor-golf-hud"
        zPosition = 100
        isHidden = !WhyWaitPresentationPreferences.showGameHUD

        strokeAccent.fillColor = SKColor(calibratedRed: 0.9, green: 0.18, blue: 0.16, alpha: 0.92)
        strokeAccent.strokeColor = SKColor.white.withAlphaComponent(0.32)
        strokeAccent.lineWidth = 0.6
        strokeAccent.position = CGPoint(x: 1.5, y: 0)
        strokeContainer.addChild(strokeAccent)

        let strokeFont = "AvenirNext-DemiBold"
        configure(
            strokeShadow,
            fontName: strokeFont,
            fontSize: 13,
            color: SKColor.black.withAlphaComponent(0.72),
            horizontalAlignment: .left
        )
        strokeShadow.position = CGPoint(x: 10, y: -1)
        strokeContainer.addChild(strokeShadow)

        configure(
            strokeLabel,
            fontName: strokeFont,
            fontSize: 13,
            color: SKColor.white.withAlphaComponent(0.96),
            horizontalAlignment: .left
        )
        strokeLabel.position.x = 9
        strokeContainer.addChild(strokeLabel)
        addChild(strokeContainer)

        let completionFont = "AvenirNext-Bold"
        configure(
            completionShadow,
            fontName: completionFont,
            fontSize: 25,
            color: SKColor.black.withAlphaComponent(0.68),
            horizontalAlignment: .center
        )
        completionShadow.position = CGPoint(x: 1.5, y: -1.5)
        completionContainer.addChild(completionShadow)

        configure(
            completionLabel,
            fontName: completionFont,
            fontSize: 25,
            color: SKColor.white,
            horizontalAlignment: .center
        )
        completionContainer.addChild(completionLabel)
        completionContainer.isHidden = true
        addChild(completionContainer)

        setStrokeCount(0)
    }

    private func configure(
        _ label: SKLabelNode,
        fontName: String,
        fontSize: CGFloat,
        color: SKColor,
        horizontalAlignment: SKLabelHorizontalAlignmentMode
    ) {
        label.fontName = fontName
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = horizontalAlignment
        label.verticalAlignmentMode = .center
    }
}
