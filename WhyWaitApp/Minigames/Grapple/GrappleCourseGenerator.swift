import CoreGraphics
import Foundation

final class GrappleCourseGenerator {
    func generate(in sceneSize: CGSize) -> GrappleCourse {
        for _ in 0..<GrappleTuning.courseGenerationAttempts {
            let archetype = GrappleCourseArchetype.allCases.randomElement() ?? .swing
            let checkpointCount = Int.random(
                in: GrappleTuning.minimumCheckpointCount...GrappleTuning.maximumCheckpointCount
            )
            let points = makeProgressionPoints(
                archetype: archetype,
                checkpointCount: checkpointCount,
                sceneSize: sceneSize
            )
            guard points.count == checkpointCount + 2 else {
                continue
            }

            let obstacles = makeObstacles(
                archetype: archetype,
                protectedPoints: points,
                sceneSize: sceneSize
            )
            let hazards = makeHazards(
                protectedPoints: points,
                obstacles: obstacles,
                sceneSize: sceneSize
            )
            let course = GrappleCourse(
                archetype: archetype,
                startPosition: points[0],
                checkpoints: Array(points.dropFirst().dropLast()),
                checkpointRespawns: Array(points.dropFirst().dropLast()),
                obstacles: obstacles,
                hazards: hazards,
                goalPosition: points[points.count - 1]
            )

            if isValid(course, in: sceneSize) {
                return course
            }
        }

        return fallbackCourse(in: sceneSize)
    }

    func isValid(_ course: GrappleCourse, in sceneSize: CGSize) -> Bool {
        guard course.checkpoints.count >= GrappleTuning.minimumCheckpointCount,
              course.checkpoints.count <= GrappleTuning.maximumCheckpointCount,
              course.checkpointRespawns.count == course.checkpoints.count,
              course.obstacles.count >= GrappleTuning.minimumObstacleCount,
              course.obstacles.count <= GrappleTuning.maximumObstacleCount,
              course.hazards.count >= GrappleTuning.minimumHazardCount,
              course.hazards.count <= GrappleTuning.maximumHazardCount,
              sceneSize.width > 300,
              sceneSize.height > 300 else {
            return false
        }

        let displayBounds = CGRect(origin: .zero, size: sceneSize).insetBy(dx: 24, dy: 24)
        let fullDisplayBounds = CGRect(origin: .zero, size: sceneSize)
        let progression = course.progressionPoints
        guard progression.allSatisfy(displayBounds.contains),
              fullDisplayBounds.contains(course.launchPlatform.boundingFrame),
              abs(course.launchPlatform.boundingFrame.maxY
                - (course.startPosition.y - GrappleTuning.playerRadius)) < 0.01 else {
            return false
        }

        for pairIndex in 1..<progression.count {
            let spacing = GrapplePhysics.distance(
                from: progression[pairIndex - 1],
                to: progression[pairIndex]
            )
            guard spacing >= GrappleTuning.minimumProgressionSpacing,
                  spacing <= GrappleTuning.maximumProgressionSpacing else {
                return false
            }
        }

        for (checkpoint, respawn) in zip(course.checkpoints, course.checkpointRespawns) {
            guard displayBounds.contains(respawn),
                  GrapplePhysics.distance(from: checkpoint, to: respawn) <= 12 else {
                return false
            }
        }

        for obstacle in course.obstacles {
            guard displayBounds.contains(obstacle.boundingFrame),
                  progression.allSatisfy({
                      !obstacle.boundingFrame
                        .insetBy(
                            dx: -(GrappleTuning.checkpointRadius
                                + GrappleTuning.playerRadius
                                + GrappleTuning.protectedPointPadding),
                            dy: -(GrappleTuning.checkpointRadius
                                + GrappleTuning.playerRadius
                                + GrappleTuning.protectedPointPadding)
                        )
                        .contains($0)
                  }) else {
                return false
            }
        }

        for hazard in course.hazards {
            guard displayBounds.contains(hazard.boundingFrame),
                  progression.allSatisfy({
                      !hazard.boundingFrame
                        .insetBy(
                            dx: -(GrappleTuning.checkpointRadius
                                + GrappleTuning.playerRadius
                                + GrappleTuning.protectedPointPadding),
                            dy: -(GrappleTuning.checkpointRadius
                                + GrappleTuning.playerRadius
                                + GrappleTuning.protectedPointPadding)
                        )
                        .contains($0)
                  }) else {
                return false
            }
        }

        for obstacleIndex in course.obstacles.indices {
            for otherIndex in course.obstacles.indices where otherIndex > obstacleIndex {
                if course.obstacles[obstacleIndex].boundingFrame
                    .insetBy(dx: -8, dy: -8)
                    .intersects(course.obstacles[otherIndex].boundingFrame) {
                    return false
                }
            }
        }

        for hazardIndex in course.hazards.indices {
            let hazard = course.hazards[hazardIndex]
            if course.obstacles.contains(where: {
                $0.boundingFrame.insetBy(dx: -12, dy: -12).intersects(hazard.boundingFrame)
            }) {
                return false
            }
            for otherIndex in course.hazards.indices where otherIndex > hazardIndex {
                if hazard.boundingFrame.insetBy(dx: -10, dy: -10)
                    .intersects(course.hazards[otherIndex].boundingFrame) {
                    return false
                }
            }
        }

        return true
    }

