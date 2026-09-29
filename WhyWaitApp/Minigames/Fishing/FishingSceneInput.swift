import Foundation
import SpriteKit

extension FishingScene {
    func mouseMoved(toScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }
        latestCursorPosition = sceneLocation
        castController.updateCursor(sceneLocation)

        switch gameState {
        case .readyToCast, .chargingCast, .fighting:
            let power = gameState == .chargingCast
                ? castController.chargePower(at: ProcessInfo.processInfo.systemUptime)
                : 0
            rod.setAim(toward: sceneLocation, power: power)
        default:
            break
        }
    }

    func leftMouseDown(atScreenLocation screenLocation: CGPoint) {
        guard isGameActive,
              let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) else {
            return
        }
        latestCursorPosition = sceneLocation

        switch gameState {
        case .readyToCast:
            beginCastCharge(at: sceneLocation)
        case .biteWindow:
            setHook()
        case .fighting:
            isMouseHeld = true
        case .showingDex:
            _ = fishDexPanel.handleClick(at: sceneLocation)
        case .showingUpgrades:
            if let action = upgradePanel.action(at: sceneLocation) {
                handleShopAction(action)
            } else {
                _ = upgradePanel.consumesClick(at: sceneLocation)
            }
        case .showingVault:
            if let action = tidevaultPanel.handleClick(at: sceneLocation) {
                handleTidevaultAction(action)
            } else {
                _ = tidevaultPanel.consumesClick(at: sceneLocation)
            }
        case .chargingCast, .bobberFlying, .waitingForBite, .hooked,
             .catchComplete, .failedCatch, .resetting:
            break
        }
    }

    func leftMouseUp(atScreenLocation screenLocation: CGPoint) {
        if let sceneLocation = sceneLocation(fromScreenLocation: screenLocation) {
            latestCursorPosition = sceneLocation
            castController.updateCursor(sceneLocation)
        }

        switch gameState {
        case .chargingCast:
            releaseCast()
        case .fighting:
            isMouseHeld = false
        default:
            isMouseHeld = false
        }
    }

    func toggleFishDex() {
        guard isGameActive else { return }
        switch gameState {
        case .readyToCast:
            guard transition(to: .showingDex) else { return }
            fishDexPanel.present(profile: profile, in: size)
        case .showingDex:
            fishDexPanel.dismiss()
            _ = transition(to: .readyToCast)
        case .showingUpgrades:
            upgradePanel.dismiss()
            guard transition(to: .showingDex) else { return }
            fishDexPanel.present(profile: profile, in: size)
        case .showingVault:
            tidevaultPanel.dismiss()
            guard transition(to: .showingDex) else { return }
            fishDexPanel.present(profile: profile, in: size)
        default:
            hud.showSmallFeedback("FINISH CURRENT CAST")
        }
    }

    func toggleUpgrades() {
        guard isGameActive else { return }
        switch gameState {
        case .readyToCast:
            guard transition(to: .showingUpgrades) else { return }
            upgradePanel.present(profile: profile, in: size)
        case .showingUpgrades:
            upgradePanel.dismiss()
            _ = transition(to: .readyToCast)
        case .showingDex:
            fishDexPanel.dismiss()
            guard transition(to: .showingUpgrades) else { return }
            upgradePanel.present(profile: profile, in: size)
        case .showingVault:
            tidevaultPanel.dismiss()
            guard transition(to: .showingUpgrades) else { return }
            upgradePanel.present(profile: profile, in: size)
        default:
            hud.showSmallFeedback("FINISH CURRENT CAST")
        }
    }

    func toggleTidevault() {
        guard isGameActive else { return }
        switch gameState {
        case .readyToCast:
            guard transition(to: .showingVault) else { return }
            tidevaultPanel.present(profile: profile, in: size)
        case .showingVault:
            tidevaultPanel.dismiss()
            _ = transition(to: .readyToCast)
        case .showingDex:
            fishDexPanel.dismiss()
            guard transition(to: .showingVault) else { return }
            tidevaultPanel.present(profile: profile, in: size)
        case .showingUpgrades:
            upgradePanel.dismiss()
            guard transition(to: .showingVault) else { return }
            tidevaultPanel.present(profile: profile, in: size)
        default:
            hud.showSmallFeedback("FINISH CURRENT CAST")
        }
    }

    func purchaseUpgrade(_ category: FishingEquipmentCategory) {
        let result = profile.purchaseUpgrade(category, transactionID: UUID())
        if case .purchased = result {
            guard saveProfile() else { return }
            hud.updateProfile(profile)
            fishDexPanel.refresh(profile: profile)
        }
        upgradePanel.refresh(profile: profile)
        upgradePanel.showPurchaseResult(result)
    }

    func handleShopAction(_ action: FishingShopAction) {
        switch action {
        case let .selectRod(model):
            let result = profile.selectRod(model, transactionID: UUID())
            if case .purchased = result { guard persistPanelChanges() else { return } }
            rod.equip(profile.equippedRod)
            upgradePanel.refresh(profile: profile)
            upgradePanel.showPurchaseResult(result)
        case let .upgrade(category):
            purchaseUpgrade(category)
        case let .buyLure(lure):
            let result = profile.purchaseLure(lure, transactionID: UUID())
            if case .purchased = result { guard persistPanelChanges() else { return } }
            upgradePanel.refresh(profile: profile)
            upgradePanel.showPurchaseResult(result)
        case let .equipLure(lure):
            guard profile.equipLure(lure) else { return }
            guard persistPanelChanges() else { return }
            upgradePanel.refresh(profile: profile)
            upgradePanel.showEquipped(lure)
        case .expandVault:
            let result = profile.purchaseVaultExpansion(transactionID: UUID())
            if case .purchased = result { guard persistPanelChanges() else { return } }
            upgradePanel.refresh(profile: profile)
            tidevaultPanel.refresh(profile: profile)
            upgradePanel.showPurchaseResult(result)
        }
    }

    func handleTidevaultAction(_ action: TidevaultAction) {
        let didChange: Bool
        switch action {
        case let .favorite(id): didChange = profile.toggleFavorite(specimenID: id)
        case let .lock(id): didChange = profile.toggleLock(specimenID: id)
        case let .release(id): didChange = profile.releaseStoredFish(specimenID: id)
        }
        guard didChange else {
            hud.showSmallFeedback("SPECIMEN LOCKED")
            return
        }
        persistPanelChanges()
        tidevaultPanel.refresh(profile: profile)
    }

    @discardableResult
    private func persistPanelChanges() -> Bool {
        guard saveProfile() else { return false }
        hud.updateProfile(profile)
        fishDexPanel.refresh(profile: profile)
        return true
    }

    func sceneLocation(fromScreenLocation screenLocation: CGPoint) -> CGPoint? {
        guard let view, let window = view.window else { return nil }
        let windowLocation = window.convertPoint(fromScreen: screenLocation)
        let viewLocation = view.convert(windowLocation, from: nil)
        return convertPoint(fromView: viewLocation)
    }
}
