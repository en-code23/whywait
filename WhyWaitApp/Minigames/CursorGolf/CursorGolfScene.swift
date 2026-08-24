import SpriteKit

final class CursorGolfScene: SKScene, SKPhysicsContactDelegate {
    private(set) var gameState: CursorGolfState = .idle
    private(set) var latestMouseScreenLocation: CGPoint?

    private let shotController = ShotController()
    private let aimIndicator = AimIndicator()
    private let courseGenerator = CourseGenerator()
    private let hud = GolfHUD()
    private let boundaryNode = SKNode()

    private var ball: GolfBall?
    private var hole: GolfHole?
    private var obstacles: [GolfObstacle] = []
    private var strokeCount = 0
    private var isGameActive = false
    private var roundToken = 0
    private var timeBelowStopSpeed: TimeInterval = 0
    private var lastUpdateTime: TimeInterval?
    private var lastImpactFeedbackTime: TimeInterval = 0
    private var impactBursts: [SKNode] = []
    private var nextImpactBurstIndex = 0
    private let visualEffectsReduced = WhyWaitPresentationPreferences.reduceVisualEffects

    override init(size: CGSize) {
        super.init(size: size)
        configureScene()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureScene()
    }

    override func didMove(to view: SKView) {
        updateBoundary()
        hud.layout(in: size)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateBoundary()
        hud.layout(in: size)

        guard isGameActive else {
            return
        }

        if gameState == .sinking || gameState == .roundComplete {
            beginNewRound()
            return
        }

        if gameState == .aiming {
            shotController.cancelAiming()
            aimIndicator.hideImmediately()
            _ = transition(to: .idle)
        }

        constrainCurrentCourseToScene()
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime: TimeInterval
        if let lastUpdateTime {
            deltaTime = min(max(currentTime - lastUpdateTime, 0), 1.0 / 20.0)
        } else {
            deltaTime = 0
        }
        self.lastUpdateTime = currentTime

        guard isGameActive, gameState == .moving else {
            return
        }

        updateMovingBall(deltaTime: deltaTime)
    }

    func startGame() {
        guard !isGameActive else {
            return
        }

        isGameActive = true
        beginNewRound()
    }

    func stopGame() {
        guard isGameActive else {
            return
        }

        isGameActive = false
        roundToken += 1
        removeAction(forKey: "round-transition")
        ball?.removeAllActions()
        ball?.physicsBody?.velocity = .zero
        ball?.physicsBody?.angularVelocity = 0
        shotController.cancelAiming()
        aimIndicator.hideImmediately()
        gameState = .roundComplete
        lastUpdateTime = nil
    }

    func mouseMoved(toScreenLocation screenLocation: CGPoint) {
        latestMouseScreenLocation = screenLocation

        guard gameState == .aiming,
              let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }

