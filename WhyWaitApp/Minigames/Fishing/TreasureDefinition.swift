import Foundation

struct TreasureDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let rarity: FishRarity
    let baseValue: Int
    let selectionWeight: Double
    let symbol: String
}

enum TreasureCatalog {
    static let all: [TreasureDefinition] = [
        TreasureDefinition(
            id: "old-boot", name: "Old Boot", rarity: .common,
            baseValue: 28, selectionWeight: 31, symbol: "⌁"
        ),
        TreasureDefinition(
            id: "soda-can", name: "Soda Can", rarity: .common,
            baseValue: 34, selectionWeight: 27, symbol: "▥"
        ),
        TreasureDefinition(
            id: "bottle-message", name: "Bottle Message", rarity: .uncommon,
            baseValue: 125, selectionWeight: 17, symbol: "✉"
        ),
        TreasureDefinition(
            id: "lost-key", name: "Lost Key", rarity: .uncommon,
            baseValue: 155, selectionWeight: 13, symbol: "⚿"
        ),
        TreasureDefinition(
            id: "old-coin", name: "Old Coin", rarity: .rare,
            baseValue: 390, selectionWeight: 7, symbol: "◉"
        ),
        TreasureDefinition(
            id: "pocket-watch", name: "Pocket Watch", rarity: .rare,
            baseValue: 520, selectionWeight: 3.5, symbol: "◷"
        ),
        TreasureDefinition(
            id: "antique-ring", name: "Antique Ring", rarity: .epic,
            baseValue: 1_250, selectionWeight: 1.3, symbol: "◌"
        ),
        TreasureDefinition(
            id: "strange-artifact", name: "Strange Artifact", rarity: .legendary,
            baseValue: 3_400, selectionWeight: 0.35, symbol: "◇"
        )
    ]

    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func treasure(id: String) -> TreasureDefinition? { byID[id] }
}

