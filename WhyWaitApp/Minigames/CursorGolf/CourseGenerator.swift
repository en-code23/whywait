import CoreGraphics

enum CursorGolfLayout: CaseIterable {
    case open
    case wall
    case bank
    case bumper
    case tight
}

struct GeneratedGolfCourse {
    let layout: CursorGolfLayout
    let ballPosition: CGPoint
    let holePosition: CGPoint
    let obstacles: [GolfObstacleDescriptor]
}

final class CourseGenerator {
    func generateCourse(in size: CGSize) -> GeneratedGolfCourse {
        let bounds = CursorGolfTuning.playableBounds(for: size)
        let positions = generateBallAndHole(in: bounds, sceneSize: size)
        let layout = CursorGolfLayout.allCases.randomElement() ?? .open
        let obstacles = generateObstacles(
            for: layout,
            ballPosition: positions.ball,
            holePosition: positions.hole,
            in: bounds,
            sceneSize: size
        )

        return GeneratedGolfCourse(
            layout: layout,
            ballPosition: positions.ball,
            holePosition: positions.hole,
            obstacles: obstacles
        )
    }

    private func generateBallAndHole(
        in bounds: CGRect,
        sceneSize: CGSize
    ) -> (ball: CGPoint, hole: CGPoint) {
        let requiredDistance = min(
            430,
            max(220, hypot(bounds.width, bounds.height) * 0.36)
        )

        for _ in 0..<160 {
            let ball = randomPoint(in: bounds)
            let hole = randomPoint(in: bounds)

            guard isOutsideHUD(ball, sceneSize: sceneSize, padding: 26),
                  isOutsideHUD(hole, sceneSize: sceneSize, padding: 26),
                  GolfGeometry.distance(from: ball, to: hole) >= requiredDistance else {
                continue
            }

            return (ball, hole)
        }

        return (
            CGPoint(x: bounds.minX + (bounds.width * 0.18), y: bounds.midY),
            CGPoint(x: bounds.maxX - (bounds.width * 0.18), y: bounds.midY)
        )
    }

    private func generateObstacles(
        for layout: CursorGolfLayout,
        ballPosition: CGPoint,
        holePosition: CGPoint,
        in bounds: CGRect,
        sceneSize: CGSize
    ) -> [GolfObstacleDescriptor] {
        var obstacles: [GolfObstacleDescriptor] = []

        switch layout {
        case .open:
            break

        case .wall:
            addWallBetween(
                ballPosition,
                and: holePosition,
                offsetRange: -48...48,
                bounds: bounds,
                sceneSize: sceneSize,
                obstacles: &obstacles
            )

        case .bank:
            addBankWall(
                between: ballPosition,
                and: holePosition,
                bounds: bounds,
                sceneSize: sceneSize,
                obstacles: &obstacles
            )

        case .bumper:
            let count = Int.random(in: 1...3)
            let courseVector = GolfGeometry.vector(from: ballPosition, to: holePosition)
            let perpendicular = GolfGeometry.normalized(
                CGVector(dx: -courseVector.dy, dy: courseVector.dx)
            )

            for index in 0..<count {
                let baseFraction = CGFloat(index + 1) / CGFloat(count + 1)
                let basePosition = GolfGeometry.point(
                    from: ballPosition,
                    to: holePosition,
                    fraction: baseFraction
                )
                let offset = CGFloat.random(in: -115...115)
                let position = GolfGeometry.point(
                    basePosition,
                    offsetBy: GolfGeometry.scaled(perpendicular, by: offset)
                )
                let candidate = GolfObstacleDescriptor(
                    shape: .bumper(radius: CGFloat.random(in: 18...25)),
                    position: position,
                    rotation: 0
                )
                appendIfValid(
                    candidate,
                    ballPosition: ballPosition,
                    holePosition: holePosition,
                    bounds: bounds,
                    sceneSize: sceneSize,
                    obstacles: &obstacles
                )
            }

        case .tight:
            let desiredCount = Int.random(in: 2...4)
            var attempts = 0

            while obstacles.count < desiredCount, attempts < 40 {
                attempts += 1
                let size = CGSize(
                    width: CGFloat.random(in: 82...142),
                    height: CGFloat.random(in: 11...16)
                )
                let candidate = GolfObstacleDescriptor(
                    shape: .wall(size: size),
                    position: randomPoint(in: bounds),
                    rotation: CGFloat.random(in: 0...(CGFloat.pi * 2))
                )
                appendIfValid(
                    candidate,
                    ballPosition: ballPosition,
                    holePosition: holePosition,
                    bounds: bounds,
                    sceneSize: sceneSize,
                    obstacles: &obstacles
                )
            }
        }

        return obstacles
    }

