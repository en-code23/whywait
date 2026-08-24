import AppKit
import SpriteKit

/// Procedural presentation for the shared rigid-body sword.
/// Decorative layers use the simulation's exact local landmarks but never own collision geometry.
final class PhysicsSword: SKNode {
    private let bladeShadow = SKShapeNode()
    private let blade = SKShapeNode()
    private let upperFacet = SKShapeNode()
    private let cuttingEdge = SKShapeNode()
    private let fuller = SKShapeNode()
    private let spineHighlight = SKShapeNode()
    private let ricasso = SKShapeNode()
    private let guardShadow = SKShapeNode()
    private let crossGuard = SKShapeNode()
    private let guardInset = SKShapeNode()
    private let gripShadow = SKShapeNode()
    private let grip = SKShapeNode()
    private let gripHighlight = SKShapeNode()
    private let pommelShadow = SKShapeNode()
    private let pommel = SKShapeNode()
    private let pommelInset = SKShapeNode(circleOfRadius: 2.2)

    override init() {
        super.init()
        name = "physics-sword"
        zPosition = 40
        buildVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PhysicsSword does not support NSCoding")
    }

    func apply(_ snapshot: SwordTransformSnapshot) {
        position = snapshot.center
        zRotation = snapshot.angle

        let tipSpeed = SwordMath.magnitude(snapshot.velocity(at: snapshot.bladeTip))
        let energy = SwordMath.clamp(
            tipSpeed / SwordEngineTuning.maximumLinearSpeed,
            minimum: 0,
            maximum: 1
        )
        blade.glowWidth = 0.35 + (energy * 2.1)
        cuttingEdge.glowWidth = energy * 1.8
        spineHighlight.alpha = 0.55 + (energy * 0.4)
        fuller.alpha = 0.48 + (energy * 0.28)
    }

    func setRecovering(_ recovering: Bool) {
        alpha = recovering ? 0.45 : 1
    }

