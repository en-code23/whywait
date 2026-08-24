import Foundation
import SpriteKit

final class GrappleScene: SKScene, SKPhysicsContactDelegate {
    private(set) var gameState: GrappleSceneState = .resetting
    private(set) var nextCheckpointIndex = 0

    private let courseLayer = SKNode()
    private let trail = GrappleTrail()
    private let ropeRenderer = RopeRenderer()
    private let player = GrapplePlayer()
    private let hud = GrappleHUD()
    private let grappleController = GrappleController()
    private let courseGenerator = GrappleCourseGenerator()

    private var course: GrappleCourse?
    private var checkpointNodes: [GrappleCheckpoint] = []
    private var hazardNodes: [GrappleHazard] = []
    private var goalNode: GrappleGoal?
    private var launchPlatformNode: GrappleObstacle?
    private var latestRespawnPosition: CGPoint = .zero
    private var previousPlayerPosition: CGPoint = .zero
    private var cursorPosition: CGPoint?

    private var isGameActive = false
    private var transitionToken = 0
    private var lastUpdateTime: TimeInterval?
    private var roundStartTime: TimeInterval?
    private var completionTime: TimeInterval?
    private var lastObstacleContactTime: TimeInterval = -.infinity
    private var lastSpeedFeedbackTime: TimeInterval = -.infinity
    private var wasAboveSpeedThreshold = false

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
        safelyDetach(showFeedback: false)
        cursorPosition = nil

        guard isGameActive,
              abs(oldSize.width - size.width) > 1
                || abs(oldSize.height - size.height) > 1 else {
            return
        }
        generateNewCourse()
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDeltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        guard isGameActive else {
            return
        }

        if rawDeltaTime > GrappleTuning.updateInterruptionThreshold {
            safelyDetach(showFeedback: false)
            cursorPosition = nil
        }

        if roundStartTime == nil, gameState == .playing {
            roundStartTime = currentTime
        }

        if gameState == .playing || gameState == .respawning {
            hud.setTime(elapsedTime(at: currentTime))
        }

        if gameState == .playing {
            let force = grappleController.ropeForce(
                playerPosition: player.position,
                playerVelocity: player.velocity,
                deltaTime: rawDeltaTime
            )
            player.apply(force: force.force)
            updateAimHelper()
        } else {
            ropeRenderer.hideAim()
        }

