import Foundation

struct FishSpecimen: Equatable {
    let definition: FishDefinition
    let variant: FishVariant
    let weight: Double
    let length: Double
    let sizePercentile: Double
    let saleValue: Int

    var sizeFightMultiplier: Double {
        (0.78 + (sizePercentile * 0.52)) * variant.fightMultiplier
    }

    var displayName: String {
        variant == .standard
            ? definition.name
            : "\(variant.displayName.capitalized) \(definition.name)"
    }
}

struct TreasureCatch: Equatable {
    let definition: TreasureDefinition
    let saleValue: Int
}

enum ProspectiveCatch: Equatable {
    case fish(FishSpecimen)
    case treasure(TreasureCatch)

    var name: String {
        switch self {
        case let .fish(specimen): return specimen.displayName
        case let .treasure(treasure): return treasure.definition.name
        }
    }

    var rarity: FishRarity {
        switch self {
        case let .fish(specimen): return specimen.definition.rarity
        case let .treasure(treasure): return treasure.definition.rarity
        }
    }

    var saleValue: Int {
        switch self {
        case let .fish(specimen): return specimen.saleValue
        case let .treasure(treasure): return treasure.saleValue
        }
    }

    var catalogID: String {
        switch self {
        case let .fish(specimen): return specimen.definition.id
        case let .treasure(treasure): return treasure.definition.id
        }
    }

    var isLegendary: Bool { rarity == .legendary }
}

struct FishingCatchTransaction: Equatable {
    let id: UUID
    let catchItem: ProspectiveCatch

    init(id: UUID = UUID(), catchItem: ProspectiveCatch) {
        self.id = id
        self.catchItem = catchItem
    }
}

struct GeneratedCatch: Equatable {
    let prospective: ProspectiveCatch
    let biteWait: TimeInterval
    let hookWindow: TimeInterval
}
