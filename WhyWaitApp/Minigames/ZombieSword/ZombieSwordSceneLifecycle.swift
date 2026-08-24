import Foundation
import SpriteKit

extension ZombieSwordScene {
    func updateStateTimers(deltaTime: TimeInterval) {
        guard gameState == .waveTransition || gameState == .playerDead else { return }
        transitionTimer -= min(max(deltaTime, 0), 0.1)
        guard transitionTimer <= 0 else { return }
        switch gameState {
        case .waveTransition:
            beginNextWave()
        case .playerDead:
            resetRun()
        case .playing, .resetting:
            break
        }
    }

    func beginNextWave() {
        guard gameState == .waveTransition else { return }
        let plan = waveController.beginNextWave()
        challengeController.beginWave()
        hud.setChallenge(challengeController.progress)
        gameState = .playing
        effects.showWave(
            plan.wave,
            at: CGPoint(x: size.width * 0.5, y: min(size.height - 70, size.height * 0.68))
        )
    }

    func checkForWaveCompletion() {
        guard gameState == .playing,
              !waveController.hasPendingSpawns,
              pendingWarnings.isEmpty,
              !zombies.contains(where: \.isAlive) else {
            return
        }
        gameState = .waveTransition
        sessionStatistics.wavesCleared += 1
        let oldHealth = player.health
        player.heal(ZombieSwordTuning.waveHealAmount)
        let healed = player.health - oldHealth
        if challengeController.registerWaveClear() {
            effects.showChallengeComplete(
                at: CGPoint(x: size.width * 0.5, y: min(size.height - 80, size.height * 0.72))
            )
        }
        hud.setChallenge(challengeController.progress)
        effects.showWaveClear(
            at: CGPoint(x: size.width * 0.5, y: min(size.height - 80, size.height * 0.62)),
            healed: healed
        )
        comboController.reset()
        transitionTimer = ZombieSwordTuning.wavePause
    }

    func updateSpawning(deltaTime: TimeInterval) {
        let occupiedCount = zombies.filter(\.isAlive).count + pendingWarnings.count
        if let type = waveController.update(deltaTime: deltaTime, occupiedSlots: occupiedCount) {
            let warning = spawner.makeWarning(
                type: type,
                bounds: CGRect(origin: .zero, size: size),
                playerPosition: player.position,
                occupied: zombies.filter(\.isAlive).map(\.position) + pendingWarnings.map(\.spawnPosition),
                archetype: waveController.currentPlan?.archetype
            )
            pendingWarnings.append(warning)
            addChild(warning)
        }

        for index in pendingWarnings.indices.reversed() {
            guard pendingWarnings[index].update(deltaTime: deltaTime) else { continue }
            let warning = pendingWarnings.remove(at: index)
            warning.removeFromParent()
            guard gameState == .playing,
                  zombies.filter(\.isAlive).count < ZombieSwordTuning.maximumActiveZombies else {
                continue
            }
            let zombie = Zombie(
                type: warning.type,
                wave: waveController.currentWave,
                position: warning.spawnPosition
            )
            zombies.append(zombie)
            addChild(zombie)
        }
    }

    func updateZombies(deltaTime: TimeInterval) {
        let living = zombies.filter(\.isAlive)
        var resolvedAttacks = 0
        for zombie in living {
            let separation = ZombieSteering.separation(for: zombie, among: living)
            if let attack = zombie.update(
                deltaTime: deltaTime,
                playerPosition: player.position,
                separation: separation
            ), resolvedAttacks < ZombieSwordTuning.maximumSimultaneousAttackResolutions {
                resolvedAttacks += 1
                resolveZombieAttack(attack)
            }
            clampZombieToPlayArea(zombie)
        }
    }

    func resolveZombieAttack(_ attack: ZombieAttackEvent) {
        guard gameState == .playing,
              player.health > 0,
              zombies.contains(where: { $0.id == attack.zombieID && $0.isAlive }) else {
            return
        }
        challengeController.registerPlayerDamage(attack.damage)
        let remaining = player.takeDamage(attack.damage)
        effects.showPlayerDamage(
            attack.damage,
            at: CGPoint(x: player.position.x, y: player.position.y + 42)
        )
        if remaining <= 0 { triggerPlayerDeath() }
    }

    func triggerPlayerDeath() {
        guard gameState == .playing || gameState == .waveTransition else { return }
        gameState = .playerDead
        transitionGeneration += 1
        waveController.cancelPendingSpawns()
        for warning in pendingWarnings { warning.removeFromParent() }
        pendingWarnings.removeAll(keepingCapacity: true)
        for zombie in zombies where zombie.isAlive {
            zombie.cancelAttackAndStagger(duration: ZombieSwordTuning.playerDeathPause)
        }
        comboController.reset()
        contactGate.reset()
        overlappingZombies.removeAll(keepingCapacity: true)
        effects.showDeath(
            wave: waveController.currentWave,
            score: score,
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.58)
        )
        transitionTimer = ZombieSwordTuning.playerDeathPause
    }

    func clampZombieToPlayArea(_ zombie: Zombie) {
        let margin = max(20, zombie.collisionRadius)
        zombie.position = CGPoint(
            x: SwordMath.clamp(zombie.position.x, minimum: margin, maximum: max(margin, size.width - margin)),
            y: SwordMath.clamp(zombie.position.y, minimum: margin, maximum: max(margin, size.height - margin))
        )
    }

    func clearEnemies() {
        for zombie in zombies { zombie.removeFromParent() }
        zombies.removeAll(keepingCapacity: true)
        for warning in pendingWarnings { warning.removeFromParent() }
        pendingWarnings.removeAll(keepingCapacity: true)
        overlappingZombies.removeAll(keepingCapacity: true)
    }
}
