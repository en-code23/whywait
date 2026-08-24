import CoreGraphics
import Foundation

enum SwordMath {
    static func vector(from start: CGPoint, to end: CGPoint) -> CGVector {
        CGVector(dx: end.x - start.x, dy: end.y - start.y)
    }

    static func point(_ point: CGPoint, adding vector: CGVector) -> CGPoint {
        CGPoint(x: point.x + vector.dx, y: point.y + vector.dy)
    }

    static func add(_ lhs: CGVector, _ rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
    }

    static func subtract(_ lhs: CGVector, _ rhs: CGVector) -> CGVector {
        CGVector(dx: lhs.dx - rhs.dx, dy: lhs.dy - rhs.dy)
    }

    static func scale(_ vector: CGVector, by scalar: CGFloat) -> CGVector {
        CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
    }

    static func magnitude(_ vector: CGVector) -> CGFloat {
        hypot(vector.dx, vector.dy)
    }

    static func normalized(
        _ vector: CGVector,
        fallback: CGVector = CGVector(dx: 1, dy: 0)
    ) -> CGVector {
        let length = magnitude(vector)
        guard length.isFinite, length > 0.000_001 else { return fallback }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    static func dot(_ lhs: CGVector, _ rhs: CGVector) -> CGFloat {
        (lhs.dx * rhs.dx) + (lhs.dy * rhs.dy)
    }

    static func cross(_ lhs: CGVector, _ rhs: CGVector) -> CGFloat {
        (lhs.dx * rhs.dy) - (lhs.dy * rhs.dx)
    }

    static func rotated(_ vector: CGVector, by angle: CGFloat) -> CGVector {
        let cosine = cos(angle)
        let sine = sin(angle)
        return CGVector(
            dx: (vector.dx * cosine) - (vector.dy * sine),
            dy: (vector.dx * sine) + (vector.dy * cosine)
        )
    }

    static func worldPoint(center: CGPoint, angle: CGFloat, localX: CGFloat, localY: CGFloat = 0) -> CGPoint {
        point(center, adding: rotated(CGVector(dx: localX, dy: localY), by: angle))
    }

    static func clampedMagnitude(_ vector: CGVector, maximum: CGFloat) -> CGVector {
        guard isFinite(vector) else { return .zero }
        let length = magnitude(vector)
        guard length > maximum, length > 0 else { return vector }
        return scale(vector, by: maximum / length)
    }

    static func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }

    static func lerp(_ start: CGPoint, _ end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + ((end.x - start.x) * progress),
            y: start.y + ((end.y - start.y) * progress)
        )
    }

    static func isFinite(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite
    }

    static func isFinite(_ vector: CGVector) -> Bool {
        vector.dx.isFinite && vector.dy.isFinite
    }

    static func closestPoint(onSegmentFrom start: CGPoint, to end: CGPoint, to point: CGPoint) -> (CGPoint, CGFloat) {
        let segment = vector(from: start, to: end)
        let lengthSquared = dot(segment, segment)
        guard lengthSquared > 0.000_001 else { return (start, 0) }
        let progress = clamp(
            dot(vector(from: start, to: point), segment) / lengthSquared,
            minimum: 0,
            maximum: 1
        )
        return (lerp(start, end, progress: progress), progress)
    }

    static func distanceFromSegment(
        _ firstStart: CGPoint,
        _ firstEnd: CGPoint,
        to secondStart: CGPoint,
        _ secondEnd: CGPoint
    ) -> (distance: CGFloat, firstProgress: CGFloat, point: CGPoint) {
        // A bounded closest-points solve for two 2D segments.
        let u = vector(from: firstStart, to: firstEnd)
        let v = vector(from: secondStart, to: secondEnd)
        let w = vector(from: secondStart, to: firstStart)
        let a = dot(u, u)
        let b = dot(u, v)
        let c = dot(v, v)
        let d = dot(u, w)
        let e = dot(v, w)
        let denominator = (a * c) - (b * b)

        var firstProgress: CGFloat = 0
        var secondProgress: CGFloat = 0
        if a <= 0.000_001, c <= 0.000_001 {
            return (hypot(firstStart.x - secondStart.x, firstStart.y - secondStart.y), 0, firstStart)
        } else if a <= 0.000_001 {
            secondProgress = clamp(e / c, minimum: 0, maximum: 1)
        } else if c <= 0.000_001 {
            firstProgress = clamp(-d / a, minimum: 0, maximum: 1)
        } else {
            firstProgress = denominator > 0.000_001
                ? clamp(((b * e) - (c * d)) / denominator, minimum: 0, maximum: 1)
                : 0
            secondProgress = clamp(((b * firstProgress) + e) / c, minimum: 0, maximum: 1)
            firstProgress = clamp(((b * secondProgress) - d) / a, minimum: 0, maximum: 1)
        }

        let firstPoint = lerp(firstStart, firstEnd, progress: firstProgress)
        let secondPoint = lerp(secondStart, secondEnd, progress: secondProgress)
        return (
            hypot(firstPoint.x - secondPoint.x, firstPoint.y - secondPoint.y),
            firstProgress,
            firstPoint
        )
    }
}

struct SwordTransformSnapshot: Equatable {
    var center: CGPoint
    var angle: CGFloat
    var linearVelocity: CGVector
    var angularVelocity: CGFloat

    var handlePoint: CGPoint {
        SwordMath.worldPoint(
            center: center,
            angle: angle,
            localX: SwordEngineTuning.handleLocalX
        )
    }

    var bladeStart: CGPoint {
        SwordMath.worldPoint(
            center: center,
            angle: angle,
            localX: SwordEngineTuning.bladeStartLocalX
        )
    }

    var bladeTip: CGPoint {
        SwordMath.worldPoint(
            center: center,
            angle: angle,
            localX: SwordEngineTuning.bladeTipLocalX
        )
    }

    var bladeDirection: CGVector {
        SwordMath.normalized(SwordMath.vector(from: bladeStart, to: bladeTip))
    }

    func velocity(at worldPoint: CGPoint) -> CGVector {
        let radius = SwordMath.vector(from: center, to: worldPoint)
        return CGVector(
            dx: linearVelocity.dx - (angularVelocity * radius.dy),
            dy: linearVelocity.dy + (angularVelocity * radius.dx)
        )
    }
}
