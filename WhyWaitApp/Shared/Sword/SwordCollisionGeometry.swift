import CoreGraphics
import Foundation

enum SwordHitShape: Equatable {
    case circle(center: CGPoint, radius: CGFloat)
    case capsule(start: CGPoint, end: CGPoint, radius: CGFloat)

    var boundingBox: CGRect {
        switch self {
        case let .circle(center, radius):
            return CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        case let .capsule(start, end, radius):
            return CGRect(
                x: min(start.x, end.x) - radius,
                y: min(start.y, end.y) - radius,
                width: abs(end.x - start.x) + (radius * 2),
                height: abs(end.y - start.y) + (radius * 2)
            )
        }
    }
}

struct SwordHitRegion<RegionID: Hashable>: Equatable {
    let id: RegionID
    let shape: SwordHitShape
}

struct SwordImpact<RegionID: Hashable>: Equatable {
    let region: RegionID
    let point: CGPoint
    let bladeProgress: CGFloat
    let contactVelocity: CGVector
    let impactSpeed: CGFloat
    let edgeAlignment: CGFloat
    let thrustAlignment: CGFloat
    let isTip: Bool
}

final class SwordCollisionDetector<RegionID: Hashable> {
    func contacts(
        previous: SwordTransformSnapshot,
        current: SwordTransformSnapshot,
        regions: [SwordHitRegion<RegionID>]
    ) -> [SwordImpact<RegionID>] {
        guard previous.center.x.isFinite,
              previous.center.y.isFinite,
              current.center.x.isFinite,
              current.center.y.isFinite else {
            return []
        }

        let startTravel = hypot(
            current.bladeStart.x - previous.bladeStart.x,
            current.bladeStart.y - previous.bladeStart.y
        )
        let tipTravel = hypot(
            current.bladeTip.x - previous.bladeTip.x,
            current.bladeTip.y - previous.bladeTip.y
        )
        let angularTravel = abs(shortestAngle(from: previous.angle, to: current.angle))
            * SwordEngineTuning.swordLength * 0.5
        let sampleCount = max(
            1,
            min(48, Int(ceil(max(startTravel, tipTravel, angularTravel) / 11)))
        )

        var results: [SwordImpact<RegionID>] = []
        results.reserveCapacity(regions.count)
        for region in regions {
            var best: (point: CGPoint, progress: CGFloat, time: CGFloat)?
            for index in 0...sampleCount {
                let time = CGFloat(index) / CGFloat(sampleCount)
                let bladeStart = SwordMath.lerp(
                    previous.bladeStart,
                    current.bladeStart,
                    progress: time
                )
                let bladeTip = SwordMath.lerp(
                    previous.bladeTip,
                    current.bladeTip,
                    progress: time
                )
                if let hit = intersectBlade(
                    from: bladeStart,
                    to: bladeTip,
                    halfWidth: SwordEngineTuning.bladeHalfWidth,
                    with: region.shape
                ) {
                    best = (hit.point, hit.progress, time)
                    break
                }
            }

            guard let best else { continue }
            let velocity = current.velocity(at: best.point)
            let speed = SwordMath.magnitude(velocity)
            let velocityDirection = SwordMath.normalized(velocity, fallback: .zero)
            let bladeDirection = current.bladeDirection
            let edgeAlignment = abs(SwordMath.cross(bladeDirection, velocityDirection))
            let thrustAlignment = abs(SwordMath.dot(bladeDirection, velocityDirection))
            results.append(
                SwordImpact(
                    region: region.id,
                    point: best.point,
                    bladeProgress: best.progress,
                    contactVelocity: velocity,
                    impactSpeed: speed.isFinite ? speed : 0,
                    edgeAlignment: SwordMath.clamp(edgeAlignment, minimum: 0, maximum: 1),
                    thrustAlignment: SwordMath.clamp(thrustAlignment, minimum: 0, maximum: 1),
                    isTip: best.progress >= 0.82
                )
            )
        }
        return results
    }

    func overlappingRegions(
        snapshot: SwordTransformSnapshot,
        regions: [SwordHitRegion<RegionID>]
    ) -> Set<RegionID> {
        Set(regions.compactMap { region in
            intersectBlade(
                from: snapshot.bladeStart,
                to: snapshot.bladeTip,
                halfWidth: SwordEngineTuning.bladeHalfWidth,
                with: region.shape
            ) == nil ? nil : region.id
        })
    }

