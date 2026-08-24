import Foundation

final class SwordComboController {
    private(set) var count = 0
    private(set) var highest = 0
    private var lastHitTime: TimeInterval = -.infinity

    @discardableResult
    func register(damage: Int, at time: TimeInterval) -> Int {
        guard damage >= SwordDummyTuning.comboMinimumDamage else { return count }
        count = time - lastHitTime <= SwordDummyTuning.comboTimeout ? count + 1 : 1
        highest = max(highest, count)
        lastHitTime = time
        return count
    }

    func update(at time: TimeInterval) {
        if count > 0, time - lastHitTime > SwordDummyTuning.comboTimeout {
            count = 0
        }
    }

    func reset() {
        count = 0
        highest = 0
        lastHitTime = -.infinity
    }
}