    private func makeProgressionPoints(
        archetype: GrappleCourseArchetype,
        checkpointCount: Int,
        sceneSize: CGSize
    ) -> [CGPoint] {
        let safe = safeRect(for: sceneSize)
        let totalSegments = checkpointCount + 1

        if archetype == .orbit {
            return makeOrbitPoints(
                checkpointCount: checkpointCount,
                safeRect: safe
            )
        }

        return (0...totalSegments).map { index in
            let progress = CGFloat(index) / CGFloat(totalSegments)
            let normalized: CGPoint

            switch archetype {
            case .swing:
                normalized = CGPoint(
                    x: progress,
                    y: 0.48 + (sin(progress * .pi * 3) * 0.23)
                )
            case .zigzag:
                let isEndpoint = index == 0 || index == totalSegments
                normalized = CGPoint(
                    x: progress,
                    y: isEndpoint ? 0.5 : (index.isMultiple(of: 2) ? 0.73 : 0.27)
                )
            case .climb:
                normalized = CGPoint(
                    x: index.isMultiple(of: 2) ? 0.35 : 0.65,
                    y: 0.06 + (progress * 0.88)
                )
            case .drop:
                normalized = CGPoint(
                    x: progress,
                    y: 0.9 - (progress * 0.75) + (sin(progress * .pi * 2) * 0.1)
                )
            case .gates:
                normalized = CGPoint(
                    x: progress,
                    y: 0.5 + (index.isMultiple(of: 2) ? 0.08 : -0.08)
                )
            case .orbit:
                normalized = .zero
            }

            let jitter: CGFloat = (index == 0 || index == totalSegments) ? 0 : 0.025
            return point(
                normalizedX: normalized.x + CGFloat.random(in: -jitter...jitter),
                normalizedY: normalized.y + CGFloat.random(in: -jitter...jitter),
                in: safe
            )
        }
    }

    private func makeOrbitPoints(
        checkpointCount: Int,
        safeRect: CGRect
    ) -> [CGPoint] {
        let center = CGPoint(x: safeRect.midX, y: safeRect.midY)
        let radiusX = min(safeRect.width * 0.31, 275)
        let radiusY = min(safeRect.height * 0.34, 235)
        var points = [
            point(normalizedX: 0.02, normalizedY: 0.24, in: safeRect)
        ]

        for index in 0..<checkpointCount {
            let progress = CGFloat(index) / CGFloat(max(1, checkpointCount - 1))
            let angle = (.pi * 1.18) - (progress * .pi * 1.35)
            points.append(
                CGPoint(
                    x: center.x + (cos(angle) * radiusX),
                    y: center.y + (sin(angle) * radiusY)
                )
            )
        }
        points.append(point(normalizedX: 0.98, normalizedY: 0.75, in: safeRect))
        return points
    }

