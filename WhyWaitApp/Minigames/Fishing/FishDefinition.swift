import Foundation

enum FishingZone: String, Codable, CaseIterable, Hashable {
    case near
    case mid
    case deep

    var displayName: String { rawValue.uppercased() }

    static func zone(for distance: Double, worldMaximumDistance: Double) -> FishingZone {
        guard worldMaximumDistance > 0, distance.isFinite else {
            return .near
        }
        let ratio = max(0, min(1, distance / worldMaximumDistance))
        if ratio < 0.35 { return .near }
        if ratio < 0.7 { return .mid }
        return .deep
    }
}

enum FishRarity: String, Codable, CaseIterable, Hashable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var displayName: String { rawValue.uppercased() }

    var baseSelectionWeight: Double {
        switch self {
        case .common: return 55
        case .uncommon: return 27
        case .rare: return 11
        case .epic: return 5
        case .legendary: return 0.8
        }
    }

    var valueMultiplier: Double {
        switch self {
        case .common: return 1
        case .uncommon: return 1.18
        case .rare: return 1.45
        case .epic: return 1.8
        case .legendary: return 2.35
        }
    }

    var marker: String {
        switch self {
        case .common: return "●"
        case .uncommon: return "◆"
        case .rare: return "★"
        case .epic: return "✦"
        case .legendary: return "✧"
        }
    }
}

struct FishingColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let accentRed: Double
    let accentGreen: Double
    let accentBlue: Double
}

struct FishDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let rarity: FishRarity
    let preferredZones: [FishingZone]
    let availableZones: [FishingZone]
    let minimumWeight: Double
    let maximumWeight: Double
    let minimumLength: Double
    let maximumLength: Double
    let baseValue: Int
    let fightPower: Double
    let stamina: Double
    let agility: Double
    let biteWindowModifier: TimeInterval
    let color: FishingColor
    let isOceanic: Bool

    var averageWeight: Double { (minimumWeight + maximumWeight) / 2 }
    var averageLength: Double { (minimumLength + maximumLength) / 2 }
}

extension FishDefinition {
    static func make(
        _ id: String,
        _ name: String,
        rarity: FishRarity,
        preferred: [FishingZone],
        available: [FishingZone],
        weight: ClosedRange<Double>,
        length: ClosedRange<Double>,
        value: Int,
        power: Double,
        stamina: Double,
        agility: Double,
        hookModifier: TimeInterval = 0,
        oceanic: Bool = false,
        body: (Double, Double, Double),
        accent: (Double, Double, Double)
    ) -> FishDefinition {
        FishDefinition(
            id: id,
            name: name,
            rarity: rarity,
            preferredZones: preferred,
            availableZones: available,
            minimumWeight: weight.lowerBound,
            maximumWeight: weight.upperBound,
            minimumLength: length.lowerBound,
            maximumLength: length.upperBound,
            baseValue: value,
            fightPower: power,
            stamina: stamina,
            agility: agility,
            biteWindowModifier: hookModifier,
            color: FishingColor(
                red: body.0,
                green: body.1,
                blue: body.2,
                accentRed: accent.0,
                accentGreen: accent.1,
                accentBlue: accent.2
            ),
            isOceanic: oceanic
        )
    }
}
