import CoreGraphics
import Foundation

enum FishingFightOutcome: Equatable {
    case none
    case landed
    case lineBroke
    case hookLost
}

struct FishingFightSnapshot {
    let fishPosition: CGPoint
    let fishVelocity: CGVector
    let lineRemaining: CGFloat
    let progress: CGFloat
    let tension: CGFloat
    let tensionLevel: FishingTensionVisualLevel
    let staminaRatio: CGFloat
    let aiState: FishAIState
    let controlAlignment: CGFloat
    let outcome: FishingFightOutcome
}

final class FishingFightController {
    private let random: FishingRandomSource
    private let tensionSystem = FishingTensionSystem()

    private var specimen: FishSpecimen?
    private var equipment: FishingEquipmentStats?
    private var fishAI: FishAI?
    private var fishPosition = CGPoint.zero
    private var fishVelocity = CGVector.zero
    private var initialLineDistance: CGFloat = 1
    private var lineRemaining: CGFloat = 1
    private var maximumStamina: CGFloat = 1
    private var stamina: CGFloat = 1
    private var elapsed: TimeInterval = 0

    var isActive: Bool { specimen != nil }
    var fightDuration: TimeInterval { elapsed }

    init(random: FishingRandomSource = SystemFishingRandomSource()) {
        self.random = random
    }

    func start(
        specimen: FishSpecimen,
        at position: CGPoint,
        initialDistance: CGFloat,
        equipment: FishingEquipmentStats
    ) {
        self.specimen = specimen
        self.equipment = equipment
        fishAI = FishAI(definition: specimen.definition, random: random)
        fishPosition = position
        fishVelocity = .zero
        initialLineDistance = max(FishingTuning.catchDistance + 24, initialDistance)
        lineRemaining = self.initialLineDistance
        maximumStamina = CGFloat(specimen.definition.stamina * specimen.sizeFightMultiplier)
        stamina = maximumStamina
        elapsed = 0
        tensionSystem.reset(equipment: equipment, random: random)
    }

