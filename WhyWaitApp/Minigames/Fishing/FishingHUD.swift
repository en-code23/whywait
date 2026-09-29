import Foundation
import SpriteKit

final class FishingHUD: SKNode {
    private let coinsShadow = WhyWaitLabelNode(fontNamed: "Menlo-Bold")
    private let coinsLabel = WhyWaitLabelNode(fontNamed: "Menlo-Bold")
    private let dexShadow = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let dexLabel = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let vaultLabel = WhyWaitLabelNode(fontNamed: "AvenirNext-Medium")
    private let zoneLabel = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let hintLabel = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Bold")

    private let feedbackContainer = SKNode()
    private let feedbackTitle = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let feedbackSubtitle = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Medium")

    private let catchContainer = SKNode()
    private let catchHalo = SKShapeNode(ellipseOf: CGSize(width: 166, height: 82))
    private let catchRule = SKShapeNode(rectOf: CGSize(width: 82, height: 1), cornerRadius: 0.5)
    private let catchEyebrow = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let catchName = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let catchRarity = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Medium")
    private let catchMeasurement = WhyWaitLabelNode(fontNamed: "Menlo-Bold")
    private let catchValue = WhyWaitLabelNode(fontNamed: "Menlo-Bold")
    private let catchRecord = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Bold")
    private var catchPreview: SKNode?

    private let tensionContainer = SKNode()
    private let tensionLabel = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Bold")
    private var tensionDots: [SKShapeNode] = []

    override init() {
        super.init()
        name = "fishing-hud"
        zPosition = 300
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FishingHUD does not support NSCoding")
    }

    func updateProfile(_ profile: FishingProfile) {
        let coins = "¢ \(profile.coins.formatted())"
        coinsLabel.text = coins
        coinsShadow.text = coins
        let dex = "FISHDEX  \(profile.discoveredFishCount)/\(FishCatalog.all.count)"
        dexLabel.text = dex
        dexShadow.text = dex
        let lure = profile.shopInventory.equippedLure.map {
            " · \($0.displayName) ×\(profile.shopInventory.quantity(of: $0))"
        } ?? ""
        vaultLabel.text = "TIDEVAULT  \(profile.storedFish.count)/\(profile.vaultCapacity)\(lure)"
    }

    func showZone(_ zone: FishingZone) {
        zoneLabel.removeAllActions()
        zoneLabel.text = WWText.text(zone.displayName)
        zoneLabel.alpha = 0
        zoneLabel.run(
            .sequence([
                .fadeAlpha(to: 0.78, duration: 0.08),
                .wait(forDuration: 0.62),
                .fadeOut(withDuration: 0.28)
            ])
        )
    }

    func showHint(_ text: String, duration: TimeInterval = 2.3) {
        hintLabel.removeAllActions()
        hintLabel.text = WWText.text(text)
        hintLabel.alpha = 0
        hintLabel.isHidden = false
        hintLabel.run(
            .sequence([
                .fadeAlpha(to: 0.86, duration: 0.12),
                .wait(forDuration: duration),
                .fadeOut(withDuration: 0.3)
            ])
        )
    }

    func showBite(at position: CGPoint) {
        feedbackContainer.position = CGPoint(x: position.x, y: position.y + 35)
        feedbackTitle.text = "!"
        feedbackTitle.fontSize = 28
        feedbackSubtitle.text = nil
        revealFeedback(autoHide: nil)
    }

    func showFailure(_ reason: FishingFailureReason) {
        feedbackContainer.position = CGPoint(x: layoutSize.width / 2, y: layoutSize.height * 0.6)
        feedbackTitle.fontSize = 22
        feedbackTitle.text = WWText.text(reason.rawValue)
        feedbackSubtitle.text = nil
        revealFeedback(autoHide: FishingTuning.failurePresentationDuration)
    }

    func showSmallFeedback(_ title: String, subtitle: String? = nil) {
        feedbackContainer.position = CGPoint(x: layoutSize.width / 2, y: layoutSize.height * 0.6)
        feedbackTitle.fontSize = 18
        feedbackTitle.text = WWText.text(title)
        feedbackSubtitle.text = subtitle.map(WWText.text)
        revealFeedback(autoHide: 0.9)
    }