    private func buildVisuals() {
        let bladePath = makeBladePath()

        bladeShadow.path = bladePath
        bladeShadow.position = CGPoint(x: 3.2, y: -4.2)
        bladeShadow.fillColor = NSColor.black.withAlphaComponent(0.23)
        bladeShadow.strokeColor = .clear
        bladeShadow.zPosition = -3

        blade.path = bladePath
        blade.fillColor = NSColor(calibratedRed: 0.70, green: 0.75, blue: 0.79, alpha: 0.98)
        blade.strokeColor = NSColor(calibratedRed: 0.94, green: 0.97, blue: 1, alpha: 0.96)
        blade.lineWidth = 1.1
        blade.glowWidth = 0.35
        blade.zPosition = 1

        let upperPath = CGMutablePath()
        upperPath.move(to: CGPoint(x: SwordEngineTuning.bladeStartLocalX + 1, y: 0.4))
        upperPath.addLine(to: CGPoint(x: SwordEngineTuning.bladeTipLocalX - 14, y: 0.4))
        upperPath.addLine(to: CGPoint(x: SwordEngineTuning.bladeTipLocalX, y: 0))
        upperPath.addLine(to: CGPoint(x: SwordEngineTuning.bladeTipLocalX - 17, y: 3.65))
        upperPath.addLine(to: CGPoint(x: SwordEngineTuning.bladeStartLocalX + 1, y: SwordEngineTuning.bladeHalfWidth - 0.5))
        upperPath.closeSubpath()
        upperFacet.path = upperPath
        upperFacet.fillColor = NSColor(calibratedRed: 0.88, green: 0.92, blue: 0.95, alpha: 0.94)
        upperFacet.strokeColor = .clear
        upperFacet.zPosition = 2

        let edgePath = CGMutablePath()
        edgePath.move(to: CGPoint(x: SwordEngineTuning.bladeStartLocalX + 1, y: -SwordEngineTuning.bladeHalfWidth + 0.5))
        edgePath.addLine(to: CGPoint(x: SwordEngineTuning.bladeTipLocalX - 13, y: -3.25))
        edgePath.addLine(to: CGPoint(x: SwordEngineTuning.bladeTipLocalX, y: 0))
        edgePath.addLine(to: CGPoint(x: SwordEngineTuning.bladeTipLocalX - 18, y: -0.7))
        edgePath.addLine(to: CGPoint(x: SwordEngineTuning.bladeStartLocalX + 1, y: -1.35))
        edgePath.closeSubpath()
        cuttingEdge.path = edgePath
        cuttingEdge.fillColor = NSColor(calibratedRed: 0.48, green: 0.55, blue: 0.62, alpha: 0.92)
        cuttingEdge.strokeColor = NSColor.white.withAlphaComponent(0.5)
        cuttingEdge.lineWidth = 0.55
        cuttingEdge.zPosition = 3

        let fullerPath = CGMutablePath()
        fullerPath.move(to: CGPoint(x: SwordEngineTuning.bladeStartLocalX + 9, y: 0.55))
        fullerPath.addCurve(
            to: CGPoint(x: SwordEngineTuning.bladeTipLocalX - 24, y: 0.28),
            control1: CGPoint(x: 4, y: 1.1),
            control2: CGPoint(x: 50, y: 0.85)
        )
        fuller.path = fullerPath
        fuller.strokeColor = NSColor(calibratedRed: 0.34, green: 0.43, blue: 0.51, alpha: 0.72)
        fuller.lineWidth = 1.15
        fuller.zPosition = 4

        let spinePath = CGMutablePath()
        spinePath.move(to: CGPoint(x: SwordEngineTuning.bladeStartLocalX + 3, y: SwordEngineTuning.bladeHalfWidth - 1.2))
        spinePath.addLine(to: CGPoint(x: SwordEngineTuning.bladeTipLocalX - 17, y: 3.15))
        spineHighlight.path = spinePath
        spineHighlight.strokeColor = NSColor.white.withAlphaComponent(0.82)
        spineHighlight.lineWidth = 0.85
        spineHighlight.zPosition = 5

        ricasso.path = CGPath(
            roundedRect: CGRect(
                x: SwordEngineTuning.bladeStartLocalX - 1,
                y: -SwordEngineTuning.bladeHalfWidth - 0.45,
                width: 11,
                height: (SwordEngineTuning.bladeHalfWidth * 2) + 0.9
            ),
            cornerWidth: 1.8,
            cornerHeight: 1.8,
            transform: nil
        )
        ricasso.fillColor = NSColor(calibratedRed: 0.58, green: 0.64, blue: 0.69, alpha: 0.9)
        ricasso.strokeColor = NSColor.white.withAlphaComponent(0.52)
        ricasso.lineWidth = 0.7
        ricasso.zPosition = 6

        let guardPath = makeGuardPath()
        let guardPosition = CGPoint(x: SwordEngineTuning.bladeStartLocalX - 2, y: 0)
        guardShadow.path = guardPath
        guardShadow.position = CGPoint(x: guardPosition.x + 2.2, y: guardPosition.y - 2.8)
        guardShadow.fillColor = NSColor.black.withAlphaComponent(0.25)
        guardShadow.strokeColor = .clear
        guardShadow.zPosition = 6

        crossGuard.path = guardPath
        crossGuard.position = guardPosition
        crossGuard.fillColor = NSColor(calibratedRed: 0.66, green: 0.48, blue: 0.16, alpha: 1)
        crossGuard.strokeColor = NSColor(calibratedRed: 0.97, green: 0.83, blue: 0.45, alpha: 0.94)
        crossGuard.lineWidth = 1.2
        crossGuard.zPosition = 8

        let guardInsetPath = CGMutablePath()
        guardInsetPath.move(to: CGPoint(x: -0.8, y: -13.5))
        guardInsetPath.addCurve(
            to: CGPoint(x: -0.8, y: 13.5),
            control1: CGPoint(x: 2.8, y: -6),
            control2: CGPoint(x: 2.8, y: 6)
        )
        guardInset.path = guardInsetPath
        guardInset.position = guardPosition
        guardInset.strokeColor = NSColor.white.withAlphaComponent(0.54)
        guardInset.lineWidth = 1
        guardInset.zPosition = 9

        buildGrip()

        addChild(bladeShadow)
        addChild(blade)
        addChild(upperFacet)
        addChild(cuttingEdge)
        addChild(fuller)
        addChild(spineHighlight)
        addChild(ricasso)
        addChild(guardShadow)
        addChild(crossGuard)
        addChild(guardInset)
        addChild(gripShadow)
        addChild(grip)
        addChild(gripHighlight)
        addChild(pommelShadow)
        addChild(pommel)
        pommel.addChild(pommelInset)
    }

    private func buildGrip() {
        let gripStart = SwordEngineTuning.handleLocalX + 2
        let gripWidth = SwordEngineTuning.gripLength - 3
        let gripRect = CGRect(x: gripStart, y: -6.2, width: gripWidth, height: 12.4)
        let gripPath = CGPath(
            roundedRect: gripRect,
            cornerWidth: 5.8,
            cornerHeight: 5.8,
            transform: nil
        )

        gripShadow.path = gripPath
        gripShadow.position = CGPoint(x: 2, y: -2.6)
        gripShadow.fillColor = NSColor.black.withAlphaComponent(0.25)
        gripShadow.strokeColor = .clear
        gripShadow.zPosition = 5

        grip.path = gripPath
        grip.fillColor = NSColor(calibratedRed: 0.16, green: 0.09, blue: 0.075, alpha: 1)
        grip.strokeColor = NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.17, alpha: 0.96)
        grip.lineWidth = 1.3
        grip.zPosition = 7

