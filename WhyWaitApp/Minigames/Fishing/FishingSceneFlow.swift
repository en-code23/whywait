import Foundation
import SpriteKit

extension FishingScene {
    func beginCastCharge(at cursorPosition: CGPoint) {
        guard gameState == .readyToCast else { return }
        interactionGeneration += 1
        cancelScheduledActions()
        hud.hideFeedback()
        hud.hideCatch()
        let began = castController.beginCharging(
            rodPosition: rod.tipPosition,
            cursorPosition: cursorPosition,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        guard began, transition(to: .chargingCast) else { return }
        isMouseHeld = true
        rod.setAim(toward: cursorPosition, power: 0)
    }

    func updateChargingVisual() {
        guard let cursor = latestCursorPosition else { return }
        let power = castController.chargePower(at: ProcessInfo.processInfo.systemUptime)
        rod.setAim(toward: cursor, power: power)
    }

    func releaseCast() {
        guard gameState == .chargingCast else { return }
        isMouseHeld = false
        guard let launch = castController.release(
            timestamp: ProcessInfo.processInfo.systemUptime,
            sceneSize: size,
            worldMaximumDistance: worldMaximumCastDistance,
            equipment: equipmentStats
        ), transition(to: .bobberFlying) else {
            castController.cancel()
            _ = transition(to: .readyToCast)
            return
        }

        activeZone = launch.zone
        castLandingPosition = launch.target
        bobber.position = launch.start
        bobber.prepareForFlight()
        rod.pulseRelease()
        lineRenderer.updateWaiting(from: rod.tipPosition, to: bobber.position)
    }

    func updateCastFlight(deltaTime: TimeInterval) {
        guard let snapshot = castController.updateFlight(deltaTime: deltaTime) else {
            failCurrentCatch(.missedBite)
            return
        }
        bobber.position = snapshot.position
        bobber.updateFlight(progress: snapshot.progress)
        lineRenderer.updateWaiting(from: rod.tipPosition, to: bobber.position)
        guard snapshot.didLand else { return }

        castLandingPosition = bobber.position
        bobber.land()
        effects.addRipple(at: bobber.position, strong: true)
        hud.showZone(activeZone)
        beginWaitingForBite()
    }

    func beginWaitingForBite() {
        guard transition(to: .waitingForBite) else { return }
        let lure = profile.shopInventory.equippedLure
        generatedCatch = catchGenerator.generate(
            zone: activeZone,
            equipment: equipmentStats,
            lure: lure
        )
        if lure != nil {
            _ = profile.consumeEquippedLure()
            saveProfile()
            hud.updateProfile(profile)
            upgradePanel.refresh(profile: profile)
        }
        nextAmbientTime = (lastUpdateTime ?? 0) + 0.7
        if tutorialSession {
            hud.showHint("CLICK WHEN IT BITES", duration: 2)
        }

        guard let generatedCatch else { return }
        let token = interactionGeneration
        run(
            .sequence([
                .wait(forDuration: generatedCatch.biteWait),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.interactionGeneration == token,
                          self.gameState == .waitingForBite else {
                        return
                    }
                    self.beginBiteWindow()
                }
            ]),
            withKey: "fishing-bite-wait"
        )
    }

    func updateAmbient(currentTime: TimeInterval) {
        guard currentTime >= nextAmbientTime,
              let generatedCatch else { return }
        let interval = Double.random(in: FishingTuning.ambientMovementInterval)
        nextAmbientTime = currentTime + interval

        bobber.twitch(intensity: generatedCatch.prospective.isLegendary ? 1.25 : 0.65)
        effects.addRipple(at: bobber.position)
        if case let .fish(specimen) = generatedCatch.prospective,
           Double.random(in: 0..<1) < 0.58 {
            effects.addFishShadow(
                near: bobber.position,
                definition: specimen.definition,
                legendaryHint: specimen.definition.rarity == .legendary
            )
        }
    }

