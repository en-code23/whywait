import Foundation
import SpriteKit

enum FishDexTab {
    case fish
    case treasures
}

final class FishDexPanel: SKNode {
    private let background = SKShapeNode()
    private let content = SKNode()
    private var profile = FishingProfile()
    private var tab: FishDexTab = .fish
    private var selectedID: String?
    private var panelSize = CGSize.zero
    private var fishTabFrame = CGRect.zero
    private var treasureTabFrame = CGRect.zero
    private var itemFrames: [String: CGRect] = [:]

    override init() {
        super.init()
        name = "fishing-fishdex-panel"
        zPosition = 500
        isHidden = true
        addChild(background)
        addChild(content)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FishDexPanel does not support NSCoding")
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
        isHidden = true
        content.removeAllChildren()
        itemFrames.removeAll(keepingCapacity: true)
    }

    func layout(in sceneSize: CGSize) {
        panelSize = CGSize(
            width: max(420, min(FishingTuning.panelMaximumSize.width, sceneSize.width - 40)),
            height: max(360, min(FishingTuning.panelMaximumSize.height, sceneSize.height - 46))
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
        if !isHidden { rebuild() }
    }

    @discardableResult
    func handleClick(at scenePoint: CGPoint) -> Bool {
        guard !isHidden, let parent else { return false }
        let local = convert(scenePoint, from: parent)
        let panelBounds = CGRect(
            x: -panelSize.width / 2,
            y: -panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
        guard panelBounds.contains(local) else { return false }

        if fishTabFrame.contains(local) {
            tab = .fish
            selectedID = nil
            rebuild()
            return true
        }
        if treasureTabFrame.contains(local) {
            tab = .treasures
            selectedID = nil
            rebuild()
            return true
        }

        if let entry = itemFrames.first(where: { $0.value.contains(local) })?.key {
            selectedID = entry
            rebuild()
        }
        return true
    }

    private func rebuild() {
        content.removeAllChildren()
        itemFrames.removeAll(keepingCapacity: true)

        let top = panelSize.height / 2
        let left = -panelSize.width / 2
        addLabel(
            "FISHDEX",
            at: CGPoint(x: left + 24, y: top - 29),
            size: 18,
            color: .white,
            alignment: .left
        )
        addLabel(
            tab == .fish
                ? "\(profile.discoveredFishCount) / \(FishCatalog.all.count) DISCOVERED"
                : "\(profile.discoveredTreasureCount) / \(TreasureCatalog.all.count) FOUND",
            at: CGPoint(x: left + 24, y: top - 52),
            size: 9,
            color: SKColor.white.withAlphaComponent(0.58),
            alignment: .left
        )

        fishTabFrame = CGRect(x: left + 178, y: top - 58, width: 72, height: 30)
        treasureTabFrame = CGRect(x: left + 256, y: top - 58, width: 105, height: 30)
        addTab(title: "FISH", frame: fishTabFrame, active: tab == .fish)
        addTab(title: "TREASURES", frame: treasureTabFrame, active: tab == .treasures)
        addLabel(
            "D  CLOSE",
            at: CGPoint(x: panelSize.width / 2 - 24, y: top - 31),
            size: 9,
            color: SKColor.white.withAlphaComponent(0.46),
            alignment: .right
        )

        switch tab {
        case .fish: buildFishGrid()
        case .treasures: buildTreasureGrid()
        }
        buildDetails()
    }

    private func buildFishGrid() {
        let left = -panelSize.width / 2 + 22
        let top = panelSize.height / 2 - 82
        let detailsWidth: CGFloat = 226
        let gridWidth = panelSize.width - detailsWidth - 54
        let columns = 6
        let rows = max(1, Int(ceil(Double(FishCatalog.all.count) / Double(columns))))
        let spacing: CGFloat = 5
        let cardWidth = (gridWidth - (CGFloat(columns - 1) * spacing)) / CGFloat(columns)
        let gridHeight = panelSize.height - 112
        let cardHeight = (gridHeight - (CGFloat(rows - 1) * spacing)) / CGFloat(rows)

        for (index, definition) in FishCatalog.all.enumerated() {
            let column = index % columns
            let row = index / columns
            let frame = CGRect(
                x: left + (CGFloat(column) * (cardWidth + spacing)),
                y: top - cardHeight - (CGFloat(row) * (cardHeight + spacing)),
                width: cardWidth,
                height: cardHeight
            )
            itemFrames[definition.id] = frame
            let record = profile.fishRecord(for: definition.id)
            addCard(
                frame: frame,
                title: record.isDiscovered ? definition.name : "???",
                subtitle: record.isDiscovered ? definition.rarity.marker : "?",
                selected: selectedID == definition.id,
                rarity: record.isDiscovered ? definition.rarity : nil
            )
            let preview = FishNode.dexPreview(
                definition: definition,
                discovered: record.isDiscovered,
                scale: min(0.44, cardWidth / 145)
            )
            preview.position = CGPoint(x: frame.midX, y: frame.midY + 8)
            content.addChild(preview)
        }
    }

    private func buildTreasureGrid() {
        let left = -panelSize.width / 2 + 28
        let top = panelSize.height / 2 - 100
        let gridWidth = panelSize.width - 292
        let columns = 2
        let rows = 4
        let spacing: CGFloat = 12
        let cardWidth = (gridWidth - spacing) / 2
        let cardHeight = min(82, (panelSize.height - 150) / CGFloat(rows))

        for (index, definition) in TreasureCatalog.all.enumerated() {
            let column = index % columns
            let row = index / columns
            let frame = CGRect(
                x: left + (CGFloat(column) * (cardWidth + spacing)),
                y: top - cardHeight - (CGFloat(row) * (cardHeight + spacing)),
                width: cardWidth,
                height: cardHeight
            )
            itemFrames[definition.id] = frame
            let record = profile.treasureRecord(for: definition.id)
            addCard(
                frame: frame,
                title: record.isDiscovered ? definition.name : "???",
                subtitle: record.isDiscovered ? definition.rarity.marker : "?",
                selected: selectedID == definition.id,
                rarity: record.isDiscovered ? definition.rarity : nil
            )
            addLabel(
                record.isDiscovered ? definition.symbol : "?",
                at: CGPoint(x: frame.minX + 29, y: frame.midY + 1),
                size: 25,
                color: record.isDiscovered
                    ? rarityColor(definition.rarity)
                    : SKColor.white.withAlphaComponent(0.22)
            )
        }
    }

    private func buildDetails() {
        let detailLeft = panelSize.width / 2 - 212
        let detailWidth: CGFloat = 190
        let detailFrame = CGRect(
            x: detailLeft,
            y: -panelSize.height / 2 + 24,
            width: detailWidth,
            height: panelSize.height - 108
        )
        let background = SKShapeNode(
            rect: detailFrame,
            cornerRadius: 12
        )
        background.fillColor = SKColor.white.withAlphaComponent(0.045)
        background.strokeColor = SKColor.white.withAlphaComponent(0.1)
        background.lineWidth = 1
        content.addChild(background)

        guard let selectedID else {
            addLabel(
                "SELECT AN ENTRY",
                at: CGPoint(x: detailFrame.midX, y: detailFrame.midY),
                size: 10,
                color: SKColor.white.withAlphaComponent(0.34)
            )
            return
        }

        switch tab {
        case .fish:
            guard let definition = FishCatalog.species(id: selectedID) else { return }
            let record = profile.fishRecord(for: selectedID)
            guard record.isDiscovered else {
                addLockedDetails(in: detailFrame)
                return
            }
            let preview = FishNode.dexPreview(definition: definition, discovered: true, scale: 1.05)
            preview.position = CGPoint(x: detailFrame.midX, y: detailFrame.maxY - 58)
            content.addChild(preview)
            addDetailTitle(definition.name, rarity: definition.rarity, frame: detailFrame)
            let lines = [
                "Caught:  \(record.timesCaught)",
                String(format: "Largest:  %.2f kg", record.bestWeight),
                String(format: "Longest:  %.1f cm", record.bestLength),
                "Preferred:  \(definition.preferredZones.map(\.displayName).joined(separator: "/"))",
                "Best value:  \(record.bestSaleValue) coins",
                "Variants:  \(record.discoveredVariantIDs.filter { $0 != FishVariant.standard.rawValue }.count) / \(FishVariant.allCases.count - 1)"
            ]
            addDetailLines(lines, in: detailFrame)

        case .treasures:
            guard let definition = TreasureCatalog.treasure(id: selectedID) else { return }
            let record = profile.treasureRecord(for: selectedID)
            guard record.isDiscovered else {
                addLockedDetails(in: detailFrame)
                return
            }
            addLabel(
                definition.symbol,
                at: CGPoint(x: detailFrame.midX, y: detailFrame.maxY - 55),
                size: 48,
                color: rarityColor(definition.rarity)
            )
            addDetailTitle(definition.name, rarity: definition.rarity, frame: detailFrame)
            addDetailLines(
                [
                    "Found:  \(record.timesFound)",
                    "Best value:  \(record.bestValue) coins",
                    "Automatically sold"
                ],
                in: detailFrame
            )
        }
    }

    private func addDetailTitle(
        _ title: String,
        rarity: FishRarity,
        frame: CGRect
    ) {
        addLabel(
            title.uppercased(),
            at: CGPoint(x: frame.midX, y: frame.maxY - 103),
            size: title.count > 18 ? 11 : 13,
            color: .white
        )
        addLabel(
            rarity.displayName,
            at: CGPoint(x: frame.midX, y: frame.maxY - 125),
            size: 9,
            color: rarityColor(rarity)
        )
    }

    private func addDetailLines(_ lines: [String], in frame: CGRect) {
        for (index, line) in lines.enumerated() {
            addLabel(
                line,
                at: CGPoint(x: frame.minX + 15, y: frame.maxY - 170 - (CGFloat(index) * 28)),
                size: 10,
                color: SKColor.white.withAlphaComponent(index == lines.count - 1 ? 0.58 : 0.8),
                alignment: .left
            )
        }
    }

    private func addLockedDetails(in frame: CGRect) {
        addLabel(
            "?",
            at: CGPoint(x: frame.midX, y: frame.midY + 22),
            size: 52,
            color: SKColor.white.withAlphaComponent(0.22)
        )
        addLabel(
            "UNDISCOVERED",
            at: CGPoint(x: frame.midX, y: frame.midY - 27),
            size: 9,
            color: SKColor.white.withAlphaComponent(0.32)
        )
    }

    private func addTab(title: String, frame: CGRect, active: Bool) {
        let node = SKShapeNode(rect: frame, cornerRadius: 7)
        node.fillColor = active
            ? SKColor(calibratedRed: 0.22, green: 0.59, blue: 0.76, alpha: 0.5)
            : SKColor.white.withAlphaComponent(0.035)
        node.strokeColor = active
            ? SKColor(calibratedRed: 0.48, green: 0.86, blue: 1, alpha: 0.5)
            : SKColor.white.withAlphaComponent(0.08)
        node.lineWidth = 1
        content.addChild(node)
        addLabel(
            title,
            at: CGPoint(x: frame.midX, y: frame.midY),
            size: 9,
            color: active ? .white : SKColor.white.withAlphaComponent(0.5)
        )
    }

    private func addCard(
        frame: CGRect,
        title: String,
        subtitle: String,
        selected: Bool,
        rarity: FishRarity?
    ) {
        let card = SKShapeNode(rect: frame, cornerRadius: 8)
        card.fillColor = selected
            ? SKColor.white.withAlphaComponent(0.12)
            : SKColor.white.withAlphaComponent(0.035)
        card.strokeColor = selected
            ? (rarity.map(rarityColor) ?? SKColor.white.withAlphaComponent(0.3))
            : SKColor.white.withAlphaComponent(0.08)
        card.lineWidth = selected ? 1.4 : 0.8
        content.addChild(card)
        addLabel(
            title,
            at: CGPoint(x: frame.midX, y: frame.minY + 13),
            size: title.count > 15 ? 7.3 : 8.2,
            color: rarity == nil
                ? SKColor.white.withAlphaComponent(0.26)
                : SKColor.white.withAlphaComponent(0.76)
        )
        addLabel(
            subtitle,
            at: CGPoint(x: frame.maxX - 12, y: frame.maxY - 11),
            size: 8,
            color: rarity.map(rarityColor) ?? SKColor.white.withAlphaComponent(0.22)
        )
    }

    private func addLabel(
        _ text: String,
        at position: CGPoint,
        size: CGFloat,
        color: SKColor,
        alignment: SKLabelHorizontalAlignmentMode = .center
    ) {
        let label = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Medium")
        label.text = WWText.text(text)
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.position = position
        content.addChild(label)
    }

    private func rarityColor(_ rarity: FishRarity) -> SKColor {
        switch rarity {
        case .common: return SKColor.white.withAlphaComponent(0.76)
        case .uncommon:
            return SKColor(calibratedRed: 0.43, green: 0.88, blue: 0.53, alpha: 0.94)
        case .rare:
            return SKColor(calibratedRed: 0.4, green: 0.74, blue: 1, alpha: 0.96)
        case .epic:
            return SKColor(calibratedRed: 0.77, green: 0.44, blue: 1, alpha: 0.98)
        case .legendary:
            return SKColor(calibratedRed: 1, green: 0.73, blue: 0.18, alpha: 1)
        }
    }
}
