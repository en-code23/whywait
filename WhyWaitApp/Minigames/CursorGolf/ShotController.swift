import CoreGraphics

struct CursorGolfAimSnapshot {
    let cursorPosition: CGPoint
    let pullDistance: CGFloat
    let power: CGFloat
}

struct CursorGolfShot {
    let launchVelocity: CGVector
    let pullDistance: CGFloat
    let power: CGFloat
}

final class ShotController {
    private(set) var isAiming = false

    private var ballAnchor = CGPoint.zero
    private var currentCursorPosition = CGPoint.zero

    func beginAiming(cursorPosition: CGPoint, ballPosition: CGPoint) -> Bool {
        let hitDistance = GolfGeometry.distance(from: cursorPosition, to: ballPosition)
        guard hitDistance <= CursorGolfTuning.ballRadius + CursorGolfTuning.ballHitSlop else {
            return false
        }

        ballAnchor = ballPosition
        currentCursorPosition = cursorPosition
        isAiming = true
        return true
    }

    func updateAiming(cursorPosition: CGPoint) -> CursorGolfAimSnapshot? {
        guard isAiming else {
            return nil
        }

        let pullVector = GolfGeometry.vector(from: ballAnchor, to: cursorPosition)
        let rawDistance = GolfGeometry.magnitude(of: pullVector)
        let clampedDistance = min(rawDistance, CursorGolfTuning.maximumDragDistance)
        let direction = GolfGeometry.normalized(pullVector)

        currentCursorPosition = GolfGeometry.point(
            ballAnchor,
            offsetBy: GolfGeometry.scaled(direction, by: clampedDistance)
        )

        return CursorGolfAimSnapshot(
            cursorPosition: currentCursorPosition,
            pullDistance: clampedDistance,
            power: clampedDistance / CursorGolfTuning.maximumDragDistance
        )
    }

    func finishAiming(cursorPosition: CGPoint) -> CursorGolfShot? {
        guard let aim = updateAiming(cursorPosition: cursorPosition) else {
            return nil
        }

        defer {
            cancelAiming()
        }

        guard aim.pullDistance >= CursorGolfTuning.minimumLaunchDrag else {
            return nil
        }

        let shotDirection = GolfGeometry.normalized(
            GolfGeometry.vector(from: aim.cursorPosition, to: ballAnchor)
        )
        let launchSpeed = min(
            aim.pullDistance * CursorGolfTuning.shotSpeedPerDragPoint,
            CursorGolfTuning.maximumLaunchSpeed
        )

        return CursorGolfShot(
            launchVelocity: GolfGeometry.scaled(shotDirection, by: launchSpeed),
            pullDistance: aim.pullDistance,
            power: aim.power
        )
    }

    func cancelAiming() {
        isAiming = false
        ballAnchor = .zero
        currentCursorPosition = .zero
    }
}
