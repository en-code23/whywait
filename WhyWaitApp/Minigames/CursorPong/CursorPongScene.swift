import Foundation
import SpriteKit

final class CursorPongScene: SKScene, SKPhysicsContactDelegate {
    private(set) var gameState: CursorPongState = .serving
    private(set) var playerScore = 0
    private(set) var cpuScore = 0
    private(set) var rallyCount = 0

    private let playerPaddle = PongPaddle(side: .player)
    private let cpuPaddle = PongPaddle(side: .cpu)
    private let ball = PongBall()
    private let ballTrail = PongBallTrail()
    private let playerController = PlayerPaddleController()
    private let cpuController = CPUPaddleController()
    private let hud = PongHUD()
    private let topBoundary = SKNode()
    private let bottomBoundary = SKNode()

    private var isGameActive = false
    private var transitionToken = 0
    private var matchNumber = 0
    private var lastUpdateTime: TimeInterval?
    private var lastPaddleContactTime: TimeInterval = -.infinity

    override init(size: CGSize) {
        super.init(size: size)
        configureScene()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureScene()
    }

    override func didMove(to view: SKView) {
        updateHorizontalBoundaries()
        layoutContent(preservePaddleY: isGameActive)
        hud.layout(in: size)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateHorizontalBoundaries()
        layoutContent(preservePaddleY: isGameActive)
        hud.layout(in: size)

        if gameState == .serving {
            centerBall()
        } else {
            ball.position.x = PongPhysics.clamp(
                ball.position.x,
                minimum: CursorPongTuning.ballRadius,
                maximum: max(
                    CursorPongTuning.ballRadius,
                    size.width - CursorPongTuning.ballRadius
                )
            )
            ball.position.y = PongPhysics.clamp(
                ball.position.y,
                minimum: CursorPongTuning.ballRadius + 2,
                maximum: max(
                    CursorPongTuning.ballRadius + 2,
                    size.height - CursorPongTuning.ballRadius - 2
                )
            )
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDeltaTime = lastUpdateTime.map { currentTime - $0 } ?? 0
        lastUpdateTime = currentTime

        guard isGameActive else {
            return
        }

        if rawDeltaTime > CursorPongTuning.updateDiscontinuityThreshold {
            playerController.reset(paddleY: playerPaddle.position.y, currentTime: currentTime)
            cpuController.reset(paddleY: cpuPaddle.position.y, currentTime: currentTime)
        }

        let deltaTime = min(max(rawDeltaTime, 0), 1.0 / 20.0)
        let paddleBounds = CursorPongTuning.paddleCenterRange(for: size.height)

        playerController.update(
            paddle: playerPaddle,
            within: paddleBounds,
            deltaTime: deltaTime,
            currentTime: currentTime
        )
        cpuController.update(
            paddle: cpuPaddle,
            ball: ball,
            sceneSize: size,
            rallyCount: rallyCount,
            deltaTime: deltaTime,
            currentTime: currentTime
        )

        guard gameState == .playing else {
            return
        }

        ballTrail.update(ballPosition: ball.position, speed: ball.travelSpeed)
        checkScoringBoundaries()
    }

    func startGame() {
        guard !isGameActive else {
            return
        }

        isGameActive = true
        startNewMatch()
    }

    func stopGame() {
        guard isGameActive else {
            return
        }

        isGameActive = false
        transitionToken += 1
        cancelScheduledTransitions()
        ball.stop()
        ballTrail.reset()
        playerController.reset(paddleY: playerPaddle.position.y)
        cpuController.reset(
            paddleY: cpuPaddle.position.y,
            currentTime: ProcessInfo.processInfo.systemUptime
        )
        lastUpdateTime = nil
        gameState = .serving
    }

    func mouseMoved(toScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }

        playerController.receiveCursor(
            y: sceneLocation.y,
            within: CursorPongTuning.paddleCenterRange(for: size.height),
            timestamp: ProcessInfo.processInfo.systemUptime
        )
    }

    func resetMatch() {
        guard isGameActive else {
            return
        }

        startNewMatch()
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard isGameActive, gameState == .playing else {
            return
        }

        let firstIsBall = contact.bodyA.categoryBitMask == PongPhysicsCategory.ball
        let secondIsBall = contact.bodyB.categoryBitMask == PongPhysicsCategory.ball
        guard firstIsBall || secondIsBall else {
            return
        }

        let otherBody = firstIsBall ? contact.bodyB : contact.bodyA
        if let paddle = otherBody.node as? PongPaddle {
            handlePaddleContact(paddle)
        } else if otherBody.categoryBitMask == PongPhysicsCategory.horizontalBoundary {
            ball.playImpact(strong: false)
        }
    }

