import CoreGraphics
import Foundation

struct ZombieDamageResult: Equatable {
    let damage: Int
    let region: ZombieBodyRegion
    let style: ZombieStrikeStyle?
    let impactDirection: CGVector
    let knockbackVelocity: CGVector
    let impactSpeed: CGFloat
    let edgeAlignment: CGFloat
    let causesStagger: Bool
    let staggerDuration: TimeInterval
    let wasArmorReduced: Bool
}

enum ZombieDamageCalculator {
    static func calculate(
        impact: SwordImpact<ZombieHitRegionID>,
        zombieType: ZombieType,
        zombieMass: CGFloat
    ) -> ZombieDamageResult {
        let speed = impact.impactSpeed.isFinite ? max(0, impact.impactSpeed) : 0
        let direction = SwordMath.normalized(impact.contactVelocity, fallback: .zero)
        guard speed >= ZombieSwordTuning.minimumDamagingSpeed else {
            return ZombieDamageResult(
                damage: 0,
                region: impact.region.bodyRegion,
                style: nil,
                impactDirection: direction,
                knockbackVelocity: .zero,
                impactSpeed: speed,
                edgeAlignment: 0,
                causesStagger: false,
                staggerDuration: 0,
                wasArmorReduced: false
            )
        }

        let speedProgress = SwordMath.clamp(
            (speed - ZombieSwordTuning.minimumDamagingSpeed)
                / (ZombieSwordTuning.referenceImpactSpeed - ZombieSwordTuning.minimumDamagingSpeed),
            minimum: 0,
            maximum: 1
        )
        let edge = impact.edgeAlignment.isFinite
            ? SwordMath.clamp(impact.edgeAlignment, minimum: 0, maximum: 1)
            : 0
        let thrust = impact.thrustAlignment.isFinite
            ? SwordMath.clamp(impact.thrustAlignment, minimum: 0, maximum: 1)
            : 0
        let cuttingMultiplier: CGFloat = impact.isTip && thrust > 0.68
            ? 0.68 + (thrust * 0.38)
            : 0.3 + (edge * 0.92)

        let regionMultiplier: CGFloat
        switch impact.region.bodyRegion {
        case .head: regionMultiplier = ZombieSwordTuning.headModifier
        case .torso: regionMultiplier = ZombieSwordTuning.torsoModifier
        case .leftArm, .rightArm: regionMultiplier = ZombieSwordTuning.armModifier
        }
        var armorMultiplier: CGFloat = 1
        let armorReduced = zombieType == .armored && impact.region.bodyRegion == .torso
        if armorReduced {
            armorMultiplier = edge >= 0.82 && speed >= 1_250
                ? ZombieSwordTuning.alignedArmorModifier
                : ZombieSwordTuning.armoredTorsoModifier
        }

        var rawDamage = (5 + (pow(speedProgress, 0.7) * 88))
            * cuttingMultiplier * regionMultiplier * armorMultiplier
        if impact.isTip, thrust > 0.68 { rawDamage *= 1.08 }
        let damage = min(ZombieSwordTuning.maximumHitDamage, max(0, Int(rawDamage.rounded())))

        let style: ZombieStrikeStyle?
        if armorReduced && damage < 28 {
            style = .armor
        } else if impact.region.bodyRegion == .head && damage >= 35 {
            style = .headshot
        } else if speed >= 1_480 && edge >= 0.88 && damage >= 48 {
            style = .perfect
        } else if damage >= 54 {
            style = .heavy
        } else if edge >= 0.68 && damage >= 14 {
            style = .slash
        } else {
            style = nil
        }

        let mass = max(0.5, zombieMass)
        let knockbackMagnitude = min(
            ZombieSwordTuning.maximumKnockbackSpeed,
            (CGFloat(damage) * 4.2 + speed * 0.045) / mass
        )
        let causesStagger = damage >= ZombieSwordTuning.staggerDamageThreshold
            || impact.region.bodyRegion == .head
        let staggerDuration = min(0.62, 0.16 + (Double(damage) / 180))
        return ZombieDamageResult(
            damage: damage,
            region: impact.region.bodyRegion,
            style: style,
            impactDirection: direction,
            knockbackVelocity: SwordMath.scale(direction, by: knockbackMagnitude),
            impactSpeed: speed,
            edgeAlignment: edge,
            causesStagger: causesStagger,
            staggerDuration: causesStagger ? staggerDuration : 0,
            wasArmorReduced: armorReduced
        )
    }
}