    private func makeObstacles(
        archetype: GrappleCourseArchetype,
        protectedPoints: [CGPoint],
        sceneSize: CGSize
    ) -> [GrappleObstacleDescriptor] {
        let safe = safeRect(for: sceneSize).insetBy(dx: 14, dy: 14)
        let targetCount = Int.random(
            in: GrappleTuning.minimumObstacleCount...GrappleTuning.maximumObstacleCount
        )
        var obstacles: [GrappleObstacleDescriptor] = []

        if archetype == .orbit {
            let central = GrappleObstacleDescriptor(
                center: CGPoint(x: safe.midX, y: safe.midY),
                size: CGSize(width: 108, height: 108),
                rotation: .pi / 4
            )
            if canPlace(
                frame: central.boundingFrame,
                protectedPoints: protectedPoints,
                existingFrames: []
            ) {
                obstacles.append(central)
            }
        } else if archetype == .gates {
            obstacles.append(
                contentsOf: makeGateObstacles(
                    protectedPoints: protectedPoints,
                    safeRect: safe
                )
            )
        }

        var attempts = 0
        while obstacles.count < targetCount, attempts < 120 {
            attempts += 1
            let style = Int.random(in: 0...3)
            let size: CGSize
            let rotation: CGFloat
            switch style {
            case 0:
                size = CGSize(width: CGFloat.random(in: 82...148), height: CGFloat.random(in: 16...24))
                rotation = 0
            case 1:
                size = CGSize(width: CGFloat.random(in: 17...25), height: CGFloat.random(in: 78...142))
                rotation = 0
            case 2:
                let side = CGFloat.random(in: 44...72)
                size = CGSize(width: side, height: side)
                rotation = 0
            default:
                size = CGSize(width: CGFloat.random(in: 88...142), height: CGFloat.random(in: 16...23))
                rotation = CGFloat.random(in: -0.38...0.38)
            }

            let candidate = GrappleObstacleDescriptor(
                center: randomCenter(fitting: size, in: safe),
                size: size,
                rotation: rotation
            )
            guard safe.contains(candidate.boundingFrame),
                  canPlace(
                    frame: candidate.boundingFrame,
                    protectedPoints: protectedPoints,
                    existingFrames: obstacles.map(\.boundingFrame)
                  ) else {
                continue
            }
            obstacles.append(candidate)
        }
        return obstacles
    }

    private func makeGateObstacles(
        protectedPoints: [CGPoint],
        safeRect: CGRect
    ) -> [GrappleObstacleDescriptor] {
        guard protectedPoints.count >= 4 else {
            return []
        }

        var obstacles: [GrappleObstacleDescriptor] = []
        let gateIndices = [1, min(3, protectedPoints.count - 2)]
        for index in Set(gateIndices).sorted() {
            let first = protectedPoints[index]
            let second = protectedPoints[index + 1]
            let gateX = (first.x + second.x) / 2
            let gapCenterY = (first.y + second.y) / 2
            // Leave enough clearance for a checkpoint, the player body, and the
            // generator's protected padding even when checkpoint jitter is at
            // its maximum. This keeps the gate walls from being discarded by
            // the same invariant checks that protect respawn positions.
            let gapHalfHeight = min(
                175,
                max(150, safeRect.height * 0.25)
            )
            let lowerTop = gapCenterY - gapHalfHeight
            let upperBottom = gapCenterY + gapHalfHeight
            let lowerHeight = lowerTop - safeRect.minY
            let upperHeight = safeRect.maxY - upperBottom

            let candidates = [
                GrappleObstacleDescriptor(
                    center: CGPoint(x: gateX, y: safeRect.minY + (lowerHeight / 2)),
                    size: CGSize(width: 20, height: lowerHeight),
                    rotation: 0
                ),
                GrappleObstacleDescriptor(
                    center: CGPoint(x: gateX, y: upperBottom + (upperHeight / 2)),
                    size: CGSize(width: 20, height: upperHeight),
                    rotation: 0
                )
            ]
            for candidate in candidates where candidate.size.height >= 45 {
                if canPlace(
                    frame: candidate.boundingFrame,
                    protectedPoints: protectedPoints,
                    existingFrames: obstacles.map(\.boundingFrame)
                ) {
                    obstacles.append(candidate)
                }
            }
        }
        return Array(obstacles.prefix(GrappleTuning.maximumObstacleCount))
    }

