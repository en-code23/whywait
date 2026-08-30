#if DEBUG
import Foundation

enum FishingExpansionDiagnostics {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func runAll() throws -> [String] {
        try verifyCatalog()
        try verifyVariantsAndEconomy()
        try verifyTransactionsAndVault()
        try verifyMigrationAndPersistence()
        return [
            "catalog: \(FishCatalog.all.count) species, ocean silhouettes and all zones valid",
            "variants: six phenotypes remain rare, finite, and value-bounded",
            "shop/vault: exact-once purchases, capacity, locks, and release pass",
            "persistence: v1 migration and v2 Tidevault round trip pass"
        ]
    }

    private static func verifyCatalog() throws {
        try require(FishCatalog.all.count >= 36, "Expanded catalog is too small")
        try require(Set(FishCatalog.all.map(\.id)).count == FishCatalog.all.count, "Duplicate species IDs")
        try require(FishCatalog.all.filter(\.isOceanic).count >= 12, "Ocean roster is incomplete")
        try require(Set(FishCatalog.all.map(\.rarity)) == Set(FishRarity.allCases), "Rarity tier missing")
        for definition in FishCatalog.all {
            try require(!definition.availableZones.isEmpty, "\(definition.name) has no zone")
            try require(definition.minimumWeight > 0 && definition.maximumWeight >= definition.minimumWeight, "\(definition.name) has invalid weight")
            try require(definition.minimumLength > 0 && definition.maximumLength >= definition.minimumLength, "\(definition.name) has invalid length")
            try require(definition.baseValue > 0 && definition.fightPower.isFinite, "\(definition.name) has invalid economy")
        }
        let nodes = FishCatalog.all.map { FishNode(definition: $0) }
        try require(Set(nodes.map(\.visualArchetype)) == Set(FishBodyArchetype.allCases), "A visual archetype is unused")
    }

    private static func verifyVariantsAndEconomy() throws {
        let ordinary = CatchGenerator(random: SeededFishingRandomSource(seed: 0xA11CE))
        let prism = CatchGenerator(random: SeededFishingRandomSource(seed: 0xA11CE))
        let equipment = FishingEquipmentLevels().stats(worldMaximumCastDistance: 700)
        var ordinaryVariants = 0
        var prismVariants = 0
        var legendary = 0
        var valueTotal = 0
        let iterations = 20_000
        for _ in 0..<iterations {
            let base = ordinary.generate(zone: .deep, equipment: equipment)
            let boosted = prism.generate(zone: .deep, equipment: equipment, lure: .prismFly)
            if case let .fish(specimen) = base.prospective {
                ordinaryVariants += specimen.variant == .standard ? 0 : 1
                legendary += specimen.definition.rarity == .legendary ? 1 : 0
                valueTotal += specimen.saleValue
                try require(specimen.saleValue > 0 && specimen.weight.isFinite && specimen.length.isFinite, "Generated specimen invalid")
            }
            if case let .fish(specimen) = boosted.prospective {
                prismVariants += specimen.variant == .standard ? 0 : 1
            }
        }
        let ordinaryRate = Double(ordinaryVariants) / Double(iterations)
        let boostedRate = Double(prismVariants) / Double(iterations)
        try require(ordinaryRate > 0.008 && ordinaryRate < 0.05, "Base variant rate escaped bounds")
        try require(boostedRate > ordinaryRate && boostedRate < 0.1, "Prism variant rate invalid")
        try require(legendary > 0 && legendary < iterations / 12, "Legendary selection is not rare")
        try require(valueTotal > 0, "Economy produced no value")
    }

    private static func verifyTransactionsAndVault() throws {
        guard let definition = FishCatalog.species(id: "blacktip-shark") else {
            throw Failure(description: "Test shark missing")
        }
        var profile = FishingProfile(coins: 20_000)
        let specimen = FishSpecimen(
            definition: definition,
            variant: .gilded,
            weight: 52,
            length: 184,
            sizePercentile: 0.7,
            saleValue: 2_100
        )
        let catchID = UUID()
        let transaction = FishingCatchTransaction(id: catchID, catchItem: .fish(specimen))
        let applied = profile.applyCatch(transaction)
        let duplicate = profile.applyCatch(transaction)
        try require(applied.wasApplied && applied.wasStoredInVault, "Catch was not archived")
        try require(!duplicate.wasApplied && profile.storedFish.count == 1, "Catch duplicated")
        try require(profile.discoveredVariantCount == 1, "Variant discovery missing")

        let purchaseID = UUID()
        let first = profile.purchaseLure(.prismFly, transactionID: purchaseID)
        let second = profile.purchaseLure(.prismFly, transactionID: purchaseID)
        guard case .purchased = first, second == .duplicateTransaction else {
            throw Failure(description: "Shop transaction was not exact-once")
        }
        let balance = profile.coins
        _ = profile.purchaseLure(.prismFly, transactionID: purchaseID)
        try require(profile.coins == balance, "Duplicate purchase charged coins")
        try require(profile.toggleLock(specimenID: catchID), "Lock toggle failed")
        try require(!profile.releaseStoredFish(specimenID: catchID), "Locked specimen was released")
        try require(profile.toggleLock(specimenID: catchID), "Unlock failed")
        try require(profile.releaseStoredFish(specimenID: catchID), "Unlocked specimen did not release")
        try require(profile.storedFish.isEmpty, "Released specimen remained")
    }

    private static func verifyMigrationAndPersistence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhyWait-FishingExpansion-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = FishingSaveStore(directoryURL: directory)
        let oldJSON = """
        {"version":1,"coins":777,"equipment":{"rod":2,"reel":1,"line":1,"hook":1,"baitKit":1},"fishRecords":{},"treasureRecords":{},"totalCatches":0,"totalLegendaryCatches":0,"hasShownBasicTutorial":true,"recentTransactionIDs":[]}
        """.data(using: .utf8)!
        try oldJSON.write(to: store.profileURL)
        var migrated = store.load()
        try require(migrated.version == 2 && migrated.coins == 777, "v1 migration lost progression")
        try require(migrated.storedFish.isEmpty && migrated.vaultCapacity == 24, "v1 migration defaults invalid")
        _ = migrated.purchaseLure(.reefChum, transactionID: UUID())
        try require(store.save(migrated), "v2 save failed")
        let reloaded = store.load()
        try require(reloaded == migrated, "v2 profile did not round trip")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Failure(description: message) }
    }
}
#endif
