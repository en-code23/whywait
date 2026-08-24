import CoreGraphics
import Foundation

struct SwordPhysicsDiagnostics {
    let handlePosition: CGPoint
    let targetPosition: CGPoint
    let springForce: CGVector
    let forceWasClamped: Bool
}

final class SwordPhysicsSimulation {
    private(set) var snapshot: SwordTransformSnapshot
    private(set) var cursorTarget: CGPoint
    private(set) var diagnostics: SwordPhysicsDiagnostics
    private(set) var parameters: SwordPhysicsParameters

    init(
        handlePosition: CGPoint = .zero,
        angle: CGFloat = 0,
        parameters: SwordPhysicsParameters = .standard
    ) {
        self.parameters = parameters
        let center = SwordMath.worldPoint(
            center: handlePosition,
            angle: angle,
            localX: -SwordEngineTuning.handleLocalX
        )
        snapshot = SwordTransformSnapshot(
            center: center,
            angle: angle,
            linearVelocity: .zero,
            angularVelocity: 0
        )
        cursorTarget = handlePosition
        diagnostics = SwordPhysicsDiagnostics(
            handlePosition: handlePosition,
            targetPosition: handlePosition,
            springForce: .zero,
            forceWasClamped: false
        )
    }

    func configure(parameters: SwordPhysicsParameters) {
        self.parameters = parameters
        snapshot.linearVelocity = SwordMath.clampedMagnitude(
            snapshot.linearVelocity,
            maximum: parameters.maximumLinearSpeed
        )
        snapshot.angularVelocity = SwordMath.clamp(
            snapshot.angularVelocity,
            minimum: -parameters.maximumAngularSpeed,
            maximum: parameters.maximumAngularSpeed
        )
    }

    func reset(handlePosition: CGPoint, angle: CGFloat = 0) {
        let safeHandle = SwordMath.isFinite(handlePosition) ? handlePosition : .zero
        let safeAngle = angle.isFinite ? angle : 0
        snapshot = SwordTransformSnapshot(
            center: SwordMath.worldPoint(
                center: safeHandle,
                angle: safeAngle,
                localX: -SwordEngineTuning.handleLocalX
            ),
            angle: safeAngle,
            linearVelocity: .zero,
            angularVelocity: 0
        )
        cursorTarget = safeHandle
        diagnostics = SwordPhysicsDiagnostics(
            handlePosition: safeHandle,
            targetPosition: safeHandle,
            springForce: .zero,
            forceWasClamped: false
        )
    }

    func setCursorTarget(_ requestedTarget: CGPoint, allowTeleport: Bool = false) {
        guard SwordMath.isFinite(requestedTarget) else { return }
        if allowTeleport {
            cursorTarget = requestedTarget
            return
        }

        let delta = SwordMath.vector(from: cursorTarget, to: requestedTarget)
        cursorTarget = SwordMath.point(
            cursorTarget,
            adding: SwordMath.clampedMagnitude(
                delta,
                maximum: SwordEngineTuning.maximumCursorTargetStep
            )
        )
    }

    @discardableResult
    func update(deltaTime rawDeltaTime: TimeInterval) -> SwordPhysicsDiagnostics {
        guard rawDeltaTime.isFinite, rawDeltaTime > 0 else { return diagnostics }
        let frameDelta = min(rawDeltaTime, SwordEngineTuning.maximumFrameDelta)
        if parameters.controlMode == .stick {
            return integrateCursorLocked(deltaTime: CGFloat(frameDelta))
        }
        let substepCount = max(
            1,
            Int(ceil(frameDelta / SwordEngineTuning.integrationSubstep))
        )
        let deltaTime = CGFloat(frameDelta / Double(substepCount))

        var lastForce = CGVector.zero
        var wasClamped = false
        for _ in 0..<substepCount {
            let result = integrateSubstep(deltaTime: deltaTime)
            lastForce = result.force
            wasClamped = wasClamped || result.wasClamped
        }

        if !isFinite {
            reset(handlePosition: cursorTarget)
        }
        diagnostics = SwordPhysicsDiagnostics(
            handlePosition: snapshot.handlePoint,
            targetPosition: cursorTarget,
            springForce: lastForce,
            forceWasClamped: wasClamped
        )
        return diagnostics
    }

    func constrain(to bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let margin: CGFloat = 76
        let allowed = bounds.insetBy(dx: -margin, dy: -margin)
        var center = snapshot.center
        var velocity = snapshot.linearVelocity

        if center.x < allowed.minX {
            center.x = allowed.minX
            velocity.dx = max(0, velocity.dx) * 0.3
        } else if center.x > allowed.maxX {
            center.x = allowed.maxX
            velocity.dx = min(0, velocity.dx) * 0.3
        }
        if center.y < allowed.minY {
            center.y = allowed.minY
            velocity.dy = max(0, velocity.dy) * 0.3
        } else if center.y > allowed.maxY {
            center.y = allowed.maxY
            velocity.dy = min(0, velocity.dy) * 0.3
        }

        snapshot.center = center
        snapshot.linearVelocity = velocity
    }

