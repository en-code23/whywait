import Foundation
import SpriteKit

enum TidevaultAction: Equatable {
    case favorite(UUID)
    case lock(UUID)
    case release(UUID)
}

final class TidevaultPanel: SKNode {
    private static let pageSize = 16

    private let backdrop = SKShapeNode()
    private let innerBorder = SKShapeNode()
    private let content = SKNode()
    private var profile = FishingProfile()
    private var panelSize = CGSize.zero
    private var selectedID: UUID?
    private var page = 0
    private var cardFrames: [UUID: CGRect] = [:]
    private var favoriteFrame = CGRect.zero
    private var lockFrame = CGRect.zero
    private var releaseFrame = CGRect.zero
    private var previousFrame = CGRect.zero
    private var nextFrame = CGRect.zero

    override init() {
        super.init()
        name = "fishing-tidevault-panel"
        zPosition = 510
        isHidden = true
        addChild(backdrop)
        addChild(innerBorder)
        addChild(content)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("TidevaultPanel does not support NSCoding")
    }

    func present(profile: FishingProfile, in sceneSize: CGSize) {
        self.profile = profile
        selectedID = selectedID.flatMap { id in
            profile.storedFish.contains(where: { $0.id == id }) ? id : nil
        }
        isHidden = false
        alpha = 0
        setScale(0.95)
        layout(in: sceneSize)
        rebuild()
        run(.group([.fadeIn(withDuration: 0.12), .scale(to: 1, duration: 0.16)]))
    }

