import Foundation
import SpriteKit

final class ZombieSwordScene: SKScene {
    var gameState: ZombieSwordSceneState = .resetting
    var swordControlState: SwordControlState = .recovering
    var sessionStatistics = ZombieSwordSessionStatistics()

    let player = ZombieSwordPlayer()
    let swordSimulation = SwordPhysicsSimulation()
    let sword = PhysicsSword()
    let trail = SwordTrail()
    let debugOverlay = SwordDebugOverlay()
    let collisionDetector = SwordCollisionDetector<ZombieHitRegionID>()
    let contactGate = SwordContactGate<ZombieHitRegionID>()
    let swingTracker = SwordSwingTracker()
    let comboController = ZombieSwordComboController()
    let challengeController = ZombieSwordChallengeController()
    let waveController: ZombieWaveController
    let spawner: ZombieSpawner
    let effects = ZombieSwordEffects()
    let hud = ZombieSwordHUD()

    var zombies: [Zombie] = []
    var pendingWarnings: [ZombieSpawnWarning] = []
    var latestCursorPosition: CGPoint?
    var previousSwordSnapshot: SwordTransformSnapshot
    var overlappingZombies: Set<UUID> = []
    var isGameActive = false
    var hasReceivedCursorSample = false
    var lastUpdateTime: TimeInterval?
    var transitionTimer: TimeInterval = 0
    var transitionGeneration = 0
    var score = 0
#if DEBUG
    let visualLineupEnabled = ProcessInfo.processInfo.environment["WHYWAIT_ZOMBIE_VISUAL_LINEUP"] == "1"
#endif

    override convenience init(size: CGSize) {
        self.init(size: size, seed: UInt64.random(in: 1...UInt64.max))
    }

    init(size: CGSize, seed: UInt64) {
        waveController = ZombieWaveController(seed: seed)
        spawner = ZombieSpawner(seed: seed ^ 0xA5A5_A5A5_A5A5_A5A5)
        previousSwordSnapshot = swordSimulation.snapshot
        super.init(size: size)
        configureScene()
    }

    required init?(coder aDecoder: NSCoder) {
        waveController = ZombieWaveController()
        spawner = ZombieSpawner()
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
              abs(oldSize.width - size.width) > 1 || abs(oldSize.height - size.height) > 1 else {
            return
        }
        resetRun()
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

        if challengeController.update(deltaTime: delta) {
            hud.setChallenge(challengeController.progress)
        }
        comboController.update(at: currentTime)
        updateStateTimers(deltaTime: delta)

        if gameState == .playing {
#if DEBUG
            if !visualLineupEnabled {
                updateSpawning(deltaTime: delta)
                updateZombies(deltaTime: delta)
            }
#else
            updateSpawning(deltaTime: delta)
            updateZombies(deltaTime: delta)
#endif
        }

        if let cursor = latestCursorPosition {
            swordSimulation.setCursorTarget(cursor)
        }
        let diagnostics = swordSimulation.update(deltaTime: delta)
        swordSimulation.constrain(to: CGRect(origin: .zero, size: size))
        let currentSnapshot = swordSimulation.snapshot
        sword.apply(currentSnapshot)
        let bladeMiddle = SwordMath.lerp(
            currentSnapshot.bladeStart,
            currentSnapshot.bladeTip,
            progress: 0.5
        )
        let swingSpeed = max(
            SwordMath.magnitude(currentSnapshot.velocity(at: currentSnapshot.bladeTip)),
            SwordMath.magnitude(currentSnapshot.velocity(at: bladeMiddle))
        )
        swingTracker.update(speed: swingSpeed, deltaTime: delta)
        if swordControlState == .normal {
            trail.update(previous: previousSwordSnapshot, current: currentSnapshot, speed: swingSpeed)
        }
        if gameState == .playing, swordControlState == .normal {
            processCombat(
                previous: previousSwordSnapshot,
                current: currentSnapshot,
                currentTime: currentTime
            )
        } else {
            contactGate.updateOverlaps([])
            overlappingZombies.removeAll(keepingCapacity: true)
        }
        debugOverlay.update(snapshot: currentSnapshot, diagnostics: diagnostics)
        previousSwordSnapshot = currentSnapshot

        zombies.removeAll { $0.parent == nil }
        hud.update(
            health: player.health,
            wave: waveController.currentWave,
            score: score,
            combo: comboController.count
        )
        if gameState == .playing {
#if DEBUG
            if !visualLineupEnabled { checkForWaveCompletion() }
#else
            checkForWaveCompletion()
#endif
        }
    }

