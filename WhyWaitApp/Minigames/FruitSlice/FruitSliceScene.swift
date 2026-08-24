import Foundation
import SpriteKit

final class FruitSliceScene: SKScene {
    private(set) var gameState: FruitSliceState = .ready
    private(set) var score = 0
    private(set) var lives = FruitSliceTuning.startingLives

    private let launchableLayer = SKNode()
    private let effectsLayer = SKNode()
    private let bladeTrail = BladeTrail()
    private let hud = FruitSliceHUD()
    private let bladeTracker = BladeTracker()
    private let comboController = ComboController()
    private let spawner = FruitSpawner()

    private var fruits: [FruitNode] = []
    private var bombs: [BombNode] = []
    private var fruitHalves: [FruitHalfNode] = []

    private var isGameActive = false
    private var transitionToken = 0
    private var lastUpdateTime: TimeInterval?
    private var runStartTime: TimeInterval?

    override init(size: CGSize) {
        super.init(size: size)
        configureScene()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureScene()
    }

    override func didMove(to view: SKView) {
        hud.layout(in: size)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        hud.layout(in: size)
        resetBladeInput()
        keepLaunchablesWithinHorizontalBounds()
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDeltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        guard isGameActive else {
            return
        }

        if rawDeltaTime > FruitSliceTuning.updateDiscontinuityThreshold {
            resetBladeInput()
        }

        cleanupOffscreenObjects(countMisses: gameState == .playing)

        guard gameState == .playing else {
            return
        }

        if bladeTracker.expire(at: currentTime) {
            comboController.endSwipe()
        }

        if runStartTime == nil {
            runStartTime = currentTime
            spawner.reset(at: currentTime)
        }

        guard let runStartTime else {
            return
        }

        let activeLaunchables = fruits.count + bombs.count
        let availableSlots = max(
            0,
            FruitSliceTuning.maximumSimultaneousLaunchables - activeLaunchables
        )
        let launches = spawner.launchesIfDue(
            currentTime: currentTime,
            runElapsedTime: currentTime - runStartTime,
            sceneSize: size,
            availableSlots: availableSlots
        )
        launches.forEach(spawn)
    }

    func startGame() {
        guard !isGameActive else {
            return
        }

        isGameActive = true
        resetRun()
    }

    func stopGame() {
        guard isGameActive else {
            return
        }

        isGameActive = false
        transitionToken += 1
        cancelScheduledRestart()
        clearRunContent()
        resetBladeInput()
        comboController.reset()
        lastUpdateTime = nil
        runStartTime = nil
        gameState = .ready
    }

    func resetRun() {
        guard isGameActive, gameState != .resetting else {
            return
        }

        guard transition(to: .resetting) else {
            return
        }

        transitionToken += 1
        cancelScheduledRestart()
        clearRunContent()
        resetBladeInput()
        comboController.reset()

        score = 0
        lives = FruitSliceTuning.startingLives
        runStartTime = nil
        lastUpdateTime = nil
        hud.reset(score: score, lives: lives)

        guard transition(to: .ready) else {
            return
        }
        _ = transition(to: .playing)
    }

    func mouseMoved(toScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              gameState == .playing,
              let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }

