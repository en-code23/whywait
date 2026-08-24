import CoreGraphics
import Foundation

enum FruitSpawnKind {
    case fruit(FruitType)
    case bomb
}

struct FruitLaunchRequest {
    let kind: FruitSpawnKind
    let position: CGPoint
    let velocity: CGVector
    let angularVelocity: CGFloat
}

private enum FruitSpawnPattern: CaseIterable {
    case single
    case pair
    case burst
    case cross
    case highToss
}

final class FruitSpawner {
    private var nextSpawnTime: TimeInterval = .infinity

    func reset(at currentTime: TimeInterval) {
        nextSpawnTime = currentTime + FruitSliceTuning.initialSpawnDelay
    }

    func launchesIfDue(
        currentTime: TimeInterval,
        runElapsedTime: TimeInterval,
        sceneSize: CGSize,
        availableSlots: Int
    ) -> [FruitLaunchRequest] {
        guard availableSlots > 0, currentTime >= nextSpawnTime else {
            return []
        }

        let difficulty = difficultyProgress(at: runElapsedTime)
        scheduleNextSpawn(from: currentTime, difficulty: difficulty)
        let pattern = choosePattern(runElapsedTime: runElapsedTime, difficulty: difficulty)
        var launches = makeLaunches(
            for: pattern,
            sceneSize: sceneSize,
            difficulty: difficulty
        )

        let bombProbability = FruitSliceTuning.initialBombProbability
            + ((FruitSliceTuning.maximumBombProbability
                - FruitSliceTuning.initialBombProbability) * difficulty)
        if runElapsedTime > 4,
           !launches.isEmpty,
           CGFloat.random(in: 0...1) < bombProbability {
            let bombIndex = Int.random(in: launches.indices)
            let original = launches[bombIndex]
            launches[bombIndex] = FruitLaunchRequest(
                kind: .bomb,
                position: original.position,
                velocity: original.velocity,
                angularVelocity: original.angularVelocity * 0.65
            )
        }

        return Array(launches.prefix(availableSlots))
    }

    func difficultyProgress(at elapsedTime: TimeInterval) -> CGFloat {
        let effectiveElapsed = max(0, elapsedTime - FruitSliceTuning.relaxedOpeningDuration)
        return min(1, CGFloat(effectiveElapsed / FruitSliceTuning.difficultyRampDuration))
    }

    private func scheduleNextSpawn(from currentTime: TimeInterval, difficulty: CGFloat) {
        let intervalRange = FruitSliceTuning.initialSpawnInterval
            - FruitSliceTuning.minimumSpawnInterval
        let interval = FruitSliceTuning.initialSpawnInterval
            - (intervalRange * TimeInterval(difficulty))
        nextSpawnTime = currentTime + (interval * Double.random(in: 0.88...1.12))
    }

    private func choosePattern(
        runElapsedTime: TimeInterval,
        difficulty: CGFloat
    ) -> FruitSpawnPattern {
        let roll = CGFloat.random(in: 0...1)

        if runElapsedTime < FruitSliceTuning.relaxedOpeningDuration {
            if roll < 0.58 { return .single }
            if roll < 0.84 { return .pair }
            return .highToss
        }

        let burstThreshold = 0.1 + (difficulty * 0.12)
        let crossThreshold = burstThreshold + 0.16
        let pairThreshold = crossThreshold + 0.28
        let highTossThreshold = pairThreshold + 0.16

        if roll < burstThreshold { return .burst }
        if roll < crossThreshold { return .cross }
        if roll < pairThreshold { return .pair }
        if roll < highTossThreshold { return .highToss }
        return .single
    }

    private func makeLaunches(
        for pattern: FruitSpawnPattern,
        sceneSize: CGSize,
        difficulty: CGFloat
    ) -> [FruitLaunchRequest] {
        switch pattern {
        case .single:
            return [makeStandardLaunch(sceneSize: sceneSize, difficulty: difficulty)]
        case .pair:
            return (0..<2).map { index in
                makeStandardLaunch(
                    sceneSize: sceneSize,
                    difficulty: difficulty,
                    horizontalOffset: CGFloat(index * 54) - 27,
                    velocityOffset: CGFloat(index * 70) - 35
                )
            }
        case .burst:
            let count = Int.random(in: 3...4)
            return (0..<count).map { index in
                let centeredIndex = CGFloat(index) - (CGFloat(count - 1) / 2)
                return makeStandardLaunch(
                    sceneSize: sceneSize,
                    difficulty: difficulty,
                    horizontalOffset: centeredIndex * 42,
                    velocityOffset: centeredIndex * 62
                )
            }
        case .cross:
            return makeCrossLaunches(sceneSize: sceneSize, difficulty: difficulty)
        case .highToss:
            return [makeHighToss(sceneSize: sceneSize, difficulty: difficulty)]
        }
    }

