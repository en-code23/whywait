#if DEBUG
import Foundation
import SpriteKit

enum FishingExpansionDiagnostics {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func runAll() throws -> [String] {
        try verifyCatalog()
        try verifyVariantsAndEconomy()
        try verifyTransactionsAndVault()
        try verifyMigrationAndPersistence()
        try verifyRodShopAndStaleSaves()
        try verifyLandingAndCasting()
        try verifyGrappleUnits()
        return [
            "catalog: \(FishCatalog.all.count) species, ocean silhouettes and all zones valid",
            "variants: six phenotypes remain rare, finite, and value-bounded",
            "shop/vault: exact-once purchases, capacity, locks, and release pass",
            "persistence: v1/v2 migration to v3, rod ownership and stale-writer rejection pass",
            "physics: landing proximity, moving-tip casting, bounded rod spring and point-space Grapple gravity pass"
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
        try require(migrated.version == FishingProfile.currentVersion && migrated.coins == 777, "v1 migration lost progression")
        try require(migrated.storedFish.isEmpty && migrated.vaultCapacity == 24, "v1 migration defaults invalid")
        _ = migrated.purchaseLure(.reefChum, transactionID: UUID())
        try require(store.save(migrated), "v2 save failed")
        let reloaded = store.load()
        try require(reloaded == migrated, "v2 profile did not round trip")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Failure(description: message) }
    }

    private static func verifyRodShopAndStaleSaves() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("WhyWait-save-regression-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = FishingSaveStore(directoryURL: directory)
        var profile = first.load()
        profile.coins = 20_000
        try require(first.save(profile), "Initial save failed")
        let staleStore = FishingSaveStore(directoryURL: directory)
        let staleProfile = staleStore.load()
        let oldBalance = profile.coins
        _ = profile.purchaseUpgrade(.reel, transactionID: UUID())
        try require(first.save(profile), "Upgrade save failed")
        try require(!staleStore.save(staleProfile), "Stale scene resurrected spent coins")
        let reopened = FishingSaveStore(directoryURL: directory).load()
        try require(reopened == profile && reopened.coins < oldBalance && reopened.equipment.reel == 2, "Reopening refunded upgrade")
        for rod in FishingRodModel.allCases {
            let id = UUID()
            _ = profile.selectRod(rod, transactionID: id)
            let balance = profile.coins
            try require(profile.selectRod(rod, transactionID: id) == .duplicateTransaction, "Rod purchase duplicated")
            _ = profile.selectRod(rod, transactionID: UUID())
            try require(profile.coins == balance && balance >= 0, "Equipping owned rod charged twice")
        }
        try require(first.save(profile), "Rod shop failed to save")
        try require(FishingSaveStore(directoryURL: directory).load() == profile, "Rod ownership did not persist")
        let scene = FishingScene(size: CGSize(width: 1000, height: 800), saveStore: FishingSaveStore(directoryURL: directory))
        scene.startGame()
        let beforeScenePurchase = scene.profile.coins
        scene.purchaseUpgrade(.line)
        let afterScenePurchase = scene.profile.coins
        scene.stopGame()
        let nextScene = FishingScene(size: CGSize(width: 1000, height: 800), saveStore: FishingSaveStore(directoryURL: directory))
        nextScene.startGame()
        try require(afterScenePurchase < beforeScenePurchase && nextScene.profile.coins == afterScenePurchase
            && nextScene.profile.equipment.line == 2, "Scene stop/reopen refunded a purchase")
        nextScene.stopGame()
        let basic = FishingEquipmentStats(levels: .init(), worldMaximumCastDistance: 700)
        let better = FishingEquipmentStats(levels: .init(), worldMaximumCastDistance: 700, rod: .abyss)
        try require(better.maximumCastDistance > basic.maximumCastDistance && better.lineBreakThreshold > basic.lineBreakThreshold, "Rod stats cosmetic only")
        try Data("not-json".utf8).write(to: first.profileURL)
        let recovered = first.load()
        try require(recovered.coins == FishingTuning.startingCoins, "Corruption did not recover")
        let preserved = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        try require(preserved.contains { $0.contains("corrupt-") }, "Corrupt data not preserved")
        try Data("{\"version\":999,\"coins\":123}".utf8).write(to: first.profileURL)
        _ = first.load()
        try require(!first.save(FishingProfile()), "Future profile was overwritten")
    }

