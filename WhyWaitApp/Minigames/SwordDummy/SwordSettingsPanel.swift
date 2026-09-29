import AppKit
import SpriteKit

final class SwordSettingsPanel: SKNode {
    private let panelSize = CGSize(width: 390, height: 390)
    private let background = SKShapeNode()
    private var buttons: [SwordDummySettingKind: SKShapeNode] = [:]
    private var valueLabels: [SwordDummySettingKind: SKLabelNode] = [:]

    override init() {
        super.init()
        name = "sword-settings-panel"
        zPosition = 180
        isHidden = true
        buildPanel()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("SwordSettingsPanel does not support NSCoding")
    }

    func present(settings: SwordDummySettings, in sceneSize: CGSize) {
        isHidden = false
        alpha = 1
        layout(in: sceneSize)
        refresh(settings: settings)
        setScale(0.96)
        run(.scale(to: 1, duration: 0.1))
    }

    func dismiss() {
        removeAllActions()
        isHidden = true
    }

    func layout(in sceneSize: CGSize) {
        position = CGPoint(x: sceneSize.width * 0.5, y: sceneSize.height * 0.5)
    }

    func refresh(settings: SwordDummySettings) {
        for kind in SwordDummySettingKind.allCases {
            valueLabels[kind]?.text = settings.value(for: kind) + "  ›"
        }
        valueLabels[.springResponse]?.fontColor = settings.controlMode == .spring
            ? .systemCyan
            : NSColor.white.withAlphaComponent(0.32)
        buttons[.springResponse]?.alpha = settings.controlMode == .spring ? 1 : 0.58
    }

    func setting(at scenePoint: CGPoint) -> SwordDummySettingKind? {
        guard !isHidden, let parent else { return nil }
        let localPoint = convert(scenePoint, from: parent)
        return SwordDummySettingKind.allCases.first { kind in
            buttons[kind]?.frame.contains(localPoint) == true
        }
    }

    func containsScenePoint(_ scenePoint: CGPoint) -> Bool {
        guard !isHidden, let parent else { return false }
        let localPoint = convert(scenePoint, from: parent)
        return background.frame.contains(localPoint)
    }

    private func buildPanel() {
        background.path = CGPath(
            roundedRect: CGRect(
                x: -panelSize.width * 0.5,
                y: -panelSize.height * 0.5,
                width: panelSize.width,
                height: panelSize.height
            ),
            cornerWidth: 20,
            cornerHeight: 20,
            transform: nil
        )
        background.fillColor = NSColor(calibratedWhite: 0.055, alpha: 0.88)
        background.strokeColor = NSColor.white.withAlphaComponent(0.17)
        background.lineWidth = 1
        addChild(background)

        let title = label("SWORD DUMMY SETTINGS", size: 17, color: .white)
        title.position = CGPoint(x: 0, y: 157)
        addChild(title)

        let swordSection = label("SWORD", size: 10, color: NSColor.systemCyan.withAlphaComponent(0.8))
        swordSection.horizontalAlignmentMode = .left
        swordSection.position = CGPoint(x: -166, y: 128)
        addChild(swordSection)

        let dummySection = label("DUMMY", size: 10, color: NSColor.systemOrange.withAlphaComponent(0.84))
        dummySection.horizontalAlignmentMode = .left
        dummySection.position = CGPoint(x: -166, y: -30)
        addChild(dummySection)

        let rowPositions: [(SwordDummySettingKind, CGFloat)] = [
            (.controlMode, 91),
            (.swordWeight, 47),
            (.springResponse, 3),
            (.dummyReaction, -67),
            (.dummyDurability, -111),
            (.dummyPlacement, -155)
        ]
        for (kind, y) in rowPositions {
            let button = SKShapeNode(
                rectOf: CGSize(width: 342, height: 37),
                cornerRadius: 10
            )
            button.position = CGPoint(x: 0, y: y)
            button.fillColor = NSColor.white.withAlphaComponent(0.055)
            button.strokeColor = NSColor.white.withAlphaComponent(0.09)
            button.lineWidth = 1
            background.addChild(button)
            buttons[kind] = button

            let titleLabel = label(kind.title, size: 12, color: NSColor.white.withAlphaComponent(0.68))
            titleLabel.horizontalAlignmentMode = .left
            titleLabel.position = CGPoint(x: -153, y: -1)
            button.addChild(titleLabel)

            let valueLabel = label("", size: 12, color: .systemCyan)
            valueLabel.horizontalAlignmentMode = .right
            valueLabel.position = CGPoint(x: 153, y: -1)
            button.addChild(valueLabel)
            valueLabels[kind] = valueLabel
        }

        let hint = label("CLICK A ROW TO CHANGE   •   S TO CLOSE", size: 10, color: NSColor.white.withAlphaComponent(0.48))
        hint.position = CGPoint(x: 0, y: -181)
        addChild(hint)
    }

    private func label(_ text: String, size: CGFloat, color: NSColor) -> SKLabelNode {
        let node = WhyWaitLabelNode(fontNamed: "AvenirNext-DemiBold")
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        return node
    }
}