    private func makeStandardLaunch(
        sceneSize: CGSize,
        difficulty: CGFloat,
        horizontalOffset: CGFloat = 0,
        velocityOffset: CGFloat = 0
    ) -> FruitLaunchRequest {
        let margin = min(90, max(36, sceneSize.width * 0.12))
        let minimumX = margin
        let maximumX = max(minimumX, sceneSize.width - margin)
        let baseX = CGFloat.random(in: minimumX...maximumX)
        let x = SliceGeometry.clamp(
            baseX + horizontalOffset,
            minimum: minimumX,
            maximum: maximumX
        )
        let centerBias = (sceneSize.width / 2 - x) * 0.18
        let variation = FruitSliceTuning.maximumDifficultyVelocityVariation * difficulty
        let horizontalVelocity = CGFloat.random(in: FruitSliceTuning.horizontalLaunchSpeed)
            + centerBias
            + velocityOffset
            + CGFloat.random(in: -variation...variation)
        let verticalVelocity = CGFloat.random(in: FruitSliceTuning.standardLaunchSpeed)
            * launchHeightScale(for: sceneSize.height)

        return makeFruitLaunch(
            position: CGPoint(x: x, y: -42),
            velocity: CGVector(dx: horizontalVelocity, dy: verticalVelocity)
        )
    }

    private func makeHighToss(
        sceneSize: CGSize,
        difficulty: CGFloat
    ) -> FruitLaunchRequest {
        let margin = min(110, max(42, sceneSize.width * 0.16))
        let x = CGFloat.random(in: margin...max(margin, sceneSize.width - margin))
        let centerBias = (sceneSize.width / 2 - x) * 0.12
        let variation = 70 + (difficulty * 80)
        let dx = centerBias + CGFloat.random(in: -variation...variation)
        let dy = CGFloat.random(in: FruitSliceTuning.highLaunchSpeed)
            * launchHeightScale(for: sceneSize.height)

        return makeFruitLaunch(
            position: CGPoint(x: x, y: -44),
            velocity: CGVector(dx: dx, dy: dy)
        )
    }

    private func makeCrossLaunches(
        sceneSize: CGSize,
        difficulty: CGFloat
    ) -> [FruitLaunchRequest] {
        let leftX = max(48, sceneSize.width * 0.14)
        let rightX = min(sceneSize.width - 48, sceneSize.width * 0.86)
        let speedBoost = difficulty * 80
        let horizontalSpeed = CGFloat.random(in: FruitSliceTuning.crossHorizontalSpeed)
            + speedBoost
        let verticalScale = launchHeightScale(for: sceneSize.height)
        let left = makeFruitLaunch(
            position: CGPoint(x: leftX, y: -42),
            velocity: CGVector(
                dx: horizontalSpeed,
                dy: CGFloat.random(in: 1_070...1_260) * verticalScale
            )
        )
        let right = makeFruitLaunch(
            position: CGPoint(x: rightX, y: -42),
            velocity: CGVector(
                dx: -horizontalSpeed,
                dy: CGFloat.random(in: 1_070...1_260) * verticalScale
            )
        )
        return [left, right]
    }

    private func makeFruitLaunch(
        position: CGPoint,
        velocity: CGVector
    ) -> FruitLaunchRequest {
        FruitLaunchRequest(
            kind: .fruit(.random()),
            position: position,
            velocity: velocity,
            angularVelocity: CGFloat.random(in: FruitSliceTuning.angularVelocity)
        )
    }

    private func launchHeightScale(for sceneHeight: CGFloat) -> CGFloat {
        sqrt(SliceGeometry.clamp(sceneHeight / 900, minimum: 0.82, maximum: 1.45))
    }
}