        updateAim(to: sceneLocation)
    }

    func leftMouseDown(atScreenLocation screenLocation: CGPoint) {
        latestMouseScreenLocation = screenLocation

        guard isGameActive,
              gameState == .idle,
              let ball,
              let sceneLocation = sceneLocation(fromScreenLocation: screenLocation),
              shotController.beginAiming(
                  cursorPosition: sceneLocation,
                  ballPosition: ball.position
              ),
              transition(to: .aiming),
              let aim = shotController.updateAiming(cursorPosition: sceneLocation) else {
            return
        }

        ball.physicsBody?.velocity = .zero
        ball.physicsBody?.angularVelocity = 0
        aimIndicator.begin(ballPosition: ball.position, aim: aim)
    }

    func leftMouseDragged(toScreenLocation screenLocation: CGPoint) {
        latestMouseScreenLocation = screenLocation

        guard gameState == .aiming,
              let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }

        updateAim(to: sceneLocation)
    }

    func leftMouseUp(atScreenLocation screenLocation: CGPoint) {
        latestMouseScreenLocation = screenLocation

        guard isGameActive, gameState == .aiming, let ball else {
            return
        }

        aimIndicator.hideImmediately()

        guard let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) else {
            shotController.cancelAiming()
            _ = transition(to: .idle)
            return
        }

        guard let shot = shotController.finishAiming(cursorPosition: sceneLocation) else {
            _ = transition(to: .idle)
            return
        }

        guard transition(to: .moving), let physicsBody = ball.physicsBody else {
            return
        }

        strokeCount += 1
        hud.setStrokeCount(strokeCount)
        timeBelowStopSpeed = 0

        physicsBody.velocity = shot.launchVelocity
        physicsBody.angularVelocity = min(
            5,
            max(-5, -shot.launchVelocity.dx / 190)
        )
    }

    func resetRound() {
        guard isGameActive else {
            return
        }

        beginNewRound()
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard isGameActive,
              gameState == .moving,
              let ball,
              let velocity = ball.physicsBody?.velocity,
              GolfGeometry.magnitude(of: velocity)
                >= CursorGolfTuning.impactFeedbackMinimumSpeed else {
            return
        }

        let firstIsBall = contact.bodyA.categoryBitMask == GolfPhysicsCategory.ball
        let secondIsBall = contact.bodyB.categoryBitMask == GolfPhysicsCategory.ball
        guard firstIsBall || secondIsBall else {
            return
        }

        let currentTime = lastUpdateTime ?? 0
        guard currentTime - lastImpactFeedbackTime > 0.065 else {
            return
        }

        lastImpactFeedbackTime = currentTime
        ball.playImpactFeedback()
        playImpactBurst(
            at: contact.contactPoint,
            normal: contact.contactNormal,
            speed: GolfGeometry.magnitude(of: velocity)
        )

        let otherBody = firstIsBall ? contact.bodyB : contact.bodyA
        (otherBody.node as? GolfObstacle)?.playImpactFeedback()
    }

    private func configureScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        isUserInteractionEnabled = false
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        boundaryNode.name = "cursor-golf-boundary"
        boundaryNode.zPosition = -100
        addChild(boundaryNode)
        addChild(aimIndicator)
        addChild(hud)
        configureImpactBursts()

        updateBoundary()
        hud.layout(in: size)
    }

    private func beginNewRound() {
        guard isGameActive else {
            return
        }

        roundToken += 1
        removeAction(forKey: "round-transition")
        ball?.removeAllActions()
        ball?.removeFromParent()
        hole?.removeFromParent()
        obstacles.forEach { $0.removeFromParent() }
        obstacles.removeAll()

        shotController.cancelAiming()
        aimIndicator.hideImmediately()
        hud.hideCompletion()
        strokeCount = 0
        hud.setStrokeCount(strokeCount)
        gameState = .idle
        timeBelowStopSpeed = 0
        lastUpdateTime = nil
        lastImpactFeedbackTime = 0

        let course = courseGenerator.generateCourse(in: size)

        let hole = GolfHole()
        hole.position = course.holePosition
        addChild(hole)
        self.hole = hole

        obstacles = course.obstacles.map { descriptor in
            let obstacle = GolfObstacle(descriptor: descriptor)
            addChild(obstacle)
            return obstacle
        }

        let ball = GolfBall()
        ball.position = course.ballPosition
        addChild(ball)
        self.ball = ball
    }

    private func updateAim(to cursorPosition: CGPoint) {
        guard let ball,
              let aim = shotController.updateAiming(cursorPosition: cursorPosition) else {
            return
        }

        aimIndicator.update(ballPosition: ball.position, aim: aim)
    }

    private func updateMovingBall(deltaTime: TimeInterval) {
        guard let ball,
              let hole,
              let physicsBody = ball.physicsBody else {
            return
        }

        let speed = GolfGeometry.magnitude(of: physicsBody.velocity)
        let holeDistance = GolfGeometry.distance(from: ball.position, to: hole.position)

        if GolfHoleRules.shouldCapture(centerDistance: holeDistance, speed: speed) {
            beginSinking(ball: ball, into: hole)
            return
        }

        if GolfHoleRules.shouldApplyAttraction(
            centerDistance: holeDistance,
            speed: speed
        ) {
            let attractionDirection = GolfGeometry.normalized(
                GolfGeometry.vector(from: ball.position, to: hole.position)
            )
            let velocityChange = GolfGeometry.scaled(
                attractionDirection,
                by: CursorGolfTuning.attractionAcceleration * CGFloat(deltaTime)
            )
            physicsBody.velocity = CGVector(
                dx: physicsBody.velocity.dx + velocityChange.dx,
                dy: physicsBody.velocity.dy + velocityChange.dy
            )
            timeBelowStopSpeed = 0
            return
        }

        if speed <= CursorGolfTuning.stoppedSpeed {
            timeBelowStopSpeed += deltaTime

            if timeBelowStopSpeed >= CursorGolfTuning.stoppedDuration {
                physicsBody.velocity = .zero
                physicsBody.angularVelocity = 0
                timeBelowStopSpeed = 0
                _ = transition(to: .idle)
            }
        } else {
            timeBelowStopSpeed = 0
        }
    }

    private func beginSinking(ball: GolfBall, into hole: GolfHole) {
        guard transition(to: .sinking) else {
            return
        }

        shotController.cancelAiming()
        aimIndicator.hideImmediately()
        ball.prepareForSinking()

        let token = roundToken
        let completedStrokeCount = strokeCount
        let duration = CursorGolfTuning.sinkAnimationDuration

        let move = SKAction.move(to: hole.position, duration: duration)
        let shrink = SKAction.scale(to: 0.06, duration: duration)
        let rotate = SKAction.rotate(byAngle: .pi / 3, duration: duration)
        let sink = SKAction.group([move, shrink, rotate])
        sink.timingMode = .easeInEaseOut

        ball.run(
            .sequence([
                sink,
                .run { [weak self] in
                    self?.completeRound(
                        token: token,
                        completedStrokeCount: completedStrokeCount
                    )
                }
            ]),
            withKey: "sink"
        )
    }

    private func completeRound(token: Int, completedStrokeCount: Int) {
        guard isGameActive,
              token == roundToken,
              gameState == .sinking,
              transition(to: .roundComplete) else {
            return
        }

        hud.showCompletion(strokes: completedStrokeCount)

        run(
            .sequence([
                .wait(forDuration: CursorGolfTuning.roundResultDuration),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.roundToken == token,
                          self.gameState == .roundComplete else {
                        return
                    }

                    self.beginNewRound()
                }
            ]),
            withKey: "round-transition"
        )
    }

    @discardableResult
    private func transition(to newState: CursorGolfState) -> Bool {
        let isValid: Bool

        switch (gameState, newState) {
        case (.idle, .aiming),
             (.aiming, .idle),
             (.aiming, .moving),
             (.moving, .idle),
             (.moving, .sinking),
             (.sinking, .roundComplete):
            isValid = true
        default:
            isValid = false
        }

        guard isValid else {
            assertionFailure("Invalid Cursor Golf state transition: \(gameState) -> \(newState)")
            return false
        }

        gameState = newState
        return true
    }

    private func updateBoundary() {
        guard size.width > 4, size.height > 4 else {
            boundaryNode.physicsBody = nil
            return
        }

        let edgeBounds = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
        let body = SKPhysicsBody(edgeLoopFrom: edgeBounds)
        body.isDynamic = false
        body.friction = CursorGolfTuning.ballFriction
        body.restitution = CursorGolfTuning.boundaryRestitution
        body.categoryBitMask = GolfPhysicsCategory.boundary
        body.collisionBitMask = GolfPhysicsCategory.ball
        body.contactTestBitMask = GolfPhysicsCategory.ball
        boundaryNode.physicsBody = body
    }

    private func constrainCurrentCourseToScene() {
        let bounds = CursorGolfTuning.playableBounds(for: size)

        if let ball {
            ball.position = GolfGeometry.clamped(ball.position, to: bounds)
        }

        if let hole {
            hole.position = GolfGeometry.clamped(hole.position, to: bounds)
        }

        for obstacle in obstacles {
            obstacle.position = GolfGeometry.clamped(
                obstacle.position,
                to: bounds,
                inset: obstacle.descriptor.clearanceRadius
            )
        }
    }

    private func configureImpactBursts() {
        guard impactBursts.isEmpty else { return }

        for _ in 0..<4 {
            let burst = SKNode()
            burst.name = "cursor-golf-impact-burst"
            burst.zPosition = 24
            burst.alpha = 0

            for angleOffset in [-0.48, 0.0, 0.48] {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 2.5, y: 0))
                path.addLine(to: CGPoint(x: visualEffectsReduced ? 8 : 12, y: 0))
                let ray = SKShapeNode(path: path)
                ray.strokeColor = SKColor(calibratedRed: 0.72, green: 0.94, blue: 1, alpha: 0.9)
                ray.lineWidth = angleOffset == 0 ? 1.5 : 1
                ray.lineCap = .round
                ray.zRotation = angleOffset
                burst.addChild(ray)
            }

            addChild(burst)
            impactBursts.append(burst)
        }
    }

    private func playImpactBurst(at point: CGPoint, normal: CGVector, speed: CGFloat) {
        guard !impactBursts.isEmpty else { return }
        let burst = impactBursts[nextImpactBurstIndex]
        nextImpactBurstIndex = (nextImpactBurstIndex + 1) % impactBursts.count

        burst.removeAllActions()
        burst.position = point
        burst.zRotation = atan2(normal.dy, normal.dx)
        burst.setScale(0.7 + min(0.55, speed / CursorGolfTuning.maximumLaunchSpeed * 0.55))
        burst.alpha = visualEffectsReduced ? 0.42 : 0.9

        let duration = visualEffectsReduced ? 0.07 : 0.16
        let motion = SKAction.group([
            .fadeOut(withDuration: duration),
            .scale(to: visualEffectsReduced ? 0.88 : 1.32, duration: duration)
        ])
        motion.timingMode = .easeOut
        burst.run(motion)
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
