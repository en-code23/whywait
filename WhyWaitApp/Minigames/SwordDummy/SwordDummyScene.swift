import Foundation
import SpriteKit

final class SwordDummyScene: SKScene {
    private(set) var gameState: SwordDummySceneState = .resetting
    var swordControlState: SwordControlState = .recovering
    var sessionStatistics = SwordDummySessionStatistics()
    var settings = SwordDummySettings()

    let swordSimulation = SwordPhysicsSimulation()
    let sword = PhysicsSword()
    let dummy = TrainingDummy()
    let collisionDetector = SwordCollisionDetector<DummyHitRegionID>()
    let contactGate = SwordContactGate<DummyHitRegionID>()
    let swingTracker = SwordSwingTracker()
    let comboController = SwordComboController()
    let challengeController = SwordChallengeController()
    let trail = SwordTrail()
    let effects = SwordEffects()
    let hud = SwordDummyHUD()
    let settingsPanel = SwordSettingsPanel()
    let debugOverlay = SwordDebugOverlay()

    var latestCursorPosition: CGPoint?
    var previousSwordSnapshot: SwordTransformSnapshot
    var isGameActive = false
    var hasReceivedCursorSample = false
    var lastUpdateTime: TimeInterval?
    var transitionGeneration = 0
    var dummyPositionIndex = 0
    var isSettingsPresented = false

    override init(size: CGSize) {
        previousSwordSnapshot = swordSimulation.snapshot
        super.init(size: size)
        configureScene()
    }

    required init?(coder aDecoder: NSCoder) {
        previousSwordSnapshot = swordSimulation.snapshot
        super.init(coder: aDecoder)
        configureScene()
    }

    override func didMove(to view: SKView) {
        layoutContent()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutContent()
        guard isGameActive,
              abs(oldSize.width - size.width) > 1
                || abs(oldSize.height - size.height) > 1 else {
            return
        }
        resetTrainingSetup(resetSessionStatistics: false)
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime
        guard isGameActive else { return }

        if rawDelta > SwordEngineTuning.interruptionThreshold {
            stabilizeAfterInputInterruption()
            return
        }
        let delta = min(max(0, rawDelta), SwordEngineTuning.maximumFrameDelta)
        guard delta > 0 else { return }

        dummy.update(deltaTime: delta)
        comboController.update(at: currentTime)
        hud.setCombo(comboController.count)

        if let cursor = latestCursorPosition {
            swordSimulation.setCursorTarget(cursor)
        }
        let diagnostics = swordSimulation.update(deltaTime: delta)
        swordSimulation.constrain(to: CGRect(origin: .zero, size: size))
        let currentSnapshot = swordSimulation.snapshot
        sword.apply(currentSnapshot)

        let tipSpeed = SwordMath.magnitude(currentSnapshot.velocity(at: currentSnapshot.bladeTip))
        let bladeMiddle = SwordMath.lerp(currentSnapshot.bladeStart, currentSnapshot.bladeTip, progress: 0.5)
        let bladeSpeed = SwordMath.magnitude(currentSnapshot.velocity(at: bladeMiddle))
        let swingSpeed = max(tipSpeed, bladeSpeed)
        swingTracker.update(speed: swingSpeed, deltaTime: delta)

        if swordControlState == .normal {
            trail.update(previous: previousSwordSnapshot, current: currentSnapshot, speed: swingSpeed)
        }
        if gameState == .playing,
           swordControlState == .normal,
           !isSettingsPresented {
            processCombat(
                previous: previousSwordSnapshot,
                current: currentSnapshot,
                currentTime: currentTime
            )
        } else {
            contactGate.updateOverlaps([])
        }

        debugOverlay.update(snapshot: currentSnapshot, diagnostics: diagnostics)
        previousSwordSnapshot = swordSimulation.snapshot
    }

    func startGame() {
        guard !isGameActive else { return }
        isGameActive = true
        sessionStatistics = SwordDummySessionStatistics()
        resetTrainingSetup(resetSessionStatistics: false)
#if DEBUG
        if ProcessInfo.processInfo.environment["WHYWAIT_SWORD_SETTINGS_OPEN"] == "1" {
            toggleSettings()
        }
#endif
    }

    func stopGame() {
        guard isGameActive else { return }
        isGameActive = false
        transitionGeneration += 1
        cancelScheduledActions()
        sword.removeAllActions()
        dummy.removeAllActions()
        trail.reset()
        effects.clear()
        settingsPanel.dismiss()
        debugOverlay.reset()
        contactGate.reset()
        swingTracker.reset()
        comboController.reset()
        latestCursorPosition = nil
        hasReceivedCursorSample = false
        lastUpdateTime = nil
        gameState = .resetting
        swordControlState = .recovering
        isSettingsPresented = false
    }