    private func addWallBetween(
        _ ballPosition: CGPoint,
        and holePosition: CGPoint,
        offsetRange: ClosedRange<CGFloat>,
        bounds: CGRect,
        sceneSize: CGSize,
        obstacles: inout [GolfObstacleDescriptor]
    ) {
        let courseVector = GolfGeometry.vector(from: ballPosition, to: holePosition)
        let perpendicular = GolfGeometry.normalized(
            CGVector(dx: -courseVector.dy, dy: courseVector.dx)
        )
        let wallRotation = atan2(courseVector.dy, courseVector.dx) + (.pi / 2)
        let wallSize = CGSize(
            width: min(190, max(112, bounds.width * 0.14)),
            height: 14
        )
        let midpoint = GolfGeometry.point(
            from: ballPosition,
            to: holePosition,
            fraction: 0.5
        )

        for _ in 0..<10 {
            let position = GolfGeometry.point(
                midpoint,
                offsetBy: GolfGeometry.scaled(
                    perpendicular,
                    by: CGFloat.random(in: offsetRange)
                )
            )
            let candidate = GolfObstacleDescriptor(
                shape: .wall(size: wallSize),
                position: position,
                rotation: wallRotation
            )
            let previousCount = obstacles.count
            appendIfValid(
                candidate,
                ballPosition: ballPosition,
                holePosition: holePosition,
                bounds: bounds,
                sceneSize: sceneSize,
                obstacles: &obstacles
            )

            if obstacles.count > previousCount {
                return
            }
        }
    }

    private func addBankWall(
        between ballPosition: CGPoint,
        and holePosition: CGPoint,
        bounds: CGRect,
        sceneSize: CGSize,
        obstacles: inout [GolfObstacleDescriptor]
    ) {
        let courseVector = GolfGeometry.vector(from: ballPosition, to: holePosition)
        let perpendicular = GolfGeometry.normalized(
            CGVector(dx: -courseVector.dy, dy: courseVector.dx)
        )
        let courseAngle = atan2(courseVector.dy, courseVector.dx)
        let basePosition = GolfGeometry.point(
            from: ballPosition,
            to: holePosition,
            fraction: CGFloat.random(in: 0.42...0.62)
        )

        for _ in 0..<12 {
            let side: CGFloat = Bool.random() ? 1 : -1
            let position = GolfGeometry.point(
                basePosition,
                offsetBy: GolfGeometry.scaled(
                    perpendicular,
                    by: side * CGFloat.random(in: 78...126)
                )
            )
            let candidate = GolfObstacleDescriptor(
                shape: .wall(size: CGSize(width: 168, height: 14)),
                position: position,
                rotation: courseAngle + (side * CGFloat.random(in: 0.32...0.58))
            )
            let previousCount = obstacles.count
            appendIfValid(
                candidate,
                ballPosition: ballPosition,
                holePosition: holePosition,
                bounds: bounds,
                sceneSize: sceneSize,
                obstacles: &obstacles
            )

            if obstacles.count > previousCount {
                return
            }
        }
    }

    private func appendIfValid(
        _ candidate: GolfObstacleDescriptor,
        ballPosition: CGPoint,
        holePosition: CGPoint,
        bounds: CGRect,
        sceneSize: CGSize,
        obstacles: inout [GolfObstacleDescriptor]
    ) {
        let radius = candidate.clearanceRadius
        let safeBounds = bounds.insetBy(dx: radius, dy: radius)

        guard safeBounds.contains(candidate.position),
              isOutsideHUD(candidate.position, sceneSize: sceneSize, padding: radius),
              GolfGeometry.distance(from: candidate.position, to: ballPosition)
                > radius + CursorGolfTuning.obstacleClearance,
              GolfGeometry.distance(from: candidate.position, to: holePosition)
                > radius + CursorGolfTuning.obstacleClearance else {
            return
        }

        let overlapsExistingObstacle = obstacles.contains { obstacle in
            GolfGeometry.distance(from: candidate.position, to: obstacle.position)
                < radius + obstacle.clearanceRadius + 20
        }

        guard !overlapsExistingObstacle else {
            return
        }

        obstacles.append(candidate)
    }

    private func randomPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: bounds.minX...bounds.maxX),
            y: CGFloat.random(in: bounds.minY...bounds.maxY)
        )
    }

    private func isOutsideHUD(
        _ point: CGPoint,
        sceneSize: CGSize,
        padding: CGFloat
    ) -> Bool {
        let hudArea = CGRect(
            x: 0,
            y: max(0, sceneSize.height - 76),
            width: min(190, sceneSize.width * 0.35),
            height: 76
        ).insetBy(dx: -padding, dy: -padding)

        return !hudArea.contains(point)
    }
}