    func beginBiteWindow() {
        guard let generatedCatch,
              transition(to: .biteWindow) else { return }
        bobber.bite()
        effects.addRipple(at: bobber.position, strong: true)
        effects.addSplash(at: bobber.position, count: generatedCatch.prospective.isLegendary ? 10 : 6)
        hud.showBite(at: bobber.position)

        let token = interactionGeneration
        run(
            .sequence([
                .wait(forDuration: generatedCatch.hookWindow),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.interactionGeneration == token,
                          self.gameState == .biteWindow else {
                        return
                    }
                    self.failCurrentCatch(.missedBite)
                }
            ]),
            withKey: "fishing-hook-window"
        )
    }

    func setHook() {
        guard gameState == .biteWindow,
              let generatedCatch,
              transition(to: .hooked) else { return }
        removeAction(forKey: "fishing-hook-window")
        hud.hideFeedback()
        bobber.removeAllActions()
        effects.addSplash(at: bobber.position, count: 9)
        activeTransaction = FishingCatchTransaction(catchItem: generatedCatch.prospective)

        switch generatedCatch.prospective {
        case let .fish(specimen):
            beginFishFight(specimen)
        case let .treasure(treasure):
            beginTreasureReel(treasure)
        }
    }

    func beginFishFight(_ specimen: FishSpecimen) {
        let fish = FishNode(
            definition: specimen.definition,
            sizePercentile: specimen.sizePercentile,
            variant: specimen.variant
        )
        fish.position = bobber.position
        catchLayer.addChild(fish)
        activeFishNode = fish
        fish.playHooked()
        nextFightRippleTime = 0
        bobber.isHidden = true
        fightController.start(
            specimen: specimen,
            at: fish.position,
            initialDistance: FishingGeometry.distance(from: rod.tipPosition, to: fish.position),
            equipment: equipmentStats
        )
        rod.updateFightVisual(tension: 0.2, isReeling: true)
        guard transition(to: .fighting) else { return }
        // The click that sets the hook can remain held and immediately become
        // the first reel input; releasing it still gives line normally.
        isMouseHeld = true
        if tutorialSession {
            hud.showHint("HOLD TO REEL  ·  MOVE TO MANAGE TENSION", duration: 3)
        }
    }

    func updateFight(deltaTime: TimeInterval) {
        guard let fish = activeFishNode else {
            failCurrentCatch(.slackEscape)
            return
        }
        let cursor = latestCursorPosition ?? CGPoint(
            x: rod.tipPosition.x + 90,
            y: rod.tipPosition.y + 100
        )
        guard let snapshot = fightController.update(
            deltaTime: deltaTime,
            rodPosition: rod.tipPosition,
            cursorPosition: cursor,
            isReeling: isMouseHeld,
            bounds: CGRect(origin: .zero, size: size)
        ) else {
            failCurrentCatch(.slackEscape)
            return
        }

        fish.position = snapshot.fishPosition
        fish.updateMotion(velocity: snapshot.fishVelocity, staminaRatio: snapshot.staminaRatio)
        rod.updateFightVisual(tension: snapshot.tension, isReeling: isMouseHeld)
        lineRenderer.updateFight(
            from: rod.tipPosition,
            rodControl: cursor,
            to: snapshot.fishPosition,
            tension: snapshot.tension,
            level: snapshot.tensionLevel
        )
        hud.setFightTension(snapshot.tension, level: snapshot.tensionLevel)
        let currentTime = lastUpdateTime ?? 0
        if snapshot.aiState == .burst,
           currentTime >= nextFightRippleTime {
            effects.addRipple(at: fish.position)
            nextFightRippleTime = currentTime + FishingTuning.fightBurstRippleInterval
        }

        switch snapshot.outcome {
        case .none:
            break
        case .landed:
            completeCatch()
        case .lineBroke:
            failCurrentCatch(.lineBroke)
        case .hookLost:
            failCurrentCatch(.slackEscape)
        }
    }

    func beginTreasureReel(_ treasure: TreasureCatch) {
        bobber.isHidden = true
        lineRenderer.hide()
        let node = SKLabelNode(fontNamed: "HelveticaNeue-Light")
        node.text = treasure.definition.symbol
        node.fontSize = 34
        node.fontColor = SKColor.white.withAlphaComponent(0.9)
        node.horizontalAlignmentMode = .center
        node.verticalAlignmentMode = .center
        node.position = bobber.position
        catchLayer.addChild(node)
        activeTreasureNode = node

        let token = interactionGeneration
        let move = SKAction.move(to: rod.tipPosition, duration: FishingTuning.treasureReelDuration)
        move.timingMode = .easeIn
        node.run(move)
        run(
            .sequence([
                .wait(forDuration: FishingTuning.treasureReelDuration),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.interactionGeneration == token,
                          self.gameState == .hooked else {
                        return
                    }
                    self.completeCatch()
                }
            ]),
            withKey: "fishing-treasure-land"
        )
    }

    func completeCatch() {
        guard (gameState == .fighting || gameState == .hooked),
              let transaction = activeTransaction,
              let generatedCatch else { return }
        let fightDuration = fightController.fightDuration
        guard transition(to: .catchComplete) else { return }

        interactionGeneration += 1
        cancelScheduledActions()
        isMouseHeld = false
        fightController.cancel()
        rod.resetVisual()
        lineRenderer.hide()
        hud.hideFightTension()
        activeFishNode?.removeFromParent()
        activeFishNode = nil
        activeTreasureNode?.removeFromParent()
        activeTreasureNode = nil
        bobber.resetVisual()

        let progression = profile.applyCatch(transaction)
        guard progression.wasApplied else {
            returnToReady()
            return
        }
        sessionStatistics.record(
            progression: progression,
            catchItem: generatedCatch.prospective,
            fightDuration: fightDuration
        )
        saveProfile()
        hud.updateProfile(profile)
        hud.showCatch(generatedCatch.prospective, progression: progression)
        fishDexPanel.refresh(profile: profile)
        tidevaultPanel.refresh(profile: profile)
        activeTransaction = nil

        let token = interactionGeneration
        run(
            .sequence([
                .wait(forDuration: FishingTuning.catchPresentationDuration),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.interactionGeneration == token,
                          self.gameState == .catchComplete else {
                        return
                    }
                    self.returnToReady()
                }
            ]),
            withKey: "fishing-result-reset"
        )
    }

    func failCurrentCatch(_ reason: FishingFailureReason) {
        guard gameState == .biteWindow
            || gameState == .fighting
            || gameState == .bobberFlying
            || gameState == .hooked else {
            return
        }
        guard transition(to: .failedCatch) else { return }

        interactionGeneration += 1
        cancelScheduledActions()
        isMouseHeld = false
        castController.cancel()
        fightController.cancel()
        rod.resetVisual()
        lineRenderer.hide()
        hud.hideFightTension()
        activeFishNode?.removeFromParent()
        activeFishNode = nil
        activeTreasureNode?.removeFromParent()
        activeTreasureNode = nil
        bobber.resetVisual()
        activeTransaction = nil
        generatedCatch = nil
        hud.showFailure(reason)

        let token = interactionGeneration
        run(
            .sequence([
                .wait(forDuration: FishingTuning.failurePresentationDuration),
                .run { [weak self] in
                    guard let self,
                          self.isGameActive,
                          self.interactionGeneration == token,
                          self.gameState == .failedCatch else {
                        return
                    }
                    self.returnToReady()
                }
            ]),
            withKey: "fishing-result-reset"
        )
    }

    func returnToReady() {
        cancelScheduledActions()
        clearInteractionNodes()
        castController.cancel()
        fightController.cancel()
        generatedCatch = nil
        activeTransaction = nil
        isMouseHeld = false
        nextAmbientTime = .infinity
        rod.resetVisual()
        if let cursor = latestCursorPosition {
            rod.setAim(toward: cursor, power: 0)
        }
        _ = transition(to: .readyToCast)
    }
}
