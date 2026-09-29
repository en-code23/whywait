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
    private var cursorSample: (CGPoint, TimeInterval)?
    private var cursorVelocity = CGVector.zero
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
        cursorSample = (cursorPosition, timestamp)
        cursorVelocity = .zero
        return true
    }

    func updateCursor(_ position: CGPoint, timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard FishingGeometry.isFinite(position), charge != nil else { return }
        if let (previous, time) = cursorSample {
            let delta = timestamp - time
            let vector = FishingGeometry.vector(from: previous, to: position)
            if delta >= 0.001 && delta < 0.15 && FishingGeometry.length(vector) < 250 {
                let measured = FishingGeometry.scaled(vector, by: 1 / CGFloat(delta))
                let magnitude = FishingGeometry.length(measured)
                let safe = FishingGeometry.scaled(measured, by: min(1, 1800 / max(1, magnitude)))
                cursorVelocity = FishingGeometry.adding(FishingGeometry.scaled(cursorVelocity, by: 0.5), FishingGeometry.scaled(safe, by: 0.5))
            } else { cursorVelocity = .zero }
        }
        cursorSample = (position, timestamp)
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
        equipment: FishingEquipmentStats,
        releasePosition: CGPoint? = nil
    ) -> FishingCastLaunch? {
        guard let charge, sceneSize.width > 0, sceneSize.height > 0 else { return nil }
        self.charge = nil
        let origin = releasePosition ?? charge.rodPosition

        let rawPower = chargePowerValue(charge: charge, timestamp: timestamp)
        let curvedPower = sqrt(max(0, rawPower))
        let power = max(FishingTuning.minimumCastPower, curvedPower)

        var direction = FishingGeometry.normalized(
            FishingGeometry.vector(from: origin, to: charge.cursorPosition)
        )
        if let (_, sampleTime) = cursorSample, timestamp - sampleTime < 0.12 {
            direction = FishingGeometry.normalized(FishingGeometry.adding(direction,
                FishingGeometry.scaled(cursorVelocity, by: 0.0001)))
        }
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
            origin,
            adding: FishingGeometry.scaled(direction, by: distance)
        )
        let safeBounds = CGRect(origin: .zero, size: sceneSize).insetBy(
            dx: FishingTuning.waterInset,
            dy: FishingTuning.waterInset
        )
        let target = FishingGeometry.clamped(intendedTarget, to: safeBounds)
        let actualDistance = FishingGeometry.distance(from: origin, to: target)
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
            start: origin,
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
        cursorSample = nil
        cursorVelocity = .zero
    }

    private func chargePowerValue(charge: Charge, timestamp: TimeInterval) -> CGFloat {
        guard timestamp.isFinite else { return FishingTuning.minimumCastPower }
        let duration = max(0, timestamp - charge.beganAt)
        return min(1, CGFloat(duration / FishingTuning.fullChargeDuration))
    }
}
