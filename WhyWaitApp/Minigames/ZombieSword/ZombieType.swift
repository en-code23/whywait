import AppKit
import CoreGraphics

enum ZombieType: String, CaseIterable {
    case walker
    case runner
    case tank
    case shambler
    case armored

    var stats: ZombieStats {
        switch self {
        case .walker:
            return ZombieStats(
                health: 100, speed: 85, radius: 23, mass: 1,
                attackDamage: 10, attackCooldown: 1.25,
                staggerResistance: 0.18, scoreValue: 100
            )
        case .runner:
            return ZombieStats(
                health: 65, speed: 140, radius: 18, mass: 0.72,
                attackDamage: 8, attackCooldown: 1.02,
                staggerResistance: 0.05, scoreValue: 120
            )
        case .tank:
            return ZombieStats(
                health: 260, speed: 55, radius: 32, mass: 2.65,
                attackDamage: 18, attackCooldown: 1.55,
                staggerResistance: 0.7, scoreValue: 250
            )
        case .shambler:
            return ZombieStats(
                health: 120, speed: 88, radius: 24, mass: 1.12,
                attackDamage: 11, attackCooldown: 1.32,
                staggerResistance: 0.28, scoreValue: 130
            )
        case .armored:
            return ZombieStats(
                health: 150, speed: 70, radius: 26, mass: 1.55,
                attackDamage: 14, attackCooldown: 1.42,
                staggerResistance: 0.46, scoreValue: 180
            )
        }
    }

    var bodyColor: NSColor {
        switch self {
        case .walker: return NSColor(calibratedRed: 0.38, green: 0.66, blue: 0.39, alpha: 0.95)
        case .runner: return NSColor(calibratedRed: 0.56, green: 0.8, blue: 0.38, alpha: 0.95)
        case .tank: return NSColor(calibratedRed: 0.31, green: 0.48, blue: 0.28, alpha: 0.98)
        case .shambler: return NSColor(calibratedRed: 0.48, green: 0.59, blue: 0.3, alpha: 0.96)
        case .armored: return NSColor(calibratedRed: 0.34, green: 0.55, blue: 0.45, alpha: 0.98)
        }
    }
}

struct ZombieStats: Equatable {
    let health: Int
    let speed: CGFloat
    let radius: CGFloat
    let mass: CGFloat
    let attackDamage: Int
    let attackCooldown: TimeInterval
    let staggerResistance: CGFloat
    let scoreValue: Int

    func scaled(forWave wave: Int) -> ZombieStats {
        let healthScale = 1 + min(0.65, CGFloat(max(0, wave - 1)) * 0.035)
        let speedScale = 1 + min(0.4, CGFloat(max(0, wave - 1)) * 0.018)
        let cooldownScale = max(0.78, 1 - (Double(max(0, wave - 1)) * 0.008))
        return ZombieStats(
            health: max(1, Int(CGFloat(health) * healthScale)),
            speed: min(175, speed * speedScale),
            radius: radius,
            mass: mass,
            attackDamage: min(24, attackDamage + ((wave - 1) / 7)),
            attackCooldown: attackCooldown * cooldownScale,
            staggerResistance: staggerResistance,
            scoreValue: scoreValue
        )
    }
}
