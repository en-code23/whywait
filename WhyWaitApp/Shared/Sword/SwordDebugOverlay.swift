import AppKit
import SpriteKit

final class SwordDebugOverlay: SKNode {
#if DEBUG
    private let centerMarker = SKShapeNode(circleOfRadius: 4)
    private let handleMarker = SKShapeNode(circleOfRadius: 4)
    private let targetMarker = SKShapeNode(circleOfRadius: 5)
    private let bladeLine = SKShapeNode()
    private let forceLine = SKShapeNode()
    private let velocityLine = SKShapeNode()
    private let contactLayer = SKNode()
    private(set) var isVisualizationEnabled = ProcessInfo.processInfo.environment["WHYWAIT_SWORD_DEBUG"] == "1"
#else
    let isVisualizationEnabled = false
#endif

    override init() {
        super.init()
        name = "sword-debug-overlay"
        zPosition = 120
#if DEBUG
        centerMarker.fillColor = .systemPink
        handleMarker.fillColor = .systemGreen
        targetMarker.fillColor = .systemCyan
        for marker in [centerMarker, handleMarker, targetMarker] {
            marker.strokeColor = .black
            marker.lineWidth = 1
            addChild(marker)
        }
        bladeLine.strokeColor = .systemYellow
        bladeLine.lineWidth = 1
        forceLine.strokeColor = .systemGreen
        forceLine.lineWidth = 1
        velocityLine.strokeColor = .systemPink
        velocityLine.lineWidth = 1
        addChild(bladeLine)
        addChild(forceLine)
        addChild(velocityLine)
        addChild(contactLayer)
        isHidden = !isVisualizationEnabled
#else
        isHidden = true
#endif
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("SwordDebugOverlay does not support NSCoding")
    }

    func update(snapshot: SwordTransformSnapshot, diagnostics: SwordPhysicsDiagnostics) {
#if DEBUG
        guard isVisualizationEnabled else { return }
        centerMarker.position = snapshot.center
        handleMarker.position = snapshot.handlePoint
        targetMarker.position = diagnostics.targetPosition
        bladeLine.path = path(from: snapshot.bladeStart, to: snapshot.bladeTip)
        forceLine.path = path(
            from: snapshot.handlePoint,
            to: SwordMath.point(snapshot.handlePoint, adding: SwordMath.scale(diagnostics.springForce, by: 0.003))
        )
        velocityLine.path = path(
            from: snapshot.bladeTip,
            to: SwordMath.point(snapshot.bladeTip, adding: SwordMath.scale(snapshot.velocity(at: snapshot.bladeTip), by: 0.04))
        )
#endif
    }

    func showContacts(_ points: [CGPoint]) {
#if DEBUG
        guard isVisualizationEnabled else { return }
        contactLayer.removeAllChildren()
        for point in points {
            let marker = SKShapeNode(circleOfRadius: 5)
            marker.position = point
            marker.strokeColor = .systemRed
            marker.fillColor = .clear
            marker.lineWidth = 1
            contactLayer.addChild(marker)
        }
#endif
    }

    func reset() {
#if DEBUG
        contactLayer.removeAllChildren()
#endif
    }

#if DEBUG
    private func path(from start: CGPoint, to end: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
#endif
}