    func applyImpactImpulse(_ impulse: CGVector, at worldPoint: CGPoint) {
        guard SwordMath.isFinite(impulse), SwordMath.isFinite(worldPoint) else { return }
        let boundedImpulse = SwordMath.clampedMagnitude(impulse, maximum: 520)
        snapshot.linearVelocity = SwordMath.add(
            snapshot.linearVelocity,
            SwordMath.scale(boundedImpulse, by: 1 / parameters.mass)
        )
        let lever = SwordMath.vector(from: snapshot.center, to: worldPoint)
        snapshot.angularVelocity += SwordMath.cross(lever, boundedImpulse)
            / parameters.momentOfInertia
        snapshot.linearVelocity = SwordMath.clampedMagnitude(
            snapshot.linearVelocity,
            maximum: parameters.maximumLinearSpeed
        )
        snapshot.angularVelocity = SwordMath.clamp(
            snapshot.angularVelocity,
            minimum: -parameters.maximumAngularSpeed,
            maximum: parameters.maximumAngularSpeed
        )
    }

    var isFinite: Bool {
        SwordMath.isFinite(snapshot.center)
            && SwordMath.isFinite(snapshot.linearVelocity)
            && snapshot.angle.isFinite
            && snapshot.angularVelocity.isFinite
    }

    private func integrateSubstep(deltaTime: CGFloat) -> (force: CGVector, wasClamped: Bool) {
        let handleRadius = SwordMath.vector(from: snapshot.center, to: snapshot.handlePoint)
        let handleVelocity = snapshot.velocity(at: snapshot.handlePoint)
        let positionError = SwordMath.vector(from: snapshot.handlePoint, to: cursorTarget)
        let rawForce = SwordMath.subtract(
            SwordMath.scale(positionError, by: parameters.springStiffness),
            SwordMath.scale(handleVelocity, by: parameters.springDamping)
        )
        let rawMagnitude = SwordMath.magnitude(rawForce)
        let springForce = SwordMath.clampedMagnitude(
            rawForce,
            maximum: parameters.maximumForce
        )

        let acceleration = SwordMath.scale(
            springForce,
            by: 1 / parameters.mass
        )
        snapshot.linearVelocity = SwordMath.add(
            snapshot.linearVelocity,
            SwordMath.scale(acceleration, by: deltaTime)
        )

        let torque = SwordMath.cross(handleRadius, springForce)
        let angularAcceleration = torque / parameters.momentOfInertia
        snapshot.angularVelocity += angularAcceleration * deltaTime

        let linearDecay = exp(-SwordEngineTuning.linearAirDamping * deltaTime)
        let angularDecay = exp(-SwordEngineTuning.angularDamping * deltaTime)
        snapshot.linearVelocity = SwordMath.scale(snapshot.linearVelocity, by: linearDecay)
        snapshot.angularVelocity *= angularDecay

        snapshot.linearVelocity = SwordMath.clampedMagnitude(
            snapshot.linearVelocity,
            maximum: parameters.maximumLinearSpeed
        )
        snapshot.angularVelocity = SwordMath.clamp(
            snapshot.angularVelocity,
            minimum: -parameters.maximumAngularSpeed,
            maximum: parameters.maximumAngularSpeed
        )
        snapshot.center = SwordMath.point(
            snapshot.center,
            adding: SwordMath.scale(snapshot.linearVelocity, by: deltaTime)
        )
        snapshot.angle += snapshot.angularVelocity * deltaTime
        if abs(snapshot.angle) > .pi * 4 {
            snapshot.angle.formTruncatingRemainder(dividingBy: .pi * 2)
        }

        return (springForce, rawMagnitude > parameters.maximumForce)
    }

    private func integrateCursorLocked(deltaTime: CGFloat) -> SwordPhysicsDiagnostics {
        guard deltaTime.isFinite, deltaTime > 0 else { return diagnostics }
        let previousCenter = snapshot.center
        let angularDecay = exp(-SwordEngineTuning.angularDamping * deltaTime)
        snapshot.angularVelocity *= angularDecay
        snapshot.angularVelocity = SwordMath.clamp(
            snapshot.angularVelocity,
            minimum: -parameters.maximumAngularSpeed,
            maximum: parameters.maximumAngularSpeed
        )
        snapshot.angle += snapshot.angularVelocity * deltaTime
        let desiredCenter = SwordMath.worldPoint(
            center: cursorTarget,
            angle: snapshot.angle,
            localX: -SwordEngineTuning.handleLocalX
        )
        snapshot.center = desiredCenter
        snapshot.linearVelocity = SwordMath.clampedMagnitude(
            SwordMath.scale(
                SwordMath.vector(from: previousCenter, to: desiredCenter),
                by: 1 / deltaTime
            ),
            maximum: parameters.maximumLinearSpeed
        )
        if !isFinite {
            reset(handlePosition: cursorTarget)
        }
        diagnostics = SwordPhysicsDiagnostics(
            handlePosition: snapshot.handlePoint,
            targetPosition: cursorTarget,
            springForce: .zero,
            forceWasClamped: false
        )
        return diagnostics
    }
}
