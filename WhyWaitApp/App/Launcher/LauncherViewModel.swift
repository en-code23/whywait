import Foundation

struct LauncherGameViewModel {
    let metadata: MinigameMetadata
    let cardStat: String
    let detailStats: [LauncherStat]
}

struct LauncherViewModel {
    let games: [LauncherGameViewModel]
    let lastPlayedID: String?
    let totalLaunches: Int
    let totalPlayTime: String
    let favoriteGameName: String?
    let settings: WhyWaitSettings
    let launchAtLogin: LaunchAtLoginStatus
    let settingsMessage: String?
    let shortcutDescription: String

    var globalSummary: String {
        var values = [
            "\(totalLaunches) \(totalLaunches == 1 ? "launch" : "launches")",
            totalPlayTime
        ]
        if let favoriteGameName { values.append("Favorite: \(favoriteGameName)") }
        return values.map(WWText.text).joined(separator: "  ·  ")
    }
}

final class LauncherViewModelBuilder {
    private let supplementalStats: GameSupplementalStatsProviding

    init(supplementalStats: GameSupplementalStatsProviding = GameSupplementalStatsProvider()) {
        self.supplementalStats = supplementalStats
    }

    func make(
        stats: WhyWaitStatsSnapshot,
        lastPlayedID: String?,
        settings: WhyWaitSettings,
        launchAtLogin: LaunchAtLoginStatus,
        settingsMessage: String?,
        shortcutDescription: String
    ) -> LauncherViewModel {
        let games = MinigameRegistry.allGames.map { metadata in
            let usage = stats.stats(for: metadata.id)
            let supplemental = supplementalStats.stats(for: metadata.id)
            let genericCardStat: String
            if usage.launches == 0 {
                genericCardStat = "Ready to play"
            } else {
                let playWord = usage.launches == 1 ? "play" : "plays"
                genericCardStat = "\(usage.launches) \(playWord) · \(WhyWaitStatsFormatting.duration(usage.playTime))"
            }
            return LauncherGameViewModel(
                metadata: metadata,
                cardStat: supplemental.cardSummary ?? genericCardStat,
                detailStats: [
                    LauncherStat(label: "LAUNCHES", value: usage.launches.formatted()),
                    LauncherStat(
                        label: "PLAY TIME",
                        value: WhyWaitStatsFormatting.duration(usage.playTime)
                    )
                ] + supplemental.detailStats
            )
        }
        let favoriteName = stats.favoriteGameID.flatMap { MinigameRegistry.metadata(for: $0)?.name }
        return LauncherViewModel(
            games: games,
            lastPlayedID: lastPlayedID,
            totalLaunches: stats.totalLaunches,
            totalPlayTime: WhyWaitStatsFormatting.duration(stats.totalPlayTime),
            favoriteGameName: favoriteName,
            settings: settings,
            launchAtLogin: launchAtLogin,
            settingsMessage: settingsMessage,
            shortcutDescription: shortcutDescription
        )
    }
}
