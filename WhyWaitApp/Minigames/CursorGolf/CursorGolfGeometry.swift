import CoreGraphics

enum GolfGeometry {
    static func vector(from start: CGPoint, to end: CGPoint) -> CGVector {
        CGVector(dx: end.x - start.x, dy: end.y - start.y)
    }

    static func point(_ point: CGPoint, offsetBy vector: CGVector) -> CGPoint {
        CGPoint(x: point.x + vector.dx, y: point.y + vector.dy)
    }

    static func point(from start: CGPoint, to end: CGPoint, fraction: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + ((end.x - start.x) * fraction),
            y: start.y + ((end.y - start.y) * fraction)
        )
    }

    static func magnitude(of vector: CGVector) -> CGFloat {
        hypot(vector.dx, vector.dy)
    }

    static func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        magnitude(of: vector(from: first, to: second))
    }

    static func normalized(_ vector: CGVector) -> CGVector {
        let length = magnitude(of: vector)
        guard length > 0.0001 else {
            return .zero
        }

        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    static func scaled(_ vector: CGVector, by scale: CGFloat) -> CGVector {
        CGVector(dx: vector.dx * scale, dy: vector.dy * scale)
    }

    static func clamped(
        _ point: CGPoint,
        to bounds: CGRect,
        inset: CGFloat = 0
    ) -> CGPoint {
        let safeBounds = bounds.insetBy(dx: inset, dy: inset)
        return CGPoint(
            x: min(max(point.x, safeBounds.minX), safeBounds.maxX),
            y: min(max(point.y, safeBounds.minY), safeBounds.maxY)
        )
    }
}
