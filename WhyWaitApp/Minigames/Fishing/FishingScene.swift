import Foundation
import SpriteKit

final class FishingScene: SKScene {
    private(set) var gameState: FishingState = .resetting
    var profile: FishingProfile
    var sessionStatistics = FishingSessionStatistics()

    let saveStore: FishingSaveStore
    let catchGenerator: CatchGenerator
    let fightController: FishingFightController
    let castController = FishingCastController()

    let ambientLayer = SKNode()
    let catchLayer = SKNode()
    let effects = FishingEffects()
    let lineRenderer = FishingLineRenderer()
    let rod = FishingRod()
    let bobber = FishingBobber()
    let hud = FishingHUD()
    let fishDexPanel = FishDexPanel()
    let upgradePanel = UpgradePanel()
    let tidevaultPanel = TidevaultPanel()

    var activeFishNode: FishNode?
    var activeTreasureNode: SKNode?
    var generatedCatch: GeneratedCatch?
    var activeTransaction: FishingCatchTransaction?
    var activeZone: FishingZone = .near
    var castLandingPosition = CGPoint.zero
    var latestCursorPosition: CGPoint?
    var isMouseHeld = false
    var isGameActive = false
    var interactionGeneration = 0
    var lastUpdateTime: TimeInterval?
    var nextAmbientTime: TimeInterval = .infinity
    var nextFightRippleTime: TimeInterval = 0
    var tutorialSession = false

    var worldMaximumCastDistance: CGFloat {
        min(
            FishingTuning.maximumWorldCastDistance,
            max(270, min(size.width * 0.72, size.height * 0.82))
        )
    }

    var equipmentStats: FishingEquipmentStats {
        FishingEquipmentStats(levels: profile.equipment, worldMaximumCastDistance: worldMaximumCastDistance, rod: profile.equippedRod)
    }

    init(
        size: CGSize,
        saveStore: FishingSaveStore = FishingSaveStore(),
        catchGenerator: CatchGenerator = CatchGenerator(),
        fightController: FishingFightController = FishingFightController()
    ) {
        self.saveStore = saveStore
        self.catchGenerator = catchGenerator
        self.fightController = fightController
        profile = saveStore.load()
        super.init(size: size)
        configureScene()
    }

    required init?(coder aDecoder: NSCoder) {
        saveStore = FishingSaveStore()
        catchGenerator = CatchGenerator()
        fightController = FishingFightController()
        profile = saveStore.load()
        super.init(coder: aDecoder)
        configureScene()
    }

