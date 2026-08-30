import Foundation
import SpriteKit

private enum TackleShopTab {
    case gear
    case supplies
}

final class UpgradePanel: SKNode {
    private let background = SKShapeNode()
    private let innerBorder = SKShapeNode()
    private let content = SKNode()
    private var profile = FishingProfile()
    private var panelSize = CGSize.zero
    private var actionFrames: [(FishingShopAction, CGRect)] = []
    private var gearTabFrame = CGRect.zero
    private var suppliesTabFrame = CGRect.zero
    private var tab: TackleShopTab = .gear
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    override init() {
        super.init()
        name = "fishing-tackle-shop-panel"
        zPosition = 500
        isHidden = true
        addChild(background)
        addChild(innerBorder)
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
        run(.group([.fadeIn(withDuration: 0.12), .scale(to: 1, duration: 0.16)]))
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
        actionFrames.removeAll(keepingCapacity: true)
    }

    func layout(in sceneSize: CGSize) {
        panelSize = CGSize(
            width: max(500, min(700, sceneSize.width - 40)),
            height: max(430, min(525, sceneSize.height - 46))
        )
        position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        let bounds = CGRect(x: -panelSize.width / 2, y: -panelSize.height / 2, width: panelSize.width, height: panelSize.height)
        background.path = CGPath(roundedRect: bounds, cornerWidth: 20, cornerHeight: 20, transform: nil)
        background.fillColor = SKColor(calibratedRed: 0.055, green: 0.045, blue: 0.085, alpha: 0.94)
        background.strokeColor = SKColor(calibratedRed: 0.64, green: 0.46, blue: 0.92, alpha: 0.42)
        background.lineWidth = 1.4
        innerBorder.path = CGPath(roundedRect: bounds.insetBy(dx: 7, dy: 7), cornerWidth: 15, cornerHeight: 15, transform: nil)
        innerBorder.fillColor = .clear
        innerBorder.strokeColor = SKColor.white.withAlphaComponent(0.055)
        innerBorder.lineWidth = 1
        feedbackLabel.position = CGPoint(x: 0, y: -panelSize.height / 2 + 21)
        if !isHidden { rebuild() }
    }

    func action(at scenePoint: CGPoint) -> FishingShopAction? {
        guard !isHidden, let parent else { return nil }
        let local = convert(scenePoint, from: parent)
        if gearTabFrame.contains(local) {
            tab = .gear
            rebuild()
            return nil
        }
        if suppliesTabFrame.contains(local) {
            tab = .supplies
            rebuild()
            return nil
        }
        return actionFrames.first(where: { $0.1.contains(local) })?.0
    }

    func consumesClick(at scenePoint: CGPoint) -> Bool {
        guard !isHidden, let parent else { return false }
        let local = convert(scenePoint, from: parent)
        return CGRect(x: -panelSize.width / 2, y: -panelSize.height / 2, width: panelSize.width, height: panelSize.height).contains(local)
    }

    func showPurchaseResult(_ result: FishingUpgradePurchaseStatus) {
        switch result {
        case let .purchased(level, cost): showFeedback("GEAR REFINED TO LV.\(level)  ·  -\(cost)", success: true)
        case let .insufficientCoins(cost): showFeedback("NEED ¢ \(cost)", success: false)
        case .maximumLevel: showFeedback("ALREADY MAX LEVEL", neutral: true)
        case .duplicateTransaction: break
        }
    }

    func showPurchaseResult(_ result: FishingShopPurchaseStatus) {
        switch result {
        case let .purchased(name, cost): showFeedback("\(name)  ·  -\(cost)", success: true)
        case let .insufficientCoins(cost): showFeedback("NEED ¢ \(cost)", success: false)
        case .full: showFeedback("STOCK ALREADY FULL", neutral: true)
        case .maximumLevel: showFeedback("TIDEVAULT AT MAXIMUM", neutral: true)
        case .duplicateTransaction: break
        }
    }

    func showEquipped(_ lure: FishingLure) {
        showFeedback("\(lure.displayName) EQUIPPED", success: true)
    }

