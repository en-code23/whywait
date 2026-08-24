enum FishingState: Equatable {
    case readyToCast
    case chargingCast
    case bobberFlying
    case waitingForBite
    case biteWindow
    case hooked
    case fighting
    case catchComplete
    case failedCatch
    case showingDex
    case showingUpgrades
    case resetting

    func canTransition(to next: FishingState) -> Bool {
        if next == .resetting {
            return self != .resetting
        }

        switch (self, next) {
        case (.resetting, .readyToCast),
             (.readyToCast, .chargingCast),
             (.readyToCast, .showingDex),
             (.readyToCast, .showingUpgrades),
             (.chargingCast, .bobberFlying),
             (.chargingCast, .readyToCast),
             (.bobberFlying, .waitingForBite),
             (.waitingForBite, .biteWindow),
             (.biteWindow, .hooked),
             (.biteWindow, .failedCatch),
             (.hooked, .fighting),
             (.hooked, .catchComplete),
             (.fighting, .catchComplete),
             (.fighting, .failedCatch),
             (.catchComplete, .readyToCast),
             (.failedCatch, .readyToCast),
             (.showingDex, .readyToCast),
             (.showingDex, .showingUpgrades),
             (.showingUpgrades, .readyToCast),
             (.showingUpgrades, .showingDex):
            return true
        default:
            return false
        }
    }

    var isPanelVisible: Bool {
        self == .showingDex || self == .showingUpgrades
    }
}

enum FishingFailureReason: String {
    case missedBite = "MISS"
    case lineBroke = "LINE BROKE"
    case slackEscape = "HOOK LOST"
}

