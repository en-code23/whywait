import Foundation

final class CatchGenerator {
    private let random: FishingRandomSource

#if DEBUG
    private var forcedFishID: String?
    private var forcedSizePercentile: Double?
#endif

    init(random: FishingRandomSource = SystemFishingRandomSource()) {
        self.random = random
    }

    func generate(
        zone: FishingZone,
        equipment: FishingEquipmentStats
    ) -> GeneratedCatch {
#if DEBUG
        if let forcedFishID,
           let definition = FishCatalog.species(id: forcedFishID) {
            self.forcedFishID = nil
            let percentile = forcedSizePercentile
            forcedSizePercentile = nil
            return generatedFish(
                definition,
                equipment: equipment,
                forcedPercentile: percentile
            )
        }
#endif

        if random.nextUnit() < equipment.treasureProbability,
           let treasure = weightedTreasure() {
            let valueVariance = random.value(in: 0.88...1.18)
            let catchItem = TreasureCatch(
                definition: treasure,
                saleValue: max(1, Int((Double(treasure.baseValue) * valueVariance).rounded()))
            )
            return GeneratedCatch(
                prospective: .treasure(catchItem),
                biteWait: boundedWait(
                    random.value(in: 1.5...3.8) * equipment.biteWaitMultiplier
                ),
                hookWindow: boundedHookWindow(
                    FishingTuning.baseHookWindow + equipment.hookWindowBonus + 0.12
                )
            )
        }

        let eligible = FishCatalog.all.filter { $0.availableZones.contains(zone) }
        let definition = weightedFish(
            from: eligible.isEmpty ? FishCatalog.all : eligible,
            zone: zone,
            rareBonus: equipment.rareWeightBonus
        ) ?? FishCatalog.all[0]
        return generatedFish(definition, equipment: equipment, forcedPercentile: nil)
    }

#if DEBUG
    func forceNextFish(id: String, sizePercentile: Double? = nil) {
        forcedFishID = id
        forcedSizePercentile = sizePercentile
    }
#endif

    func selectionWeight(
        for definition: FishDefinition,
        zone: FishingZone,
        rareBonus: Double
    ) -> Double {
        guard definition.availableZones.contains(zone), rareBonus.isFinite else {
            return 0
        }

        let sameTierCount = FishCatalog.all.filter {
            $0.rarity == definition.rarity && $0.availableZones.contains(zone)
        }.count
        guard sameTierCount > 0 else { return 0 }

        let rarityScale: Double
        switch definition.rarity {
        case .common: rarityScale = max(0.72, 1 - (rareBonus * 0.35))
        case .uncommon: rarityScale = 1 + (rareBonus * 0.45)
        case .rare: rarityScale = 1 + rareBonus
        case .epic: rarityScale = 1 + (rareBonus * 1.45)
        case .legendary: rarityScale = 1 + (rareBonus * 1.7)
        }
        let zoneScale = definition.preferredZones.contains(zone) ? 1.42 : 0.62
        let weight = (definition.rarity.baseSelectionWeight / Double(sameTierCount))
            * rarityScale
            * zoneScale
        return weight.isFinite ? max(0, weight) : 0
    }

    private func generatedFish(
        _ definition: FishDefinition,
        equipment: FishingEquipmentStats,
        forcedPercentile: Double?
    ) -> GeneratedCatch {
        let percentile = max(
            0,
            min(1, forcedPercentile ?? clusteredSizePercentile())
        )
        let length = interpolate(
            minimum: definition.minimumLength,
            maximum: definition.maximumLength,
            percentile: percentile
        )
        let condition = random.value(in: 0.94...1.06)
        let weightPercentile = max(0, min(1, pow(percentile, 1.12) * condition))
        let weight = interpolate(
            minimum: definition.minimumWeight,
            maximum: definition.maximumWeight,
            percentile: weightPercentile
        )
        let sizeValueMultiplier = 0.72 + (percentile * 0.82)
        let saleValue = max(
            1,
            Int(
                (Double(definition.baseValue)
                    * definition.rarity.valueMultiplier
                    * sizeValueMultiplier).rounded()
            )
        )
        let specimen = FishSpecimen(
            definition: definition,
            weight: weight,
            length: length,
            sizePercentile: percentile,
            saleValue: saleValue
        )

        let rarityDelay: TimeInterval
        switch definition.rarity {
        case .common: rarityDelay = 0
        case .uncommon: rarityDelay = 0.2
        case .rare: rarityDelay = 0.42
        case .epic: rarityDelay = 0.62
        case .legendary: rarityDelay = 0.82
        }
        let wait = (random.value(in: 1.5...5.15) + rarityDelay)
            * equipment.biteWaitMultiplier
        return GeneratedCatch(
            prospective: .fish(specimen),
            biteWait: boundedWait(wait),
            hookWindow: boundedHookWindow(
                FishingTuning.baseHookWindow
                    + equipment.hookWindowBonus
                    + definition.biteWindowModifier
            )
        )
    }

    private func weightedFish(
        from definitions: [FishDefinition],
        zone: FishingZone,
        rareBonus: Double
    ) -> FishDefinition? {
        weightedChoice(definitions) {
            selectionWeight(for: $0, zone: zone, rareBonus: rareBonus)
        }
    }

    private func weightedTreasure() -> TreasureDefinition? {
        weightedChoice(TreasureCatalog.all) { $0.selectionWeight }
    }

    private func weightedChoice<Element>(
        _ elements: [Element],
        weight: (Element) -> Double
    ) -> Element? {
        let weights = elements.map { element -> Double in
            let candidate = weight(element)
            return candidate.isFinite ? max(0, candidate) : 0
        }
        let total = weights.reduce(0, +)
        guard total > 0, total.isFinite else { return nil }

        var threshold = random.nextUnit() * total
        for (element, elementWeight) in zip(elements, weights) {
            threshold -= elementWeight
            if threshold <= 0 { return element }
        }
        return elements.last
    }

    private func clusteredSizePercentile() -> Double {
        let average = (random.nextUnit() + random.nextUnit() + random.nextUnit()) / 3
        if random.nextUnit() < 0.025 {
            return random.value(in: 0.91...1)
        }
        return max(0.02, min(0.98, average))
    }

    private func interpolate(minimum: Double, maximum: Double, percentile: Double) -> Double {
        minimum + ((maximum - minimum) * percentile)
    }

    private func boundedWait(_ value: TimeInterval) -> TimeInterval {
        min(FishingTuning.biteWaitRange.upperBound, max(FishingTuning.biteWaitRange.lowerBound, value))
    }

    private func boundedHookWindow(_ value: TimeInterval) -> TimeInterval {
        min(FishingTuning.maximumHookWindow, max(FishingTuning.minimumHookWindow, value))
    }
}

