import SpriteKit

enum FruitShapeArchetype {
    case lobed
    case round
    case oblong
    case citrus
    case fuzzy
}

enum FruitType: CaseIterable {
    case apple
    case orange
    case watermelon
    case lemon
    case kiwi

    var radius: CGFloat {
        switch self {
        case .apple: 27
        case .orange: 25
        case .watermelon: 34
        case .lemon: 25
        case .kiwi: 24
        }
    }

    var scoreValue: Int {
        switch self {
        case .apple, .orange: 100
        case .lemon: 120
        case .kiwi: 130
        case .watermelon: 180
        }
    }

    var shapeArchetype: FruitShapeArchetype {
        switch self {
        case .apple: .lobed
        case .orange: .round
        case .watermelon: .oblong
        case .lemon: .citrus
        case .kiwi: .fuzzy
        }
    }

    var bodySize: CGSize {
        switch self {
        case .apple:
            CGSize(width: radius * 1.92, height: radius * 1.86)
        case .orange:
            CGSize(width: radius * 1.92, height: radius * 1.92)
        case .watermelon:
            CGSize(width: radius * 1.58, height: radius * 2.02)
        case .lemon:
            CGSize(width: radius * 2.15, height: radius * 1.56)
        case .kiwi:
            CGSize(width: radius * 1.82, height: radius * 2.02)
        }
    }

    var primaryColor: SKColor {
        switch self {
        case .apple:
            SKColor(calibratedRed: 0.92, green: 0.18, blue: 0.2, alpha: 0.96)
        case .orange:
            SKColor(calibratedRed: 1, green: 0.48, blue: 0.08, alpha: 0.96)
        case .watermelon:
            SKColor(calibratedRed: 0.2, green: 0.68, blue: 0.32, alpha: 0.96)
        case .lemon:
            SKColor(calibratedRed: 1, green: 0.85, blue: 0.12, alpha: 0.96)
        case .kiwi:
            SKColor(calibratedRed: 0.49, green: 0.3, blue: 0.16, alpha: 0.96)
        }
    }

    var fleshColor: SKColor {
        switch self {
        case .apple:
            SKColor(calibratedRed: 1, green: 0.86, blue: 0.72, alpha: 1)
        case .orange:
            SKColor(calibratedRed: 1, green: 0.63, blue: 0.15, alpha: 1)
        case .watermelon:
            SKColor(calibratedRed: 0.98, green: 0.25, blue: 0.36, alpha: 1)
        case .lemon:
            SKColor(calibratedRed: 1, green: 0.94, blue: 0.38, alpha: 1)
        case .kiwi:
            SKColor(calibratedRed: 0.48, green: 0.76, blue: 0.2, alpha: 1)
        }
    }

    var accentColor: SKColor {
        switch self {
        case .apple: SKColor(calibratedRed: 0.28, green: 0.62, blue: 0.22, alpha: 1)
        case .orange: SKColor(calibratedRed: 1, green: 0.78, blue: 0.3, alpha: 1)
        case .watermelon: SKColor(calibratedRed: 0.08, green: 0.38, blue: 0.16, alpha: 1)
        case .lemon: SKColor(calibratedRed: 0.92, green: 0.68, blue: 0.04, alpha: 1)
        case .kiwi: SKColor(calibratedRed: 0.18, green: 0.34, blue: 0.1, alpha: 1)
        }
    }

    static func random() -> FruitType {
        allCases.randomElement() ?? .apple
    }
}
