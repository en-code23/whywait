import AppKit
import Foundation
import SpriteKit

extension ZombieSwordScene {
    func mouseMoved(toScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              let location = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }
        let target = clampedCursorTarget(location)
        latestCursorPosition = target
        if !hasReceivedCursorSample {
            hasReceivedCursorSample = true
            swordSimulation.reset(handlePosition: target, angle: swordSimulation.snapshot.angle)
            previousSwordSnapshot = swordSimulation.snapshot
            sword.apply(previousSwordSnapshot)
            contactGate.reset()
            overlappingZombies.removeAll(keepingCapacity: true)
            swingTracker.reset()
            trail.reset()
        } else {
            swordSimulation.setCursorTarget(target)
        }
    }

    func recoverSword(atScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              gameState != .playerDead,
              let location = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }
        let target = clampedCursorTarget(location)
        latestCursorPosition = target
        hasReceivedCursorSample = true
        transitionGeneration += 1
        let generation = transitionGeneration
        removeAction(forKey: "sword-recovery")
        swordControlState = .recovering
        sword.setRecovering(true)
        swordSimulation.reset(handlePosition: target, angle: 0.08)
        previousSwordSnapshot = swordSimulation.snapshot
        sword.apply(previousSwordSnapshot)
        contactGate.reset()
        overlappingZombies.removeAll(keepingCapacity: true)
        swingTracker.reset()
        trail.reset()
        effects.showRecovery(at: target)
        run(.sequence([
            .wait(forDuration: 0.12),
            .run { [weak self] in
                guard let self,
                      self.isGameActive,
                      self.gameState != .playerDead,
                      self.transitionGeneration == generation else {
                    return
                }
                self.swordControlState = .normal
                self.sword.setRecovering(false)
                self.previousSwordSnapshot = self.swordSimulation.snapshot
            }
        ]), withKey: "sword-recovery")
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
        overlappingZombies.removeAll(keepingCapacity: true)
        trail.reset()
        hasReceivedCursorSample = false
        for zombie in zombies where zombie.isAttacking {
            zombie.cancelAttackAndStagger(duration: 0.18)
        }
    }

    func sceneLocation(fromScreenLocation screenLocation: CGPoint) -> CGPoint? {
        guard let view, let window = view.window else { return nil }
        let windowLocation = window.convertPoint(fromScreen: screenLocation)
        let viewLocation = view.convert(windowLocation, from: nil)
        return convertPoint(fromView: viewLocation)
    }
}
