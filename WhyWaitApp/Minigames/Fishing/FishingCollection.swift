import Foundation

enum FishVariant: String, Codable, CaseIterable, Hashable {
    case standard
    case albino
    case melanistic
    case gilded
    case iridescent
    case ancient

    var displayName: String {
        switch self {
        case .standard: return "STANDARD"
        case .albino: return "ALBINO"
        case .melanistic: return "MELANISTIC"
        case .gilded: return "GILDED"
        case .iridescent: return "IRIDESCENT"
        case .ancient: return "ANCIENT"
        }
    }

    var shortMarker: String {
        switch self {
        case .standard: return ""
        case .albino: return "A"
        case .melanistic: return "M"
        case .gilded: return "G"
        case .iridescent: return "I"
        case .ancient: return "✦"
        }
    }

    var valueMultiplier: Double {
        switch self {
        case .standard: return 1
        case .albino: return 1.65
        case .melanistic: return 1.75
        case .gilded: return 2.25
        case .iridescent: return 2.8
        case .ancient: return 3.5
        }
    }

    var fightMultiplier: Double {
        switch self {
        case .standard: return 1
        case .albino: return 1.04
        case .melanistic: return 1.08
        case .gilded: return 1.12
        case .iridescent: return 1.17
        case .ancient: return 1.25
        }
    }

    /// Relative weights after a rare-variant roll has succeeded.
    var conditionalWeight: Double {
        switch self {
        case .standard: return 0
        case .albino: return 35
        case .melanistic: return 30
        case .gilded: return 18
        case .iridescent: return 11
        case .ancient: return 6
        }
    }
}

struct StoredFishSpecimen: Codable, Equatable, Identifiable {
    let id: UUID
    let speciesID: String
    let variant: FishVariant
    let weight: Double
    let length: Double
    let assessedValue: Int
    let caughtAt: Date
    var isFavorite: Bool
    var isLocked: Bool

    init(
        id: UUID,
        specimen: FishSpecimen,
        caughtAt: Date = Date(),
        isFavorite: Bool = false,
        isLocked: Bool = false
    ) {
        self.id = id
        speciesID = specimen.definition.id
        variant = specimen.variant
        weight = specimen.weight
        length = specimen.length
        assessedValue = specimen.saleValue
        self.caughtAt = caughtAt
        self.isFavorite = isFavorite
        self.isLocked = isLocked
    }

    var definition: FishDefinition? { FishCatalog.species(id: speciesID) }
}

enum FishingLure: String, Codable, CaseIterable, Hashable {
    case reefChum = "reef-chum"
    case prismFly = "prism-fly"
    case abyssLantern = "abyss-lantern"

    var displayName: String {
        switch self {
        case .reefChum: return "REEF CHUM"
        case .prismFly: return "PRISM FLY"
        case .abyssLantern: return "ABYSS LANTERN"
        }
    }

    var detail: String {
        switch self {
        case .reefChum: return "Quicker bites · modest rarity lift"
        case .prismFly: return "Greatly improves variant sightings"
        case .abyssLantern: return "Draws deep-water ocean species"
        }
    }

    var cost: Int {
        switch self {
        case .reefChum: return 140
        case .prismFly: return 320
        case .abyssLantern: return 480
        }
    }

    var rareWeightBonus: Double {
        switch self {
        case .reefChum: return 0.08
        case .prismFly: return 0.05
        case .abyssLantern: return 0.16
        }
    }

    var variantChanceMultiplier: Double {
        switch self {
        case .reefChum: return 1.1
        case .prismFly: return 3.4
        case .abyssLantern: return 1.25
        }
    }

    var oceanWeightMultiplier: Double {
        switch self {
        case .reefChum: return 1.2
        case .prismFly: return 1
        case .abyssLantern: return 2.35
        }
    }

    var biteWaitMultiplier: Double {
        switch self {
        case .reefChum: return 0.86
        case .prismFly: return 0.96
        case .abyssLantern: return 0.92
        }
    }
}

struct FishingShopInventory: Codable, Equatable {
    var lureQuantities: [String: Int] = [:]
    var equippedLureID: String?
    var vaultLevel = 0

    var equippedLure: FishingLure? {
        guard let equippedLureID,
              let lure = FishingLure(rawValue: equippedLureID),
              quantity(of: lure) > 0 else { return nil }
        return lure
    }

    func quantity(of lure: FishingLure) -> Int {
        max(0, lureQuantities[lure.rawValue] ?? 0)
    }

    mutating func add(_ lure: FishingLure) {
        lureQuantities[lure.rawValue] = min(
            FishingTuning.maximumLureQuantity,
            quantity(of: lure) + 1
        )
        equippedLureID = lure.rawValue
    }

    mutating func equip(_ lure: FishingLure) -> Bool {
        guard quantity(of: lure) > 0 else { return false }
        equippedLureID = lure.rawValue
        return true
    }

    @discardableResult
    mutating func consumeEquippedLure() -> FishingLure? {
        guard let lure = equippedLure else { return nil }
        let remaining = max(0, quantity(of: lure) - 1)
        lureQuantities[lure.rawValue] = remaining
        if remaining == 0 { equippedLureID = nil }
        return lure
    }

    mutating func normalize() {
        vaultLevel = min(FishingTuning.maximumVaultLevel, max(0, vaultLevel))
        for lure in FishingLure.allCases {
            lureQuantities[lure.rawValue] = min(
                FishingTuning.maximumLureQuantity,
                max(0, lureQuantities[lure.rawValue] ?? 0)
            )
        }
        if equippedLure == nil { equippedLureID = nil }
    }
}

enum FishingShopPurchaseStatus: Equatable {
    case purchased(name: String, cost: Int)
    case insufficientCoins(cost: Int)
    case full
    case maximumLevel
    case duplicateTransaction
}

enum FishingShopAction: Equatable {
    case upgrade(FishingEquipmentCategory)
    case buyLure(FishingLure)
    case equipLure(FishingLure)
    case expandVault
}