    func startGame() {
        guard !isGameActive else { return }
        isGameActive = true
        resetRun()
    }

    func stopGame() {
        guard isGameActive else { return }
        isGameActive = false
        transitionGeneration += 1
        removeAllActions()
        clearEnemies()
        waveController.reset()
        spawner.reset()
        trail.reset()
        effects.clear()
        debugOverlay.reset()
        contactGate.reset()
        swingTracker.reset()
        comboController.reset()
        latestCursorPosition = nil
        hasReceivedCursorSample = false
        lastUpdateTime = nil
        gameState = .resetting
        swordControlState = .recovering
    }

    func resetRun() {
        guard isGameActive else { return }
        gameState = .resetting
        transitionGeneration += 1
        removeAction(forKey: "sword-recovery")
        clearEnemies()
        waveController.reset()
        spawner.reset()
        trail.reset()
        effects.clear()
        debugOverlay.reset()
        contactGate.reset()
        swingTracker.reset()
        comboController.reset()
        challengeController.reset(startingIndex: Int.random(in: 0..<ZombieSwordChallengeType.allCases.count))
        sessionStatistics = ZombieSwordSessionStatistics()
        score = 0

        let center = safePlayerPosition()
        player.reset(at: center)
        swordSimulation.configure(parameters: .standard)
        let target = clampedCursorTarget(
            latestCursorPosition ?? CGPoint(x: max(110, center.x - 190), y: center.y)
        )
        swordSimulation.reset(handlePosition: target, angle: 0.08)
        previousSwordSnapshot = swordSimulation.snapshot
        sword.apply(previousSwordSnapshot)
        sword.setRecovering(false)
        swordControlState = .normal
        hasReceivedCursorSample = latestCursorPosition != nil
        lastUpdateTime = nil
        hud.layout(in: size)
        hud.update(health: player.health, wave: 0, score: 0, combo: 0)
        hud.setChallenge(challengeController.progress)
        gameState = .waveTransition
        transitionTimer = 0.35
#if DEBUG
        if visualLineupEnabled { installVisualLineup() }
#endif
    }

    func layoutContent() {
        hud.layout(in: size)
        if !isGameActive { player.position = safePlayerPosition() }
    }

    func safePlayerPosition() -> CGPoint {
        CGPoint(
            x: SwordMath.clamp(size.width * 0.5, minimum: 120, maximum: max(120, size.width - 120)),
            y: SwordMath.clamp(size.height * 0.47, minimum: 115, maximum: max(115, size.height - 115))
        )
    }

    func clampedCursorTarget(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: SwordMath.clamp(point.x, minimum: 18, maximum: max(18, size.width - 18)),
            y: SwordMath.clamp(point.y, minimum: 18, maximum: max(18, size.height - 18))
        )
    }

    private func configureScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        isUserInteractionEnabled = false
        physicsWorld.gravity = .zero
        addChild(trail)
        addChild(player)
        addChild(sword)
        addChild(effects)
        hud.isHidden = !WhyWaitPresentationPreferences.showGameHUD
        addChild(hud)
        addChild(debugOverlay)
        layoutContent()
    }

#if DEBUG
    private func installVisualLineup() {
        gameState = .playing
        transitionTimer = 0
        let types = ZombieType.allCases
        for (index, type) in types.enumerated() {
            let zombie = Zombie(
                type: type,
                wave: 1,
                position: CGPoint(
                    x: size.width * CGFloat(index + 1) / CGFloat(types.count + 1),
                    y: size.height * 0.48
                )
            )
            zombie.prepareVisualPreview()
            zombies.append(zombie)
            addChild(zombie)
        }
    }
#endif
}