    private func configureScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
        isUserInteractionEnabled = false
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        topBoundary.name = "cursor-pong-top-boundary"
        bottomBoundary.name = "cursor-pong-bottom-boundary"
        addChild(topBoundary)
        addChild(bottomBoundary)
        addChild(ballTrail)
        addChild(cpuPaddle)
        addChild(playerPaddle)
        addChild(ball)
        addChild(hud)

        updateHorizontalBoundaries()
        layoutContent(preservePaddleY: false)
        hud.layout(in: size)
    }

    private func startNewMatch() {
        transitionToken += 1
        cancelScheduledTransitions()
        matchNumber += 1

        playerScore = 0
        cpuScore = 0
        rallyCount = 0
        hud.setScores(player: playerScore, cpu: cpuScore)
        hud.setRally(rallyCount)
        hud.hideFeedback()

        let centerY = size.height / 2
        playerPaddle.position.y = centerY
        cpuPaddle.position.y = centerY
        playerPaddle.verticalVelocity = 0
        cpuPaddle.verticalVelocity = 0
        playerController.reset(
            paddleY: centerY,
            currentTime: ProcessInfo.processInfo.systemUptime
        )
        cpuController.reset(
            paddleY: centerY,
            currentTime: ProcessInfo.processInfo.systemUptime
        )

        gameState = .serving
        prepareBallForServe()
        let initialServeSide: PongSide = matchNumber.isMultiple(of: 2) ? .cpu : .player
        scheduleServe(toward: initialServeSide, delay: CursorPongTuning.initialServeDelay)
    }

    private func handlePaddleContact(_ paddle: PongPaddle) {
        let currentTime = lastUpdateTime ?? ProcessInfo.processInfo.systemUptime
        guard currentTime - lastPaddleContactTime
                >= CursorPongTuning.paddleContactCooldown else {
            return
        }

        switch paddle.side {
        case .player where ball.velocity.dx <= 0:
            return
        case .cpu where ball.velocity.dx >= 0:
            return
        default:
            break
        }

        lastPaddleContactTime = currentTime
        let outgoingDirection: CGFloat = paddle.side == .player ? -1 : 1
        let paddleInfluence = paddle.side == .player
            ? CursorPongTuning.playerSwipeInfluence
            : CursorPongTuning.cpuPaddleInfluence
        let outgoingVelocity = PongPhysics.reboundVelocity(
            incomingVelocity: ball.velocity,
            ballY: ball.position.y,
            paddleY: paddle.position.y,
            paddleHeight: paddle.paddleSize.height,
            outgoingDirection: outgoingDirection,
            paddleVerticalVelocity: paddle.verticalVelocity,
            paddleInfluence: paddleInfluence
        )

        if paddle.side == .player {
            ball.position.x = paddle.position.x
                - (paddle.paddleSize.width / 2)
                - CursorPongTuning.ballRadius
                - 1
        } else {
            ball.position.x = paddle.position.x
                + (paddle.paddleSize.width / 2)
                + CursorPongTuning.ballRadius
                + 1
        }
        ball.velocity = outgoingVelocity

        rallyCount += 1
        hud.setRally(rallyCount)
        let strongHit = abs(paddle.verticalVelocity) > 720
            || PongPhysics.magnitude(of: outgoingVelocity) > 720
        paddle.playImpact(strong: strongHit)
        ball.playImpact(strong: strongHit)
    }

    private func checkScoringBoundaries() {
        if ball.position.x < -CursorPongTuning.ballRadius {
            awardPoint(to: .player)
        } else if ball.position.x > size.width + CursorPongTuning.ballRadius {
            awardPoint(to: .cpu)
        }
    }

    private func awardPoint(to scorer: PongSide) {
        guard transition(to: .pointScored) else {
            return
        }

        transitionToken += 1
        cancelScheduledTransitions()
        ball.stop()
        ballTrail.reset()
        rallyCount = 0
        hud.setRally(rallyCount)

        if scorer == .player {
            playerScore += 1
        } else {
            cpuScore += 1
        }
        hud.setScores(player: playerScore, cpu: cpuScore)

        let winningScore = scorer == .player ? playerScore : cpuScore
        if winningScore >= CursorPongTuning.winningScore {
            completeMatch(winner: scorer)
        } else {
            hud.showPointScored(by: scorer)
            scheduleNextPoint(toward: scorer.opponent)
        }
    }

    private func scheduleNextPoint(toward concedingSide: PongSide) {
        let token = transitionToken
        run(
            .sequence([
                .wait(forDuration: CursorPongTuning.pointDisplayDuration),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.transitionToken == token,
                          self.gameState == .pointScored,
                          self.transition(to: .serving) else {
                        return
                    }

                    self.hud.hideFeedback()
                    self.prepareBallForServe()
                    self.scheduleServe(
                        toward: concedingSide,
                        delay: CursorPongTuning.serveDelay
                    )
                }
            ]),
            withKey: "pong-point-pause"
        )
    }

    private func completeMatch(winner: PongSide) {
        guard transition(to: .matchComplete) else {
            return
        }

        hud.showMatchResult(winner: winner)
        let token = transitionToken
        run(
            .sequence([
                .wait(forDuration: CursorPongTuning.matchResultDuration),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.transitionToken == token,
                          self.gameState == .matchComplete else {
                        return
                    }

                    self.startNewMatch()
                }
            ]),
            withKey: "pong-match-result"
        )
    }

    private func scheduleServe(toward side: PongSide, delay: TimeInterval) {
        let token = transitionToken
        run(
            .sequence([
                .wait(forDuration: delay),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.transitionToken == token,
                          self.gameState == .serving,
                          self.transition(to: .playing) else {
                        return
                    }

                    self.lastPaddleContactTime = -.infinity
                    self.ball.velocity = PongPhysics.serveVelocity(
                        toward: side,
                        angleDegrees: CGFloat.random(in: -16...16)
                    )
                }
            ]),
            withKey: "pong-serve"
        )
    }

    private func prepareBallForServe() {
        centerBall()
        ball.stop()
        ballTrail.reset(at: ball.position)
    }

    private func centerBall() {
        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    @discardableResult
    private func transition(to newState: CursorPongState) -> Bool {
        guard gameState.canTransition(to: newState) else {
            assertionFailure("Invalid Cursor Pong state transition: \(gameState) -> \(newState)")
            return false
        }

        gameState = newState
        return true
    }

    private func cancelScheduledTransitions() {
        removeAction(forKey: "pong-point-pause")
        removeAction(forKey: "pong-serve")
        removeAction(forKey: "pong-match-result")
    }

    private func updateHorizontalBoundaries() {
        guard size.width > 4, size.height > 4 else {
            topBoundary.physicsBody = nil
            bottomBoundary.physicsBody = nil
            return
        }

        topBoundary.physicsBody = makeBoundaryBody(
            from: CGPoint(x: 0, y: size.height - 2),
            to: CGPoint(x: size.width, y: size.height - 2)
        )
        bottomBoundary.physicsBody = makeBoundaryBody(
            from: CGPoint(x: 0, y: 2),
            to: CGPoint(x: size.width, y: 2)
        )
    }

    private func makeBoundaryBody(from start: CGPoint, to end: CGPoint) -> SKPhysicsBody {
        let body = SKPhysicsBody(edgeFrom: start, to: end)
        body.isDynamic = false
        body.friction = 0
        body.restitution = 1
        body.categoryBitMask = PongPhysicsCategory.horizontalBoundary
        body.collisionBitMask = PongPhysicsCategory.ball
        body.contactTestBitMask = PongPhysicsCategory.ball
        return body
    }

    private func layoutContent(preservePaddleY: Bool) {
        let paddleBounds = CursorPongTuning.paddleCenterRange(for: size.height)
        let centerY = size.height / 2
        cpuPaddle.position.x = CursorPongTuning.paddleEdgeInset
        playerPaddle.position.x = max(
            CursorPongTuning.paddleEdgeInset,
            size.width - CursorPongTuning.paddleEdgeInset
        )

        if preservePaddleY {
            cpuPaddle.position.y = PongPhysics.clamp(
                cpuPaddle.position.y,
                minimum: paddleBounds.lowerBound,
                maximum: paddleBounds.upperBound
            )
            playerPaddle.position.y = PongPhysics.clamp(
                playerPaddle.position.y,
                minimum: paddleBounds.lowerBound,
                maximum: paddleBounds.upperBound
            )
        } else {
            cpuPaddle.position.y = centerY
            playerPaddle.position.y = centerY
        }
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
