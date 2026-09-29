import SpriteKit

/// A presentation-only articulated rod. Gameplay still consumes only `tipPosition`.
final class FishingRod: SKNode {
    private enum Metrics {
        static let blankLength: CGFloat = 148
        static let handleLength: CGFloat = 37
        static let guidePositions: [CGFloat] = [57, 83, 108, 130, 145]
    }

    private let groundShadow = SKShapeNode(ellipseOf: CGSize(width: 76, height: 13))
    private let assembly = SKNode()
    private let blankShadow = SKShapeNode()
    private let blank = SKShapeNode()
    private let blankHighlight = SKShapeNode()
    private let guideLayer = SKNode()
    private let throughLine = SKShapeNode()
    private let grip = SKShapeNode(rectOf: CGSize(width: 35, height: 12), cornerRadius: 5)
    private let gripCap = SKShapeNode(circleOfRadius: 6.3)
    private let reelSeat = SKShapeNode(rectOf: CGSize(width: 17, height: 7), cornerRadius: 2.5)
    private let reelStem = SKShapeNode()
    private let reelBody = SKShapeNode(circleOfRadius: 9.5)
    private let spool = SKNode()
    private let crank = SKNode()
    private let chargeGlow = SKShapeNode(circleOfRadius: 10)
    private var guideNodes: [SKShapeNode] = []
    private var localTip = CGPoint(x: Metrics.blankLength, y: 0)
    private var rodAngle: CGFloat = .pi * 0.3
    private var castBend: CGFloat = 0
    private var tensionBend: CGFloat = 0
    private var reelIsTurning = false
    private var targetAngle: CGFloat = .pi * 0.3
    private var angularVelocity: CGFloat = 0
    private var bend: CGFloat = 0
    private var bendVelocity: CGFloat = 0
    private var model: FishingRodModel = .willow

    func equip(_ model: FishingRodModel) {
        self.model = model
        let colors: [FishingRodModel: SKColor] = [
            .willow: SKColor(calibratedRed: 0.43, green: 0.27, blue: 0.12, alpha: 1),
            .tideglass: .systemTeal, .carbon: .lightGray, .abyss: .systemPurple
        ]
        blank.strokeColor = colors[model] ?? .gray
        reelBody.strokeColor = colors[model] ?? .gray
    }

    /// Bounded angular spring and flexible blank; cursor changes aim, never teleports the tip.
    func simulate(deltaTime: TimeInterval) {
        let dt = CGFloat(min(1.0 / 30, max(0, deltaTime)))
        guard dt > 0 else { return }
        let steps = 4
        let h = dt / CGFloat(steps)
        for _ in 0..<steps {
            let error = atan2(sin(targetAngle - rodAngle), cos(targetAngle - rodAngle))
            angularVelocity += (error * model.stiffness - angularVelocity * 13) * h
            angularVelocity = min(5, max(-5, angularVelocity))
            rodAngle += angularVelocity * h
            let targetBend = max(castBend, tensionBend) + angularVelocity * 3.2
            bendVelocity += ((targetBend - bend) * 145 - bendVelocity * 15) * h
            bendVelocity = min(160, max(-160, bendVelocity))
            bend = min(34, max(-24, bend + bendVelocity * h))
        }
        assembly.zRotation = rodAngle
        rebuildBlank()
    }

    var basePosition: CGPoint { position }

    var tipPosition: CGPoint {
        CGPoint(
            x: position.x + (cos(rodAngle) * localTip.x) - (sin(rodAngle) * localTip.y),
            y: position.y + (sin(rodAngle) * localTip.x) + (cos(rodAngle) * localTip.y)
        )
    }

