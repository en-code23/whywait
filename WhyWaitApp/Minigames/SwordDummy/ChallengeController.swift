import Foundation

enum SwordChallengeType: CaseIterable, Equatable {
    case headshots
    case heavyHit
    case precision
    case combo
    case perfectCut

    var title: String {
        switch self {
        case .headshots: return "HEADSHOTS 0/3"
        case .heavyHit: return "HEAVY HIT 50+"
        case .precision: return "PRECISION TIP STRIKE"
        case .combo: return "COMBO x5"
        case .perfectCut: return "PERFECT CUT"
        }
    }
}

struct SwordChallengeProgress: Equatable {
    let type: SwordChallengeType
    var headHits = 0
    var isComplete = false

    var displayText: String {
        switch type {
        case .headshots:
            return "HEADSHOTS \(min(headHits, SwordDummyTuning.challengeHeadHits))/\(SwordDummyTuning.challengeHeadHits)"
        default:
            return type.title
        }
    }
}

final class SwordChallengeController {
    private(set) var progress: SwordChallengeProgress
    private var nextChallengeIndex: Int

    init(startingIndex: Int = 0) {
        let challenges = SwordChallengeType.allCases
        nextChallengeIndex = abs(startingIndex) % challenges.count
        progress = SwordChallengeProgress(type: challenges[nextChallengeIndex])
    }

    @discardableResult
    func beginNextChallenge() -> SwordChallengeProgress {
        let challenges = SwordChallengeType.allCases
        nextChallengeIndex = (nextChallengeIndex + 1) % challenges.count
        progress = SwordChallengeProgress(type: challenges[nextChallengeIndex])
        return progress
    }

    @discardableResult
    func register(result: SwordDamageResult, combo: Int) -> Bool {
        guard !progress.isComplete, result.damage > 0 else { return false }
        var completed = false
        switch progress.type {
        case .headshots:
            if result.region == .head {
                progress.headHits += 1
                completed = progress.headHits >= SwordDummyTuning.challengeHeadHits
            }
        case .heavyHit:
            completed = result.damage >= SwordDummyTuning.challengeHeavyDamage
        case .precision:
            completed = result.style == .precision || result.style == .thrust
        case .combo:
            completed = combo >= SwordDummyTuning.challengeCombo
        case .perfectCut:
            completed = result.style == .perfect
        }
        progress.isComplete = completed
        return completed
    }

    func reset(startingIndex: Int = 0) {
        let challenges = SwordChallengeType.allCases
        nextChallengeIndex = abs(startingIndex) % challenges.count
        progress = SwordChallengeProgress(type: challenges[nextChallengeIndex])
    }
}

struct SwordDummySessionStatistics {
    var totalDamage = 0
    var strongestHit = 0
    var highestCombo = 0
    var dummyDestructions = 0
    var headHits = 0
    var perfectStrikes = 0
    var meaningfulStrikeCount = 0

    var averageMeaningfulDamage: CGFloat {
        guard meaningfulStrikeCount > 0 else { return 0 }
        return CGFloat(totalDamage) / CGFloat(meaningfulStrikeCount)
    }

    mutating func record(result: SwordDamageResult, combo: Int) {
        guard result.damage > 0 else { return }
        totalDamage += result.damage
        strongestHit = max(strongestHit, result.damage)
        highestCombo = max(highestCombo, combo)
        meaningfulStrikeCount += 1
        if result.region == .head { headHits += 1 }
        if result.style == .perfect { perfectStrikes += 1 }
    }
}