        for index in 1...7 {
            let x = gripStart + CGFloat(index) * 4.05
            let wrapPath = CGMutablePath()
            wrapPath.move(to: CGPoint(x: x - 2.2, y: -5.1))
            wrapPath.addLine(to: CGPoint(x: x + 2.2, y: 5.1))
            let wrap = SKShapeNode(path: wrapPath)
            wrap.strokeColor = index.isMultiple(of: 2)
                ? NSColor(calibratedRed: 0.72, green: 0.46, blue: 0.22, alpha: 0.72)
                : NSColor.black.withAlphaComponent(0.42)
            wrap.lineWidth = 1.25
            wrap.zPosition = 8
            addChild(wrap)
        }

        let highlightPath = CGMutablePath()
        highlightPath.move(to: CGPoint(x: gripStart + 4, y: 3.9))
        highlightPath.addLine(to: CGPoint(x: gripStart + gripWidth - 5, y: 3.9))
        gripHighlight.path = highlightPath
        gripHighlight.strokeColor = NSColor.white.withAlphaComponent(0.16)
        gripHighlight.lineWidth = 1
        gripHighlight.zPosition = 9

        let pommelPath = CGMutablePath()
        let centerX = SwordEngineTuning.handleLocalX - 3.8
        pommelPath.move(to: CGPoint(x: centerX - 7.5, y: 0))
        pommelPath.addLine(to: CGPoint(x: centerX - 3.8, y: -6.2))
        pommelPath.addLine(to: CGPoint(x: centerX + 3.8, y: -6.2))
        pommelPath.addLine(to: CGPoint(x: centerX + 7.5, y: 0))
        pommelPath.addLine(to: CGPoint(x: centerX + 3.8, y: 6.2))
        pommelPath.addLine(to: CGPoint(x: centerX - 3.8, y: 6.2))
        pommelPath.closeSubpath()
        pommelShadow.path = pommelPath
        pommelShadow.position = CGPoint(x: 2.2, y: -2.5)
        pommelShadow.fillColor = NSColor.black.withAlphaComponent(0.27)
        pommelShadow.strokeColor = .clear
        pommelShadow.zPosition = 5

        pommel.path = pommelPath
        pommel.fillColor = NSColor(calibratedRed: 0.59, green: 0.41, blue: 0.13, alpha: 1)
        pommel.strokeColor = NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.42, alpha: 0.93)
        pommel.lineWidth = 1.1
        pommel.zPosition = 8
        pommelInset.position = CGPoint(x: centerX, y: 0)
        pommelInset.fillColor = NSColor(calibratedRed: 0.22, green: 0.38, blue: 0.48, alpha: 0.95)
        pommelInset.strokeColor = NSColor.white.withAlphaComponent(0.52)
        pommelInset.lineWidth = 0.7
    }

    private func makeBladePath() -> CGPath {
        let path = CGMutablePath()
        let start = SwordEngineTuning.bladeStartLocalX
        let tip = SwordEngineTuning.bladeTipLocalX
        let halfWidth = SwordEngineTuning.bladeHalfWidth
        path.move(to: CGPoint(x: start, y: -halfWidth))
        path.addLine(to: CGPoint(x: tip - 18, y: -4.1))
        path.addLine(to: CGPoint(x: tip, y: 0))
        path.addLine(to: CGPoint(x: tip - 18, y: 4.1))
        path.addLine(to: CGPoint(x: start, y: halfWidth))
        path.closeSubpath()
        return path
    }

    private func makeGuardPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -4.5, y: -19))
        path.addCurve(
            to: CGPoint(x: -1.2, y: -8.5),
            control1: CGPoint(x: -8.5, y: -15.8),
            control2: CGPoint(x: -5.5, y: -10.7)
        )
        path.addLine(to: CGPoint(x: 4.4, y: -5.4))
        path.addCurve(
            to: CGPoint(x: 4.4, y: 5.4),
            control1: CGPoint(x: 7.3, y: -2.5),
            control2: CGPoint(x: 7.3, y: 2.5)
        )
        path.addLine(to: CGPoint(x: -1.2, y: 8.5))
        path.addCurve(
            to: CGPoint(x: -4.5, y: 19),
            control1: CGPoint(x: -5.5, y: 10.7),
            control2: CGPoint(x: -8.5, y: 15.8)
        )
        path.addCurve(
            to: CGPoint(x: -6.8, y: 11.5),
            control1: CGPoint(x: -1.7, y: 18.3),
            control2: CGPoint(x: -2.7, y: 14.3)
        )
        path.addLine(to: CGPoint(x: -4.6, y: 5.2))
        path.addCurve(
            to: CGPoint(x: -4.6, y: -5.2),
            control1: CGPoint(x: -8.1, y: 2.6),
            control2: CGPoint(x: -8.1, y: -2.6)
        )
        path.addLine(to: CGPoint(x: -6.8, y: -11.5))
        path.addCurve(
            to: CGPoint(x: -4.5, y: -19),
            control1: CGPoint(x: -2.7, y: -14.3),
            control2: CGPoint(x: -1.7, y: -18.3)
        )
        path.closeSubpath()
        return path
    }
}