    private func showFeedback(_ text: String, success: Bool = false, neutral: Bool = false) {
        feedbackLabel.removeAllActions()
        feedbackLabel.text = text
        if neutral {
            feedbackLabel.fontColor = SKColor.white.withAlphaComponent(0.7)
        } else if success {
            feedbackLabel.fontColor = SKColor(calibratedRed: 0.47, green: 0.94, blue: 0.68, alpha: 0.96)
        } else {
            feedbackLabel.fontColor = SKColor(calibratedRed: 1, green: 0.56, blue: 0.28, alpha: 0.96)
        }
        feedbackLabel.alpha = 0
        feedbackLabel.run(.sequence([.fadeIn(withDuration: 0.08), .wait(forDuration: 0.75), .fadeOut(withDuration: 0.24)]))
    }

    private func rebuild() {
        content.removeAllChildren()
        actionFrames.removeAll(keepingCapacity: true)
        let left = -panelSize.width / 2
        let top = panelSize.height / 2
        addLabel("THE TACKLE ROOM", at: CGPoint(x: left + 27, y: top - 31), size: 18, color: .white, alignment: .left)
        addLabel("HAND-TUNED GEAR & TIDEBREAK SUPPLIES", at: CGPoint(x: left + 27, y: top - 53), size: 8, color: SKColor(calibratedRed: 0.75, green: 0.61, blue: 1, alpha: 0.7), alignment: .left)
        addLabel("¢ \(profile.coins.formatted())", at: CGPoint(x: panelSize.width / 2 - 27, y: top - 31), size: 13, color: SKColor(calibratedRed: 1, green: 0.82, blue: 0.25, alpha: 0.96), alignment: .right)
        addLabel("U  CLOSE", at: CGPoint(x: panelSize.width / 2 - 27, y: top - 52), size: 9, color: SKColor.white.withAlphaComponent(0.42), alignment: .right)

        gearTabFrame = CGRect(x: left + 27, y: top - 89, width: 92, height: 28)
        suppliesTabFrame = CGRect(x: left + 125, y: top - 89, width: 112, height: 28)
        addTab("EQUIPMENT", frame: gearTabFrame, active: tab == .gear)
        addTab("LURES + VAULT", frame: suppliesTabFrame, active: tab == .supplies)
        switch tab {
        case .gear: buildGearRows()
        case .supplies: buildSupplyRows()
        }
    }

    private func buildGearRows() {
        let left = -panelSize.width / 2
        let top = panelSize.height / 2
        let rowWidth = panelSize.width - 54
        let rowHeight: CGFloat = 55
        let startY = top - 110
        for (index, category) in FishingEquipmentCategory.allCases.enumerated() {
            let frame = CGRect(x: left + 27, y: startY - rowHeight - CGFloat(index) * 61, width: rowWidth, height: rowHeight)
            addRow(frame)
            let level = profile.equipment.level(for: category)
            addLabel(category.displayName, at: CGPoint(x: frame.minX + 15, y: frame.midY + 9), size: 11, color: .white, alignment: .left)
            addLabel("LV.\(level)", at: CGPoint(x: frame.minX + 15, y: frame.midY - 11), size: 8, color: SKColor.white.withAlphaComponent(0.5), alignment: .left)
            addLabel(category.effectDescription(level: level), at: CGPoint(x: frame.minX + 103, y: frame.midY), size: 9, color: SKColor.white.withAlphaComponent(0.68), alignment: .left)
            let button = CGRect(x: frame.maxX - 112, y: frame.midY - 16, width: 96, height: 32)
            let cost = profile.equipment.upgradeCost(for: category)
            actionFrames.append((.upgrade(category), button))
            addActionButton(cost.map { "REFINE  \($0)" } ?? "MAX", frame: button, enabled: cost != nil && profile.coins >= (cost ?? .max))
        }
    }

