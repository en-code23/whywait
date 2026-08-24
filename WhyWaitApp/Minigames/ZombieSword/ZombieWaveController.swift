import Foundation

struct ZombieWavePlan {
    let wave: Int
    let archetype: ZombieWaveArchetype
    let zombieTypes: [ZombieType]
    let spawnInterval: TimeInterval
}

enum ZombieWavePlanner {
    static func makePlan(wave: Int, random: inout ZombieRandom) -> ZombieWavePlan {
        let safeWave = max(1, wave)
        let archetype: ZombieWaveArchetype
        if safeWave.isMultiple(of: 5) {
            archetype = safeWave.isMultiple(of: 10) ? .heavy : .armored
        } else {
            let available: [ZombieWaveArchetype] = safeWave < 3
                ? [.swarm, .mixed, .encircle]
                : ZombieWaveArchetype.allCases
            archetype = available.randomElement(using: &random) ?? .mixed
        }

        let count = min(ZombieSwordTuning.maximumActiveZombies, 2 + safeWave)
        var types: [ZombieType] = []
        types.reserveCapacity(count)
        for index in 0..<count {
            types.append(type(for: archetype, wave: safeWave, index: index, random: &random))
        }
        if safeWave.isMultiple(of: 5), !types.contains(where: { $0 == .tank || $0 == .armored }) {
            types[types.count - 1] = safeWave.isMultiple(of: 10) ? .tank : .armored
        }
        let interval = max(
            ZombieSwordTuning.minimumSpawnInterval,
            ZombieSwordTuning.initialSpawnInterval - (Double(safeWave - 1) * 0.025)
        )
        return ZombieWavePlan(
            wave: safeWave,
            archetype: archetype,
            zombieTypes: types,
            spawnInterval: interval
        )
    }

    private static func type(
        for archetype: ZombieWaveArchetype,
        wave: Int,
        index: Int,
        random: inout ZombieRandom
    ) -> ZombieType {
        let roll = Double.random(in: 0..<1, using: &random)
        switch archetype {
        case .swarm:
            return wave >= 3 && roll < 0.24 ? .runner : .walker
        case .rush:
            return roll < 0.72 ? .runner : .walker
        case .heavy:
            return index == 0 || roll < 0.34 ? .tank : .walker
        case .armored:
            return index.isMultiple(of: 3) || roll < 0.42 ? .armored : .walker
        case .encircle:
            if wave >= 4, roll < 0.18 { return .shambler }
            return roll < 0.38 ? .runner : .walker
        case .mixed:
            if wave >= 6, roll < 0.12 { return .tank }
            if wave >= 4, roll < 0.3 { return .armored }
            if wave >= 3, roll < 0.53 { return .shambler }
            if wave >= 2, roll < 0.74 { return .runner }
            return .walker
        }
    }
}

final class ZombieWaveController {
    private(set) var currentWave = 0
    private(set) var currentPlan: ZombieWavePlan?
    private(set) var pendingTypes: [ZombieType] = []
    private(set) var spawnTimer: TimeInterval = 0
    private var random: ZombieRandom

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        random = ZombieRandom(seed: seed)
    }

    @discardableResult
    func beginNextWave() -> ZombieWavePlan {
        currentWave += 1
        let plan = ZombieWavePlanner.makePlan(wave: currentWave, random: &random)
        currentPlan = plan
        pendingTypes = plan.zombieTypes
        spawnTimer = 0
        return plan
    }

    func update(deltaTime: TimeInterval, occupiedSlots: Int) -> ZombieType? {
        guard !pendingTypes.isEmpty,
              occupiedSlots < ZombieSwordTuning.maximumActiveZombies else {
            return nil
        }
        spawnTimer -= min(max(deltaTime, 0), 0.1)
        guard spawnTimer <= 0 else { return nil }
        spawnTimer = currentPlan?.spawnInterval ?? ZombieSwordTuning.initialSpawnInterval
        return pendingTypes.removeFirst()
    }

    var hasPendingSpawns: Bool { !pendingTypes.isEmpty }

    func reset() {
        currentWave = 0
        currentPlan = nil
        pendingTypes.removeAll(keepingCapacity: true)
        spawnTimer = 0
    }

    func cancelPendingSpawns() {
        pendingTypes.removeAll(keepingCapacity: true)
        spawnTimer = 0
    }
}
