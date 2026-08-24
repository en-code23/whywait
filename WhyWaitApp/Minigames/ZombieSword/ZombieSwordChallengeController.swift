import Foundation

enum ZombieSwordChallengeType: String, CaseIterable {
    case multiKill = "MULTI-KILL"
    case headhunter = "HEADHUNTER"
    case untouchable = "UNTOUCHABLE"
    case heavyDuty = "HEAVY DUTY"
    case combo = "COMBO"
    case perfectCut = "PERFECT CUT"

    var target: Int {
        switch self {
        case .multiKill: return 3
        case .headhunter: return 5
        case .untouchable, .heavyDuty: return 1
        case .combo: return 10
        case .perfectCut: return 3
        }
    }
}

struct ZombieSwordChallengeProgress: Equatable {
    let type: ZombieSwordChallengeType
    let value: Int
    var isComplete: Bool { value >= type.target }
    var displayText: String { "\(type.rawValue)  \(min(value, type.target))/\(type.target)" }
}

final class ZombieSwordChallengeController {
    private(set) var progress = ZombieSwordChallengeProgress(type: .multiKill, value: 0)
    private var nextIndex = 0
    private var waveDamageTaken = 0
    private var completionDelay: TimeInterval?

    func reset(startingIndex: Int = 0) {
        nextIndex = max(0, startingIndex) % ZombieSwordChallengeType.allCases.count
        waveDamageTaken = 0
        completionDelay = nil
        beginNext()
    }

    func beginWave() {
        waveDamageTaken = 0
    }

    func registerPlayerDamage(_ damage: Int) {
        waveDamageTaken += max(0, damage)
    }

    @discardableResult
    func registerHit(
        result: ZombieDamageResult,
        zombieType: ZombieType,
        killed: Bool,
        combo: Int,
        multiKill: Int
    ) -> Bool {
        guard !progress.isComplete else { return false }
        var increment = 0
        switch progress.type {
        case .multiKill:
            if multiKill >= progress.type.target { increment = progress.type.target }
        case .headhunter:
            if killed && result.region == .head { increment = 1 }
        case .untouchable:
            break
        case .heavyDuty:
            if killed && zombieType == .tank { increment = 1 }
        case .combo:
            if combo >= progress.type.target { increment = progress.type.target }
        case .perfectCut:
            if result.style == .perfect { increment = 1 }
        }
        return applyIncrement(increment)
    }

    @discardableResult
    func registerWaveClear() -> Bool {
        guard progress.type == .untouchable, waveDamageTaken == 0 else { return false }
        return applyIncrement(1)
    }

    func update(deltaTime: TimeInterval) -> Bool {
        guard let delay = completionDelay else { return false }
        let nextDelay = delay - min(max(deltaTime, 0), 0.1)
        completionDelay = nextDelay
        guard nextDelay <= 0 else { return false }
        beginNext()
        return true
    }

    private func applyIncrement(_ increment: Int) -> Bool {
        guard increment > 0 else { return false }
        let wasComplete = progress.isComplete
        progress = ZombieSwordChallengeProgress(
            type: progress.type,
            value: min(progress.type.target, progress.value + increment)
        )
        if !wasComplete, progress.isComplete {
            completionDelay = ZombieSwordTuning.challengeAdvanceDelay
            return true
        }
        return false
    }

    private func beginNext() {
        let all = ZombieSwordChallengeType.allCases
        let type = all[nextIndex % all.count]
        nextIndex = (nextIndex + 1) % all.count
        progress = ZombieSwordChallengeProgress(type: type, value: 0)
        completionDelay = nil
    }
}