    override init() {
        super.init()
        name = "fishing-rod"
        zPosition = 80
        configure()
        setAim(toward: CGPoint(x: 1, y: 1), power: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FishingRod does not support NSCoding")
    }

    func layout(in sceneSize: CGSize) {
        position = CGPoint(
            x: max(54, sceneSize.width * FishingTuning.rodHorizontalFraction),
            y: max(38, FishingTuning.rodBottomInset)
        )
    }

    func setAim(toward scenePoint: CGPoint, power: CGFloat) {
        let direction = FishingGeometry.normalized(
            FishingGeometry.vector(from: position, to: scenePoint),
            fallback: CGVector(dx: 0.55, dy: 0.84)
        )
        let upward = FishingGeometry.normalized(
            CGVector(dx: direction.dx, dy: max(0.22, direction.dy))
        )
        targetAngle = atan2(upward.dy, upward.dx)
        castBend = CGFloat.fishingClamp(power, 0...1) * 15
        rebuildBlank()

        let normalizedPower = CGFloat.fishingClamp(power, 0...1)
        chargeGlow.position = localTip
        chargeGlow.alpha = normalizedPower * 0.68
        chargeGlow.setScale(0.55 + (normalizedPower * 0.72))
    }

    /// Bends the blank and turns the reel without changing fight rules or line tuning.
    func updateFightVisual(tension: CGFloat, isReeling: Bool) {
        let target = CGFloat.fishingClamp(tension, 0...1.2) * 18
        tensionBend += (target - tensionBend) * 0.18
        castBend = 0
        rebuildBlank()
        setReelTurning(isReeling)
    }

    func pulseRelease() {
        bendVelocity = -120
        castBend = 0
        chargeGlow.alpha = 0
    }

    func resetVisual() {
        chargeGlow.alpha = 0
        assembly.removeAllActions()
        assembly.zRotation = rodAngle
        castBend = 0
        tensionBend = 0
        angularVelocity = 0
        bendVelocity = 0
        bend = 0
        setReelTurning(false)
        rebuildBlank()
    }

    private func configure() {
        groundShadow.position = CGPoint(x: 17, y: -9)
        groundShadow.fillColor = SKColor.black.withAlphaComponent(0.24)
        groundShadow.strokeColor = .clear
        groundShadow.zRotation = -0.12
        addChild(groundShadow)

        addChild(assembly)

        grip.fillColor = SKColor(calibratedRed: 0.19, green: 0.12, blue: 0.08, alpha: 0.98)
        grip.strokeColor = SKColor(calibratedRed: 0.49, green: 0.31, blue: 0.18, alpha: 0.9)
        grip.lineWidth = 1.1
        grip.position = CGPoint(x: Metrics.handleLength * 0.48, y: 0)
        assembly.addChild(grip)

        gripCap.fillColor = SKColor(calibratedWhite: 0.1, alpha: 1)
        gripCap.strokeColor = SKColor.white.withAlphaComponent(0.28)
        gripCap.lineWidth = 1
        assembly.addChild(gripCap)

        for index in 0..<5 {
            let wrap = SKShapeNode(rectOf: CGSize(width: 1.4, height: 10), cornerRadius: 0.7)
            wrap.fillColor = SKColor(calibratedRed: 0.56, green: 0.35, blue: 0.19, alpha: 0.7)
            wrap.strokeColor = .clear
            wrap.position = CGPoint(x: 8 + CGFloat(index) * 5.6, y: 0)
            wrap.zRotation = -0.16
            assembly.addChild(wrap)
        }

        reelSeat.fillColor = SKColor(calibratedWhite: 0.28, alpha: 1)
        reelSeat.strokeColor = SKColor.white.withAlphaComponent(0.55)
        reelSeat.lineWidth = 0.8
        reelSeat.position = CGPoint(x: 35, y: 0)
        assembly.addChild(reelSeat)

        let stemPath = CGMutablePath()
        stemPath.move(to: CGPoint(x: 34, y: -2))
        stemPath.addQuadCurve(to: CGPoint(x: 30, y: -14), control: CGPoint(x: 38, y: -9))
        reelStem.path = stemPath
        reelStem.strokeColor = SKColor(calibratedWhite: 0.55, alpha: 0.95)
        reelStem.lineWidth = 3
        reelStem.lineCap = .round
        assembly.addChild(reelStem)

        reelBody.fillColor = SKColor(calibratedRed: 0.12, green: 0.24, blue: 0.29, alpha: 0.98)
        reelBody.strokeColor = SKColor(calibratedRed: 0.58, green: 0.79, blue: 0.86, alpha: 0.9)
        reelBody.lineWidth = 1.4
        reelBody.position = CGPoint(x: 27, y: -19)
        assembly.addChild(reelBody)
        configureSpool()
        configureCrank()

        blankShadow.strokeColor = SKColor.black.withAlphaComponent(0.42)
        blankShadow.lineWidth = 6.2
        blankShadow.lineCap = .round
        blankShadow.position = CGPoint(x: 0.8, y: -1.4)
        assembly.addChild(blankShadow)

        blank.strokeColor = SKColor(calibratedRed: 0.17, green: 0.34, blue: 0.38, alpha: 1)
        blank.lineWidth = 4.2
        blank.lineCap = .round
        assembly.addChild(blank)

        blankHighlight.strokeColor = SKColor(calibratedRed: 0.62, green: 0.9, blue: 0.91, alpha: 0.78)
        blankHighlight.lineWidth = 1.15
        blankHighlight.lineCap = .round
        blankHighlight.position.y = 1.05
        assembly.addChild(blankHighlight)

        assembly.addChild(guideLayer)
        configureGuides()

        throughLine.strokeColor = SKColor.white.withAlphaComponent(0.68)
        throughLine.lineWidth = 0.72
        throughLine.lineCap = .round
        assembly.addChild(throughLine)

        chargeGlow.fillColor = SKColor(calibratedRed: 0.25, green: 0.78, blue: 1, alpha: 0.14)
        chargeGlow.strokeColor = SKColor(calibratedRed: 0.56, green: 0.92, blue: 1, alpha: 0.92)
        chargeGlow.lineWidth = 1.2
        chargeGlow.alpha = 0
        assembly.addChild(chargeGlow)
        rebuildBlank()
    }

    private func configureSpool() {
        spool.position = reelBody.position
        assembly.addChild(spool)
        let outer = SKShapeNode(circleOfRadius: 6.5)
        outer.fillColor = SKColor(calibratedWhite: 0.13, alpha: 1)
        outer.strokeColor = SKColor(calibratedRed: 0.57, green: 0.84, blue: 0.93, alpha: 0.95)
        outer.lineWidth = 1.1
        spool.addChild(outer)
        for angle in stride(from: CGFloat.zero, to: .pi * 2, by: .pi / 2) {
            let spoke = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: cos(angle) * 5.1, y: sin(angle) * 5.1))
            spoke.path = path
            spoke.strokeColor = SKColor.white.withAlphaComponent(0.4)
            spoke.lineWidth = 0.8
            spool.addChild(spoke)
        }
        let hub = SKShapeNode(circleOfRadius: 2)
        hub.fillColor = SKColor(calibratedRed: 0.76, green: 0.86, blue: 0.89, alpha: 1)
        hub.strokeColor = .clear
        spool.addChild(hub)
    }

    private func configureCrank() {
        crank.position = CGPoint(x: 27, y: -19)
        assembly.addChild(crank)
        let arm = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 11, y: -2))
        arm.path = path
        arm.strokeColor = SKColor(calibratedWhite: 0.65, alpha: 0.9)
        arm.lineWidth = 1.8
        arm.lineCap = .round
        crank.addChild(arm)
        let knob = SKShapeNode(ellipseOf: CGSize(width: 7, height: 4.5))
        knob.position = CGPoint(x: 12.5, y: -2.3)
        knob.fillColor = SKColor(calibratedWhite: 0.11, alpha: 1)
        knob.strokeColor = SKColor.white.withAlphaComponent(0.42)
        knob.lineWidth = 0.7
        crank.addChild(knob)
    }

    private func configureGuides() {
        guideNodes.removeAll(keepingCapacity: true)
        guideLayer.removeAllChildren()
        for (index, x) in Metrics.guidePositions.enumerated() {
            let guide = SKShapeNode(ellipseOf: CGSize(
                width: index == Metrics.guidePositions.count - 1 ? 4.2 : 5.8,
                height: index == Metrics.guidePositions.count - 1 ? 7 : 9
            ))
            guide.fillColor = .clear
            guide.strokeColor = SKColor(calibratedWhite: 0.72, alpha: 0.92)
            guide.lineWidth = index == Metrics.guidePositions.count - 1 ? 0.8 : 1.1
            guide.position.x = x
            guideLayer.addChild(guide)
            guideNodes.append(guide)
        }
    }

    private func rebuildBlank() {
        let totalBend = bend
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 34, y: 0))
        path.addCurve(
            to: CGPoint(x: Metrics.blankLength, y: -totalBend),
            control1: CGPoint(x: 76, y: 2),
            control2: CGPoint(x: 126, y: -totalBend * 0.35)
        )
        blank.path = path
        blankShadow.path = path
        blankHighlight.path = path
        localTip = CGPoint(x: Metrics.blankLength, y: -totalBend)

        let linePath = CGMutablePath()
        linePath.move(to: CGPoint(x: 27, y: -19))
        linePath.addQuadCurve(to: CGPoint(x: 49, y: 1), control: CGPoint(x: 41, y: -8))
        for (index, guide) in guideNodes.enumerated() {
            let fraction = Metrics.guidePositions[index] / Metrics.blankLength
            let y = -totalBend * pow(fraction, 2.2)
            guide.position = CGPoint(x: Metrics.guidePositions[index], y: y + 3.4)
            linePath.addLine(to: guide.position)
        }
        linePath.addLine(to: localTip)
        throughLine.path = linePath
        chargeGlow.position = localTip
    }

    private func setReelTurning(_ turning: Bool) {
        guard turning != reelIsTurning else { return }
        reelIsTurning = turning
        spool.removeAction(forKey: "spool-turn")
        crank.removeAction(forKey: "crank-turn")
        guard turning else { return }
        let duration = WhyWaitPresentationPreferences.reduceVisualEffects ? 0.5 : 0.28
        spool.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: duration)), withKey: "spool-turn")
        crank.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: duration * 1.2)), withKey: "crank-turn")
    }
}