    private func makeHazards(
        protectedPoints: [CGPoint],
        obstacles: [GrappleObstacleDescriptor],
        sceneSize: CGSize
    ) -> [GrappleHazardDescriptor] {
        let safe = safeRect(for: sceneSize).insetBy(dx: 12, dy: 12)
        let targetCount = Int.random(
            in: GrappleTuning.minimumHazardCount...GrappleTuning.maximumHazardCount
        )
        var hazards: [GrappleHazardDescriptor] = []
        var attempts = 0

        while hazards.count < targetCount, attempts < 100 {
            attempts += 1
            let shape: GrappleHazardShape
            let fittingSize: CGSize
            switch Int.random(in: 0...2) {
            case 0:
                let radius = CGFloat.random(in: 20...31)
                shape = .orb(radius: radius)
                fittingSize = CGSize(width: radius * 2, height: radius * 2)
            case 1:
                fittingSize = CGSize(
                    width: CGFloat.random(in: 48...86),
                    height: CGFloat.random(in: 20...32)
                )
                shape = .block(size: fittingSize)
            default:
                fittingSize = CGSize(
                    width: CGFloat.random(in: 62...112),
                    height: CGFloat.random(in: 22...31)
                )
                shape = .spikes(size: fittingSize)
            }

            let candidate = GrappleHazardDescriptor(
                center: randomCenter(fitting: fittingSize, in: safe),
                shape: shape
            )
            let existingFrames = obstacles.map(\.boundingFrame)
                + hazards.map(\.boundingFrame)
            guard safe.contains(candidate.boundingFrame),
                  canPlace(
                    frame: candidate.boundingFrame,
                    protectedPoints: protectedPoints,
                    existingFrames: existingFrames
                  ) else {
                continue
            }
            hazards.append(candidate)
        }
        return hazards
    }

    private func canPlace(
        frame: CGRect,
        protectedPoints: [CGPoint],
        existingFrames: [CGRect]
    ) -> Bool {
        let protectedFrame = frame.insetBy(
            dx: -(GrappleTuning.checkpointRadius
                + GrappleTuning.playerRadius
                + GrappleTuning.protectedPointPadding),
            dy: -(GrappleTuning.checkpointRadius
                + GrappleTuning.playerRadius
                + GrappleTuning.protectedPointPadding)
        )
        guard protectedPoints.allSatisfy({ !protectedFrame.contains($0) }) else {
            return false
        }
        return existingFrames.allSatisfy {
            !$0.insetBy(dx: -18, dy: -18).intersects(frame)
        }
    }

    private func fallbackCourse(in sceneSize: CGSize) -> GrappleCourse {
        let safe = safeRect(for: sceneSize)
        let checkpoints = [
            point(normalizedX: 0.23, normalizedY: 0.68, in: safe),
            point(normalizedX: 0.42, normalizedY: 0.38, in: safe),
            point(normalizedX: 0.62, normalizedY: 0.7, in: safe),
            point(normalizedX: 0.8, normalizedY: 0.42, in: safe)
        ]
        let points = [point(normalizedX: 0.03, normalizedY: 0.3, in: safe)]
            + checkpoints
            + [point(normalizedX: 0.97, normalizedY: 0.64, in: safe)]
        let obstacles = makeObstacles(
            archetype: .swing,
            protectedPoints: points,
            sceneSize: sceneSize
        )
        let hazards = makeHazards(
            protectedPoints: points,
            obstacles: obstacles,
            sceneSize: sceneSize
        )
        return GrappleCourse(
            archetype: .swing,
            startPosition: points[0],
            checkpoints: checkpoints,
            checkpointRespawns: checkpoints,
            obstacles: obstacles,
            hazards: hazards,
            goalPosition: points[points.count - 1]
        )
    }

    private func safeRect(for sceneSize: CGSize) -> CGRect {
        let horizontalInset = min(
            GrappleTuning.courseHorizontalInset,
            max(36, sceneSize.width * 0.08)
        )
        let verticalInset = min(
            GrappleTuning.courseVerticalInset,
            max(38, sceneSize.height * 0.09)
        )
        return CGRect(origin: .zero, size: sceneSize)
            .insetBy(dx: horizontalInset, dy: verticalInset)
    }

    private func point(
        normalizedX: CGFloat,
        normalizedY: CGFloat,
        in rect: CGRect
    ) -> CGPoint {
        CGPoint(
            x: rect.minX + (GrapplePhysics.clamp(normalizedX, minimum: 0, maximum: 1) * rect.width),
            y: rect.minY + (GrapplePhysics.clamp(normalizedY, minimum: 0, maximum: 1) * rect.height)
        )
    }

    private func randomCenter(fitting size: CGSize, in rect: CGRect) -> CGPoint {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let minimumX = rect.minX + halfWidth
        let maximumX = max(minimumX, rect.maxX - halfWidth)
        let minimumY = rect.minY + halfHeight
        let maximumY = max(minimumY, rect.maxY - halfHeight)
        return CGPoint(
            x: CGFloat.random(in: minimumX...maximumX),
            y: CGFloat.random(in: minimumY...maximumY)
        )
    }
}