        let timestamp = ProcessInfo.processInfo.systemUptime
        switch bladeTracker.record(position: sceneLocation, timestamp: timestamp) {
        case .primed, .ignored:
            break
        case .inactive:
            comboController.endSwipe()
        case .interrupted:
            bladeTrail.reset()
            comboController.endSwipe()
        case let .cutting(segment):
            bladeTrail.add(segment: segment)
            processSlice(segment, timestamp: timestamp)
        }
    }

    private func configureScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        isUserInteractionEnabled = false
        physicsWorld.gravity = FruitSliceTuning.gravity

        launchableLayer.name = "fruit-slice-launchables"
        effectsLayer.name = "fruit-slice-effects"
        addChild(launchableLayer)
        addChild(effectsLayer)
        addChild(bladeTrail)
        hud.isHidden = !WhyWaitPresentationPreferences.showGameHUD
        addChild(hud)
        hud.layout(in: size)
    }

    private func spawn(_ request: FruitLaunchRequest) {
        guard gameState == .playing else {
            return
        }

        switch request.kind {
        case let .fruit(type):
            let fruit = FruitNode(
                type: type,
                velocity: request.velocity,
                angularVelocity: request.angularVelocity
            )
            fruit.position = request.position
            launchableLayer.addChild(fruit)
            fruits.append(fruit)
        case .bomb:
            let bomb = BombNode(
                velocity: request.velocity,
                angularVelocity: request.angularVelocity
            )
            bomb.position = request.position
            launchableLayer.addChild(bomb)
            bombs.append(bomb)
        }
    }

    private func processSlice(_ blade: CuttingBladeSegment, timestamp: TimeInterval) {
        guard gameState == .playing else {
            return
        }

        if let bomb = intersectedBomb(by: blade), bomb.trigger() {
            let burstPosition = bomb.position
            bomb.physicsBody = nil
            bomb.removeAllActions()
            bomb.removeFromParent()
            bombs.removeAll { $0 === bomb }
            SliceEffects.addBombBurst(to: effectsLayer, at: burstPosition)
            endRun(reason: .bomb)
            return
        }

        for fruit in fruits where fruit.parent != nil {
            guard let intersection = SliceGeometry.intersection(
                segmentStart: blade.start,
                segmentEnd: blade.end,
                circleCenter: fruit.position,
                circleRadius: fruit.collisionRadius + FruitSliceTuning.bladeCollisionPadding
            ), fruit.markSliced() else {
                continue
            }

            slice(
                fruit,
                intersection: intersection,
                blade: blade,
                timestamp: timestamp
            )
        }
        fruits.removeAll { $0.parent == nil }
    }

    private func intersectedBomb(by blade: CuttingBladeSegment) -> BombNode? {
        bombs.first { bomb in
            !bomb.hasTriggered
                && SliceGeometry.intersection(
                    segmentStart: blade.start,
                    segmentEnd: blade.end,
                    circleCenter: bomb.position,
                    circleRadius: bomb.collisionRadius + FruitSliceTuning.bladeCollisionPadding
                ) != nil
        }
    }

    private func slice(
        _ fruit: FruitNode,
        intersection: SliceIntersection,
        blade: CuttingBladeSegment,
        timestamp: TimeInterval
    ) {
        let originalPosition = fruit.position
        let isPerfect = blade.speed >= FruitSliceTuning.perfectSliceMinimumSpeed
            && intersection.distanceFromCenter
                <= fruit.collisionRadius * FruitSliceTuning.perfectSliceRadiusRatio
        let basePoints = fruit.fruitType.scoreValue
            + (isPerfect ? FruitSliceTuning.perfectSliceBonus : 0)
        let award = comboController.registerSlice(
            basePoints: basePoints,
            sessionID: blade.sessionID,
            timestamp: timestamp
        )

        score += award.points
        hud.setScore(score)
        hud.showCombo(award.comboCount, at: originalPosition)
        if isPerfect {
            hud.showPerfect(at: originalPosition)
        }

        let halves = SliceEffects.makeHalves(from: fruit, blade: blade)
        halves.forEach {
            launchableLayer.addChild($0)
            fruitHalves.append($0)
        }
        SliceEffects.addJuiceBurst(
            to: effectsLayer,
            at: originalPosition,
            color: fruit.fruitType.fleshColor,
            blade: blade,
            isPerfect: isPerfect
        )

        fruit.physicsBody = nil
        fruit.removeAllActions()
        fruit.removeFromParent()
    }

    private func cleanupOffscreenObjects(countMisses: Bool) {
        let cutoff = -FruitSliceTuning.offscreenCleanupMargin

        for fruit in fruits where fruit.position.y < cutoff - fruit.collisionRadius {
            if countMisses, fruit.markMissed() {
                loseLife()
            }
            fruit.removeFromParent()
        }
        fruits.removeAll { $0.parent == nil }

        for bomb in bombs where bomb.position.y < cutoff - bomb.collisionRadius {
            bomb.removeFromParent()
        }
        bombs.removeAll { $0.parent == nil }

        for half in fruitHalves where half.position.y < cutoff - half.cleanupRadius {
            half.removeFromParent()
        }
        fruitHalves.removeAll { $0.parent == nil }
    }

    private func loseLife() {
        guard gameState == .playing, lives > 0 else {
            return
        }

        lives = max(0, lives - 1)
        hud.setLives(lives)
        if lives == 0 {
            endRun(reason: .misses)
        }
    }

    private func endRun(reason: FruitSliceGameOverReason) {
        guard transition(to: .gameOver) else {
            return
        }

        transitionToken += 1
        cancelScheduledRestart()
        resetBladeInput()
        comboController.reset()
        hud.showGameOver(score: score, reason: reason)

        let token = transitionToken
        run(
            .sequence([
                .wait(forDuration: FruitSliceTuning.gameOverDuration),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.transitionToken == token,
                          self.gameState == .gameOver else {
                        return
                    }
                    self.resetRun()
                }
            ]),
            withKey: "fruit-slice-restart"
        )
    }

    private func clearRunContent() {
        launchableLayer.removeAllChildren()
        effectsLayer.removeAllChildren()
        fruits.removeAll(keepingCapacity: true)
        bombs.removeAll(keepingCapacity: true)
        fruitHalves.removeAll(keepingCapacity: true)
    }

    private func resetBladeInput() {
        bladeTracker.reset()
        bladeTrail.reset()
        comboController.endSwipe()
    }

    private func keepLaunchablesWithinHorizontalBounds() {
        guard size.width > 1 else {
            return
        }

        for fruit in fruits {
            fruit.position.x = SliceGeometry.clamp(
                fruit.position.x,
                minimum: fruit.collisionRadius,
                maximum: max(fruit.collisionRadius, size.width - fruit.collisionRadius)
            )
        }
        for bomb in bombs {
            bomb.position.x = SliceGeometry.clamp(
                bomb.position.x,
                minimum: bomb.collisionRadius,
                maximum: max(bomb.collisionRadius, size.width - bomb.collisionRadius)
            )
        }
        for half in fruitHalves {
            half.position.x = SliceGeometry.clamp(
                half.position.x,
                minimum: 0,
                maximum: size.width
            )
        }
    }

    private func cancelScheduledRestart() {
        removeAction(forKey: "fruit-slice-restart")
    }

    @discardableResult
    private func transition(to newState: FruitSliceState) -> Bool {
        guard gameState.canTransition(to: newState) else {
            assertionFailure("Invalid Fruit Slice state transition: \(gameState) -> \(newState)")
            return false
        }

        gameState = newState
        return true
    }

    private func sceneLocation(fromScreenLocation screenLocation: CGPoint) -> CGPoint? {
        guard let view, let window = view.window else {
            return nil
        }

        let windowLocation = window.convertPoint(fromScreen: screenLocation)
        let viewLocation = view.convert(windowLocation, from: nil)
        return convertPoint(fromView: viewLocation)
    }
}
