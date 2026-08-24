import CoreGraphics
import Foundation

enum FishAIState: String, CaseIterable {
    case calm
    case swim
    case burst
    case turn
    case tired
}

struct FishAIPull {
    let state: FishAIState
    let direction: CGVector
    let intensity: CGFloat
}

final class FishAI {
    private let random: FishingRandomSource
    private let definition: FishDefinition
    private(set) var state: FishAIState = .swim
    private var stateTimeRemaining: TimeInterval = 0
    private var direction = CGVector(dx: 1, dy: 0)

    init(definition: FishDefinition, random: FishingRandomSource) {
        self.definition = definition
        self.random = random
        chooseDirection(awayFrom: .zero, fishPosition: .zero)
        stateTimeRemaining = random.value(in: 0.45...0.9)
    }

    func update(
        deltaTime: TimeInterval,
        staminaRatio: CGFloat,
        fishPosition: CGPoint,
        rodPosition: CGPoint
    ) -> FishAIPull {
        let delta = min(FishingTuning.maximumFightDeltaTime, max(0, deltaTime))
        stateTimeRemaining -= delta
        if stateTimeRemaining <= 0 {
            transition(
                staminaRatio: staminaRatio,
                fishPosition: fishPosition,
                rodPosition: rodPosition
            )
        }

        let intensity: CGFloat
        switch state {
        case .calm: intensity = 0.15
        case .swim: intensity = 0.45
        case .burst: intensity = 1
        case .turn: intensity = 0.7
        case .tired: intensity = 0.22
        }
        return FishAIPull(state: state, direction: direction, intensity: intensity)
    }

    private func transition(
        staminaRatio: CGFloat,
        fishPosition: CGPoint,
        rodPosition: CGPoint
    ) {
        let roll = random.nextUnit()
        if staminaRatio < 0.24, roll < 0.62 {
            state = .tired
            stateTimeRemaining = random.value(in: 0.55...1.1)
        } else {
            let burstChance = 0.12 + (definition.agility * 0.28 * Double(staminaRatio))
            let turnChance = 0.2 + (definition.agility * 0.18)
            if roll < burstChance {
                state = .burst
                stateTimeRemaining = random.value(in: 0.22...0.48)
            } else if roll < burstChance + turnChance {
                state = .turn
                stateTimeRemaining = random.value(in: 0.18...0.42)
            } else if roll < 0.8 {
                state = .swim
                stateTimeRemaining = random.value(in: 0.45...0.95)
            } else {
                state = .calm
                stateTimeRemaining = random.value(in: 0.3...0.72)
            }
        }
        chooseDirection(awayFrom: rodPosition, fishPosition: fishPosition)
    }

    private func chooseDirection(awayFrom rodPosition: CGPoint, fishPosition: CGPoint) {
        let away = FishingGeometry.normalized(
            FishingGeometry.vector(from: rodPosition, to: fishPosition),
            fallback: CGVector(dx: 1, dy: 0.25)
        )
        let variation = CGFloat(random.value(in: -1.05...1.05))
        let cosine = cos(variation)
        let sine = sin(variation)
        direction = FishingGeometry.normalized(
            CGVector(
                dx: (away.dx * cosine) - (away.dy * sine),
                dy: (away.dx * sine) + (away.dy * cosine)
            )
        )
    }
}

