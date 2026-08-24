import CoreGraphics
import Foundation

enum FishingGeometry {
    static func vector(from start: CGPoint, to end: CGPoint) -> CGVector {
        CGVector(dx: end.x - start.x, dy: end.y - start.y)
    }

    static func length(_ vector: CGVector) -> CGFloat {
        hypot(vector.dx, vector.dy)
    }

    static func normalized(_ vector: CGVector, fallback: CGVector = CGVector(dx: 0, dy: 1)) -> CGVector {
        let magnitude = length(vector)
        guard magnitude.isFinite, magnitude > 0.0001 else { return fallback }
        return CGVector(dx: vector.dx / magnitude, dy: vector.dy / magnitude)
    }

    static func scaled(_ vector: CGVector, by scalar: CGFloat) -> CGVector {
        CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
    }

    static func adding(_ first: CGVector, _ second: CGVector) -> CGVector {
        CGVector(dx: first.dx + second.dx, dy: first.dy + second.dy)
    }

    static func dot(_ first: CGVector, _ second: CGVector) -> CGFloat {
        (first.dx * second.dx) + (first.dy * second.dy)
    }

    static func point(_ point: CGPoint, adding vector: CGVector) -> CGPoint {
        CGPoint(x: point.x + vector.dx, y: point.y + vector.dy)
    }

    static func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        length(vector(from: start, to: end))
    }

    static func clamped(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(rect.maxX, max(rect.minX, point.x)),
            y: min(rect.maxY, max(rect.minY, point.y))
        )
    }

    static func isFinite(_ point: CGPoint) -> Bool {
        point.x.isFinite && point.y.isFinite
    }

    static func isFinite(_ vector: CGVector) -> Bool {
        vector.dx.isFinite && vector.dy.isFinite
    }
}

