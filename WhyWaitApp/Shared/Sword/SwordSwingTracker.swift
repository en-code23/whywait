import CoreGraphics
import Foundation

final class SwordSwingTracker {
    private(set) var activeSwingID: Int?
    private(set) var strongestDamageInSwing = 0
    private var nextSwingID = 1
    private var idleDuration: TimeInterval = 0

    func update(speed: CGFloat, deltaTime: TimeInterval) {
        let safeSpeed = speed.isFinite ? max(0, speed) : 0
        let safeDelta = deltaTime.isFinite ? min(max(0, deltaTime), 0.1) : 0

        if activeSwingID == nil, safeSpeed >= SwordEngineTuning.swingStartSpeed {
            activeSwingID = nextSwingID
            nextSwingID += 1
            strongestDamageInSwing = 0
            idleDuration = 0
            return
        }

        guard activeSwingID != nil else { return }
        if safeSpeed <= SwordEngineTuning.swingEndSpeed {
            idleDuration += safeDelta
            if idleDuration >= SwordEngineTuning.swingIdleDuration {
                activeSwingID = nil
                strongestDamageInSwing = 0
                idleDuration = 0
            }
        } else {
            idleDuration = 0
        }
    }

    func registerDamage(_ damage: Int) {
        strongestDamageInSwing = max(strongestDamageInSwing, damage)
    }

    func reset() {
        activeSwingID = nil
        strongestDamageInSwing = 0
        nextSwingID = 1
        idleDuration = 0
    }
}
