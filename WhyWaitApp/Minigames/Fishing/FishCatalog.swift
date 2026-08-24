import Foundation

enum FishCatalog {
    static let all: [FishDefinition] = [
        .make(
            "bluegill", "Bluegill", rarity: .common,
            preferred: [.near], available: [.near, .mid],
            weight: 0.12...1.0, length: 14...34, value: 68,
            power: 0.3, stamina: 38, agility: 0.52,
            body: (0.24, 0.56, 0.72), accent: (0.94, 0.67, 0.24)
        ),
        .make(
            "roach", "Roach", rarity: .common,
            preferred: [.near], available: [.near, .mid],
            weight: 0.1...1.7, length: 13...42, value: 62,
            power: 0.28, stamina: 35, agility: 0.48,
            body: (0.58, 0.65, 0.66), accent: (0.9, 0.35, 0.2)
        ),
        .make(
            "perch", "Perch", rarity: .common,
            preferred: [.near, .mid], available: [.near, .mid],
            weight: 0.18...2.6, length: 16...49, value: 82,
            power: 0.36, stamina: 43, agility: 0.58,
            body: (0.44, 0.67, 0.22), accent: (0.13, 0.22, 0.16)
        ),
        .make(
            "crucian-carp", "Crucian Carp", rarity: .common,
            preferred: [.near], available: [.near, .mid],
            weight: 0.25...3.2, length: 18...52, value: 88,
            power: 0.4, stamina: 48, agility: 0.35,
            body: (0.69, 0.55, 0.22), accent: (0.94, 0.81, 0.36)
        ),
        .make(
            "smallmouth-bass", "Smallmouth Bass", rarity: .common,
            preferred: [.mid], available: [.near, .mid, .deep],
            weight: 0.35...4.8, length: 22...62, value: 105,
            power: 0.5, stamina: 55, agility: 0.62,
            body: (0.38, 0.48, 0.29), accent: (0.72, 0.63, 0.39)
        ),
        .make(
            "channel-catfish", "Channel Catfish", rarity: .common,
            preferred: [.mid], available: [.near, .mid],
            weight: 0.45...7.5, length: 28...82, value: 116,
            power: 0.55, stamina: 61, agility: 0.28,
            body: (0.29, 0.38, 0.42), accent: (0.7, 0.79, 0.76)
        ),

        .make(
            "rainbow-trout", "Rainbow Trout", rarity: .uncommon,
            preferred: [.mid], available: [.near, .mid, .deep],
            weight: 0.35...6.8, length: 24...78, value: 185,
            power: 0.64, stamina: 68, agility: 0.76,
            body: (0.46, 0.7, 0.72), accent: (0.93, 0.34, 0.54)
        ),
        .make(
            "common-carp", "Common Carp", rarity: .uncommon,
            preferred: [.mid], available: [.near, .mid, .deep],
            weight: 0.9...18, length: 36...105, value: 205,
            power: 0.72, stamina: 82, agility: 0.34,
            body: (0.58, 0.48, 0.24), accent: (0.85, 0.72, 0.38)
        ),
        .make(
            "largemouth-bass", "Largemouth Bass", rarity: .uncommon,
            preferred: [.mid], available: [.mid, .deep],
            weight: 0.6...9.5, length: 30...84, value: 225,
            power: 0.74, stamina: 76, agility: 0.7,
            body: (0.23, 0.43, 0.27), accent: (0.7, 0.76, 0.47)
        ),
        .make(
            "eel", "Eel", rarity: .uncommon,
            preferred: [.deep], available: [.mid, .deep],
            weight: 0.3...5.5, length: 42...126, value: 238,
            power: 0.68, stamina: 73, agility: 0.88,
            body: (0.18, 0.34, 0.31), accent: (0.53, 0.82, 0.57)
        ),
        .make(
            "northern-pike", "Northern Pike", rarity: .uncommon,
            preferred: [.mid, .deep], available: [.mid, .deep],
            weight: 0.8...14, length: 38...112, value: 260,
            power: 0.86, stamina: 84, agility: 0.79,
            body: (0.32, 0.51, 0.27), accent: (0.78, 0.83, 0.46)
        ),
        .make(
            "koi", "Koi", rarity: .uncommon,
            preferred: [.near, .mid], available: [.near, .mid],
            weight: 0.5...8.2, length: 28...78, value: 285,
            power: 0.62, stamina: 70, agility: 0.52,
            body: (0.94, 0.48, 0.12), accent: (0.98, 0.96, 0.84)
        ),

        .make(
            "golden-trout", "Golden Trout", rarity: .rare,
            preferred: [.deep], available: [.mid, .deep],
            weight: 0.35...4.5, length: 25...66, value: 410,
            power: 0.83, stamina: 92, agility: 0.88, hookModifier: -0.05,
            body: (0.94, 0.7, 0.12), accent: (0.96, 0.22, 0.16)
        ),
        .make(
            "walleye", "Walleye", rarity: .rare,
            preferred: [.deep], available: [.mid, .deep],
            weight: 0.7...10.5, length: 34...91, value: 455,
            power: 0.9, stamina: 98, agility: 0.68, hookModifier: -0.03,
            body: (0.49, 0.57, 0.25), accent: (0.92, 0.84, 0.35)
        ),
        .make(
            "muskie", "Muskie", rarity: .rare,
            preferred: [.deep], available: [.deep],
            weight: 2.5...24, length: 58...137, value: 540,
            power: 1.05, stamina: 112, agility: 0.86, hookModifier: -0.07,
            body: (0.32, 0.46, 0.31), accent: (0.72, 0.77, 0.48)
        ),
        .make(
            "lake-sturgeon", "Lake Sturgeon", rarity: .rare,
            preferred: [.deep], available: [.deep],
            weight: 4...42, length: 70...172, value: 620,
            power: 1.14, stamina: 128, agility: 0.32, hookModifier: -0.08,
            body: (0.32, 0.38, 0.42), accent: (0.72, 0.78, 0.78)
        ),
        .make(
            "redtail-catfish", "Redtail Catfish", rarity: .rare,
            preferred: [.deep], available: [.deep],
            weight: 3...38, length: 60...145, value: 680,
            power: 1.12, stamina: 122, agility: 0.48, hookModifier: -0.08,
            body: (0.2, 0.27, 0.3), accent: (0.91, 0.27, 0.14)
        ),

        .make(
            "arapaima", "Arapaima", rarity: .epic,
            preferred: [.deep], available: [.deep],
            weight: 18...105, length: 120...265, value: 1_180,
            power: 1.32, stamina: 148, agility: 0.52, hookModifier: -0.11,
            body: (0.23, 0.3, 0.32), accent: (0.91, 0.18, 0.2)
        ),
        .make(
            "alligator-gar", "Alligator Gar", rarity: .epic,
            preferred: [.deep], available: [.deep],
            weight: 14...92, length: 110...248, value: 1_260,
            power: 1.38, stamina: 152, agility: 0.64, hookModifier: -0.12,
            body: (0.24, 0.35, 0.24), accent: (0.58, 0.68, 0.42)
        ),
        .make(
            "peacock-bass", "Peacock Bass", rarity: .epic,
            preferred: [.mid, .deep], available: [.mid, .deep],
            weight: 1.5...16, length: 42...103, value: 1_080,
            power: 1.26, stamina: 132, agility: 0.96, hookModifier: -0.13,
            body: (0.82, 0.66, 0.12), accent: (0.16, 0.38, 0.5)
        ),
        .make(
            "giant-snakehead", "Giant Snakehead", rarity: .epic,
            preferred: [.deep], available: [.deep],
            weight: 5...32, length: 66...154, value: 1_340,
            power: 1.43, stamina: 157, agility: 0.83, hookModifier: -0.14,
            body: (0.24, 0.21, 0.18), accent: (0.78, 0.42, 0.18)
        ),

        .make(
            "golden-koi", "Golden Koi", rarity: .legendary,
            preferred: [.deep], available: [.deep],
            weight: 3...18, length: 48...112, value: 2_600,
            power: 1.52, stamina: 174, agility: 0.9, hookModifier: -0.16,
            body: (0.98, 0.75, 0.12), accent: (1, 0.96, 0.58)
        ),
        .make(
            "ancient-sturgeon", "Ancient Sturgeon", rarity: .legendary,
            preferred: [.deep], available: [.deep],
            weight: 35...185, length: 165...345, value: 3_250,
            power: 1.74, stamina: 205, agility: 0.4, hookModifier: -0.18,
            body: (0.24, 0.3, 0.38), accent: (0.53, 0.79, 0.9)
        ),
        .make(
            "midnight-leviathan", "Midnight Leviathan", rarity: .legendary,
            preferred: [.deep], available: [.deep],
            weight: 70...280, length: 220...430, value: 4_200,
            power: 1.92, stamina: 230, agility: 0.72, hookModifier: -0.2,
            body: (0.08, 0.1, 0.2), accent: (0.46, 0.32, 0.94)
        )
    ]

    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func species(id: String) -> FishDefinition? { byID[id] }
}
