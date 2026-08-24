import CoreGraphics

struct GrappleRopeForce {
    let force: CGVector
    let stretch: CGFloat
    let normalizedTension: CGFloat
}

struct GrappleConstraintResult {
    let position: CGPoint
    let velocity: CGVector
    let wasConstrained: Bool
}

enum GrapplePhysics {
    static func ropeForce(
        playerPosition: CGPoint,
        playerVelocity: CGVector,
        anchor: CGPoint,
        ropeLength: CGFloat
    ) -> GrappleRopeForce {
        let offset = CGVector(
            dx: playerPosition.x - anchor.x,
            dy: playerPosition.y - anchor.y
        )
        let distance = magnitude(of: offset)
        guard distance > 0.001, distance > ropeLength else {
            return GrappleRopeForce(force: .zero, stretch: 0, normalizedTension: 0)
        }

        let direction = CGVector(dx: offset.dx / distance, dy: offset.dy / distance)
        let stretch = distance - ropeLength
        let radialVelocity = dot(playerVelocity, direction)
        let rawForce = (GrappleTuning.ropeStiffness * stretch)
            + (GrappleTuning.ropeDamping * radialVelocity)
        let forceMagnitude = clamp(
            rawForce,
            minimum: 0,
            maximum: GrappleTuning.maximumRopeForce
        )

        return GrappleRopeForce(
            force: CGVector(
                dx: -direction.dx * forceMagnitude,
                dy: -direction.dy * forceMagnitude
            ),
            stretch: stretch,
            normalizedTension: forceMagnitude / GrappleTuning.maximumRopeForce
        )
    }

    static func constrainedToRope(
        playerPosition: CGPoint,
        playerVelocity: CGVector,
        anchor: CGPoint,
        ropeLength: CGFloat
    ) -> GrappleConstraintResult {
        let offset = CGVector(
            dx: playerPosition.x - anchor.x,
            dy: playerPosition.y - anchor.y
        )
        let distance = magnitude(of: offset)
        let maximumDistance = ropeLength * (1 + GrappleTuning.maximumRopeStretchRatio)

        guard distance.isFinite,
              distance > 0.001,
              distance > maximumDistance else {
            return GrappleConstraintResult(
                position: playerPosition,
                velocity: finiteVelocity(playerVelocity),
                wasConstrained: false
            )
        }

        let direction = CGVector(dx: offset.dx / distance, dy: offset.dy / distance)
        let radialVelocity = dot(playerVelocity, direction)
        var velocity = finiteVelocity(playerVelocity)
        if radialVelocity > 0 {
            velocity.dx -= direction.dx * radialVelocity
            velocity.dy -= direction.dy * radialVelocity
        }

        return GrappleConstraintResult(
            position: CGPoint(
                x: anchor.x + (direction.dx * maximumDistance),
                y: anchor.y + (direction.dy * maximumDistance)
            ),
            velocity: velocity,
            wasConstrained: true
        )
    }

    static func cappedVelocity(_ velocity: CGVector) -> CGVector {
        let finite = finiteVelocity(velocity)
        let speed = magnitude(of: finite)
        guard speed > GrappleTuning.maximumPlayerSpeed, speed > 0 else {
            return finite
        }

        let scale = GrappleTuning.maximumPlayerSpeed / speed
        return CGVector(dx: finite.dx * scale, dy: finite.dy * scale)
    }

    static func segmentIntersectsCircle(
        from start: CGPoint,
        to end: CGPoint,
        center: CGPoint,
        radius: CGFloat
    ) -> Bool {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = (dx * dx) + (dy * dy)
        guard lengthSquared > .ulpOfOne else {
            return hypot(center.x - start.x, center.y - start.y) <= radius
        }

        let progress = clamp(
            (((center.x - start.x) * dx) + ((center.y - start.y) * dy)) / lengthSquared,
            minimum: 0,
            maximum: 1
        )
        let nearest = CGPoint(x: start.x + (dx * progress), y: start.y + (dy * progress))
        return hypot(center.x - nearest.x, center.y - nearest.y) <= radius
    }

    static func segmentIntersectsRect(
        from start: CGPoint,
        to end: CGPoint,
        rect: CGRect,
        padding: CGFloat
    ) -> Bool {
        let expanded = rect.insetBy(dx: -padding, dy: -padding)
        if expanded.contains(start) || expanded.contains(end) {
            return true
        }

        let edges = [
            (CGPoint(x: expanded.minX, y: expanded.minY), CGPoint(x: expanded.maxX, y: expanded.minY)),
            (CGPoint(x: expanded.maxX, y: expanded.minY), CGPoint(x: expanded.maxX, y: expanded.maxY)),
            (CGPoint(x: expanded.maxX, y: expanded.maxY), CGPoint(x: expanded.minX, y: expanded.maxY)),
            (CGPoint(x: expanded.minX, y: expanded.maxY), CGPoint(x: expanded.minX, y: expanded.minY))
        ]
        return edges.contains { segmentsIntersect(start, end, $0.0, $0.1) }
    }

    static func magnitude(of vector: CGVector) -> CGFloat {
        hypot(vector.dx, vector.dy)
    }

    static func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        hypot(second.x - first.x, second.y - first.y)
    }

    static func normalizedVector(from start: CGPoint, to end: CGPoint) -> CGVector? {
        let distance = distance(from: start, to: end)
        guard distance > 0.001 else {
            return nil
        }
        return CGVector(dx: (end.x - start.x) / distance, dy: (end.y - start.y) / distance)
    }

    static func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }

    private static func finiteVelocity(_ velocity: CGVector) -> CGVector {
        guard velocity.dx.isFinite, velocity.dy.isFinite else {
            return .zero
        }
        return velocity
    }

    private static func dot(_ lhs: CGVector, _ rhs: CGVector) -> CGFloat {
        (lhs.dx * rhs.dx) + (lhs.dy * rhs.dy)
    }

    private static func segmentsIntersect(
        _ a: CGPoint,
        _ b: CGPoint,
        _ c: CGPoint,
        _ d: CGPoint
    ) -> Bool {
        func orientation(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> CGFloat {
            ((q.y - p.y) * (r.x - q.x)) - ((q.x - p.x) * (r.y - q.y))
        }

        func liesOnSegment(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> Bool {
            point.x >= min(start.x, end.x) - 0.001
                && point.x <= max(start.x, end.x) + 0.001
                && point.y >= min(start.y, end.y) - 0.001
                && point.y <= max(start.y, end.y) + 0.001
        }

        let first = orientation(a, b, c)
        let second = orientation(a, b, d)
        let third = orientation(c, d, a)
        let fourth = orientation(c, d, b)
        let epsilon: CGFloat = 0.001

        if abs(first) <= epsilon, liesOnSegment(c, a, b) { return true }
        if abs(second) <= epsilon, liesOnSegment(d, a, b) { return true }
        if abs(third) <= epsilon, liesOnSegment(a, c, d) { return true }
        if abs(fourth) <= epsilon, liesOnSegment(b, c, d) { return true }

        return (first > 0) != (second > 0)
            && (third > 0) != (fourth > 0)
    }
}
