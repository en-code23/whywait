import Foundation
import SpriteKit

extension SwordDummyScene {
    func processCombat(
        previous: SwordTransformSnapshot,
        current: SwordTransformSnapshot,
        currentTime: TimeInterval
    ) {
        let regions = dummy.hitRegions()
        let contacts = collisionDetector.contacts(
            previous: previous,
            current: current,
            regions: regions
        )
        debugOverlay.showContacts(contacts.map(\.point))

        var registeredBladeContact = false
        for contact in contacts {
            guard gameState == .playing,
                  contactGate.canRegister(
                    contact,
                    at: currentTime,
                    swingID: swingTracker.activeSwingID
                  ) else {
                continue
            }
            registeredBladeContact = true
            let result = SwordDamageCalculator.calculate(contact: contact)
            guard result.damage > 0 else { continue }

            swingTracker.registerDamage(result.damage)
            let combo = comboController.register(damage: result.damage, at: currentTime)
            sessionStatistics.record(result: result, combo: combo)
            let remainingHealth = dummy.applyDamage(result, at: contact.point)
            swordSimulation.applyImpactImpulse(
                SwordMath.scale(result.impactDirection, by: -CGFloat(result.damage) * 3.4),
                at: contact.point
            )
            effects.showImpact(result: result, at: contact.point)
            hud.setCombo(combo)

            if challengeController.register(result: result, combo: combo) {
                hud.setChallenge(challengeController.progress)
                effects.showChallengeComplete(
                    near: CGPoint(x: dummy.position.x, y: min(size.height - 55, dummy.position.y + 250))
                )
            } else {
                hud.setChallenge(challengeController.progress)
            }

            if remainingHealth <= 0 {
                destroyDummy(with: result)
                break
            }
        }

        if !registeredBladeContact {
            let handleHits = collisionDetector.handleContacts(
                previous: previous,
                current: current,
                regions: regions
            )
            if !handleHits.isEmpty {
                let handleVelocity = current.velocity(at: current.handlePoint)
                if SwordMath.magnitude(handleVelocity) > 120 {
                    dummy.applyWeakHandleReaction(
                        direction: SwordMath.normalized(handleVelocity, fallback: .zero)
                    )
                }
            }
        }

        contactGate.updateOverlaps(
            collisionDetector.overlappingRegions(snapshot: current, regions: regions)
        )
    }

    func destroyDummy(with result: SwordDamageResult) {
        guard gameState == .playing,
              transition(to: .dummyDestroyed) else {
            return
        }
        transitionGeneration += 1
        let generation = transitionGeneration
        sessionStatistics.dummyDestructions += 1
        comboController.reset()
        hud.setCombo(0)
        contactGate.reset()
        dummy.breakApart(direction: result.impactDirection)
        effects.showDestroyed(
            near: CGPoint(x: dummy.position.x, y: min(size.height - 70, dummy.position.y + 245)),
            statistics: sessionStatistics
        )

        removeAction(forKey: "dummy-rebuild")
        run(.sequence([
            .wait(forDuration: SwordDummyTuning.dummyResetDelay),
            .run { [weak self] in
                guard let self,
                      self.isGameActive,
                      self.gameState == .dummyDestroyed,
                      self.transitionGeneration == generation else {
                    return
                }
                self.rebuildDummyAfterDestruction()
            }
        ]), withKey: "dummy-rebuild")
    }

    func rebuildDummyAfterDestruction() {
        guard transition(to: .resetting) else { return }
        let placementIndex = settings.dummyPlacement == .fixed ? 0 : dummyPositionIndex
        let newPosition = safeDummyPosition(index: placementIndex)
        if settings.dummyPlacement == .varied {
            dummyPositionIndex = (dummyPositionIndex + 1) % 3
        }
        dummy.reset(at: newPosition)
        comboController.reset()
        contactGate.reset()
        let challenge = challengeController.beginNextChallenge()
        hud.layout(in: size, dummyPosition: newPosition)
        hud.reset(challenge: challenge)
        previousSwordSnapshot = swordSimulation.snapshot
        _ = transition(to: .playing)
    }
}