    override func didMove(to view: SKView) {
        layoutContent()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutContent()
        guard isGameActive else { return }

        if gameState == .showingDex {
            fishDexPanel.layout(in: size)
        } else if gameState == .showingUpgrades {
            upgradePanel.layout(in: size)
        } else if gameState == .showingVault {
            tidevaultPanel.layout(in: size)
        } else if gameState != .readyToCast {
            resetCurrentInteraction(showHint: false)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime
        guard isGameActive else { return }

        if rawDelta > FishingTuning.updateInterruptionThreshold {
            handleTimingInterruption()
        }
        let delta = min(
            FishingTuning.maximumFightDeltaTime,
            max(0, rawDelta)
        )
        rod.simulate(deltaTime: rawDelta > FishingTuning.updateInterruptionThreshold ? 0 : delta)

        switch gameState {
        case .chargingCast:
            updateChargingVisual()
        case .bobberFlying:
            updateCastFlight(deltaTime: delta)
        case .waitingForBite:
            lineRenderer.updateWaiting(from: rod.tipPosition, to: bobber.position)
            updateAmbient(currentTime: currentTime)
        case .biteWindow:
            lineRenderer.updateWaiting(from: rod.tipPosition, to: bobber.position)
        case .fighting:
            updateFight(deltaTime: delta)
        case .readyToCast, .hooked, .catchComplete, .failedCatch,
             .showingDex, .showingUpgrades, .showingVault, .resetting:
            break
        }
    }

    func startGame() {
        guard !isGameActive else { return }
        isGameActive = true
        profile = saveStore.load()
        tutorialSession = !profile.hasShownBasicTutorial
        rod.equip(profile.equippedRod)
        if tutorialSession {
            profile.hasShownBasicTutorial = true
            saveProfile()
        }
        resetCurrentInteraction(showHint: tutorialSession)
    }

    func stopGame() {
        guard isGameActive else { return }
        isGameActive = false
        interactionGeneration += 1
        cancelScheduledActions()
        clearInteractionNodes()
        fishDexPanel.dismiss()
        upgradePanel.dismiss()
        tidevaultPanel.dismiss()
        effects.clearTransientEffects()
        hud.reset(profile: profile)
        castController.cancel()
        fightController.cancel()
        isMouseHeld = false
        lastUpdateTime = nil
        gameState = .resetting
    }

    func resetCurrentInteraction(showHint: Bool = true) {
        guard isGameActive else { return }
        if gameState != .resetting {
            guard transition(to: .resetting) else { return }
        }

        interactionGeneration += 1
        cancelScheduledActions()
        clearInteractionNodes()
        fishDexPanel.dismiss()
        upgradePanel.dismiss()
        tidevaultPanel.dismiss()
        effects.clearTransientEffects()
        castController.cancel()
        fightController.cancel()
        generatedCatch = nil
        activeTransaction = nil
        activeZone = .near
        castLandingPosition = .zero
        isMouseHeld = false
        nextAmbientTime = .infinity
        nextFightRippleTime = 0
        lastUpdateTime = nil
        rod.resetVisual()
        rod.layout(in: size)
        if let cursor = latestCursorPosition {
            rod.setAim(toward: cursor, power: 0)
        }
        hud.reset(profile: profile)
        guard transition(to: .readyToCast) else { return }
        if showHint {
            hud.showHint("HOLD + RELEASE TO CAST")
        }
    }

    func layoutContent() {
        rod.layout(in: size)
        hud.layout(in: size)
        fishDexPanel.layout(in: size)
        upgradePanel.layout(in: size)
        tidevaultPanel.layout(in: size)
        if gameState == .readyToCast, let cursor = latestCursorPosition {
            rod.setAim(toward: cursor, power: 0)
        }
    }

    func handleTimingInterruption() {
        isMouseHeld = false
        if gameState == .chargingCast {
            castController.cancel()
            rod.resetVisual()
            _ = transition(to: .readyToCast)
        }
    }

    func clearInteractionNodes() {
        bobber.resetVisual()
        lineRenderer.hide()
        activeFishNode?.removeAllActions()
        activeFishNode?.removeFromParent()
        activeFishNode = nil
        activeTreasureNode?.removeAllActions()
        activeTreasureNode?.removeFromParent()
        activeTreasureNode = nil
        catchLayer.removeAllChildren()
        hud.hideCatch()
        hud.hideFeedback()
        hud.hideFightTension()
    }

    @discardableResult
    func saveProfile() -> Bool {
        guard !saveStore.save(profile) else { return true }
        // Never keep displaying an uncommitted purchase/catch as if it persisted.
        profile = saveStore.load()
        hud.updateProfile(profile)
        hud.showSmallFeedback("SAVE CHANGED OR UNAVAILABLE · TRY AGAIN")
        upgradePanel.refresh(profile: profile)
        fishDexPanel.refresh(profile: profile)
        tidevaultPanel.refresh(profile: profile)
        return false
    }

    func cancelScheduledActions() {
        removeAction(forKey: "fishing-bite-wait")
        removeAction(forKey: "fishing-hook-window")
        removeAction(forKey: "fishing-treasure-land")
        removeAction(forKey: "fishing-result-reset")
    }

    @discardableResult
    func transition(to newState: FishingState) -> Bool {
        guard gameState.canTransition(to: newState) else {
            assertionFailure("Invalid Fishing state transition: \(gameState) -> \(newState)")
            return false
        }
        gameState = newState
        return true
    }

    private func configureScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        isUserInteractionEnabled = false
        physicsWorld.gravity = .zero

        ambientLayer.name = "fishing-ambient"
        catchLayer.name = "fishing-catches"
        addChild(ambientLayer)
        addChild(effects)
        addChild(lineRenderer)
        addChild(catchLayer)
        addChild(bobber)
        addChild(rod)
        addChild(hud)
        addChild(fishDexPanel)
        addChild(upgradePanel)
        addChild(tidevaultPanel)
        layoutContent()
        hud.updateProfile(profile)
    }
}
