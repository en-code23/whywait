import CoreGraphics
import Foundation

struct SwordDamageResult: Equatable {
    let damage: Int
    let style: SwordStrikeStyle?
    let region: DummyHitRegionID
    let impactDirection: CGVector
    let speed: CGFloat
    let edgeAlignment: CGFloat
}

enum SwordDamageCalculator {
    static func calculate(contact: SwordContact) -> SwordDamageResult {
        let speed = contact.impactSpeed.isFinite ? max(0, contact.impactSpeed) : 0
        guard speed >= SwordDummyTuning.minimumDamagingSpeed else {
            return SwordDamageResult(
                damage: 0,
                style: nil,
                region: contact.region,
                impactDirection: .zero,
                speed: speed,
                edgeAlignment: 0
            )
        }

        let speedProgress = SwordMath.clamp(
            (speed - SwordDummyTuning.minimumDamagingSpeed)
                / (SwordDummyTuning.referenceImpactSpeed - SwordDummyTuning.minimumDamagingSpeed),
            minimum: 0,
            maximum: 1
        )
        let speedDamage = 4 + (pow(speedProgress, 0.72) * 78)
        let edgeAlignment = contact.edgeAlignment.isFinite
            ? SwordMath.clamp(contact.edgeAlignment, minimum: 0, maximum: 1)
            : 0
        let thrustAlignment = contact.thrustAlignment.isFinite
            ? SwordMath.clamp(contact.thrustAlignment, minimum: 0, maximum: 1)
            : 0

        let cuttingMultiplier: CGFloat
        if contact.isTip, thrustAlignment > 0.62 {
            cuttingMultiplier = 0.58 + (thrustAlignment * 0.42)
        } else {
            cuttingMultiplier = SwordDummyTuning.minimumEdgeMultiplier
                + ((SwordDummyTuning.maximumEdgeMultiplier - SwordDummyTuning.minimumEdgeMultiplier)
                    * edgeAlignment)
        }

        let regionMultiplier: CGFloat
        switch contact.region {
        case .head:
            regionMultiplier = SwordDummyTuning.headModifier
        case .torso:
            regionMultiplier = SwordDummyTuning.torsoModifier
        case .leftArm, .rightArm:
            regionMultiplier = SwordDummyTuning.armModifier
        }

        var rawDamage = speedDamage * cuttingMultiplier * regionMultiplier
        if contact.isTip {
            rawDamage *= thrustAlignment > 0.62
                ? SwordDummyTuning.thrustModifier
                : SwordDummyTuning.tipModifier
        }
        let damage = min(
            SwordDummyTuning.maximumHitDamage,
            max(0, Int(rawDamage.rounded()))
        )

        let style: SwordStrikeStyle?
        if speed >= SwordDummyTuning.perfectSpeed,
           edgeAlignment >= SwordDummyTuning.perfectAlignment,
           damage >= 50 {
            style = .perfect
        } else if contact.isTip, thrustAlignment >= 0.72, speed >= 1_100 {
            style = .thrust
        } else if contact.isTip, speed >= 1_250 {
            style = .precision
        } else if damage >= SwordDummyTuning.challengeHeavyDamage {
            style = .heavy
        } else if edgeAlignment >= 0.66, damage >= 12 {
            style = .slash
        } else {
            style = nil
        }

        return SwordDamageResult(
            damage: damage,
            style: style,
            region: contact.region,
            impactDirection: SwordMath.normalized(contact.contactVelocity, fallback: .zero),
            speed: speed,
            edgeAlignment: edgeAlignment
        )
    }
}
