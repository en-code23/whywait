import Foundation

struct WhyWaitGameStats: Codable, Equatable {
    var launches = 0
    var playTime: TimeInterval = 0

    mutating func normalize() {
        launches = max(0, launches)
        playTime = playTime.isFinite ? max(0, playTime) : 0
    }
}

struct WhyWaitStatsSnapshot: Equatable {
    let games: [String: WhyWaitGameStats]
    let lastPlayedGameID: String?

    var totalLaunches: Int {
        games.values.reduce(0) { $0 + $1.launches }
    }

    var totalPlayTime: TimeInterval {
        games.values.reduce(0) { $0 + $1.playTime }
    }

    var favoriteGameID: String? {
        games
            .filter { $0.value.launches > 0 }
            .max {
                if $0.value.launches == $1.value.launches {
                    return $0.value.playTime < $1.value.playTime
                }
                return $0.value.launches < $1.value.launches
            }?
            .key
    }

    func stats(for gameID: String) -> WhyWaitGameStats {
        games[gameID] ?? WhyWaitGameStats()
    }
}

private struct ActiveMinigameSession: Codable, Equatable {
    let gameID: String
    let startedAt: Date
    var lastObservedAt: Date
}

private struct WhyWaitStatsProfile: Codable {
    static let currentVersion = 1

    var version = currentVersion
    var games: [String: WhyWaitGameStats] = [:]
    var lastPlayedGameID: String?
    var activeSession: ActiveMinigameSession?

    mutating func normalize(validGameIDs: Set<String>) {
        version = Self.currentVersion
        games = games.filter { validGameIDs.contains($0.key) }
        for gameID in games.keys {
            games[gameID]?.normalize()
        }
        if let lastPlayedGameID, !validGameIDs.contains(lastPlayedGameID) {
            self.lastPlayedGameID = nil
        }
        if let activeSession, !validGameIDs.contains(activeSession.gameID) {
            self.activeSession = nil
        }
    }
}

/// Lightweight, app-wide usage statistics stored independently of game progression.
final class WhyWaitStatsStore {
    static let maximumRecordedSession: TimeInterval = 4 * 60 * 60

    private let storageKey = "whywait.stats.v1"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let validGameIDs: Set<String>
    private var profile: WhyWaitStatsProfile

    init(
        defaults: UserDefaults = .standard,
        validGameIDs: Set<String> = Set(MinigameRegistry.allGames.map(\.id))
    ) {
        self.defaults = defaults
        self.validGameIDs = validGameIDs
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? decoder.decode(WhyWaitStatsProfile.self, from: data),
           decoded.version <= WhyWaitStatsProfile.currentVersion {
            profile = decoded
        } else {
            profile = WhyWaitStatsProfile()
        }
        profile.normalize(validGameIDs: validGameIDs)
    }

    var snapshot: WhyWaitStatsSnapshot {
        WhyWaitStatsSnapshot(
            games: profile.games,
            lastPlayedGameID: profile.lastPlayedGameID
        )
    }

    func recordGameStarted(_ gameID: String, at date: Date = Date()) {
        guard validGameIDs.contains(gameID) else { return }
        _ = recoverInterruptedSession(at: date)
        var stats = profile.games[gameID] ?? WhyWaitGameStats()
        stats.launches += 1
        stats.normalize()
        profile.games[gameID] = stats
        profile.lastPlayedGameID = gameID
        profile.activeSession = ActiveMinigameSession(
            gameID: gameID,
            startedAt: date,
            lastObservedAt: date
        )
        persist()
    }

    func checkpointActiveSession(at date: Date = Date()) {
        guard var session = profile.activeSession else { return }
        let latestAllowed = session.startedAt.addingTimeInterval(Self.maximumRecordedSession)
        session.lastObservedAt = min(max(date, session.startedAt), latestAllowed)
        profile.activeSession = session
        persist()
    }

    @discardableResult
    func recordGameStopped(_ gameID: String, at date: Date = Date()) -> TimeInterval {
        guard let session = profile.activeSession, session.gameID == gameID else { return 0 }
        let duration = boundedDuration(from: session.startedAt, to: date)
        addPlayTime(duration, to: gameID)
        profile.activeSession = nil
        persist()
        return duration
    }

    /// Recovers only through the last periodic checkpoint, avoiding overnight crash inflation.
    @discardableResult
    func recoverInterruptedSession(at date: Date = Date()) -> TimeInterval {
        guard let session = profile.activeSession else { return 0 }
        let observed = min(session.lastObservedAt, date)
        let duration = boundedDuration(from: session.startedAt, to: observed)
        addPlayTime(duration, to: session.gameID)
        profile.activeSession = nil
        persist()
        return duration
    }

    private func addPlayTime(_ duration: TimeInterval, to gameID: String) {
        guard duration.isFinite, duration > 0, validGameIDs.contains(gameID) else { return }
        var stats = profile.games[gameID] ?? WhyWaitGameStats()
        stats.playTime += duration
        stats.normalize()
        profile.games[gameID] = stats
    }

    private func boundedDuration(from start: Date, to end: Date) -> TimeInterval {
        let rawDuration = end.timeIntervalSince(start)
        guard rawDuration.isFinite else { return 0 }
        return min(Self.maximumRecordedSession, max(0, rawDuration))
    }

    private func persist() {
        profile.normalize(validGameIDs: validGameIDs)
        guard let data = try? encoder.encode(profile) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
