import Foundation

struct FishRecord: Codable, Equatable {
    var timesCaught = 0
    var bestWeight = 0.0
    var bestLength = 0.0
    var bestSaleValue = 0

    var isDiscovered: Bool { timesCaught > 0 }
}

struct TreasureRecord: Codable, Equatable {
    var timesFound = 0
    var bestValue = 0

    var isDiscovered: Bool { timesFound > 0 }
}

struct FishingCatchProgression: Equatable {
    let wasApplied: Bool
    let coinsAwarded: Int
    let isNewDiscovery: Bool
    let isNewWeightRecord: Bool
    let isNewLengthRecord: Bool
    let receivedRecordBonus: Bool

    static let duplicate = FishingCatchProgression(
        wasApplied: false,
        coinsAwarded: 0,
        isNewDiscovery: false,
        isNewWeightRecord: false,
        isNewLengthRecord: false,
        receivedRecordBonus: false
    )
}

enum FishingUpgradePurchaseStatus: Equatable {
    case purchased(newLevel: Int, cost: Int)
    case insufficientCoins(cost: Int)
    case maximumLevel
    case duplicateTransaction
}

struct FishingProfile: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var coins: Int
    var equipment: FishingEquipmentLevels
    var fishRecords: [String: FishRecord]
    var treasureRecords: [String: TreasureRecord]
    var totalCatches: Int
    var totalLegendaryCatches: Int
    var hasShownBasicTutorial: Bool
    var recentTransactionIDs: [String]

    init(
        version: Int = FishingProfile.currentVersion,
        coins: Int = FishingTuning.startingCoins,
        equipment: FishingEquipmentLevels = FishingEquipmentLevels(),
        fishRecords: [String: FishRecord] = [:],
        treasureRecords: [String: TreasureRecord] = [:],
        totalCatches: Int = 0,
        totalLegendaryCatches: Int = 0,
        hasShownBasicTutorial: Bool = false,
        recentTransactionIDs: [String] = []
    ) {
        self.version = version
        self.coins = coins
        self.equipment = equipment
        self.fishRecords = fishRecords
        self.treasureRecords = treasureRecords
        self.totalCatches = totalCatches
        self.totalLegendaryCatches = totalLegendaryCatches
        self.hasShownBasicTutorial = hasShownBasicTutorial
        self.recentTransactionIDs = recentTransactionIDs
        normalize()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        coins = try container.decodeIfPresent(Int.self, forKey: .coins)
            ?? FishingTuning.startingCoins
        equipment = try container.decodeIfPresent(
            FishingEquipmentLevels.self,
            forKey: .equipment
        ) ?? FishingEquipmentLevels()
        fishRecords = try container.decodeIfPresent(
            [String: FishRecord].self,
            forKey: .fishRecords
        ) ?? [:]
        treasureRecords = try container.decodeIfPresent(
            [String: TreasureRecord].self,
            forKey: .treasureRecords
        ) ?? [:]
        totalCatches = try container.decodeIfPresent(Int.self, forKey: .totalCatches) ?? 0
        totalLegendaryCatches = try container.decodeIfPresent(
            Int.self,
            forKey: .totalLegendaryCatches
        ) ?? 0
        hasShownBasicTutorial = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasShownBasicTutorial
        ) ?? false
        recentTransactionIDs = try container.decodeIfPresent(
            [String].self,
            forKey: .recentTransactionIDs
        ) ?? []
        normalize()
    }

    var discoveredFishCount: Int {
        FishCatalog.all.reduce(0) { count, definition in
            count + ((fishRecords[definition.id]?.isDiscovered == true) ? 1 : 0)
        }
    }

    var discoveredTreasureCount: Int {
        TreasureCatalog.all.reduce(0) { count, definition in
            count + ((treasureRecords[definition.id]?.isDiscovered == true) ? 1 : 0)
        }
    }

    mutating func applyCatch(
        _ transaction: FishingCatchTransaction
    ) -> FishingCatchProgression {
        guard registerTransaction(transaction.id) else {
            return .duplicate
        }

        let catchItem = transaction.catchItem
        var isNewDiscovery = false
        var newWeightRecord = false
        var newLengthRecord = false

        switch catchItem {
        case let .fish(specimen):
            var record = fishRecords[specimen.definition.id] ?? FishRecord()
            isNewDiscovery = !record.isDiscovered
            newWeightRecord = specimen.weight > record.bestWeight
            newLengthRecord = specimen.length > record.bestLength
            record.timesCaught += 1
            record.bestWeight = max(record.bestWeight, specimen.weight)
            record.bestLength = max(record.bestLength, specimen.length)

            let getsRecordBonus = newWeightRecord || newLengthRecord
            let recordBonus = getsRecordBonus
                ? Int((Double(specimen.saleValue) * FishingTuning.recordValueBonus).rounded())
                : 0
            let awarded = max(0, specimen.saleValue + recordBonus)
            record.bestSaleValue = max(record.bestSaleValue, awarded)
            fishRecords[specimen.definition.id] = record
            coins += awarded
            totalCatches += 1
            if specimen.definition.rarity == .legendary {
                totalLegendaryCatches += 1
            }
            normalizeCounters()
            return FishingCatchProgression(
                wasApplied: true,
                coinsAwarded: awarded,
                isNewDiscovery: isNewDiscovery,
                isNewWeightRecord: newWeightRecord,
                isNewLengthRecord: newLengthRecord,
                receivedRecordBonus: getsRecordBonus
            )

        case let .treasure(treasure):
            var record = treasureRecords[treasure.definition.id] ?? TreasureRecord()
            isNewDiscovery = !record.isDiscovered
            record.timesFound += 1
            record.bestValue = max(record.bestValue, treasure.saleValue)
            treasureRecords[treasure.definition.id] = record
            let awarded = max(0, treasure.saleValue)
            coins += awarded
            totalCatches += 1
            normalizeCounters()
            return FishingCatchProgression(
                wasApplied: true,
                coinsAwarded: awarded,
                isNewDiscovery: isNewDiscovery,
                isNewWeightRecord: false,
                isNewLengthRecord: false,
                receivedRecordBonus: false
            )
        }
    }

    mutating func purchaseUpgrade(
        _ category: FishingEquipmentCategory,
        transactionID: UUID
    ) -> FishingUpgradePurchaseStatus {
        let transactionKey = transactionID.uuidString
        guard !recentTransactionIDs.contains(transactionKey) else {
            return .duplicateTransaction
        }
        guard let cost = equipment.upgradeCost(for: category) else {
            return .maximumLevel
        }
        guard coins >= cost else {
            return .insufficientCoins(cost: cost)
        }

        _ = registerTransaction(transactionID)
        coins -= cost
        equipment.setLevel(equipment.level(for: category) + 1, for: category)
        normalize()
        return .purchased(newLevel: equipment.level(for: category), cost: cost)
    }

    func fishRecord(for id: String) -> FishRecord {
        fishRecords[id] ?? FishRecord()
    }

    func treasureRecord(for id: String) -> TreasureRecord {
        treasureRecords[id] ?? TreasureRecord()
    }

    mutating func normalize() {
        version = max(1, min(Self.currentVersion, version))
        coins = max(0, coins)
        equipment.normalize()
        normalizeCounters()
        if recentTransactionIDs.count > FishingTuning.maximumRecentTransactions {
            recentTransactionIDs.removeFirst(
                recentTransactionIDs.count - FishingTuning.maximumRecentTransactions
            )
        }
    }

    private mutating func normalizeCounters() {
        totalCatches = max(0, totalCatches)
        totalLegendaryCatches = max(0, min(totalCatches, totalLegendaryCatches))
        coins = max(0, coins)
    }

    @discardableResult
    private mutating func registerTransaction(_ id: UUID) -> Bool {
        let key = id.uuidString
        guard !recentTransactionIDs.contains(key) else { return false }
        recentTransactionIDs.append(key)
        if recentTransactionIDs.count > FishingTuning.maximumRecentTransactions {
            recentTransactionIDs.removeFirst(
                recentTransactionIDs.count - FishingTuning.maximumRecentTransactions
            )
        }
        return true
    }
}
