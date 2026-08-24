import CoreGraphics
import Foundation

enum ZombieSteering {
    static func separation(for zombie: Zombie, among zombies: [Zombie]) -> CGVector {
        var result = CGVector.zero
        var neighbors = 0
        for other in zombies where other !== zombie && other.isAlive {
            let away = SwordMath.vector(from: other.position, to: zombie.position)
            let distance = SwordMath.magnitude(away)
            let desiredSpacing = min(
                ZombieSwordTuning.separationRadius,
                zombie.collisionRadius + other.collisionRadius + 14
            )
            guard distance > 0.001, distance < desiredSpacing else { continue }
            let strength = (1 - (distance / desiredSpacing)) * ZombieSwordTuning.separationStrength
            result = SwordMath.add(
                result,
                SwordMath.scale(SwordMath.normalized(away), by: strength)
            )
            neighbors += 1
        }
        guard neighbors > 0 else { return .zero }
        return SwordMath.clampedMagnitude(
            SwordMath.scale(result, by: 1 / CGFloat(neighbors)),
            maximum: ZombieSwordTuning.separationStrength
        )
    }
}
