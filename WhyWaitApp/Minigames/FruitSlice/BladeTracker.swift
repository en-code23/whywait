import CoreGraphics
import Foundation

struct BladeSample {
    let position: CGPoint
    let timestamp: TimeInterval
}

struct CuttingBladeSegment {
    let start: CGPoint
    let end: CGPoint
    let speed: CGFloat
    let direction: CGVector
    let sessionID: Int
}

enum BladeUpdate {
    case primed
    case ignored
    case inactive
    case interrupted
    case cutting(CuttingBladeSegment)
}

final class BladeTracker {
    private(set) var recentSamples: [BladeSample] = []

    private var previousSample: BladeSample?
    private var activeSessionID: Int?
    private var nextSessionID = 0
    private var lastCuttingTime: TimeInterval?

    func record(position: CGPoint, timestamp: TimeInterval) -> BladeUpdate {
        let sample = BladeSample(position: position, timestamp: timestamp)
        guard let previousSample else {
            prime(with: sample)
            return .primed
        }

        let elapsed = timestamp - previousSample.timestamp
        guard elapsed >= FruitSliceTuning.minimumCursorSampleInterval else {
            return .ignored
        }

        let distance = hypot(
            position.x - previousSample.position.x,
            position.y - previousSample.position.y
        )
        guard elapsed <= FruitSliceTuning.inputInterruptionInterval,
              distance <= FruitSliceTuning.maximumCursorSegmentLength else {
            prime(with: sample)
            return .interrupted
        }

        self.previousSample = sample
        append(sample)

        guard distance >= FruitSliceTuning.minimumCursorSegmentLength else {
            endSwipe()
            return .inactive
        }

        let rawSpeed = distance / CGFloat(elapsed)
        guard rawSpeed >= FruitSliceTuning.minimumSliceSpeed,
              let direction = SliceGeometry.normalizedDirection(
                from: previousSample.position,
                to: sample.position
              ) else {
            endSwipe()
            return .inactive
        }

        let sessionID = cuttingSessionID(at: timestamp)
        lastCuttingTime = timestamp
        return .cutting(
            CuttingBladeSegment(
                start: previousSample.position,
                end: sample.position,
                speed: min(rawSpeed, FruitSliceTuning.maximumAcceptedCursorSpeed),
                direction: direction,
                sessionID: sessionID
            )
        )
    }

    func expire(at timestamp: TimeInterval) -> Bool {
        guard let lastCuttingTime,
              timestamp - lastCuttingTime > FruitSliceTuning.swipeSessionGap else {
            return false
        }

        endSwipe()
        return true
    }

    func reset() {
        recentSamples.removeAll(keepingCapacity: true)
        previousSample = nil
        activeSessionID = nil
        lastCuttingTime = nil
    }

    private func prime(with sample: BladeSample) {
        recentSamples = [sample]
        previousSample = sample
        endSwipe()
    }

    private func append(_ sample: BladeSample) {
        recentSamples.append(sample)
        let cutoff = sample.timestamp - FruitSliceTuning.bladeHistoryDuration
        recentSamples.removeAll { $0.timestamp < cutoff }
        if recentSamples.count > FruitSliceTuning.maximumBladeSamples {
            recentSamples.removeFirst(recentSamples.count - FruitSliceTuning.maximumBladeSamples)
        }
    }

    private func cuttingSessionID(at timestamp: TimeInterval) -> Int {
        if let activeSessionID,
           let lastCuttingTime,
           timestamp - lastCuttingTime <= FruitSliceTuning.swipeSessionGap {
            return activeSessionID
        }

        nextSessionID += 1
        activeSessionID = nextSessionID
        return nextSessionID
    }

    private func endSwipe() {
        activeSessionID = nil
        lastCuttingTime = nil
    }
}

