import SpriteKit

enum GolfHoleRules {
    static func shouldCapture(centerDistance: CGFloat, speed: CGFloat) -> Bool {
        centerDistance <= CursorGolfTuning.holeCaptureDistance
            && speed <= CursorGolfTuning.maximumSinkSpeed
    }

    static func shouldApplyAttraction(centerDistance: CGFloat, speed: CGFloat) -> Bool {
        centerDistance > CursorGolfTuning.holeCaptureDistance
            && centerDistance <= CursorGolfTuning.attractionRadius
            && speed <= CursorGolfTuning.maximumAttractionSpeed
    }
}

final class GolfHole: SKNode {
    let radius = CursorGolfTuning.holeRadius
    private let visualEffectsReduced = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        configureAppearance()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GolfHole does not support NSCoding")
    }

    private func configureAppearance() {
        name = "cursor-golf-hole"
        zPosition = 4

        let shadow = SKShapeNode(ellipseOf: CGSize(width: (radius + 5) * 2, height: radius + 10))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -3.5)
        shadow.zPosition = -2
        addChild(shadow)

        let rimSize = CGSize(width: (radius + 2) * 2, height: radius + 7)
        let rim = SKShapeNode(ellipseOf: rimSize)
        rim.fillColor = SKColor(calibratedRed: 0.58, green: 0.64, blue: 0.64, alpha: 0.9)
        rim.strokeColor = SKColor.white.withAlphaComponent(0.7)
        rim.lineWidth = 1.15
        rim.zPosition = -1
        addChild(rim)

        let opening = SKShapeNode(
            ellipseOf: CGSize(width: (radius - 1.5) * 2, height: radius + 1)
        )
        opening.fillColor = SKColor(calibratedRed: 0.018, green: 0.024, blue: 0.025, alpha: 0.96)
        opening.strokeColor = SKColor.black.withAlphaComponent(0.85)
        opening.lineWidth = 1.2
        opening.position.y = -0.8
        addChild(opening)

        let cupDepth = SKShapeNode(
            ellipseOf: CGSize(width: (radius - 6) * 2, height: radius * 0.5)
        )
        cupDepth.fillColor = SKColor(calibratedWhite: 0.12, alpha: 0.72)
        cupDepth.strokeColor = .clear
        cupDepth.position = CGPoint(x: 0, y: -4.4)
        cupDepth.zPosition = 0.2
        addChild(cupDepth)

        let frontLipPath = CGMutablePath()
        frontLipPath.move(to: CGPoint(x: -radius + 1, y: -1))
        frontLipPath.addCurve(
            to: CGPoint(x: radius - 1, y: -1),
            control1: CGPoint(x: -radius * 0.72, y: -radius * 0.57),
            control2: CGPoint(x: radius * 0.72, y: -radius * 0.57)
        )
        let frontLip = SKShapeNode(path: frontLipPath)
        frontLip.strokeColor = SKColor(calibratedWhite: 0.78, alpha: 0.72)
        frontLip.lineWidth = 2.2
        frontLip.lineCap = .round
        frontLip.zPosition = 1
        addChild(frontLip)

        addFlagstick()
    }

    private func addFlagstick() {
        let poleShadowPath = CGMutablePath()
        poleShadowPath.move(to: CGPoint(x: 2.5, y: 0))
        poleShadowPath.addLine(to: CGPoint(x: 2.5, y: 67))
        let poleShadow = SKShapeNode(path: poleShadowPath)
        poleShadow.strokeColor = SKColor.black.withAlphaComponent(0.32)
        poleShadow.lineWidth = 3.8
        poleShadow.lineCap = .round
        poleShadow.zPosition = 20
        addChild(poleShadow)

        let polePath = CGMutablePath()
        polePath.move(to: CGPoint(x: 0, y: 0))
        polePath.addLine(to: CGPoint(x: 0, y: 68))
        let pole = SKShapeNode(path: polePath)
        pole.strokeColor = SKColor(calibratedWhite: 0.91, alpha: 0.97)
        pole.lineWidth = 2.35
        pole.lineCap = .round
        pole.zPosition = 21
        addChild(pole)

        let poleHighlightPath = CGMutablePath()
        poleHighlightPath.move(to: CGPoint(x: -0.55, y: 4))
        poleHighlightPath.addLine(to: CGPoint(x: -0.55, y: 65))
        let poleHighlight = SKShapeNode(path: poleHighlightPath)
        poleHighlight.strokeColor = SKColor.white.withAlphaComponent(0.76)
        poleHighlight.lineWidth = 0.65
        poleHighlight.zPosition = 22
        addChild(poleHighlight)

        let flagPath = CGMutablePath()
        flagPath.move(to: .zero)
        flagPath.addCurve(
            to: CGPoint(x: 30, y: -3.2),
            control1: CGPoint(x: 9, y: 3),
            control2: CGPoint(x: 21, y: -1)
        )
        flagPath.addCurve(
            to: CGPoint(x: 1, y: -18),
            control1: CGPoint(x: 24, y: -10),
            control2: CGPoint(x: 10, y: -16)
        )
        flagPath.closeSubpath()

        let flag = SKShapeNode(path: flagPath)
        flag.fillColor = SKColor(calibratedRed: 0.9, green: 0.17, blue: 0.17, alpha: 0.96)
        flag.strokeColor = SKColor(calibratedRed: 0.42, green: 0.05, blue: 0.05, alpha: 0.9)
        flag.lineWidth = 1
        flag.position = CGPoint(x: 1, y: 67)
        flag.zPosition = 23
        addChild(flag)

        let foldPath = CGMutablePath()
        foldPath.move(to: CGPoint(x: 8, y: -1.2))
        foldPath.addCurve(
            to: CGPoint(x: 10, y: -13.5),
            control1: CGPoint(x: 11, y: -5),
            control2: CGPoint(x: 8, y: -9)
        )
        let fold = SKShapeNode(path: foldPath)
        fold.strokeColor = SKColor.white.withAlphaComponent(0.3)
        fold.lineWidth = 1
        fold.lineCap = .round
        flag.addChild(fold)

        let cap = SKShapeNode(circleOfRadius: 2.1)
        cap.fillColor = SKColor.white.withAlphaComponent(0.95)
        cap.strokeColor = SKColor.black.withAlphaComponent(0.32)
        cap.lineWidth = 0.7
        cap.position = CGPoint(x: 0, y: 68.4)
        cap.zPosition = 24
        addChild(cap)

        guard !visualEffectsReduced else { return }
        let furl = SKAction.scaleX(to: 0.86, duration: 0.7)
        furl.timingMode = .easeInEaseOut
        let open = SKAction.scaleX(to: 1.04, duration: 0.82)
        open.timingMode = .easeInEaseOut
        flag.run(.repeatForever(.sequence([furl, open])), withKey: "flag-wave")
    }
}
