import CoreGraphics

struct SliceIntersection {
    let closestPoint: CGPoint
    let distanceFromCenter: CGFloat
    let segmentProgress: CGFloat
}

enum SliceGeometry {
    static func intersection(
        segmentStart: CGPoint,
        segmentEnd: CGPoint,
        circleCenter: CGPoint,
        circleRadius: CGFloat
    ) -> SliceIntersection? {
        let dx = segmentEnd.x - segmentStart.x
        let dy = segmentEnd.y - segmentStart.y
        let lengthSquared = (dx * dx) + (dy * dy)

        guard lengthSquared > .ulpOfOne else {
            return nil
        }

        let centerDX = circleCenter.x - segmentStart.x
        let centerDY = circleCenter.y - segmentStart.y
        let rawProgress = ((centerDX * dx) + (centerDY * dy)) / lengthSquared
        let progress = min(max(rawProgress, 0), 1)
        let closestPoint = CGPoint(
            x: segmentStart.x + (dx * progress),
            y: segmentStart.y + (dy * progress)
        )
        let distance = hypot(
            circleCenter.x - closestPoint.x,
            circleCenter.y - closestPoint.y
        )

        guard distance <= circleRadius else {
            return nil
        }

        return SliceIntersection(
            closestPoint: closestPoint,
            distanceFromCenter: distance,
            segmentProgress: progress
        )
    }

    static func normalizedDirection(from start: CGPoint, to end: CGPoint) -> CGVector? {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > .ulpOfOne else {
            return nil
        }

        return CGVector(dx: dx / length, dy: dy / length)
    }

    static func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }
}