    private func buildSupplyRows() {
        let left = -panelSize.width / 2
        let top = panelSize.height / 2
        let rowWidth = panelSize.width - 54
        let rowHeight: CGFloat = 65
        let startY = top - 113
        for (index, lure) in FishingLure.allCases.enumerated() {
            let frame = CGRect(x: left + 27, y: startY - rowHeight - CGFloat(index) * 72, width: rowWidth, height: rowHeight)
            addRow(frame)
            let quantity = profile.shopInventory.quantity(of: lure)
            let equipped = profile.shopInventory.equippedLure == lure
            addLabel(lure.displayName, at: CGPoint(x: frame.minX + 16, y: frame.midY + 12), size: 11, color: equipped ? SKColor(calibratedRed: 0.57, green: 0.94, blue: 0.82, alpha: 1) : .white, alignment: .left)
            addLabel("IN TACKLE  \(quantity)\(equipped ? "  ·  RIGGED" : "")", at: CGPoint(x: frame.minX + 16, y: frame.midY - 11), size: 8, color: SKColor.white.withAlphaComponent(0.46), alignment: .left)
            addLabel(lure.detail, at: CGPoint(x: frame.minX + 143, y: frame.midY), size: 8.5, color: SKColor.white.withAlphaComponent(0.64), alignment: .left)
            let equipFrame = CGRect(x: frame.maxX - 182, y: frame.midY - 15, width: 68, height: 30)
            let buyFrame = CGRect(x: frame.maxX - 106, y: frame.midY - 15, width: 90, height: 30)
            actionFrames.append((.equipLure(lure), equipFrame))
            actionFrames.append((.buyLure(lure), buyFrame))
            addActionButton(equipped ? "RIGGED" : "EQUIP", frame: equipFrame, enabled: quantity > 0 && !equipped, accent: equipped)
            addActionButton("BUY  \(lure.cost)", frame: buyFrame, enabled: quantity < FishingTuning.maximumLureQuantity && profile.coins >= lure.cost)
        }

        let index = FishingLure.allCases.count
        let frame = CGRect(x: left + 27, y: startY - rowHeight - CGFloat(index) * 72, width: rowWidth, height: rowHeight)
        addRow(frame)
        addLabel("TIDEVAULT BERTH", at: CGPoint(x: frame.minX + 16, y: frame.midY + 12), size: 11, color: .white, alignment: .left)
        addLabel("CAPACITY  \(profile.vaultCapacity)", at: CGPoint(x: frame.minX + 16, y: frame.midY - 11), size: 8, color: SKColor.white.withAlphaComponent(0.46), alignment: .left)
        addLabel("Archive more favorite specimens", at: CGPoint(x: frame.minX + 143, y: frame.midY), size: 8.5, color: SKColor.white.withAlphaComponent(0.64), alignment: .left)
        let button = CGRect(x: frame.maxX - 126, y: frame.midY - 15, width: 110, height: 30)
        let level = profile.shopInventory.vaultLevel
        let cost = level < FishingTuning.maximumVaultLevel ? FishingTuning.vaultUpgradeCosts[level] : nil
        actionFrames.append((.expandVault, button))
        addActionButton(cost.map { "EXPAND  \($0)" } ?? "MAX", frame: button, enabled: cost != nil && profile.coins >= (cost ?? .max))
    }

    private func addRow(_ frame: CGRect) {
        let row = SKShapeNode(rect: frame, cornerRadius: 10)
        row.fillColor = SKColor.white.withAlphaComponent(0.035)
        row.strokeColor = SKColor.white.withAlphaComponent(0.08)
        row.lineWidth = 1
        content.addChild(row)
    }

    private func addTab(_ title: String, frame: CGRect, active: Bool) {
        let node = SKShapeNode(rect: frame, cornerRadius: 7)
        node.fillColor = active ? SKColor(calibratedRed: 0.39, green: 0.25, blue: 0.67, alpha: 0.62) : SKColor.white.withAlphaComponent(0.035)
        node.strokeColor = active ? SKColor(calibratedRed: 0.76, green: 0.61, blue: 1, alpha: 0.58) : SKColor.white.withAlphaComponent(0.08)
        node.lineWidth = 1
        content.addChild(node)
        addLabel(title, at: CGPoint(x: frame.midX, y: frame.midY), size: 8.5, color: active ? .white : SKColor.white.withAlphaComponent(0.48))
    }

    private func addActionButton(_ title: String, frame: CGRect, enabled: Bool, accent: Bool = false) {
        let button = SKShapeNode(rect: frame, cornerRadius: 7)
        let color = SKColor(calibratedRed: 0.47, green: 0.33, blue: 0.78, alpha: 1)
        button.fillColor = enabled || accent ? color.withAlphaComponent(accent ? 0.28 : 0.54) : SKColor.white.withAlphaComponent(0.035)
        button.strokeColor = enabled || accent ? color.withAlphaComponent(0.7) : SKColor.white.withAlphaComponent(0.09)
        button.lineWidth = 1
        content.addChild(button)
        addLabel(title, at: CGPoint(x: frame.midX, y: frame.midY), size: 8, color: enabled || accent ? SKColor.white.withAlphaComponent(0.9) : SKColor.white.withAlphaComponent(0.3))
    }

    private func addLabel(_ text: String, at position: CGPoint, size: CGFloat, color: SKColor, alignment: SKLabelHorizontalAlignmentMode = .center) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.position = position
        content.addChild(label)
    }
}
