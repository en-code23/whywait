import CoreGraphics
import Foundation

struct GrappleAttachResult {
    let anchor: CGPoint
    let wasClamped: Bool
}

struct GrappleRelease {
    let anchor: CGPoint
    let normalizedTension: CGFloat
}

final class GrappleController {
    private(set) var state: GrappleAttachmentState = .detached
    private(set) var normalizedTension: CGFloat = 0

    var isAttached: Bool {
        if case .attached = state { return true }
        return false
    }

    func attach(
        playerPosition: CGPoint,
        requestedAnchor: CGPoint
    ) -> GrappleAttachResult? {
        let distance = GrapplePhysics.distance(from: playerPosition, to: requestedAnchor)
        guard distance >= GrappleTuning.minimumGrappleDistance,
              let direction = GrapplePhysics.normalizedVector(
                from: playerPosition,
                to: requestedAnchor
              ) else {
            return nil
        }

        let wasClamped = distance > GrappleTuning.maximumGrappleDistance
        let ropeLength = min(distance, GrappleTuning.maximumGrappleDistance)
        let anchor = wasClamped
            ? CGPoint(
                x: playerPosition.x + (direction.dx * ropeLength),
                y: playerPosition.y + (direction.dy * ropeLength)
            )
            : requestedAnchor
        state = .attached(anchor: anchor, ropeLength: ropeLength)
        normalizedTension = 0
        return GrappleAttachResult(anchor: anchor, wasClamped: wasClamped)
    }

    func ropeForce(
        playerPosition: CGPoint,
        playerVelocity: CGVector,
        deltaTime: TimeInterval
    ) -> GrappleRopeForce {
        guard case let .attached(anchor, currentLength) = state else {
            normalizedTension = 0
            return GrappleRopeForce(force: .zero, stretch: 0, normalizedTension: 0)
        }

        let safeDeltaTime = min(
            max(deltaTime, 0),
            GrappleTuning.maximumPhysicsDeltaTime
        )
        let shortenedLength = max(
            GrappleTuning.minimumGrappleDistance,
            currentLength - (GrappleTuning.ropeRetractionSpeed * CGFloat(safeDeltaTime))
        )
        state = .attached(anchor: anchor, ropeLength: shortenedLength)

        let result = GrapplePhysics.ropeForce(
            playerPosition: playerPosition,
            playerVelocity: playerVelocity,
            anchor: anchor,
            ropeLength: shortenedLength
        )
        normalizedTension = result.normalizedTension
        return result
    }

    func enforceConstraint(
        playerPosition: CGPoint,
        playerVelocity: CGVector
    ) -> GrappleConstraintResult? {
        guard case let .attached(anchor, ropeLength) = state else {
            return nil
        }
        return GrapplePhysics.constrainedToRope(
            playerPosition: playerPosition,
            playerVelocity: playerVelocity,
            anchor: anchor,
            ropeLength: ropeLength
        )
    }

    func detach() -> GrappleRelease? {
        guard case let .attached(anchor, _) = state else {
            return nil
        }

        let release = GrappleRelease(
            anchor: anchor,
            normalizedTension: normalizedTension
        )
        state = .detached
        normalizedTension = 0
        return release
    }

    func reset() {
        state = .detached
        normalizedTension = 0
    }
}