    func hideFeedback() {
        feedbackContainer.removeAllActions()
        feedbackContainer.isHidden = true
        feedbackContainer.alpha = 0
    }

    func showCatch(
        _ catchItem: ProspectiveCatch,
        progression: FishingCatchProgression
    ) {
        hideFeedback()
        catchPreview?.removeFromParent()
        catchPreview = nil

        switch catchItem {
        case let .fish(specimen):
            if progression.isNewDiscovery {
                catchEyebrow.text = catchItem.isLegendary
                    ? "LEGENDARY DISCOVERY!"
                    : "NEW SPECIES!"
            } else if specimen.variant != .standard {
                catchEyebrow.text = "RARE \(specimen.variant.displayName) VARIANT"
            } else {
                catchEyebrow.text = "LANDED"
            }
        case .treasure:
            catchEyebrow.text = progression.isNewDiscovery
                ? "NEW TREASURE!"
                : "TREASURE FOUND"
        }
        catchName.text = catchItem.name.uppercased()
        catchRarity.text = "\(catchItem.rarity.marker)  \(catchItem.rarity.displayName)"
        catchValue.text = "+\(progression.coinsAwarded.formatted()) COINS"
        catchRecord.text = (progression.isNewWeightRecord || progression.isNewLengthRecord)
            ? "NEW RECORD"
            : (progression.vaultWasFull ? "TIDEVAULT FULL · CATCH APPRAISED" : nil)

        switch catchItem {
        case let .fish(specimen):
            catchMeasurement.text = String(
                format: "%.2f kg   ·   %.1f cm",
                specimen.weight,
                specimen.length
            )
            let preview = FishNode.dexPreview(
                definition: specimen.definition,
                discovered: true,
                scale: 1,
                variant: specimen.variant
            )
            preview.position = CGPoint(x: 0, y: 37)
            preview.alpha = 0
            preview.setScale(0.72)
            catchContainer.addChild(preview)
            preview.run(
                .group([
                    .fadeIn(withDuration: 0.16),
                    .scale(to: 1.18, duration: 0.24),
                    .moveBy(x: 0, y: 5, duration: 0.24)
                ])
            )
            catchPreview = preview
        case let .treasure(treasure):
            catchMeasurement.text = treasure.definition.symbol
            let preview = WhyWaitLabelNode(fontNamed: "HelveticaNeue-Light")
            preview.text = treasure.definition.symbol
            preview.fontSize = 48
            preview.fontColor = rarityColor(treasure.definition.rarity)
            preview.verticalAlignmentMode = .center
            preview.position = CGPoint(x: 0, y: 37)
            catchContainer.addChild(preview)
            catchPreview = preview
        }

        let rarityAccent = rarityColor(catchItem.rarity)
        catchRarity.fontColor = rarityAccent
        catchHalo.strokeColor = rarityAccent.withAlphaComponent(0.46)
        catchHalo.glowWidth = catchItem.isLegendary ? 5 : 1.5
        catchRule.fillColor = rarityAccent.withAlphaComponent(0.74)
        catchContainer.removeAllActions()
        WWText.localizeLabels(in: catchContainer)
        catchContainer.isHidden = false
        catchContainer.alpha = 0
        catchContainer.setScale(0.86)
        catchContainer.position = CGPoint(
            x: layoutSize.width / 2,
            y: (layoutSize.height * 0.56) - 6
        )
        catchContainer.run(
            .sequence([
                .group([
                    .fadeIn(withDuration: 0.14),
                    .scale(to: 1, duration: 0.2),
                    .moveBy(x: 0, y: 6, duration: 0.2)
                ]),
                .run { [weak self] in
                    guard let self else { return }
                    self.catchContainer.position = CGPoint(
                        x: self.layoutSize.width / 2,
                        y: self.layoutSize.height * 0.56
                    )
                }
            ])
        )
        if catchRecord.text != nil, !WhyWaitPresentationPreferences.reduceVisualEffects {
            catchRecord.run(
                .sequence([
                    .scale(to: 1.12, duration: 0.16),
                    .scale(to: 1, duration: 0.2)
                ])
            )
        }
    }

    func hideCatch() {
        catchContainer.removeAllActions()
        catchContainer.isHidden = true
        catchContainer.alpha = 0
        catchPreview?.removeFromParent()
        catchPreview = nil
    }

