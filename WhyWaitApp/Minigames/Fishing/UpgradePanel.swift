import Foundation
import SpriteKit

final class UpgradePanel: SKNode {
    private let background = SKShapeNode()
    private let content = SKNode()
    private var profile = FishingProfile()
    private var panelSize = CGSize.zero
    private var buttonFrames: [FishingEquipmentCategory: CGRect] = [:]
    private let feedbackLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")

    override init() {
        super.init()
        name = "fishing-upgrade-panel"
        zPosition = 500
        isHidden = true
        addChild(background)
        addChild(content)
        feedbackLabel.fontSize = 10
        feedbackLabel.horizontalAlignmentMode = .center
        feedbackLabel.verticalAlignmentMode = .center
        feedbackLabel.alpha = 0
        addChild(feedbackLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("UpgradePanel does not support NSCoding")
    }

    func present(profile: FishingProfile, in sceneSize: CGSize) {
        self.profile = profile
        isHidden = false
        alpha = 0
        setScale(0.94)
        layout(in: sceneSize)
        rebuild()
        run(
            .group([
                .fadeIn(withDuration: 0.12),
                .scale(to: 1, duration: 0.16)
            ])
        )
    }

    func refresh(profile: FishingProfile) {
        self.profile = profile
        if !isHidden { rebuild() }
    }

    func dismiss() {
        removeAllActions()
        feedbackLabel.removeAllActions()
        isHidden = true
        content.removeAllChildren()
        buttonFrames.removeAll(keepingCapacity: true)
    }

    func layout(in sceneSize: CGSize) {
        panelSize = CGSize(
            width: max(420, min(680, sceneSize.width - 40)),
            height: max(400, min(500, sceneSize.height - 46))
        )
        position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        background.path = CGPath(
            roundedRect: CGRect(
                x: -panelSize.width / 2,
                y: -panelSize.height / 2,
                width: panelSize.width,
                height: panelSize.height
            ),
            cornerWidth: 18,
            cornerHeight: 18,
            transform: nil
        )
        background.fillColor = SKColor(calibratedWhite: 0.055, alpha: 0.9)
        background.strokeColor = SKColor.white.withAlphaComponent(0.2)
        background.lineWidth = 1.2
        feedbackLabel.position = CGPoint(x: 0, y: -panelSize.height / 2 + 23)
        if !isHidden { rebuild() }
    }

    func upgrade(at scenePoint: CGPoint) -> FishingEquipmentCategory? {
        guard !isHidden, let parent else { return nil }
        let local = convert(scenePoint, from: parent)
        return buttonFrames.first(where: { $0.value.contains(local) })?.key
    }

    func consumesClick(at scenePoint: CGPoint) -> Bool {
        guard !isHidden, let parent else { return false }
        let local = convert(scenePoint, from: parent)
        return CGRect(
            x: -panelSize.width / 2,
            y: -panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        ).contains(local)
    }

    func showPurchaseResult(_ result: FishingUpgradePurchaseStatus) {
        feedbackLabel.removeAllActions()
        switch result {
        case let .purchased(level, cost):
            feedbackLabel.text = "UPGRADED TO LV.\(level)  ·  -\(cost) COINS"
            feedbackLabel.fontColor = SKColor(
                calibratedRed: 0.45,
                green: 0.93,
                blue: 0.62,
                alpha: 0.96
            )
        case let .insufficientCoins(cost):
            feedbackLabel.text = "NEED \(cost) COINS"
            feedbackLabel.fontColor = SKColor(
                calibratedRed: 1,
                green: 0.56,
                blue: 0.28,
                alpha: 0.96
            )
        case .maximumLevel:
            feedbackLabel.text = "ALREADY MAX LEVEL"
            feedbackLabel.fontColor = SKColor.white.withAlphaComponent(0.7)
        case .duplicateTransaction:
            return
        }
        feedbackLabel.alpha = 0
        feedbackLabel.run(
            .sequence([
                .fadeIn(withDuration: 0.08),
                .wait(forDuration: 0.72),
                .fadeOut(withDuration: 0.24)
            ])
        )
    }

    private func rebuild() {
        content.removeAllChildren()
        buttonFrames.removeAll(keepingCapacity: true)

        let left = -panelSize.width / 2
        let top = panelSize.height / 2
        addLabel(
            "EQUIPMENT",
            at: CGPoint(x: left + 25, y: top - 31),
            size: 18,
            color: .white,
            alignment: .left
        )
        addLabel(
            "¢ \(profile.coins.formatted())",
            at: CGPoint(x: panelSize.width / 2 - 25, y: top - 31),
            size: 13,
            color: SKColor(calibratedRed: 1, green: 0.82, blue: 0.25, alpha: 0.96),
            alignment: .right
        )
        addLabel(
            "U  CLOSE",
            at: CGPoint(x: panelSize.width / 2 - 25, y: top - 53),
            size: 9,
            color: SKColor.white.withAlphaComponent(0.42),
            alignment: .right
        )

        let rowWidth = panelSize.width - 50
        let rowHeight: CGFloat = 61
        let startY = top - 93
        for (index, category) in FishingEquipmentCategory.allCases.enumerated() {
            let rowFrame = CGRect(
                x: left + 25,
                y: startY - rowHeight - (CGFloat(index) * 67),
                width: rowWidth,
                height: rowHeight
            )
            let row = SKShapeNode(rect: rowFrame, cornerRadius: 10)
            row.fillColor = SKColor.white.withAlphaComponent(0.035)
            row.strokeColor = SKColor.white.withAlphaComponent(0.08)
            row.lineWidth = 1
            content.addChild(row)

            let level = profile.equipment.level(for: category)
            addLabel(
                category.displayName,
                at: CGPoint(x: rowFrame.minX + 16, y: rowFrame.midY + 10),
                size: 12,
                color: .white,
                alignment: .left
            )
            addLabel(
                "LV.\(level)",
                at: CGPoint(x: rowFrame.minX + 16, y: rowFrame.midY - 11),
                size: 9,
                color: SKColor.white.withAlphaComponent(0.55),
                alignment: .left
            )
            addLabel(
                category.effectDescription(level: level),
                at: CGPoint(x: rowFrame.minX + 106, y: rowFrame.midY + 9),
                size: 10,
                color: SKColor.white.withAlphaComponent(0.72),
                alignment: .left
            )
            if level < FishingEquipmentLevels.maximumLevel {
                addLabel(
                    "NEXT  \(category.effectDescription(level: level + 1))",
                    at: CGPoint(x: rowFrame.minX + 106, y: rowFrame.midY - 12),
                    size: 8.5,
                    color: SKColor(
                        calibratedRed: 0.46,
                        green: 0.84,
                        blue: 1,
                        alpha: 0.66
                    ),
                    alignment: .left
                )
            }

            let buttonFrame = CGRect(
                x: rowFrame.maxX - 112,
                y: rowFrame.midY - 17,
                width: 96,
                height: 34
            )
            buttonFrames[category] = buttonFrame
            let button = SKShapeNode(rect: buttonFrame, cornerRadius: 8)
            let cost = profile.equipment.upgradeCost(for: category)
            let canAfford = cost.map { profile.coins >= $0 } ?? false
            button.fillColor = cost == nil
                ? SKColor.white.withAlphaComponent(0.055)
                : SKColor(
                    calibratedRed: 0.18,
                    green: 0.55,
                    blue: 0.72,
                    alpha: canAfford ? 0.56 : 0.24
                )
            button.strokeColor = cost == nil
                ? SKColor.white.withAlphaComponent(0.12)
                : SKColor(
                    calibratedRed: 0.45,
                    green: 0.84,
                    blue: 1,
                    alpha: canAfford ? 0.6 : 0.24
                )
            button.lineWidth = 1
            content.addChild(button)
            addLabel(
                cost.map { "UPGRADE  \($0)" } ?? "MAX",
                at: CGPoint(x: buttonFrame.midX, y: buttonFrame.midY),
                size: cost == nil ? 10 : 8.5,
                color: canAfford || cost == nil
                    ? SKColor.white.withAlphaComponent(0.86)
                    : SKColor.white.withAlphaComponent(0.38)
            )
        }
    }

    private func addLabel(
        _ text: String,
        at position: CGPoint,
        size: CGFloat,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode = .center
    ) {
        let label = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.position = position
        content.addChild(label)
    }
}
