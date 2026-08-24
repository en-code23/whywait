import SpriteKit

final class RopeRenderer: SKNode {
    private let ropeShadow = SKShapeNode()
    private let ropeCore = SKShapeNode()
    private let ropeHighlight = SKShapeNode()
    private let anchorMarker = SKNode()
    private let anchorHalo = SKShapeNode(circleOfRadius: 8)
    private let anchorHook = SKShapeNode(path: RopeRenderer.makeHookPath())
    private let aimMarker = SKNode()
    private let aimRing = SKShapeNode(circleOfRadius: 5.5)
    private let aimTicks = SKShapeNode(path: RopeRenderer.makeAimTicksPath())
    private let playerSwivel = SKShapeNode(circleOfRadius: 3)
    private let transientLayer = SKNode()
    private let reduceVisualEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("RopeRenderer does not support NSCoding")
    }

    func update(
        playerPosition: CGPoint,
        attachment: GrappleAttachmentState,
        normalizedTension: CGFloat
    ) {
        guard case let .attached(anchor, _) = attachment else {
            ropeShadow.isHidden = true
            ropeCore.isHidden = true
            ropeHighlight.isHidden = true
            playerSwivel.isHidden = true
            anchorMarker.isHidden = true
            return
        }

        let tension = min(max(normalizedTension, 0), 1)
        let distance = GrapplePhysics.distance(from: playerPosition, to: anchor)
        let sag = reduceVisualEffects ? 0 : (1 - tension) * min(16, distance * 0.035)
        let midpoint = CGPoint(
            x: (playerPosition.x + anchor.x) / 2,
            y: ((playerPosition.y + anchor.y) / 2) - sag
        )
        let path = CGMutablePath()
        path.move(to: playerPosition)
        path.addQuadCurve(to: anchor, control: midpoint)

        ropeShadow.path = path
        ropeShadow.lineWidth = 4.1 + (tension * 1.2)
        ropeShadow.alpha = 0.24 + (tension * 0.14)
        ropeShadow.isHidden = false

        ropeCore.path = path
        ropeCore.lineWidth = 2.1 + (tension * 1.15)
        ropeCore.strokeColor = SKColor(
            calibratedRed: 0.34 + (tension * 0.36),
            green: 0.68 + (tension * 0.2),
            blue: 0.78 + (tension * 0.18),
            alpha: 0.9
        )
        ropeCore.glowWidth = reduceVisualEffects ? 0 : tension * 1.3
        ropeCore.isHidden = false

        ropeHighlight.path = path
        ropeHighlight.lineWidth = 0.7
        ropeHighlight.alpha = 0.32 + (tension * 0.44)
        ropeHighlight.isHidden = false

        let ropeAngle = atan2(
            playerPosition.y - anchor.y,
            playerPosition.x - anchor.x
        )
        anchorMarker.position = anchor
        anchorMarker.zRotation = ropeAngle - (.pi / 2)
        anchorMarker.setScale(1 + (tension * 0.16))
        anchorHalo.alpha = 0.2 + (tension * 0.28)
        anchorHalo.glowWidth = reduceVisualEffects ? 0 : tension * 2
        anchorHook.strokeColor = SKColor(
            calibratedRed: 0.56 + tension * 0.28,
            green: 0.89 + tension * 0.08,
            blue: 1,
            alpha: 0.98
        )
        anchorMarker.isHidden = false

        playerSwivel.position = playerPosition
        playerSwivel.setScale(0.88 + tension * 0.22)
        playerSwivel.isHidden = false
        aimMarker.isHidden = true
    }

    func showAim(at cursor: CGPoint, from player: CGPoint) {
        let distance = GrapplePhysics.distance(from: player, to: cursor)
        let inRange = distance >= GrappleTuning.minimumGrappleDistance
            && distance <= GrappleTuning.maximumGrappleDistance
        let color = inRange
            ? SKColor(calibratedRed: 0.42, green: 0.95, blue: 0.72, alpha: 0.88)
            : SKColor(calibratedRed: 1, green: 0.36, blue: 0.3, alpha: 0.86)
        aimMarker.position = cursor
        aimRing.strokeColor = color
        aimTicks.strokeColor = color.withAlphaComponent(0.68)
        aimMarker.setScale(inRange ? 1 : 0.88)
        aimMarker.isHidden = false
    }

    func hideAim() {
        aimMarker.isHidden = true
    }

    func showRejectedAnchor(at position: CGPoint) {
        makeRoomForTransient()
        let marker = SKNode()
        marker.position = position

        let ring = SKShapeNode(circleOfRadius: 7)
        ring.fillColor = SKColor.black.withAlphaComponent(0.08)
        ring.strokeColor = SKColor(calibratedRed: 1, green: 0.3, blue: 0.26, alpha: 0.9)
        ring.lineWidth = 1.8
        marker.addChild(ring)

        let crossPath = CGMutablePath()
        crossPath.move(to: CGPoint(x: -3, y: -3))
        crossPath.addLine(to: CGPoint(x: 3, y: 3))
        crossPath.move(to: CGPoint(x: -3, y: 3))
        crossPath.addLine(to: CGPoint(x: 3, y: -3))
        let cross = SKShapeNode(path: crossPath)
        cross.strokeColor = ring.strokeColor
        cross.lineWidth = 1.4
        cross.lineCap = .round
        marker.addChild(cross)

        transientLayer.addChild(marker)
        marker.run(
            .sequence([
                .group([
                    .scale(to: reduceVisualEffects ? 1.25 : 1.7, duration: 0.2),
                    .fadeOut(withDuration: 0.2)
                ]),
                .removeFromParent()
            ])
        )
    }

    func showRelease(at anchor: CGPoint, intensity: CGFloat) {
        guard intensity > 0 else {
            return
        }
        makeRoomForTransient()
        let snap = SKShapeNode(circleOfRadius: 5)
        snap.position = anchor
        snap.fillColor = .clear
        snap.strokeColor = SKColor.white.withAlphaComponent(0.78)
        snap.lineWidth = 1.2 + intensity
        transientLayer.addChild(snap)
        snap.run(
            .sequence([
                .group([
                    .scale(to: (reduceVisualEffects ? 1.35 : 1.8) + intensity, duration: 0.16),
                    .fadeOut(withDuration: 0.16)
                ]),
                .removeFromParent()
            ])
        )
    }

    func reset() {
        ropeShadow.path = nil
        ropeCore.path = nil
        ropeHighlight.path = nil
        ropeShadow.isHidden = true
        ropeCore.isHidden = true
        ropeHighlight.isHidden = true
        playerSwivel.isHidden = true
        anchorMarker.isHidden = true
        aimMarker.isHidden = true
        transientLayer.removeAllChildren()
    }

    private func configure() {
        name = "grapple-rope-renderer"
        zPosition = 55

        ropeShadow.strokeColor = SKColor.black.withAlphaComponent(0.8)
        ropeShadow.lineCap = .round
        ropeShadow.isHidden = true
        addChild(ropeShadow)

        ropeCore.lineCap = .round
        ropeCore.isHidden = true
        addChild(ropeCore)

        ropeHighlight.strokeColor = SKColor.white.withAlphaComponent(0.9)
        ropeHighlight.lineCap = .round
        ropeHighlight.isHidden = true
        addChild(ropeHighlight)

        anchorHalo.fillColor = SKColor(calibratedRed: 0.3, green: 0.83, blue: 1, alpha: 0.3)
        anchorHalo.strokeColor = .clear
        anchorMarker.addChild(anchorHalo)

        anchorHook.fillColor = .clear
        anchorHook.strokeColor = SKColor(calibratedRed: 0.58, green: 0.9, blue: 1, alpha: 0.98)
        anchorHook.lineWidth = 1.8
        anchorHook.lineCap = .round
        anchorHook.lineJoin = .round
        anchorMarker.addChild(anchorHook)
        anchorMarker.isHidden = true
        addChild(anchorMarker)

        aimRing.fillColor = SKColor.black.withAlphaComponent(0.06)
        aimRing.lineWidth = 1.3
        aimMarker.addChild(aimRing)
        aimTicks.fillColor = .clear
        aimTicks.lineWidth = 1
        aimTicks.lineCap = .round
        aimMarker.addChild(aimTicks)
        aimMarker.isHidden = true
        addChild(aimMarker)

        playerSwivel.fillColor = SKColor(calibratedWhite: 0.12, alpha: 0.9)
        playerSwivel.strokeColor = SKColor(calibratedRed: 0.62, green: 0.94, blue: 1, alpha: 0.9)
        playerSwivel.lineWidth = 1
        playerSwivel.isHidden = true
        addChild(playerSwivel)

        addChild(transientLayer)
    }

    private func makeRoomForTransient() {
        while transientLayer.children.count >= 12 {
            transientLayer.children.first?.removeFromParent()
        }
    }

    private static func makeHookPath() -> CGPath {
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -2.2, y: 5.5, width: 4.4, height: 4.4))
        path.move(to: CGPoint(x: 0, y: 5.5))
        path.addLine(to: CGPoint(x: 0, y: -4))
        path.addCurve(
            to: CGPoint(x: -7, y: -1),
            control1: CGPoint(x: -1, y: -8),
            control2: CGPoint(x: -6, y: -6)
        )
        path.move(to: CGPoint(x: 0, y: -4))
        path.addCurve(
            to: CGPoint(x: 7, y: -1),
            control1: CGPoint(x: 1, y: -8),
            control2: CGPoint(x: 6, y: -6)
        )
        return path
    }

    private static func makeAimTicksPath() -> CGPath {
        let path = CGMutablePath()
        for angle in stride(from: CGFloat(0), to: .pi * 2, by: .pi / 2) {
            path.move(to: CGPoint(x: cos(angle) * 8, y: sin(angle) * 8))
            path.addLine(to: CGPoint(x: cos(angle) * 11, y: sin(angle) * 11))
        }
        return path
    }
}