    func setFightTension(_ tension: CGFloat, level: FishingTensionVisualLevel) {
        tensionContainer.isHidden = false
        tensionLabel.text = WWText.text(level == .critical ? "LINE!" : "LINE")
        let activeCount = min(
            tensionDots.count,
            max(0, Int(ceil(min(1, tension) * CGFloat(tensionDots.count))))
        )
        let color: SKColor
        switch level {
        case .low: color = SKColor.white.withAlphaComponent(0.36)
        case .normal:
            color = SKColor(calibratedRed: 0.47, green: 0.87, blue: 1, alpha: 0.86)
        case .high:
            color = SKColor(calibratedRed: 1, green: 0.66, blue: 0.24, alpha: 0.94)
        case .critical:
            color = SKColor(calibratedRed: 1, green: 0.25, blue: 0.2, alpha: 1)
        }
        tensionLabel.fontColor = color
        for (index, dot) in tensionDots.enumerated() {
            dot.fillColor = index < activeCount
                ? color
                : SKColor.white.withAlphaComponent(0.13)
        }
    }

    func hideFightTension() {
        tensionContainer.isHidden = true
    }

    func reset(profile: FishingProfile) {
        updateProfile(profile)
        hideFeedback()
        hideCatch()
        hideFightTension()
        zoneLabel.removeAllActions()
        zoneLabel.alpha = 0
        hintLabel.removeAllActions()
        hintLabel.alpha = 0
    }

    private(set) var layoutSize = CGSize.zero

    func layout(in size: CGSize) {
        layoutSize = size
        let topY = max(32, size.height - 38)
        coinsLabel.position = CGPoint(x: 30, y: topY)
        coinsShadow.position = CGPoint(x: 31.2, y: topY - 1.2)
        dexLabel.position = CGPoint(x: 30, y: topY - 24)
        dexShadow.position = CGPoint(x: 31, y: topY - 25)
        vaultLabel.position = CGPoint(x: 30, y: topY - 43)
        zoneLabel.position = CGPoint(x: size.width / 2, y: topY)
        hintLabel.position = CGPoint(x: size.width / 2, y: max(72, size.height * 0.18))
        feedbackContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        catchContainer.position = CGPoint(x: size.width / 2, y: size.height * 0.56)
        tensionContainer.position = CGPoint(x: max(72, size.width - 78), y: topY - 8)
    }

