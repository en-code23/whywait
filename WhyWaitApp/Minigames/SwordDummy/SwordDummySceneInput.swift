import AppKit
import Foundation
import SpriteKit

extension SwordDummyScene {
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
            trail.reset()
        } else {
            swordSimulation.setCursorTarget(target)
        }
    }

    func recoverSword(atScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              gameState == .playing,
              !isSettingsPresented,
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
        swingTracker.reset()
        trail.reset()
        effects.showRecovery(at: target)

        run(.sequence([
            .wait(forDuration: 0.12),
            .run { [weak self] in
                guard let self,
                      self.isGameActive,
                      self.gameState == .playing,
                      self.transitionGeneration == generation else {
                    return
                }
                self.swordControlState = .normal
                self.sword.setRecovering(false)
                self.previousSwordSnapshot = self.swordSimulation.snapshot
            }
        ]), withKey: "sword-recovery")
    }

    func leftMouseDown(atScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              isSettingsPresented,
              let location = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }
        guard let kind = settingsPanel.setting(at: location) else {
            _ = settingsPanel.containsScenePoint(location)
            return
        }
        applySettingChange(kind)
    }

    func toggleSettings() {
        guard isGameActive, gameState == .playing else { return }
        if isSettingsPresented {
            isSettingsPresented = false
            settingsPanel.dismiss()
            swordSimulation.configure(parameters: settings.physicsParameters)
            let target = clampedCursorTarget(
                latestCursorPosition ?? swordSimulation.snapshot.handlePoint
            )
            swordSimulation.reset(
                handlePosition: target,
                angle: swordSimulation.snapshot.angle
            )
            previousSwordSnapshot = swordSimulation.snapshot
            sword.apply(previousSwordSnapshot)
            swordControlState = .normal
            sword.setRecovering(false)
            contactGate.reset()
            swingTracker.reset()
            trail.reset()
        } else {
            isSettingsPresented = true
            settingsPanel.present(settings: settings, in: size)
            swordControlState = .recovering
            sword.setRecovering(true)
            contactGate.reset()
            swingTracker.reset()
            trail.reset()
        }
    }

    func applySettingChange(_ kind: SwordDummySettingKind) {
        guard isSettingsPresented else { return }
        settings.cycle(kind)
        swordSimulation.configure(parameters: settings.physicsParameters)

        switch kind {
        case .controlMode, .swordWeight, .springResponse:
            let target = clampedCursorTarget(
                latestCursorPosition ?? swordSimulation.snapshot.handlePoint
            )
            swordSimulation.reset(
                handlePosition: target,
                angle: swordSimulation.snapshot.angle
            )
            previousSwordSnapshot = swordSimulation.snapshot
            sword.apply(previousSwordSnapshot)
        case .dummyReaction, .dummyDurability:
            dummy.configure(
                reaction: settings.dummyReaction,
                durability: settings.dummyDurability
            )
            dummy.reset(at: dummy.position)
            comboController.reset()
            hud.setCombo(0)
        case .dummyPlacement:
            let index = settings.dummyPlacement == .fixed ? 0 : dummyPositionIndex
            let position = safeDummyPosition(index: index)
            dummy.reset(at: position)
            hud.layout(in: size, dummyPosition: position)
        }
        contactGate.reset()
        swingTracker.reset()
        settingsPanel.refresh(settings: settings)
    }

    func sceneLocation(fromScreenLocation screenLocation: CGPoint) -> CGPoint? {
        guard let view, let window = view.window else { return nil }
        let windowLocation = window.convertPoint(fromScreen: screenLocation)
        let viewLocation = view.convert(windowLocation, from: nil)
        return convertPoint(fromView: viewLocation)
    }
}
