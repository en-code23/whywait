import Foundation

struct ComboAward {
    let comboCount: Int
    let points: Int
}

final class ComboController {
    private(set) var currentCount = 0

    private var sessionID: Int?
    private var lastSliceTime: TimeInterval?

    func registerSlice(
        basePoints: Int,
        sessionID: Int,
        timestamp: TimeInterval
    ) -> ComboAward {
        if self.sessionID == sessionID,
           let lastSliceTime,
           timestamp - lastSliceTime <= FruitSliceTuning.comboSliceWindow {
            currentCount += 1
        } else {
            self.sessionID = sessionID
            currentCount = 1
        }

        lastSliceTime = timestamp
        let bonusScale = CGFloat(max(0, currentCount - 1))
            * FruitSliceTuning.comboBonusPerAdditionalFruit
        let bonus = Int((CGFloat(basePoints) * bonusScale).rounded())
        return ComboAward(comboCount: currentCount, points: basePoints + bonus)
    }

    func endSwipe() {
        sessionID = nil
        lastSliceTime = nil
        currentCount = 0
    }

    func reset() {
        endSwipe()
    }
}