    private func configure() {
        configureLabel(coinsShadow, size: 15, color: SKColor.black.withAlphaComponent(0.72))
        coinsShadow.horizontalAlignmentMode = .left
        addChild(coinsShadow)
        configureLabel(coinsLabel, size: 15, color: SKColor.white.withAlphaComponent(0.96))
        coinsLabel.horizontalAlignmentMode = .left
        addChild(coinsLabel)

        configureLabel(dexShadow, size: 10, color: SKColor.black.withAlphaComponent(0.7))
        dexShadow.horizontalAlignmentMode = .left
        addChild(dexShadow)
        configureLabel(dexLabel, size: 10, color: SKColor.white.withAlphaComponent(0.72))
        dexLabel.horizontalAlignmentMode = .left
        addChild(dexLabel)
        configureLabel(
            vaultLabel,
            size: 8.5,
            color: SKColor(calibratedRed: 0.48, green: 0.88, blue: 0.84, alpha: 0.64)
        )
        vaultLabel.horizontalAlignmentMode = .left
        addChild(vaultLabel)
        let persistentHUDVisible = WhyWaitPresentationPreferences.showGameHUD
        coinsShadow.isHidden = !persistentHUDVisible
        coinsLabel.isHidden = !persistentHUDVisible
        dexShadow.isHidden = !persistentHUDVisible
        dexLabel.isHidden = !persistentHUDVisible
        vaultLabel.isHidden = !persistentHUDVisible

        configureLabel(zoneLabel, size: 10, color: SKColor.white.withAlphaComponent(0.78))
        zoneLabel.alpha = 0
        addChild(zoneLabel)

        configureLabel(hintLabel, size: 12, color: SKColor.white.withAlphaComponent(0.86))
        hintLabel.alpha = 0
        addChild(hintLabel)

        configureLabel(feedbackTitle, size: 22, color: .white)
        feedbackTitle.position.y = 8
        feedbackContainer.addChild(feedbackTitle)
        configureLabel(
            feedbackSubtitle,
            size: 11,
            color: SKColor.white.withAlphaComponent(0.78)
        )
        feedbackSubtitle.position.y = -18
        feedbackContainer.addChild(feedbackSubtitle)
        feedbackContainer.isHidden = true
        addChild(feedbackContainer)

        catchHalo.position.y = 40
        catchHalo.fillColor = SKColor.black.withAlphaComponent(0.13)
        catchHalo.strokeColor = SKColor.white.withAlphaComponent(0.3)
        catchHalo.lineWidth = 1
        catchHalo.zPosition = -1
        catchContainer.addChild(catchHalo)
        catchRule.position.y = 16
        catchRule.fillColor = SKColor.white.withAlphaComponent(0.5)
        catchRule.strokeColor = .clear
        catchContainer.addChild(catchRule)

        configureLabel(catchEyebrow, size: 10, color: SKColor.white.withAlphaComponent(0.74))
        catchEyebrow.position.y = 93
        catchContainer.addChild(catchEyebrow)
        configureLabel(catchName, size: 25, color: .white)
        catchName.position.y = 72
        catchContainer.addChild(catchName)
        configureLabel(catchRarity, size: 11, color: .white)
        catchRarity.position.y = 5
        catchContainer.addChild(catchRarity)
        configureLabel(catchMeasurement, size: 13, color: SKColor.white.withAlphaComponent(0.9))
        catchMeasurement.position.y = -18
        catchContainer.addChild(catchMeasurement)
        configureLabel(
            catchValue,
            size: 12,
            color: SKColor(calibratedRed: 0.98, green: 0.82, blue: 0.26, alpha: 0.96)
        )
        catchValue.position.y = -42
        catchContainer.addChild(catchValue)
        configureLabel(
            catchRecord,
            size: 11,
            color: SKColor(calibratedRed: 0.48, green: 0.93, blue: 1, alpha: 0.96)
        )
        catchRecord.position.y = -64
        catchContainer.addChild(catchRecord)
        catchContainer.isHidden = true
        addChild(catchContainer)

        configureLabel(tensionLabel, size: 9, color: .white)
        tensionLabel.position.y = 10
        tensionContainer.addChild(tensionLabel)
        for index in 0..<5 {
            let dot = SKShapeNode(circleOfRadius: 2.2)
            dot.position = CGPoint(x: CGFloat(index - 2) * 8, y: -4)
            dot.fillColor = SKColor.white.withAlphaComponent(0.13)
            dot.strokeColor = .clear
            tensionContainer.addChild(dot)
            tensionDots.append(dot)
        }
        tensionContainer.isHidden = true
        addChild(tensionContainer)
    }

    private func revealFeedback(autoHide: TimeInterval?) {
        feedbackContainer.removeAllActions()
        feedbackContainer.isHidden = false
        feedbackContainer.alpha = 0
        feedbackContainer.setScale(0.78)
        var actions: [SKAction] = [
            .group([
                .fadeIn(withDuration: 0.08),
                .scale(to: 1, duration: 0.13)
            ])
        ]
        if let autoHide {
            actions.append(.wait(forDuration: autoHide * 0.65))
            actions.append(.fadeOut(withDuration: autoHide * 0.35))
        }
        feedbackContainer.run(.sequence(actions))
    }

    private func rarityColor(_ rarity: FishRarity) -> SKColor {
        switch rarity {
        case .common: return SKColor.white.withAlphaComponent(0.82)
        case .uncommon:
            return SKColor(calibratedRed: 0.45, green: 0.9, blue: 0.55, alpha: 0.96)
        case .rare:
            return SKColor(calibratedRed: 0.42, green: 0.76, blue: 1, alpha: 0.98)
        case .epic:
            return SKColor(calibratedRed: 0.78, green: 0.48, blue: 1, alpha: 0.98)
        case .legendary:
            return SKColor(calibratedRed: 1, green: 0.75, blue: 0.2, alpha: 1)
        }
    }

    private func configureLabel(_ label: SKLabelNode, size: CGFloat, color: SKColor) {
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
    }
}