    func handleContacts(
        previous: SwordTransformSnapshot,
        current: SwordTransformSnapshot,
        regions: [SwordHitRegion<RegionID>]
    ) -> Set<RegionID> {
        let previousGripEnd = SwordMath.worldPoint(
            center: previous.center,
            angle: previous.angle,
            localX: SwordEngineTuning.bladeStartLocalX - 3
        )
        let currentGripEnd = SwordMath.worldPoint(
            center: current.center,
            angle: current.angle,
            localX: SwordEngineTuning.bladeStartLocalX - 3
        )
        return Set(regions.compactMap { region in
            let previousHandle = SwordHitShape.capsule(
                start: previous.handlePoint,
                end: previousGripEnd,
                radius: 7
            )
            let currentHandle = SwordHitShape.capsule(
                start: current.handlePoint,
                end: currentGripEnd,
                radius: 7
            )
            let pommelSweep = SwordHitShape.capsule(
                start: previous.handlePoint,
                end: current.handlePoint,
                radius: 7
            )
            let guardSweep = SwordHitShape.capsule(
                start: previousGripEnd,
                end: currentGripEnd,
                radius: 7
            )
            return shapesOverlap(previousHandle, region.shape)
                || shapesOverlap(currentHandle, region.shape)
                || shapesOverlap(pommelSweep, region.shape)
                || shapesOverlap(guardSweep, region.shape)
                ? region.id
                : nil
        })
    }

    private func intersectBlade(
        from start: CGPoint,
        to end: CGPoint,
        halfWidth: CGFloat,
        with shape: SwordHitShape
    ) -> (point: CGPoint, progress: CGFloat)? {
        switch shape {
        case let .circle(center, radius):
            let closest = SwordMath.closestPoint(onSegmentFrom: start, to: end, to: center)
            let distance = hypot(closest.0.x - center.x, closest.0.y - center.y)
            return distance <= radius + halfWidth ? (closest.0, closest.1) : nil
        case let .capsule(capsuleStart, capsuleEnd, radius):
            let closest = SwordMath.distanceFromSegment(
                start,
                end,
                to: capsuleStart,
                capsuleEnd
            )
            return closest.distance <= radius + halfWidth
                ? (closest.point, closest.firstProgress)
                : nil
        }
    }

    private func shapesOverlap(_ first: SwordHitShape, _ second: SwordHitShape) -> Bool {
        func capsule(for shape: SwordHitShape) -> (CGPoint, CGPoint, CGFloat) {
            switch shape {
            case let .circle(center, radius): return (center, center, radius)
            case let .capsule(start, end, radius): return (start, end, radius)
            }
        }
        let firstCapsule = capsule(for: first)
        let secondCapsule = capsule(for: second)
        return SwordMath.distanceFromSegment(
            firstCapsule.0,
            firstCapsule.1,
            to: secondCapsule.0,
            secondCapsule.1
        ).distance <= firstCapsule.2 + secondCapsule.2
    }

    private func shortestAngle(from start: CGFloat, to end: CGFloat) -> CGFloat {
        var delta = end - start
        while delta > .pi { delta -= .pi * 2 }
        while delta < -.pi { delta += .pi * 2 }
        return delta
    }
}

final class SwordContactGate<RegionID: Hashable> {
    private var currentlyOverlapping: Set<RegionID> = []
    private var lastHitTime: [RegionID: TimeInterval] = [:]

    func canRegister(
        _ contact: SwordImpact<RegionID>,
        at time: TimeInterval,
        swingID: Int?
    ) -> Bool {
        guard swingID != nil,
              !currentlyOverlapping.contains(contact.region),
              time - (lastHitTime[contact.region] ?? -.infinity) >= SwordEngineTuning.contactCooldown else {
            return false
        }
        lastHitTime[contact.region] = time
        return true
    }

    func updateOverlaps(_ regions: Set<RegionID>) {
        currentlyOverlapping = regions
    }

    func reset() {
        currentlyOverlapping.removeAll(keepingCapacity: true)
        lastHitTime.removeAll(keepingCapacity: true)
    }
}
