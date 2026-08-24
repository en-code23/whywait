import CoreGraphics

enum GrappleCourseArchetype: String, CaseIterable {
    case swing
    case zigzag
    case climb
    case drop
    case gates
    case orbit
}

struct GrappleObstacleDescriptor {
    let center: CGPoint
    let size: CGSize
    let rotation: CGFloat

    var boundingFrame: CGRect {
        let cosine = abs(cos(rotation))
        let sine = abs(sin(rotation))
        let width = (size.width * cosine) + (size.height * sine)
        let height = (size.width * sine) + (size.height * cosine)
        return CGRect(
            x: center.x - (width / 2),
            y: center.y - (height / 2),
            width: width,
            height: height
        )
    }
}

enum GrappleHazardShape {
    case orb(radius: CGFloat)
    case block(size: CGSize)
    case spikes(size: CGSize)
}

struct GrappleHazardDescriptor {
    let center: CGPoint
    let shape: GrappleHazardShape

    var boundingFrame: CGRect {
        switch shape {
        case let .orb(radius):
            CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        case let .block(size), let .spikes(size):
            CGRect(
                x: center.x - (size.width / 2),
                y: center.y - (size.height / 2),
                width: size.width,
                height: size.height
            )
        }
    }
}

struct GrappleCourse {
    let archetype: GrappleCourseArchetype
    let startPosition: CGPoint
    let checkpoints: [CGPoint]
    let checkpointRespawns: [CGPoint]
    let obstacles: [GrappleObstacleDescriptor]
    let hazards: [GrappleHazardDescriptor]
    let goalPosition: CGPoint

    var progressionPoints: [CGPoint] {
        [startPosition] + checkpoints + [goalPosition]
    }

    /// A small solid launch perch gives the player time to choose the first
    /// grapple point. It is derived from the start point so procedural course
    /// generation and retries remain deterministic and the course itself does
    /// not need another persisted field.
    var launchPlatform: GrappleObstacleDescriptor {
        let size = GrappleTuning.launchPlatformSize
        return GrappleObstacleDescriptor(
            center: CGPoint(
                x: startPosition.x,
                y: startPosition.y - GrappleTuning.playerRadius - (size.height / 2)
            ),
            size: size,
            rotation: 0
        )
    }
}
