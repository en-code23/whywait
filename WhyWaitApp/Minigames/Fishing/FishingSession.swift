import Foundation

struct FishingSessionStatistics {
    private(set) var catches = 0
    private(set) var coinsEarned = 0
    private(set) var newSpecies = 0
    private(set) var longestFight: TimeInterval = 0

    mutating func record(
        progression: FishingCatchProgression,
        catchItem: ProspectiveCatch,
        fightDuration: TimeInterval
    ) {
        guard progression.wasApplied else { return }
        catches += 1
        coinsEarned += progression.coinsAwarded
        if progression.isNewDiscovery,
           case .fish = catchItem {
            newSpecies += 1
        }
        longestFight = max(longestFight, max(0, fightDuration))
    }
}

