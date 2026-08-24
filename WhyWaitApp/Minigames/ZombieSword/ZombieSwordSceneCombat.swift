import Foundation

extension ZombieSwordScene {
    func processCombat(
        previous: SwordTransformSnapshot,
        current: SwordTransformSnapshot,
        currentTime: TimeInterval
    ) {
        let broadPhase = sweptBladeBounds(previous: previous, current: current)
        let candidateZombies = zombies.filter {
            guard $0.isAlive else { return false }
            let radius = $0.collisionRadius * 1.75
            return broadPhase.intersects(
                CGRect(
                    x: $0.position.x - radius,
                    y: $0.position.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
        }
        let regions = candidateZombies.flatMap { $0.hitRegions() }
        let contacts = collisionDetector.contacts(
            previous: previous,
            current: current,
            regions: regions
        )
        debugOverlay.showContacts(contacts.map(\.point))

        let livingByID = Dictionary(uniqueKeysWithValues: zombies.filter(\.isAlive).map { ($0.id, $0) })
        var bestByZombie: [UUID: (impact: SwordImpact<ZombieHitRegionID>, result: ZombieDamageResult)] = [:]
        for impact in contacts {
            guard let zombie = livingByID[impact.region.zombieID] else { continue }
            let result = ZombieDamageCalculator.calculate(
                impact: impact,
                zombieType: zombie.type,
                zombieMass: zombie.stats.mass
            )
            if let existing = bestByZombie[zombie.id], existing.result.damage >= result.damage {
                continue
            }
            bestByZombie[zombie.id] = (impact, result)
        }

        for zombieID in bestByZombie.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard gameState == .playing,
                  swordControlState == .normal,
                  let zombie = livingByID[zombieID],
                  let candidate = bestByZombie[zombieID],
                  candidate.result.damage > 0,
                  let swingID = swingTracker.activeSwingID,
                  !overlappingZombies.contains(zombieID),
                  contactGate.canRegister(candidate.impact, at: currentTime, swingID: swingID) else {
                continue
            }

            let result = candidate.result
            let died = zombie.applyHit(result)
            swingTracker.registerDamage(result.damage)
            let combo = comboController.registerHit(at: currentTime)
            sessionStatistics.strongestHit = max(sessionStatistics.strongestHit, result.damage)
            sessionStatistics.highestCombo = max(sessionStatistics.highestCombo, combo)
            if result.style == .perfect { sessionStatistics.perfectCuts += 1 }

            let resistance = zombie.type == .tank ? 2.2 : 1.25
            swordSimulation.applyImpactImpulse(
                SwordMath.scale(
                    result.impactDirection,
                    by: -min(260, CGFloat(result.damage) * resistance)
                ),
                at: candidate.impact.point
            )
            effects.showImpact(result, at: candidate.impact.point)

            var multiKill = 0
            if died { multiKill = resolveZombieDeath(zombie, result: result, swingID: swingID) }
            if challengeController.registerHit(
                result: result,
                zombieType: zombie.type,
                killed: died,
                combo: combo,
                multiKill: multiKill
            ) {
                effects.showChallengeComplete(
                    at: CGPoint(x: size.width * 0.5, y: min(size.height - 75, size.height * 0.72))
                )
            }
            hud.setChallenge(challengeController.progress)
        }

        let allLivingRegions = zombies.filter(\.isAlive).flatMap { $0.hitRegions() }
        let currentOverlaps = collisionDetector.overlappingRegions(
            snapshot: current,
            regions: allLivingRegions
        )
        contactGate.updateOverlaps(currentOverlaps)
        overlappingZombies = Set(currentOverlaps.map(\.zombieID))
    }

    @discardableResult
    func resolveZombieDeath(
        _ zombie: Zombie,
        result: ZombieDamageResult,
        swingID: Int
    ) -> Int {
        guard zombie.markDeathAwarded() else { return 0 }
        sessionStatistics.kills += 1
        if result.region == .head { sessionStatistics.headshotKills += 1 }
        let multiKill = comboController.registerKill(swingID: swingID)
        sessionStatistics.highestMultiKill = max(sessionStatistics.highestMultiKill, multiKill)
        let headBonus = result.region == .head ? 25 : 0
        let perfectBonus = result.style == .perfect ? 30 : 0
        let comboBonus = min(80, max(0, comboController.count - 1) * 4)
        let multiBonus = multiKill >= 2 ? multiKill * 20 : 0
        score += zombie.stats.scoreValue + headBonus + perfectBonus + comboBonus + multiBonus
        if multiKill >= 2 {
            effects.showMultiKill(
                multiKill,
                at: CGPoint(x: size.width * 0.5, y: size.height * 0.58)
            )
        }
        zombie.playDeathAnimation()
        return multiKill
    }

    func sweptBladeBounds(
        previous: SwordTransformSnapshot,
        current: SwordTransformSnapshot
    ) -> CGRect {
        let points = [
            previous.bladeStart, previous.bladeTip,
            current.bladeStart, current.bladeTip
        ]
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        return CGRect(
            x: minX - 24,
            y: minY - 24,
            width: max(1, maxX - minX + 48),
            height: max(1, maxY - minY + 48)
        )
    }
}
