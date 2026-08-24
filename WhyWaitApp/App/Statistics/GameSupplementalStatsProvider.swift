import Foundation

struct LauncherStat: Equatable {
    let label: String
    let value: String
}

struct SupplementalGameStats: Equatable {
    let cardSummary: String?
    let detailStats: [LauncherStat]

    static let empty = SupplementalGameStats(cardSummary: nil, detailStats: [])
}

protocol GameSupplementalStatsProviding {
    func stats(for gameID: String) -> SupplementalGameStats
}

/// Reads game-owned progression without moving or rewriting its save model.
final class GameSupplementalStatsProvider: GameSupplementalStatsProviding {
    private let fishingStore: FishingSaveStore

    init(fishingStore: FishingSaveStore = FishingSaveStore()) {
        self.fishingStore = fishingStore
    }

    func stats(for gameID: String) -> SupplementalGameStats {
        guard gameID == "fishing" else { return .empty }
        let profile = fishingStore.load()
        let speciesCount = FishCatalog.all.count
        return SupplementalGameStats(
            cardSummary: "\(profile.discoveredFishCount) / \(speciesCount) fish",
            detailStats: [
                LauncherStat(
                    label: "FISH DISCOVERED",
                    value: "\(profile.discoveredFishCount) / \(speciesCount)"
                ),
                LauncherStat(label: "COINS", value: profile.coins.formatted()),
                LauncherStat(label: "TOTAL CATCHES", value: profile.totalCatches.formatted())
            ]
        )
    }
}

enum WhyWaitStatsFormatting {
    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, interval.isFinite ? interval : 0)
        if seconds < 60 { return seconds > 0 ? "<1m" : "0m" }
        let totalMinutes = Int(seconds / 60)
        if totalMinutes < 60 { return "\(totalMinutes)m" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