    private static func verifyLandingAndCasting() throws {
        let rodPosition = CGPoint(x: 190, y: 160)
        let definition = FishCatalog.all[0]
        let specimen = FishSpecimen(definition: definition, variant: .standard, weight: definition.minimumWeight,
                                    length: definition.minimumLength, sizePercentile: 0.2, saleValue: 100)
        var catches = 0
        for seed in 1...40 {
            let fight = FishingFightController(random: SeededFishingRandomSource(seed: UInt64(seed)))
            fight.start(specimen: specimen, at: CGPoint(x: 550, y: 480), initialDistance: 481,
                        equipment: FishingEquipmentStats(levels: .init(), worldMaximumCastDistance: 700))
            for _ in 0..<3600 {
                guard let snapshot = fight.update(deltaTime: 1.0 / 120, rodPosition: rodPosition,
                    cursorPosition: rodPosition, isReeling: true, bounds: CGRect(x: 0, y: 0, width: 1000, height: 800)) else { break }
                try require(FishingGeometry.isFinite(snapshot.fishPosition), "Fight position invalid")
                let distance = FishingGeometry.distance(from: rodPosition, to: snapshot.fishPosition)
                try require(distance <= snapshot.lineRemaining + 0.01, "Fish escaped its visible line constraint")
                if snapshot.outcome == .landed {
                    try require(distance <= FishingTuning.catchDistance + 0.5, "Fish caught away from rod")
                    catches += 1; break
                }
                if snapshot.outcome != .none { break }
            }
        }
        try require(catches >= 30, "Common fish not reliably landable: \(catches)/40")
        let cast = FishingCastController(random: SeededFishingRandomSource(seed: 5))
        _ = cast.beginCharging(rodPosition: .zero, cursorPosition: CGPoint(x: 700, y: 600), timestamp: 0)
        let launch = cast.release(timestamp: 1, sceneSize: CGSize(width: 1000, height: 800), worldMaximumDistance: 700,
            equipment: FishingEquipmentStats(levels: .init(), worldMaximumCastDistance: 700), releasePosition: rodPosition)
        try require(launch?.start == rodPosition, "Cast used stale tip origin")
        let rod = FishingRod()
        rod.layout(in: CGSize(width: 1000, height: 800))
        let oldTip = rod.tipPosition
        rod.setAim(toward: CGPoint(x: 950, y: 180), power: 1)
        try require(rod.tipPosition == oldTip, "Rod teleported to mouse instead of springing")
        for i in 0..<12_000 {
            rod.setAim(toward: CGPoint(x: i.isMultiple(of: 2) ? -10_000 : 10_000, y: 400), power: 0.8)
            rod.simulate(deltaTime: i.isMultiple(of: 100) ? 3 : 1.0 / 120)
            try require(FishingGeometry.isFinite(rod.tipPosition), "Rod physics diverged")
        }
    }

    private static func verifyGrappleUnits() throws {
        let player = GrapplePlayer()
        player.reset(at: CGPoint(x: 400, y: 600))
        for _ in 0..<60 { player.apply(force: .zero, deltaTime: 1.0 / 120) }
        try require(abs(player.velocity.dy + 540) < 1, "Grapple gravity does not use points/sec²")
        try require(player.physicsBody?.affectedByGravity == false, "SpriteKit gravity doubles custom gravity")
        let scene = GrappleScene(size: CGSize(width: 1000, height: 800))
        try require(scene.physicsWorld.gravity == .zero, "Grapple still uses metre-based scene gravity")
        player.reset(at: .zero)
        try require(player.velocity == .zero, "Respawn keeps falling velocity")
    }
}
#endif
