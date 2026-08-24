import Foundation

protocol FishingRandomSource: AnyObject {
    func nextUnit() -> Double
}

extension FishingRandomSource {
    func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + ((range.upperBound - range.lowerBound) * nextUnit())
    }

    func integer(in range: ClosedRange<Int>) -> Int {
        let count = range.upperBound - range.lowerBound + 1
        return range.lowerBound + min(count - 1, Int(nextUnit() * Double(count)))
    }
}

final class SystemFishingRandomSource: FishingRandomSource {
    func nextUnit() -> Double {
        Double.random(in: 0..<1)
    }
}

/// Small deterministic generator used by invariant/economy tests.
final class SeededFishingRandomSource: FishingRandomSource {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    func nextUnit() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value >> 11) / Double(UInt64(1) << 53)
    }
}

