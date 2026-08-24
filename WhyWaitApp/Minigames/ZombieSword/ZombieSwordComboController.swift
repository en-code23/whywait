import Foundation

struct ZombieSwordSessionStatistics: Equatable {
    var kills = 0
    var strongestHit = 0
    var highestCombo = 0
    var highestMultiKill = 0
    var headshotKills = 0
    var perfectCuts = 0
    var wavesCleared = 0
}

final class ZombieSwordComboController {
    private(set) var count = 0
    private var lastHitTime: TimeInterval?
    private var killsBySwing: [Int: Int] = [:]

    @discardableResult
    func registerHit(at time: TimeInterval) -> Int {
        if let lastHitTime, time - lastHitTime <= ZombieSwordTuning.comboTimeout {
            count += 1
        } else {
            count = 1
        }
        self.lastHitTime = time
        return count
    }

    @discardableResult
    func registerKill(swingID: Int?) -> Int {
        guard let swingID else { return 1 }
        let value = (killsBySwing[swingID] ?? 0) + 1
        killsBySwing[swingID] = value
        if killsBySwing.count > 12 {
            let keys = killsBySwing.keys.sorted()
            for key in keys.prefix(keys.count - 8) { killsBySwing.removeValue(forKey: key) }
        }
        return value
    }

    func update(at time: TimeInterval) {
        guard let lastHitTime,
              time - lastHitTime > ZombieSwordTuning.comboTimeout else { return }
        count = 0
        self.lastHitTime = nil
    }

    func reset() {
        count = 0
        lastHitTime = nil
        killsBySwing.removeAll(keepingCapacity: true)
    }
}