    func resetTrainingSetup(resetSessionStatistics: Bool = false) {
        guard isGameActive else { return }
        if gameState != .resetting {
            guard transition(to: .resetting) else { return }
        }

        transitionGeneration += 1
        cancelScheduledActions()
        isSettingsPresented = false
        settingsPanel.dismiss()
        trail.reset()
        effects.clear()
        debugOverlay.reset()
        contactGate.reset()
        swingTracker.reset()
        comboController.reset()
        if resetSessionStatistics {
            sessionStatistics = SwordDummySessionStatistics()
        }
        challengeController.reset(startingIndex: Int.random(in: 0..<SwordChallengeType.allCases.count))

        swordSimulation.configure(parameters: settings.physicsParameters)
        dummy.configure(
            reaction: settings.dummyReaction,
            durability: settings.dummyDurability
        )
        let placementIndex = settings.dummyPlacement == .fixed ? 0 : dummyPositionIndex
        let dummyPosition = safeDummyPosition(index: placementIndex)
        dummy.reset(at: dummyPosition)
        if settings.dummyPlacement == .varied {
            dummyPositionIndex = (dummyPositionIndex + 1) % 3
        }

        let target = latestCursorPosition ?? CGPoint(
            x: max(120, size.width * 0.26),
            y: max(130, size.height * 0.46)
        )
        swordSimulation.reset(handlePosition: clampedCursorTarget(target), angle: 0.08)
        previousSwordSnapshot = swordSimulation.snapshot
        sword.apply(previousSwordSnapshot)
        sword.setRecovering(false)
        swordControlState = .normal
        lastUpdateTime = nil
        contactGate.updateOverlaps(
            collisionDetector.overlappingRegions(
                snapshot: previousSwordSnapshot,
                regions: dummy.hitRegions()
            )
        )
        hud.layout(in: size, dummyPosition: dummyPosition)
        hud.reset(challenge: challengeController.progress)
        settingsPanel.layout(in: size)
        if isSettingsPresented {
            settingsPanel.present(settings: settings, in: size)
        }
        _ = transition(to: .playing)
    }

    func layoutContent() {
        let dummyPosition = safeDummyPosition(index: max(0, dummyPositionIndex - 1))
        if !isGameActive {
            dummy.position = dummyPosition
        }
        hud.layout(in: size, dummyPosition: dummy.position)
        settingsPanel.layout(in: size)
    }

    func safeDummyPosition(index: Int) -> CGPoint {
        let horizontalRatios: [CGFloat] = [0.68, 0.52, 0.79]
        let safeX = SwordMath.clamp(
            size.width * horizontalRatios[index % horizontalRatios.count],
            minimum: 145,
            maximum: max(145, size.width - 145)
        )
        let safeY = SwordMath.clamp(
            size.height * 0.2,
            minimum: 70,
            maximum: max(70, size.height - 235)
        )
        return CGPoint(x: safeX, y: safeY)
    }

    func clampedCursorTarget(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: SwordMath.clamp(point.x, minimum: 18, maximum: max(18, size.width - 18)),
            y: SwordMath.clamp(point.y, minimum: 18, maximum: max(18, size.height - 18))
        )
    }

    func stabilizeAfterInputInterruption() {
        let target = clampedCursorTarget(latestCursorPosition ?? swordSimulation.snapshot.handlePoint)
        swordSimulation.reset(handlePosition: target, angle: swordSimulation.snapshot.angle)
        previousSwordSnapshot = swordSimulation.snapshot
        sword.apply(previousSwordSnapshot)
        swordControlState = .normal
        sword.setRecovering(false)
        swingTracker.reset()
        contactGate.reset()
        trail.reset()
        hasReceivedCursorSample = false
    }

    func cancelScheduledActions() {
        removeAction(forKey: "sword-recovery")
        removeAction(forKey: "dummy-rebuild")
    }

    @discardableResult
    func transition(to next: SwordDummySceneState) -> Bool {
        guard gameState.canTransition(to: next) else {
            assertionFailure("Invalid Sword Dummy transition: \(gameState) -> \(next)")
            return false
        }
        gameState = next
        return true
    }

    private func configureScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        isUserInteractionEnabled = false
        physicsWorld.gravity = .zero

        addChild(trail)
        addChild(dummy)
        addChild(sword)
        addChild(effects)
        hud.isHidden = !WhyWaitPresentationPreferences.showGameHUD
        addChild(hud)
        addChild(settingsPanel)
        addChild(debugOverlay)
        layoutContent()
    }
}
