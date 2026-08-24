import CoreGraphics
import Foundation

struct FishingCastLaunch: Equatable {
    let start: CGPoint
    let target: CGPoint
    let power: CGFloat
    let zone: FishingZone
    let duration: TimeInterval
    let arcHeight: CGFloat
}

struct FishingCastFlightSnapshot {
    let position: CGPoint
    let progress: CGFloat
    let didLand: Bool
}

final class FishingCastController {
    private struct Charge {
        let rodPosition: CGPoint
        let beganAt: TimeInterval
        var cursorPosition: CGPoint
    }

    private var charge: Charge?
    private var launch: FishingCastLaunch?
    private var flightElapsed: TimeInterval = 0
    private let random: FishingRandomSource

    var isCharging: Bool { charge != nil }
    var isFlying: Bool { launch != nil }

    init(random: FishingRandomSource = SystemFishingRandomSource()) {
        self.random = random
    }

    func beginCharging(
        rodPosition: CGPoint,
        cursorPosition: CGPoint,
        timestamp: TimeInterval
    ) -> Bool {
        guard charge == nil, launch == nil, timestamp.isFinite else { return false }
        charge = Charge(
            rodPosition: rodPosition,
            beganAt: timestamp,
            cursorPosition: cursorPosition
        )
        return true
    }

    func updateCursor(_ position: CGPoint) {
        guard FishingGeometry.isFinite(position), charge != nil else { return }
        charge?.cursorPosition = position
    }

    func chargePower(at timestamp: TimeInterval) -> CGFloat {
        guard let charge, timestamp.isFinite else { return 0 }
        let duration = max(0, timestamp - charge.beganAt)
        return min(1, CGFloat(duration / FishingTuning.fullChargeDuration))
    }

    func release(
        timestamp: TimeInterval,
        sceneSize: CGSize,
        worldMaximumDistance: CGFloat,
        equipment: FishingEquipmentStats
    ) -> FishingCastLaunch? {
        guard let charge, sceneSize.width > 0, sceneSize.height > 0 else { return nil }
        self.charge = nil

        let rawPower = chargePowerValue(charge: charge, timestamp: timestamp)
        let curvedPower = sqrt(max(0, rawPower))
        let power = max(FishingTuning.minimumCastPower, curvedPower)

        var direction = FishingGeometry.normalized(
            FishingGeometry.vector(from: charge.rodPosition, to: charge.cursorPosition)
        )
        direction.dy = max(FishingTuning.minimumCastUpwardComponent, direction.dy)
        direction = FishingGeometry.normalized(direction)
        let controlError = max(0, 1 - equipment.castControl) * 0.23
        if controlError > 0 {
            let angle = CGFloat(random.value(in: -Double(controlError)...Double(controlError)))
            let cosine = cos(angle)
            let sine = sin(angle)
            direction = FishingGeometry.normalized(
                CGVector(
                    dx: (direction.dx * cosine) - (direction.dy * sine),
                    dy: (direction.dx * sine) + (direction.dy * cosine)
                )
            )
        }

        let maximum = max(FishingTuning.minimumCastDistance, equipment.maximumCastDistance)
        let distance = FishingTuning.minimumCastDistance
            + ((maximum - FishingTuning.minimumCastDistance) * power)
        let intendedTarget = FishingGeometry.point(
            charge.rodPosition,
            adding: FishingGeometry.scaled(direction, by: distance)
        )
        let safeBounds = CGRect(origin: .zero, size: sceneSize).insetBy(
            dx: FishingTuning.waterInset,
            dy: FishingTuning.waterInset
        )
        let target = FishingGeometry.clamped(intendedTarget, to: safeBounds)
        let actualDistance = FishingGeometry.distance(from: charge.rodPosition, to: target)
        let normalizedDistance = min(1, actualDistance / max(1, worldMaximumDistance))
        let duration = FishingTuning.bobberFlightDurationRange.lowerBound
            + ((FishingTuning.bobberFlightDurationRange.upperBound
                - FishingTuning.bobberFlightDurationRange.lowerBound)
                * TimeInterval(normalizedDistance))
        let arcHeight = FishingTuning.bobberArcHeightRange.lowerBound
            + ((FishingTuning.bobberArcHeightRange.upperBound
                - FishingTuning.bobberArcHeightRange.lowerBound)
                * normalizedDistance)
        let cast = FishingCastLaunch(
            start: charge.rodPosition,
            target: target,
            power: power,
            zone: FishingZone.zone(
                for: Double(actualDistance),
                worldMaximumDistance: Double(max(1, worldMaximumDistance))
            ),
            duration: duration,
            arcHeight: arcHeight
        )
        launch = cast
        flightElapsed = 0
        return cast
    }

    func updateFlight(deltaTime: TimeInterval) -> FishingCastFlightSnapshot? {
        guard let launch else { return nil }
        let delta = min(
            FishingTuning.maximumFightDeltaTime,
            max(0, deltaTime)
        )
        flightElapsed += delta
        let fraction = min(1, max(0, flightElapsed / max(0.001, launch.duration)))
        let progress = CGFloat(fraction)
        let linear = CGPoint(
            x: launch.start.x + ((launch.target.x - launch.start.x) * progress),
            y: launch.start.y + ((launch.target.y - launch.start.y) * progress)
        )
        let arc = 4 * launch.arcHeight * progress * (1 - progress)
        let snapshot = FishingCastFlightSnapshot(
            position: CGPoint(x: linear.x, y: linear.y + arc),
            progress: progress,
            didLand: fraction >= 1
        )
        if snapshot.didLand {
            self.launch = nil
            flightElapsed = 0
        }
        return snapshot
    }

    func cancel() {
        charge = nil
        launch = nil
        flightElapsed = 0
    }

    private func chargePowerValue(charge: Charge, timestamp: TimeInterval) -> CGFloat {
        guard timestamp.isFinite else { return FishingTuning.minimumCastPower }
        let duration = max(0, timestamp - charge.beganAt)
        return min(1, CGFloat(duration / FishingTuning.fullChargeDuration))
    }
}