    func refresh(profile: FishingProfile) {
        self.profile = profile
        if let selectedID,
           !profile.storedFish.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        }
        clampPage()
        if !isHidden { rebuild() }
    }

    func dismiss() {
        removeAllActions()
        isHidden = true
        content.removeAllChildren()
        cardFrames.removeAll(keepingCapacity: true)
    }

    func layout(in sceneSize: CGSize) {
        panelSize = CGSize(
            width: max(560, min(790, sceneSize.width - 40)),
            height: max(410, min(540, sceneSize.height - 46))
        )
        position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        let bounds = CGRect(
            x: -panelSize.width / 2,
            y: -panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
        backdrop.path = CGPath(
            roundedRect: bounds,
            cornerWidth: 20,
            cornerHeight: 20,
            transform: nil
        )
        backdrop.fillColor = SKColor(calibratedRed: 0.025, green: 0.075, blue: 0.095, alpha: 0.94)
        backdrop.strokeColor = SKColor(calibratedRed: 0.29, green: 0.78, blue: 0.79, alpha: 0.42)
        backdrop.lineWidth = 1.4
        innerBorder.path = CGPath(
            roundedRect: bounds.insetBy(dx: 7, dy: 7),
            cornerWidth: 15,
            cornerHeight: 15,
            transform: nil
        )
        innerBorder.fillColor = .clear
        innerBorder.strokeColor = SKColor.white.withAlphaComponent(0.055)
        innerBorder.lineWidth = 1
        if !isHidden { rebuild() }
    }

    func handleClick(at scenePoint: CGPoint) -> TidevaultAction? {
        guard !isHidden, let parent else { return nil }
        let local = convert(scenePoint, from: parent)
        let bounds = CGRect(
            x: -panelSize.width / 2,
            y: -panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
        guard bounds.contains(local) else { return nil }
        if previousFrame.contains(local), page > 0 {
            page -= 1
            selectedID = nil
            rebuild()
            return nil
        }
        if nextFrame.contains(local), page < maximumPage {
            page += 1
            selectedID = nil
            rebuild()
            return nil
        }
        if let id = cardFrames.first(where: { $0.value.contains(local) })?.key {
            selectedID = id
            rebuild()
            return nil
        }
        guard let selectedID else { return nil }
        if favoriteFrame.contains(local) { return .favorite(selectedID) }
        if lockFrame.contains(local) { return .lock(selectedID) }
        if releaseFrame.contains(local) { return .release(selectedID) }
        return nil
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

    private var maximumPage: Int {
        max(0, (max(0, profile.storedFish.count - 1)) / Self.pageSize)
    }

    private func clampPage() {
        page = min(maximumPage, max(0, page))
    }

    private func rebuild() {
        content.removeAllChildren()
        cardFrames.removeAll(keepingCapacity: true)
        clampPage()
        let left = -panelSize.width / 2
        let top = panelSize.height / 2

        addLabel("TIDEVAULT", at: CGPoint(x: left + 27, y: top - 31), size: 19, color: .white, alignment: .left)
        addLabel(
            "CATCH ARCHIVE  ·  \(profile.storedFish.count) / \(profile.vaultCapacity)",
            at: CGPoint(x: left + 27, y: top - 54),
            size: 9,
            color: SKColor(calibratedRed: 0.48, green: 0.88, blue: 0.86, alpha: 0.76),
            alignment: .left
        )
        addLabel("B  CLOSE", at: CGPoint(x: panelSize.width / 2 - 26, y: top - 32), size: 9, color: SKColor.white.withAlphaComponent(0.45), alignment: .right)

        let detailWidth: CGFloat = 222
        let gridLeft = left + 26
        let gridTop = top - 82
        let gridWidth = panelSize.width - detailWidth - 72
        let gridHeight = panelSize.height - 130
        let spacing: CGFloat = 8
        let columns = 4
        let rows = 4
        let cardWidth = (gridWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        let cardHeight = (gridHeight - CGFloat(rows - 1) * spacing) / CGFloat(rows)
        let start = page * Self.pageSize
        let end = min(profile.storedFish.count, start + Self.pageSize)

        if start < end {
            for (localIndex, specimen) in profile.storedFish[start..<end].enumerated() {
                let column = localIndex % columns
                let row = localIndex / columns
                let frame = CGRect(
                    x: gridLeft + CGFloat(column) * (cardWidth + spacing),
                    y: gridTop - cardHeight - CGFloat(row) * (cardHeight + spacing),
                    width: cardWidth,
                    height: cardHeight
                )
                cardFrames[specimen.id] = frame
                addSpecimenCard(specimen, frame: frame, selected: specimen.id == selectedID)
            }
        } else {
            addLabel("YOUR NEXT CATCH CAN LIVE HERE", at: CGPoint(x: gridLeft + gridWidth / 2, y: gridTop - gridHeight / 2), size: 10, color: SKColor.white.withAlphaComponent(0.3))
        }

        previousFrame = CGRect(x: gridLeft, y: -top + 21, width: 74, height: 25)
        nextFrame = CGRect(x: gridLeft + gridWidth - 74, y: -top + 21, width: 74, height: 25)
        addSmallButton("PREV", frame: previousFrame, enabled: page > 0)
        addSmallButton("NEXT", frame: nextFrame, enabled: page < maximumPage)
        addLabel("PAGE \(page + 1) / \(maximumPage + 1)", at: CGPoint(x: gridLeft + gridWidth / 2, y: -top + 33), size: 8, color: SKColor.white.withAlphaComponent(0.42))

        let detailFrame = CGRect(
            x: panelSize.width / 2 - detailWidth - 23,
            y: -panelSize.height / 2 + 24,
            width: detailWidth,
            height: panelSize.height - 104
        )
        let detail = SKShapeNode(rect: detailFrame, cornerRadius: 14)
        detail.fillColor = SKColor.white.withAlphaComponent(0.045)
        detail.strokeColor = SKColor(calibratedRed: 0.32, green: 0.75, blue: 0.76, alpha: 0.2)
        detail.lineWidth = 1
        content.addChild(detail)
        buildDetails(in: detailFrame)
    }

    private func addSpecimenCard(_ specimen: StoredFishSpecimen, frame: CGRect, selected: Bool) {
        let card = SKShapeNode(rect: frame, cornerRadius: 9)
        card.fillColor = selected
            ? SKColor(calibratedRed: 0.12, green: 0.42, blue: 0.45, alpha: 0.48)
            : SKColor.white.withAlphaComponent(0.035)
        card.strokeColor = selected
            ? SKColor(calibratedRed: 0.44, green: 0.92, blue: 0.88, alpha: 0.72)
            : SKColor.white.withAlphaComponent(0.09)
        card.lineWidth = selected ? 1.4 : 0.8
        content.addChild(card)
        guard let definition = specimen.definition else { return }
        let fish = FishNode.dexPreview(
            definition: definition,
            discovered: true,
            scale: min(0.58, card.frame.width / 150),
            variant: specimen.variant
        )
        fish.position = CGPoint(x: frame.midX, y: frame.midY + 8)
        content.addChild(fish)
        addLabel(
            definition.name.uppercased(),
            at: CGPoint(x: frame.midX, y: frame.minY + 12),
            size: definition.name.count > 17 ? 6.5 : 7.5,
            color: SKColor.white.withAlphaComponent(0.78)
        )
        if specimen.variant != .standard {
            addBadge(specimen.variant.shortMarker, at: CGPoint(x: frame.maxX - 12, y: frame.maxY - 12), color: variantColor(specimen.variant))
        }
        if specimen.isFavorite {
            addLabel("★", at: CGPoint(x: frame.minX + 12, y: frame.maxY - 12), size: 9, color: SKColor(calibratedRed: 1, green: 0.76, blue: 0.24, alpha: 0.96))
        }
        if specimen.isLocked {
            addLabel("L", at: CGPoint(x: frame.minX + 12, y: frame.minY + 12), size: 7, color: SKColor.white.withAlphaComponent(0.5))
        }
    }

    private func buildDetails(in frame: CGRect) {
        guard let selectedID,
              let specimen = profile.storedFish.first(where: { $0.id == selectedID }),
              let definition = specimen.definition else {
            addLabel("SELECT A SPECIMEN", at: CGPoint(x: frame.midX, y: frame.midY), size: 9, color: SKColor.white.withAlphaComponent(0.34))
            return
        }
        let fish = FishNode.dexPreview(definition: definition, discovered: true, scale: 1.08, variant: specimen.variant)
        fish.position = CGPoint(x: frame.midX, y: frame.maxY - 62)
        content.addChild(fish)
        addLabel(definition.name.uppercased(), at: CGPoint(x: frame.midX, y: frame.maxY - 112), size: definition.name.count > 19 ? 11 : 13, color: .white)
        addLabel(
            specimen.variant.displayName,
            at: CGPoint(x: frame.midX, y: frame.maxY - 133),
            size: 9,
            color: specimen.variant == .standard ? SKColor.white.withAlphaComponent(0.48) : variantColor(specimen.variant)
        )
        let lines = [
            String(format: "WEIGHT   %.2f kg", specimen.weight),
            String(format: "LENGTH   %.1f cm", specimen.length),
            "ASSESSED   ¢ \(specimen.assessedValue.formatted())",
            specimen.isFavorite ? "FAVORITE SPECIMEN" : "ARCHIVED SPECIMEN"
        ]
        for (index, line) in lines.enumerated() {
            addLabel(line, at: CGPoint(x: frame.minX + 16, y: frame.maxY - 178 - CGFloat(index) * 25), size: 9, color: SKColor.white.withAlphaComponent(index == 3 ? 0.46 : 0.75), alignment: .left)
        }
        favoriteFrame = CGRect(x: frame.minX + 14, y: frame.minY + 76, width: frame.width - 28, height: 30)
        lockFrame = CGRect(x: frame.minX + 14, y: frame.minY + 42, width: (frame.width - 32) / 2, height: 28)
        releaseFrame = CGRect(x: lockFrame.maxX + 4, y: frame.minY + 42, width: (frame.width - 32) / 2, height: 28)
        addSmallButton(specimen.isFavorite ? "UNFAVORITE" : "FAVORITE", frame: favoriteFrame, enabled: true, accent: true)
        addSmallButton(specimen.isLocked ? "UNLOCK" : "LOCK", frame: lockFrame, enabled: true)
        addSmallButton("RELEASE", frame: releaseFrame, enabled: !specimen.isLocked, danger: true)
        addLabel("Catches are already appraised on landing", at: CGPoint(x: frame.midX, y: frame.minY + 19), size: 7, color: SKColor.white.withAlphaComponent(0.28))
    }

    private func addBadge(_ text: String, at position: CGPoint, color: SKColor) {
        let badge = SKShapeNode(circleOfRadius: 8)
        badge.position = position
        badge.fillColor = color.withAlphaComponent(0.24)
        badge.strokeColor = color.withAlphaComponent(0.68)
        badge.lineWidth = 0.8
        content.addChild(badge)
        addLabel(text, at: position, size: 7, color: color)
    }

    private func addSmallButton(
        _ title: String,
        frame: CGRect,
        enabled: Bool,
        accent: Bool = false,
        danger: Bool = false
    ) {
        let node = SKShapeNode(rect: frame, cornerRadius: 7)
        let base = danger
            ? SKColor(calibratedRed: 0.78, green: 0.22, blue: 0.19, alpha: 1)
            : SKColor(calibratedRed: 0.2, green: 0.68, blue: 0.68, alpha: 1)
        node.fillColor = enabled ? base.withAlphaComponent(accent ? 0.42 : 0.2) : SKColor.white.withAlphaComponent(0.025)
        node.strokeColor = enabled ? base.withAlphaComponent(0.56) : SKColor.white.withAlphaComponent(0.08)
        node.lineWidth = 0.8
        content.addChild(node)
        addLabel(title, at: CGPoint(x: frame.midX, y: frame.midY), size: 8, color: enabled ? SKColor.white.withAlphaComponent(0.84) : SKColor.white.withAlphaComponent(0.24))
    }

    private func addLabel(
        _ text: String,
        at position: CGPoint,
        size: CGFloat,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode = .center
    ) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.position = position
        content.addChild(label)
    }

    private func variantColor(_ variant: FishVariant) -> SKColor {
        switch variant {
        case .standard: return SKColor.white.withAlphaComponent(0.7)
        case .albino: return SKColor(calibratedRed: 1, green: 0.78, blue: 0.83, alpha: 1)
        case .melanistic: return SKColor(calibratedRed: 0.58, green: 0.62, blue: 0.72, alpha: 1)
        case .gilded: return SKColor(calibratedRed: 1, green: 0.72, blue: 0.16, alpha: 1)
        case .iridescent: return SKColor(calibratedRed: 0.48, green: 0.88, blue: 1, alpha: 1)
        case .ancient: return SKColor(calibratedRed: 0.34, green: 0.92, blue: 0.62, alpha: 1)
        }
    }
}