    func update(
        deltaTime: TimeInterval,
        rodPosition: CGPoint,
        cursorPosition: CGPoint,
        isReeling: Bool,
        bounds: CGRect
    ) -> FishingFightSnapshot? {
        guard let specimen, let equipment, let fishAI else { return nil }
        let delta = min(
            FishingTuning.maximumFightDeltaTime,
            max(FishingTuning.minimumFightDeltaTime, deltaTime)
        )
        elapsed += delta

        let staminaRatio = CGFloat.fishingClamp(stamina / max(1, maximumStamina), 0...1)
        let pull = fishAI.update(
            deltaTime: delta,
            staminaRatio: staminaRatio,
            fishPosition: fishPosition,
            rodPosition: rodPosition
        )
        let pullDirection = FishingGeometry.normalized(pull.direction)
        let rodDirection = FishingGeometry.normalized(
            FishingGeometry.vector(from: fishPosition, to: cursorPosition),
            fallback: FishingGeometry.scaled(pullDirection, by: -1)
        )
        let counterDirection = FishingGeometry.scaled(pullDirection, by: -1)
        let control = CGFloat.fishingClamp(
            (FishingGeometry.dot(rodDirection, counterDirection) + 1) / 2,
            0...1
        )

        let fightPower = CGFloat(specimen.definition.fightPower * specimen.sizeFightMultiplier)
        let pullAcceleration = (105 + (fightPower * 132)) * pull.intensity
        fishVelocity = FishingGeometry.adding(
            fishVelocity,
            FishingGeometry.scaled(pullDirection, by: pullAcceleration * CGFloat(delta))
        )
        if isReeling {
            let towardRod = FishingGeometry.normalized(
                FishingGeometry.vector(from: fishPosition, to: rodPosition)
            )
            fishVelocity = FishingGeometry.adding(
                fishVelocity,
                FishingGeometry.scaled(
                    towardRod,
                    by: (54 + (equipment.reelRate * 0.28))
                        * (0.48 + (control * 0.72))
                        * CGFloat(delta)
                )
            )
        }
        let velocityDamping = max(0, 1 - (CGFloat(delta) * 1.42))
        fishVelocity = FishingGeometry.scaled(fishVelocity, by: velocityDamping)
        fishVelocity = cappedVelocity(fishVelocity)
        fishPosition = FishingGeometry.point(
            fishPosition,
            adding: FishingGeometry.scaled(fishVelocity, by: CGFloat(delta))
        )
        constrainFish(to: bounds.insetBy(dx: 28, dy: 34))

        let pullResistance = min(
            0.84,
            fightPower * pull.intensity * (0.23 + (staminaRatio * 0.24))
        )
        let reelDistance = isReeling
            ? equipment.reelRate
                * (0.4 + (control * 0.72))
                * max(0.12, 1 - pullResistance)
                * CGFloat(delta)
            : 0
        var pullOut = FishingTuning.fishPullOutRate
            * fightPower
            * pull.intensity
            * (0.24 + (staminaRatio * 0.76))
            / max(1, equipment.runRecovery)
            * CGFloat(delta)
        if pull.state == .calm || pull.state == .tired {
            pullOut *= 0.22
        } else if pull.state == .burst {
            pullOut *= 1.18
        }
        lineRemaining += pullOut - reelDistance
        lineRemaining = CGFloat.fishingClamp(
            lineRemaining,
            (FishingTuning.catchDistance - 2)...(initialLineDistance
                * FishingTuning.maximumLineDistanceMultiplier)
        )

        let staminaDrain = FishingTuning.staminaNaturalDrain
            + (isReeling
                ? FishingTuning.staminaDrainWhileReeling * (0.42 + (control * 0.8))
                : 0)
        stamina = max(0, stamina - (staminaDrain * CGFloat(delta)))

        let normalizedPower = min(1.12, fightPower / 1.75)
        let distanceRatio = lineRemaining / max(1, initialLineDistance)
        var targetTension: CGFloat = 0.11
            + (pull.intensity * normalizedPower * FishingTuning.tensionPullGain)
            + (distanceRatio * FishingTuning.tensionDistanceGain)
            - (control * FishingTuning.tensionControlRelief)
        if isReeling {
            targetTension += FishingTuning.tensionReelGain
        } else {
            targetTension -= FishingTuning.tensionRestRelief
        }
        if pull.state == .burst { targetTension += 0.16 }

        let tensionOutcome = tensionSystem.update(
            targetTension: targetTension,
            fishIsActivelyPulling: pull.state != .calm && pull.state != .tired,
            isReeling: isReeling,
            deltaTime: delta,
            equipment: equipment
        )
        let outcome: FishingFightOutcome
        switch tensionOutcome {
        case .lineBroke: outcome = .lineBroke
        case .hookLost: outcome = .hookLost
        case .none:
            outcome = lineRemaining <= FishingTuning.catchDistance ? .landed : .none
        }

        return FishingFightSnapshot(
            fishPosition: fishPosition,
            fishVelocity: fishVelocity,
            lineRemaining: lineRemaining,
            progress: CGFloat.fishingClamp(
                (initialLineDistance - lineRemaining)
                    / max(1, initialLineDistance - FishingTuning.catchDistance),
                0...1
            ),
            tension: tensionSystem.tension,
            tensionLevel: tensionSystem.visualLevel,
            staminaRatio: CGFloat.fishingClamp(stamina / max(1, maximumStamina), 0...1),
            aiState: pull.state,
            controlAlignment: control,
            outcome: outcome
        )
    }

    func cancel() {
        specimen = nil
        equipment = nil
        fishAI = nil
        fishPosition = .zero
        fishVelocity = .zero
        initialLineDistance = 1
        lineRemaining = 1
        maximumStamina = 1
        stamina = 1
        elapsed = 0
    }

    private func cappedVelocity(_ velocity: CGVector) -> CGVector {
        guard FishingGeometry.isFinite(velocity) else { return .zero }
        let speed = FishingGeometry.length(velocity)
        guard speed > FishingTuning.fishVisualMaximumSpeed else { return velocity }
        return FishingGeometry.scaled(
            FishingGeometry.normalized(velocity),
            by: FishingTuning.fishVisualMaximumSpeed
        )
    }

    private func constrainFish(to bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        if fishPosition.x < bounds.minX || fishPosition.x > bounds.maxX {
            fishPosition.x = min(bounds.maxX, max(bounds.minX, fishPosition.x))
            fishVelocity.dx *= -0.58
        }
        if fishPosition.y < bounds.minY || fishPosition.y > bounds.maxY {
            fishPosition.y = min(bounds.maxY, max(bounds.minY, fishPosition.y))
            fishVelocity.dy *= -0.58
        }
        if !FishingGeometry.isFinite(fishPosition) || !FishingGeometry.isFinite(fishVelocity) {
            fishPosition = CGPoint(x: bounds.midX, y: bounds.midY)
            fishVelocity = .zero
        }
    }
}