        ropeRenderer.update(
            playerPosition: player.position,
            attachment: grappleController.state,
            normalizedTension: grappleController.normalizedTension
        )
        player.updateAppearance()
    }

    override func didSimulatePhysics() {
        guard isGameActive, gameState == .playing else {
            return
        }

        if let constraint = grappleController.enforceConstraint(
            playerPosition: player.position,
            playerVelocity: player.velocity
        ), constraint.wasConstrained {
            player.position = constraint.position
            player.velocity = constraint.velocity
        }
        player.velocity = GrapplePhysics.cappedVelocity(player.velocity)

        guard player.position.x.isFinite,
              player.position.y.isFinite,
              player.velocity.dx.isFinite,
              player.velocity.dy.isFinite else {
            triggerFailure(reason: .outOfBounds)
            return
        }

        trail.update(position: player.position, speed: player.travelSpeed)
        ropeRenderer.update(
            playerPosition: player.position,
            attachment: grappleController.state,
            normalizedTension: grappleController.normalizedTension
        )

        let movementStart = previousPlayerPosition
        let movementEnd = player.position
        if hazardNodes.contains(where: {
            $0.sweptContact(from: movementStart, to: movementEnd)
        }) {
            triggerFailure(reason: .hazard)
            return
        }

        if isPlayerOutOfBounds() {
            triggerFailure(reason: .outOfBounds)
            return
        }

        activateCheckpointIfNeeded(from: movementStart, to: movementEnd)
        if gameState == .playing {
            completeRoundIfNeeded(from: movementStart, to: movementEnd)
        }
        if gameState == .playing {
            updateSpeedFeedback()
            previousPlayerPosition = player.position
        }
    }

    func startGame() {
        guard !isGameActive else {
            return
        }

        isGameActive = true
        generateNewCourse()
    }

    func stopGame() {
        guard isGameActive else {
            return
        }

        isGameActive = false
        transitionToken += 1
        cancelScheduledActions()
        grappleController.reset()
        ropeRenderer.reset()
        trail.reset()
        player.freezeForRoundCompletion()
        courseLayer.removeAllChildren()
        checkpointNodes.removeAll()
        hazardNodes.removeAll()
        goalNode = nil
        launchPlatformNode = nil
        course = nil
        lastUpdateTime = nil
        roundStartTime = nil
        completionTime = nil
        gameState = .resetting
    }

    func generateNewCourse() {
        guard isGameActive else {
            return
        }

        if gameState != .resetting,
           !transition(to: .resetting) {
            return
        }

        transitionToken += 1
        cancelScheduledActions()
        grappleController.reset()
        ropeRenderer.reset()
        trail.reset()
        courseLayer.removeAllChildren()
        checkpointNodes.removeAll(keepingCapacity: true)
        hazardNodes.removeAll(keepingCapacity: true)
        goalNode = nil
        launchPlatformNode = nil

        let newCourse = courseGenerator.generate(in: size)
        course = newCourse
        buildCourse(newCourse)
        nextCheckpointIndex = 0
        latestRespawnPosition = newCourse.startPosition
        previousPlayerPosition = newCourse.startPosition
        player.reset(at: newCourse.startPosition)
        trail.reset(at: newCourse.startPosition)
        roundStartTime = nil
        completionTime = nil
        lastUpdateTime = nil
        lastObstacleContactTime = -.infinity
        lastSpeedFeedbackTime = -.infinity
        wasAboveSpeedThreshold = false
        cursorPosition = nil
        hud.reset(checkpointCount: newCourse.checkpoints.count)
        updateCheckpointVisuals()

        _ = transition(to: .playing)
    }

    func mouseMoved(toScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }

        cursorPosition = sceneLocation
        updateAimHelper()
    }

    func leftMouseDown(atScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              gameState == .playing,
              let requestedAnchor = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }

        cursorPosition = requestedAnchor
        safelyDetach(showFeedback: false)
        guard let result = grappleController.attach(
            playerPosition: player.position,
            requestedAnchor: requestedAnchor
        ) else {
            ropeRenderer.showRejectedAnchor(at: requestedAnchor)
            return
        }

        releaseLaunchPlatformIfNeeded()
        ropeRenderer.hideAim()
        ropeRenderer.update(
            playerPosition: player.position,
            attachment: grappleController.state,
            normalizedTension: 0
        )
        if result.wasClamped {
            ropeRenderer.showRejectedAnchor(at: requestedAnchor)
        }
    }

    func leftMouseUp(atScreenLocation screenLocation: CGPoint) {
        if let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) {
            cursorPosition = sceneLocation
        }
        safelyDetach(showFeedback: gameState == .playing)
        updateAimHelper()
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard isGameActive, gameState == .playing else {
            return
        }

        let firstIsPlayer = contact.bodyA.categoryBitMask == GrapplePhysicsCategory.player
        let secondIsPlayer = contact.bodyB.categoryBitMask == GrapplePhysicsCategory.player
        guard firstIsPlayer || secondIsPlayer else {
            return
        }

        let otherBody = firstIsPlayer ? contact.bodyB : contact.bodyA
        if otherBody.categoryBitMask == GrapplePhysicsCategory.hazard {
            triggerFailure(reason: .hazard)
        } else if otherBody.categoryBitMask == GrapplePhysicsCategory.obstacle {
            lastObstacleContactTime = lastUpdateTime ?? ProcessInfo.processInfo.systemUptime
            player.playImpact()
        }
    }

    private func configureScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        isUserInteractionEnabled = false
        physicsWorld.gravity = GrappleTuning.gravity
        physicsWorld.contactDelegate = self

        courseLayer.name = "grapple-course"
        addChild(courseLayer)
        addChild(trail)
        addChild(ropeRenderer)
        addChild(player)
        hud.isHidden = !WhyWaitPresentationPreferences.showGameHUD
        addChild(hud)
        hud.layout(in: size)
    }

    private func buildCourse(_ course: GrappleCourse) {
        let launchPlatform = GrappleObstacle(descriptor: course.launchPlatform)
        launchPlatform.name = "grapple-launch-platform"
        launchPlatform.zPosition = 17
        launchPlatform.configureAsLaunchPlatform()
        courseLayer.addChild(launchPlatform)
        launchPlatformNode = launchPlatform

        let startMarker = SKNode()
        startMarker.name = "grapple-start"
        startMarker.position = course.startPosition
        let startShadow = SKShapeNode(
            ellipseOf: CGSize(width: (GrappleTuning.playerRadius + 11) * 2, height: 14)
        )
        startShadow.fillColor = SKColor.black.withAlphaComponent(0.14)
        startShadow.strokeColor = .clear
        startShadow.position.y = -7
        startMarker.addChild(startShadow)

        let startPad = SKShapeNode(
            ellipseOf: CGSize(width: (GrappleTuning.playerRadius + 9) * 2, height: 12)
        )
        startPad.fillColor = SKColor(calibratedWhite: 0.16, alpha: 0.44)
        startPad.strokeColor = SKColor(
            calibratedRed: 0.38,
            green: 0.86,
            blue: 1,
            alpha: 0.55
        )
        startPad.lineWidth = 1.3
        startMarker.addChild(startPad)

        let startCore = SKShapeNode(
            ellipseOf: CGSize(width: GrappleTuning.playerRadius * 1.65, height: 6)
        )
        startCore.fillColor = SKColor(calibratedRed: 0.2, green: 0.66, blue: 0.78, alpha: 0.24)
        startCore.strokeColor = SKColor.white.withAlphaComponent(0.18)
        startCore.lineWidth = 0.8
        startCore.position.y = 1
        startMarker.addChild(startCore)
        startMarker.zPosition = 12
        courseLayer.addChild(startMarker)

        for obstacleDescriptor in course.obstacles {
            courseLayer.addChild(GrappleObstacle(descriptor: obstacleDescriptor))
        }

        for hazardDescriptor in course.hazards {
            let hazard = GrappleHazard(descriptor: hazardDescriptor)
            courseLayer.addChild(hazard)
            hazardNodes.append(hazard)
        }

        for (index, checkpointPosition) in course.checkpoints.enumerated() {
            let checkpoint = GrappleCheckpoint(index: index)
            checkpoint.position = checkpointPosition
            courseLayer.addChild(checkpoint)
            checkpointNodes.append(checkpoint)
        }

        let goal = GrappleGoal()
        goal.position = course.goalPosition
        courseLayer.addChild(goal)
        goalNode = goal
    }

    private func activateCheckpointIfNeeded(from start: CGPoint, to end: CGPoint) {
        guard let course,
              checkpointNodes.indices.contains(nextCheckpointIndex),
              GrapplePhysics.segmentIntersectsCircle(
                from: start,
                to: end,
                center: course.checkpoints[nextCheckpointIndex],
                radius: GrappleTuning.checkpointRadius + GrappleTuning.playerRadius
              ) else {
            return
        }

        let activatedIndex = nextCheckpointIndex
        checkpointNodes[activatedIndex].playActivation()
        latestRespawnPosition = course.checkpointRespawns[activatedIndex]
        nextCheckpointIndex += 1
        hud.setCheckpointProgress(
            completed: nextCheckpointIndex,
            total: course.checkpoints.count
        )

        let currentTime = lastUpdateTime ?? ProcessInfo.processInfo.systemUptime
        if player.travelSpeed >= GrappleTuning.highSpeedThreshold,
           currentTime - lastObstacleContactTime
            >= GrappleTuning.cleanCheckpointCollisionGrace {
            hud.showClean(at: player.position)
        }
        updateCheckpointVisuals()
    }

    private func updateCheckpointVisuals() {
        for (index, checkpoint) in checkpointNodes.enumerated() {
            if index < nextCheckpointIndex {
                checkpoint.setVisualState(.completed)
            } else if index == nextCheckpointIndex {
                checkpoint.setVisualState(.next)
            } else {
                checkpoint.setVisualState(.future)
            }
        }
        goalNode?.setActive(nextCheckpointIndex == checkpointNodes.count)
    }

    private func completeRoundIfNeeded(from start: CGPoint, to end: CGPoint) {
        guard let course,
              nextCheckpointIndex == course.checkpoints.count,
              GrapplePhysics.segmentIntersectsCircle(
                from: start,
                to: end,
                center: course.goalPosition,
                radius: GrappleTuning.goalRadius + GrappleTuning.playerRadius
              ) else {
            return
        }
        completeRound()
    }

    private func completeRound() {
        guard transition(to: .roundComplete) else {
            return
        }

        transitionToken += 1
        cancelScheduledActions()
        safelyDetach(showFeedback: false)
        trail.reset()
        player.freezeForRoundCompletion()
        goalNode?.playCompletion()

        let currentTime = lastUpdateTime ?? ProcessInfo.processInfo.systemUptime
        let finalTime = elapsedTime(at: currentTime)
        completionTime = finalTime
        hud.setTime(finalTime)
        let praise: String
        if finalTime < 12 {
            praise = "FAST!"
        } else if finalTime < 22 {
            praise = "NICE!"
        } else {
            praise = "CLEAN!"
        }
        hud.showFinish(time: finalTime, praise: praise)

        let token = transitionToken
        run(
            .sequence([
                .wait(forDuration: GrappleTuning.roundCompletionPause),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.transitionToken == token,
                          self.gameState == .roundComplete else {
                        return
                    }
                    self.generateNewCourse()
                }
            ]),
            withKey: "grapple-new-course"
        )
    }

    private func triggerFailure(reason: GrappleFailureReason) {
        guard transition(to: .respawning) else {
            return
        }

        transitionToken += 1
        cancelScheduledActions()
        safelyDetach(showFeedback: false)
        trail.reset()
        player.prepareForRespawn()
        hud.showMissed()

        let token = transitionToken
        run(
            .sequence([
                .wait(forDuration: GrappleTuning.respawnDelay),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.transitionToken == token,
                          self.gameState == .respawning,
                          self.transition(to: .playing) else {
                        return
                    }

                    self.restoreLaunchPlatformIfNeeded()
                    self.player.reset(at: self.latestRespawnPosition)
                    self.previousPlayerPosition = self.latestRespawnPosition
                    self.trail.reset(at: self.latestRespawnPosition)
                    self.lastObstacleContactTime = -.infinity
                    self.wasAboveSpeedThreshold = false
                    self.hud.hideFeedback()
                    self.updateAimHelper()
                }
            ]),
            withKey: "grapple-respawn"
        )
    }

    private func safelyDetach(showFeedback: Bool) {
        guard let release = grappleController.detach() else {
            ropeRenderer.update(
                playerPosition: player.position,
                attachment: .detached,
                normalizedTension: 0
            )
            return
        }

        if showFeedback,
           player.travelSpeed >= GrappleTuning.releaseFeedbackMinimumSpeed
            || release.normalizedTension >= GrappleTuning.releaseFeedbackMinimumTension {
            let speedRatio = min(1, player.travelSpeed / GrappleTuning.maximumPlayerSpeed)
            ropeRenderer.showRelease(
                at: release.anchor,
                intensity: max(speedRatio, release.normalizedTension)
            )
        }
        ropeRenderer.update(
            playerPosition: player.position,
            attachment: .detached,
            normalizedTension: 0
        )
    }

    private func releaseLaunchPlatformIfNeeded() {
        guard let launchPlatformNode,
              launchPlatformNode.isActiveLaunchPlatform else {
            return
        }
        launchPlatformNode.setLaunchPlatformActive(false)
        // SpriteKit can retain a downward contact velocity while a dynamic
        // circle rests against a static body. Clear only that stale component;
        // the grapple then starts from rest and gravity creates the intended
        // initial rope stretch.
        if player.velocity.dy < 0 {
            player.velocity = CGVector(dx: player.velocity.dx, dy: 0)
        }
    }

    private func restoreLaunchPlatformIfNeeded() {
        guard let course,
              GrapplePhysics.distance(
                from: latestRespawnPosition,
                to: course.startPosition
              ) < 1 else {
            return
        }
        launchPlatformNode?.setLaunchPlatformActive(true)
    }

    private func updateAimHelper() {
        guard isGameActive,
              gameState == .playing,
              !grappleController.isAttached,
              let cursorPosition else {
            ropeRenderer.hideAim()
            return
        }
        ropeRenderer.showAim(at: cursorPosition, from: player.position)
    }

    private func updateSpeedFeedback() {
        let isHighSpeed = player.travelSpeed >= GrappleTuning.highSpeedThreshold
        let currentTime = lastUpdateTime ?? 0
        if isHighSpeed,
           !wasAboveSpeedThreshold,
           currentTime - lastSpeedFeedbackTime > 0.8 {
            hud.showSpeed(at: player.position)
            lastSpeedFeedbackTime = currentTime
        }
        wasAboveSpeedThreshold = isHighSpeed
    }

    private func isPlayerOutOfBounds() -> Bool {
        let margin = GrappleTuning.outOfBoundsMargin
        return player.position.x < -margin
            || player.position.x > size.width + margin
            || player.position.y < -margin
            || player.position.y > size.height + margin
    }

    private func elapsedTime(at currentTime: TimeInterval) -> TimeInterval {
        if let completionTime {
            return completionTime
        }
        guard let roundStartTime else {
            return 0
        }
        return max(0, currentTime - roundStartTime)
    }

    private func cancelScheduledActions() {
        removeAction(forKey: "grapple-respawn")
        removeAction(forKey: "grapple-new-course")
    }

    @discardableResult
    private func transition(to newState: GrappleSceneState) -> Bool {
        guard gameState.canTransition(to: newState) else {
            assertionFailure("Invalid Grapple state transition: \(gameState) -> \(newState)")
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
