import SpriteKit

enum FishBodyArchetype: String, CaseIterable {
    case sunfish
    case streamlined
    case bass
    case carp
    case catfish
    case eel
    case pike
    case sturgeon
    case giant
    case flatfish
    case shark
    case ray
    case billfish
}

private struct FishVisualProfile {
    let archetype: FishBodyArchetype
    let heightRatio: CGFloat
    let tailScale: CGFloat
    let dorsalScale: CGFloat
    let noseExtension: CGFloat

    static func make(for definition: FishDefinition) -> FishVisualProfile {
        switch definition.id {
        case "bluegill":
            return FishVisualProfile(archetype: .sunfish, heightRatio: 0.72, tailScale: 0.72, dorsalScale: 1.25, noseExtension: 0)
        case "crucian-carp", "common-carp", "koi", "golden-koi":
            return FishVisualProfile(archetype: .carp, heightRatio: 0.56, tailScale: 0.9, dorsalScale: 0.92, noseExtension: 0)
        case "channel-catfish", "redtail-catfish":
            return FishVisualProfile(archetype: .catfish, heightRatio: 0.39, tailScale: 0.9, dorsalScale: 0.55, noseExtension: 0.04)
        case "eel":
            return FishVisualProfile(archetype: .eel, heightRatio: 0.2, tailScale: 0.5, dorsalScale: 0.3, noseExtension: 0.03)
        case "northern-pike", "muskie", "alligator-gar", "giant-snakehead":
            return FishVisualProfile(
                archetype: .pike,
                heightRatio: definition.id == "alligator-gar" ? 0.24 : 0.3,
                tailScale: 1.05,
                dorsalScale: 0.6,
                noseExtension: definition.id == "alligator-gar" ? 0.18 : 0.09
            )
        case "lake-sturgeon", "ancient-sturgeon":
            return FishVisualProfile(archetype: .sturgeon, heightRatio: 0.32, tailScale: 1.1, dorsalScale: 0.58, noseExtension: 0.12)
        case "smallmouth-bass", "largemouth-bass", "peacock-bass":
            return FishVisualProfile(archetype: .bass, heightRatio: 0.43, tailScale: 0.92, dorsalScale: 0.88, noseExtension: 0.04)
        case "arapaima", "midnight-leviathan":
            return FishVisualProfile(archetype: .giant, heightRatio: 0.31, tailScale: 1.05, dorsalScale: 0.62, noseExtension: 0.06)
        case "sand-flounder":
            return FishVisualProfile(archetype: .flatfish, heightRatio: 0.64, tailScale: 0.62, dorsalScale: 0.38, noseExtension: 0.02)
        case "blacktip-shark", "blue-shark", "hammerhead-shark", "whale-shark":
            return FishVisualProfile(archetype: .shark, heightRatio: 0.3, tailScale: 1.28, dorsalScale: 1.35, noseExtension: definition.id == "hammerhead-shark" ? 0.14 : 0.07)
        case "moon-manta", "starfall-manta":
            return FishVisualProfile(archetype: .ray, heightRatio: 0.78, tailScale: 1.9, dorsalScale: 0.18, noseExtension: 0.02)
        case "swordfish":
            return FishVisualProfile(archetype: .billfish, heightRatio: 0.27, tailScale: 1.15, dorsalScale: 0.84, noseExtension: 0.32)
        case "abyssal-oarfish":
            return FishVisualProfile(archetype: .eel, heightRatio: 0.16, tailScale: 0.42, dorsalScale: 0.65, noseExtension: 0.03)
        default:
            return FishVisualProfile(archetype: .streamlined, heightRatio: 0.38, tailScale: 0.9, dorsalScale: 0.82, noseExtension: 0.02)
        }
    }
}

final class FishNode: SKNode {
    let definition: FishDefinition
    let variant: FishVariant
    let visualArchetype: FishBodyArchetype

    private let profile: FishVisualProfile
    private let bodyDepth = SKShapeNode()
    private let body = SKShapeNode()
    private let tail = SKShapeNode()
    private let dorsalFin = SKShapeNode()
    private let pectoralFin = SKShapeNode()
    private let pelvicFin = SKShapeNode()
    private let eyeWhite = SKShapeNode(circleOfRadius: 2.05)
    private let pupil = SKShapeNode(circleOfRadius: 0.92)
    private let mouth = SKShapeNode()
    private let gill = SKShapeNode()
    private let highlight = SKShapeNode()
    private let lateralLine = SKShapeNode()
    private let detailLayer = SKNode()
    private let aura = SKShapeNode()
    private let bodyWidth: CGFloat
    private let bodyHeight: CGFloat
    private let shadowOnly: Bool
    private var facesRight = true

    init(
        definition: FishDefinition,
        sizePercentile: Double = 0.5,
        variant: FishVariant = .standard,
        shadowOnly: Bool = false
    ) {
        self.definition = definition
        self.variant = variant
        profile = FishVisualProfile.make(for: definition)
        visualArchetype = profile.archetype
        self.shadowOnly = shadowOnly
        let percentile = CGFloat(min(1, max(0, sizePercentile)))
        let speciesWidth = min(82, max(42, 36 + (sqrt(CGFloat(definition.maximumLength)) * 2.15)))
        bodyWidth = speciesWidth * (0.88 + (percentile * 0.24))
        bodyHeight = speciesWidth * profile.heightRatio
        super.init()
        name = "fishing-fish-\(definition.id)"
        zPosition = shadowOnly ? 35 : 92
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FishNode does not support NSCoding")
    }

    func updateMotion(velocity: CGVector, staminaRatio: CGFloat) {
        if abs(velocity.dx) > 8 {
            let shouldFaceRight = velocity.dx >= 0
            if shouldFaceRight != facesRight {
                facesRight = shouldFaceRight
                xScale = abs(xScale) * (shouldFaceRight ? 1 : -1)
            }
        }
        let angle = atan2(velocity.dy, max(22, abs(velocity.dx)))
        zRotation = min(0.38, max(-0.38, angle * 0.48))
        let speed = min(1, FishingGeometry.length(velocity) / FishingTuning.fishVisualMaximumSpeed)
        let fatigue = 1 - CGFloat.fishingClamp(staminaRatio, 0...1)
        yScale = 1 - (speed * 0.07) + (fatigue * 0.025)
        let horizontal = 1 + (speed * 0.09)
        xScale = (facesRight ? 1 : -1) * horizontal
        tail.speed = 0.55 + (speed * 2.2)
        pectoralFin.speed = 0.55 + (speed * 1.25)
        highlight.alpha = shadowOnly ? 0 : 0.42 + (speed * 0.35)
        body.glowWidth = definition.rarity == .legendary
            ? 2.5 + (speed * 2)
            : speed > 0.84 ? 1.1 : 0
    }

    func playHooked() {
        removeAction(forKey: "fish-hooked")
        setScale(0.72)
        run(
            .sequence([
                .group([
                    .scale(to: 1.12, duration: 0.11),
                    .rotate(byAngle: 0.18, duration: 0.11)
                ]),
                .group([
                    .scale(to: 1, duration: 0.12),
                    .rotate(byAngle: -0.18, duration: 0.12)
                ])
            ]),
            withKey: "fish-hooked"
        )
    }

    static func dexPreview(
        definition: FishDefinition,
        discovered: Bool,
        scale: CGFloat = 0.72,
        variant: FishVariant = .standard
    ) -> SKNode {
        let fish = FishNode(
            definition: definition,
            sizePercentile: 0.5,
            variant: variant,
            shadowOnly: !discovered
        )
        fish.setScale(scale)
        if !discovered {
            fish.alpha = 0.46
        }
        return fish
    }

    private func configure() {
        let baseBodyColor = color(
            red: definition.color.red,
            green: definition.color.green,
            blue: definition.color.blue,
            alpha: shadowOnly ? 0.34 : 0.98
        )
        let baseAccentColor = color(
            red: definition.color.accentRed,
            green: definition.color.accentGreen,
            blue: definition.color.accentBlue,
            alpha: shadowOnly ? 0.24 : 0.96
        )
        let bodyColor = variantColor(base: baseBodyColor, accent: false)
        let accentColor = variantColor(base: baseAccentColor, accent: true)
        let silhouette = SKColor.black.withAlphaComponent(shadowOnly ? 0.3 : 0)
        let bodyPath = makeBodyPath()

        if !shadowOnly {
            bodyDepth.path = bodyPath
            bodyDepth.position = CGPoint(x: 0.9, y: -1.8)
            bodyDepth.fillColor = bodyColor.blended(withFraction: 0.42, of: .black) ?? bodyColor
            bodyDepth.strokeColor = .clear
            addChild(bodyDepth)
        }

        body.path = bodyPath
        body.fillColor = shadowOnly ? silhouette : bodyColor
        body.strokeColor = shadowOnly ? .clear : SKColor.white.withAlphaComponent(0.34)
        body.lineWidth = shadowOnly ? 0 : 0.9
        addChild(body)

        configureTail(color: shadowOnly ? silhouette : accentColor)
        configureFins(color: shadowOnly ? silhouette : accentColor)

        guard !shadowOnly else {
            startSecondaryAnimation()
            return
        }

        configureFace(accent: accentColor)
        configureSurfaceDetails(accent: accentColor)
        configureSpeciesDetails(accent: accentColor)
        configureLegendaryTreatment(accent: accentColor)
        configureVariantTreatment(accent: accentColor)
        startSecondaryAnimation()
    }

    private func makeBodyPath() -> CGPath {
        let w = bodyWidth
        let h = bodyHeight
        let tailRoot = -w * 0.43
        let nose = w * (0.46 + profile.noseExtension)
        let topPeak: CGFloat
        let lowerPeak: CGFloat
        switch profile.archetype {
        case .sunfish:
            topPeak = h * 0.58
            lowerPeak = -h * 0.58
        case .carp:
            topPeak = h * 0.54
            lowerPeak = -h * 0.52
        case .catfish:
            topPeak = h * 0.43
            lowerPeak = -h * 0.48
        case .sturgeon:
            topPeak = h * 0.45
            lowerPeak = -h * 0.38
        case .flatfish:
            topPeak = h * 0.5
            lowerPeak = -h * 0.48
        case .ray:
            topPeak = h * 0.62
            lowerPeak = -h * 0.62
        case .shark, .billfish:
            topPeak = h * 0.44
            lowerPeak = -h * 0.38
        default:
            topPeak = h * 0.5
            lowerPeak = -h * 0.5
        }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: tailRoot, y: 0))
        path.addCurve(
            to: CGPoint(x: nose, y: profile.archetype == .sturgeon ? -h * 0.05 : 0),
            control1: CGPoint(x: -w * 0.25, y: topPeak),
            control2: CGPoint(
                x: w * (profile.archetype == .catfish ? 0.36 : 0.3),
                y: topPeak * (profile.archetype == .pike ? 0.72 : 1)
            )
        )
        path.addCurve(
            to: CGPoint(x: tailRoot, y: 0),
            control1: CGPoint(
                x: w * (profile.archetype == .catfish ? 0.42 : 0.3),
                y: lowerPeak
            ),
            control2: CGPoint(x: -w * 0.27, y: lowerPeak)
        )
        path.closeSubpath()
        return path
    }

    private func configureTail(color: SKColor) {
        let rootX = -bodyWidth * 0.42
        let tailLength = bodyWidth * 0.26 * profile.tailScale
        let tailHeight = max(bodyHeight * 0.54, bodyWidth * 0.1) * profile.tailScale
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 1, y: 0))
        path.addCurve(
            to: CGPoint(x: -tailLength, y: tailHeight),
            control1: CGPoint(x: -tailLength * 0.3, y: tailHeight * 0.15),
            control2: CGPoint(x: -tailLength * 0.72, y: tailHeight * 0.76)
        )
        path.addQuadCurve(
            to: CGPoint(x: -tailLength * 0.72, y: 0),
            control: CGPoint(x: -tailLength * 0.92, y: tailHeight * 0.28)
        )
        path.addQuadCurve(
            to: CGPoint(x: -tailLength, y: -tailHeight),
            control: CGPoint(x: -tailLength * 0.92, y: -tailHeight * 0.28)
        )
        path.addCurve(
            to: CGPoint(x: 1, y: 0),
            control1: CGPoint(x: -tailLength * 0.72, y: -tailHeight * 0.76),
            control2: CGPoint(x: -tailLength * 0.3, y: -tailHeight * 0.15)
        )
        tail.path = path
        tail.position = CGPoint(x: rootX, y: 0)
        tail.fillColor = color
        tail.strokeColor = shadowOnly ? .clear : SKColor.white.withAlphaComponent(0.19)
        tail.lineWidth = 0.7
        tail.zPosition = -0.2
        addChild(tail)
    }

    private func configureFins(color: SKColor) {
        let dorsalPath = CGMutablePath()
        dorsalPath.move(to: CGPoint(x: -bodyWidth * 0.18, y: bodyHeight * 0.34))
        dorsalPath.addCurve(
            to: CGPoint(x: bodyWidth * 0.13, y: bodyHeight * 0.39),
            control1: CGPoint(x: -bodyWidth * 0.1, y: bodyHeight * 0.74 * profile.dorsalScale),
            control2: CGPoint(x: bodyWidth * 0.04, y: bodyHeight * 0.68 * profile.dorsalScale)
        )
        dorsalPath.closeSubpath()
        dorsalFin.path = dorsalPath
        dorsalFin.fillColor = color.withAlphaComponent(shadowOnly ? 0.3 : 0.86)
        dorsalFin.strokeColor = .clear
        dorsalFin.zPosition = -0.1
        addChild(dorsalFin)

        let pectoralPath = CGMutablePath()
        pectoralPath.move(to: .zero)
        pectoralPath.addCurve(
            to: CGPoint(x: -bodyWidth * 0.18, y: -bodyHeight * 0.42),
            control1: CGPoint(x: -bodyWidth * 0.01, y: -bodyHeight * 0.2),
            control2: CGPoint(x: -bodyWidth * 0.12, y: -bodyHeight * 0.4)
        )
        pectoralPath.addLine(to: CGPoint(x: bodyWidth * 0.07, y: -bodyHeight * 0.1))
        pectoralPath.closeSubpath()
        pectoralFin.path = pectoralPath
        pectoralFin.position = CGPoint(x: bodyWidth * 0.12, y: -bodyHeight * 0.02)
        pectoralFin.fillColor = color.withAlphaComponent(shadowOnly ? 0.3 : 0.78)
        pectoralFin.strokeColor = shadowOnly ? .clear : SKColor.white.withAlphaComponent(0.14)
        pectoralFin.lineWidth = 0.5
        addChild(pectoralFin)

        let pelvicPath = CGMutablePath()
        pelvicPath.move(to: CGPoint(x: -bodyWidth * 0.16, y: -bodyHeight * 0.31))
        pelvicPath.addLine(to: CGPoint(x: -bodyWidth * 0.3, y: -bodyHeight * 0.55))
        pelvicPath.addLine(to: CGPoint(x: -bodyWidth * 0.04, y: -bodyHeight * 0.34))
        pelvicPath.closeSubpath()
        pelvicFin.path = pelvicPath
        pelvicFin.fillColor = color.withAlphaComponent(shadowOnly ? 0.28 : 0.62)
        pelvicFin.strokeColor = .clear
        pelvicFin.zPosition = -0.1
        addChild(pelvicFin)
    }

    private func configureFace(accent: SKColor) {
        let eyeX = bodyWidth * (0.29 + profile.noseExtension * 0.5)
        eyeWhite.position = CGPoint(x: eyeX, y: bodyHeight * 0.13)
        eyeWhite.fillColor = SKColor.white.withAlphaComponent(0.96)
        eyeWhite.strokeColor = SKColor.black.withAlphaComponent(0.52)
        eyeWhite.lineWidth = 0.65
        addChild(eyeWhite)

        pupil.position = CGPoint(x: eyeX + 0.55, y: bodyHeight * 0.13)
        pupil.fillColor = definition.rarity == .legendary ? accent : SKColor.black.withAlphaComponent(0.92)
        pupil.strokeColor = .clear
        addChild(pupil)

        let mouthPath = CGMutablePath()
        let noseX = bodyWidth * (0.43 + profile.noseExtension)
        mouthPath.move(to: CGPoint(x: noseX - bodyWidth * 0.08, y: -bodyHeight * 0.06))
        mouthPath.addQuadCurve(
            to: CGPoint(x: noseX, y: -bodyHeight * 0.04),
            control: CGPoint(x: noseX - bodyWidth * 0.035, y: -bodyHeight * 0.11)
        )
        mouth.path = mouthPath
        mouth.strokeColor = SKColor.black.withAlphaComponent(0.58)
        mouth.lineWidth = profile.archetype == .bass ? 1.5 : 0.9
        mouth.lineCap = .round
        addChild(mouth)

        let gillPath = CGMutablePath()
        gillPath.move(to: CGPoint(x: bodyWidth * 0.19, y: bodyHeight * 0.24))
        gillPath.addQuadCurve(
            to: CGPoint(x: bodyWidth * 0.17, y: -bodyHeight * 0.24),
            control: CGPoint(x: bodyWidth * 0.09, y: 0)
        )
        gill.path = gillPath
        gill.strokeColor = accent.withAlphaComponent(0.58)
        gill.lineWidth = 1
        gill.lineCap = .round
        addChild(gill)
    }

    private func configureSurfaceDetails(accent: SKColor) {
        let highlightPath = CGMutablePath()
        highlightPath.move(to: CGPoint(x: -bodyWidth * 0.25, y: bodyHeight * 0.22))
        highlightPath.addCurve(
            to: CGPoint(x: bodyWidth * 0.22, y: bodyHeight * 0.25),
            control1: CGPoint(x: -bodyWidth * 0.08, y: bodyHeight * 0.4),
            control2: CGPoint(x: bodyWidth * 0.12, y: bodyHeight * 0.34)
        )
        highlight.path = highlightPath
        highlight.strokeColor = SKColor.white.withAlphaComponent(0.52)
        highlight.lineWidth = max(1, bodyHeight * 0.055)
        highlight.lineCap = .round
        addChild(highlight)

        let lateralPath = CGMutablePath()
        lateralPath.move(to: CGPoint(x: -bodyWidth * 0.34, y: -bodyHeight * 0.02))
        lateralPath.addQuadCurve(
            to: CGPoint(x: bodyWidth * 0.18, y: 0),
            control: CGPoint(x: -bodyWidth * 0.04, y: -bodyHeight * 0.12)
        )
        lateralLine.path = lateralPath
        lateralLine.strokeColor = accent.withAlphaComponent(0.58)
        lateralLine.lineWidth = definition.rarity == .legendary ? 1.8 : 1
        lateralLine.lineCap = .round
        addChild(lateralLine)
        addChild(detailLayer)
    }

    private func configureSpeciesDetails(accent: SKColor) {
        switch visualArchetype {
        case .catfish:
            addBarbels()
        case .sturgeon:
            addScutes(color: accent)
        case .carp:
            addScaleArcs(color: accent)
        case .pike:
            addPredatorMarks(color: accent)
        case .sunfish:
            addVerticalBars(count: 4, color: accent.withAlphaComponent(0.45))
        case .bass:
            addBrokenStripe(color: accent)
        case .eel:
            addDorsalRibbon(color: accent)
        case .giant:
            addGiantScales(color: accent)
        case .flatfish:
            addFlounderSpots(color: accent)
        case .shark:
            addSharkDetails(color: accent)
        case .ray:
            addRayDetails(color: accent)
        case .billfish:
            addBillfishDetails(color: accent)
        case .streamlined:
            if definition.id.contains("trout") {
                addTroutSpots(color: accent)
            } else if definition.id == "perch" {
                addVerticalBars(count: 5, color: accent.withAlphaComponent(0.62))
            }
        }

        if definition.id == "koi" || definition.id == "golden-koi" {
            addKoiPatches(color: accent)
        }
        if definition.id == "alligator-gar" {
            addGarJaw()
        }
        if definition.id == "redtail-catfish" {
            tail.fillColor = SKColor(calibratedRed: 0.82, green: 0.14, blue: 0.08, alpha: 0.96)
        }
    }

    private func addBarbels() {
        let origin = CGPoint(x: bodyWidth * (0.43 + profile.noseExtension), y: -bodyHeight * 0.08)
        for offset in [-0.12, 0.02, 0.15] as [CGFloat] {
            let whisker = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: origin.x - bodyWidth * 0.03, y: origin.y + bodyHeight * offset))
            path.addQuadCurve(
                to: CGPoint(x: origin.x + bodyWidth * 0.24, y: origin.y + bodyHeight * (offset - 0.22)),
                control: CGPoint(x: origin.x + bodyWidth * 0.13, y: origin.y + bodyHeight * (offset + 0.02))
            )
            whisker.path = path
            whisker.strokeColor = SKColor.white.withAlphaComponent(0.62)
            whisker.lineWidth = 0.7
            whisker.lineCap = .round
            detailLayer.addChild(whisker)
        }
    }

    private func addScutes(color: SKColor) {
        for index in 0..<6 {
            let diamond = SKShapeNode(rectOf: CGSize(width: 4.2, height: 4.2), cornerRadius: 0.8)
            diamond.zRotation = .pi / 4
            diamond.position = CGPoint(
                x: -bodyWidth * 0.27 + CGFloat(index) * bodyWidth * 0.105,
                y: bodyHeight * 0.27
            )
            diamond.fillColor = color.withAlphaComponent(0.68)
            diamond.strokeColor = SKColor.white.withAlphaComponent(0.24)
            diamond.lineWidth = 0.5
            detailLayer.addChild(diamond)
        }
    }

    private func addScaleArcs(color: SKColor) {
        for row in 0..<2 {
            for column in 0..<4 {
                let scale = SKShapeNode()
                let path = CGMutablePath()
                path.addArc(
                    center: .zero,
                    radius: 3.2,
                    startAngle: -.pi * 0.1,
                    endAngle: .pi * 0.9,
                    clockwise: false
                )
                scale.path = path
                scale.position = CGPoint(
                    x: -bodyWidth * 0.2 + CGFloat(column) * bodyWidth * 0.11,
                    y: bodyHeight * (0.1 - CGFloat(row) * 0.24)
                )
                scale.strokeColor = color.withAlphaComponent(0.32)
                scale.lineWidth = 0.65
                detailLayer.addChild(scale)
            }
        }
    }

    private func addPredatorMarks(color: SKColor) {
        for index in 0..<5 {
            let mark = SKShapeNode(ellipseOf: CGSize(width: 3.2, height: 1.6))
            mark.position = CGPoint(
                x: -bodyWidth * 0.27 + CGFloat(index) * bodyWidth * 0.12,
                y: index.isMultiple(of: 2) ? bodyHeight * 0.13 : -bodyHeight * 0.12
            )
            mark.fillColor = color.withAlphaComponent(0.62)
            mark.strokeColor = .clear
            detailLayer.addChild(mark)
        }
    }

    private func addVerticalBars(count: Int, color: SKColor) {
        for index in 0..<count {
            let bar = SKShapeNode()
            let x = -bodyWidth * 0.25 + CGFloat(index) * bodyWidth * 0.115
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: bodyHeight * 0.28))
            path.addLine(to: CGPoint(x: x + 2, y: -bodyHeight * 0.29))
            bar.path = path
            bar.strokeColor = color
            bar.lineWidth = 1.5
            bar.lineCap = .round
            detailLayer.addChild(bar)
        }
    }

    private func addBrokenStripe(color: SKColor) {
        for index in 0..<4 {
            let dash = SKShapeNode(rectOf: CGSize(width: bodyWidth * 0.095, height: 2.1), cornerRadius: 1)
            dash.position = CGPoint(x: -bodyWidth * 0.22 + CGFloat(index) * bodyWidth * 0.13, y: -bodyHeight * 0.03)
            dash.fillColor = color.withAlphaComponent(0.65)
            dash.strokeColor = .clear
            detailLayer.addChild(dash)
        }
    }

    private func addDorsalRibbon(color: SKColor) {
        let ribbon = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -bodyWidth * 0.34, y: bodyHeight * 0.2))
        path.addCurve(
            to: CGPoint(x: bodyWidth * 0.18, y: bodyHeight * 0.23),
            control1: CGPoint(x: -bodyWidth * 0.15, y: bodyHeight * 0.44),
            control2: CGPoint(x: bodyWidth * 0.02, y: bodyHeight * 0.42)
        )
        ribbon.path = path
        ribbon.strokeColor = color.withAlphaComponent(0.62)
        ribbon.lineWidth = 1.4
        ribbon.lineCap = .round
        detailLayer.addChild(ribbon)
    }

    private func addGiantScales(color: SKColor) {
        for index in 0..<6 {
            let plate = SKShapeNode(ellipseOf: CGSize(width: 6.5, height: 3.2))
            plate.position = CGPoint(
                x: -bodyWidth * 0.25 + CGFloat(index) * bodyWidth * 0.095,
                y: -bodyHeight * 0.16
            )
            plate.fillColor = color.withAlphaComponent(0.38 + CGFloat(index) * 0.035)
            plate.strokeColor = .clear
            detailLayer.addChild(plate)
        }
    }

    private func addTroutSpots(color: SKColor) {
        for index in 0..<7 {
            let spot = SKShapeNode(circleOfRadius: index.isMultiple(of: 3) ? 1.35 : 0.95)
            spot.position = CGPoint(
                x: -bodyWidth * 0.28 + CGFloat(index) * bodyWidth * 0.09,
                y: index.isMultiple(of: 2) ? bodyHeight * 0.17 : -bodyHeight * 0.13
            )
            spot.fillColor = color.withAlphaComponent(0.75)
            spot.strokeColor = .clear
            detailLayer.addChild(spot)
        }
    }

    private func addKoiPatches(color: SKColor) {
        for (x, y, scale) in [(-0.2, 0.13, 1.0), (0.02, -0.14, 0.78), (0.2, 0.12, 0.66)] as [(CGFloat, CGFloat, CGFloat)] {
            let patch = SKShapeNode(ellipseOf: CGSize(width: 9 * scale, height: 6 * scale))
            patch.position = CGPoint(x: bodyWidth * x, y: bodyHeight * y)
            patch.fillColor = color.withAlphaComponent(0.76)
            patch.strokeColor = .clear
            patch.zRotation = x * 1.2
            detailLayer.addChild(patch)
        }
    }

    private func addGarJaw() {
        let jaw = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: bodyWidth * 0.31, y: -bodyHeight * 0.08))
        path.addLine(to: CGPoint(x: bodyWidth * 0.62, y: -bodyHeight * 0.1))
        jaw.path = path
        jaw.strokeColor = SKColor.white.withAlphaComponent(0.52)
        jaw.lineWidth = 0.8
        jaw.lineCap = .round
        detailLayer.addChild(jaw)
    }

    private func addFlounderSpots(color: SKColor) {
        for index in 0..<6 {
            let spot = SKShapeNode(circleOfRadius: index.isMultiple(of: 2) ? 1.5 : 1)
            spot.position = CGPoint(
                x: -bodyWidth * 0.24 + CGFloat(index) * bodyWidth * 0.09,
                y: index.isMultiple(of: 2) ? bodyHeight * 0.14 : -bodyHeight * 0.13
            )
            spot.fillColor = color.withAlphaComponent(0.58)
            spot.strokeColor = .clear
            detailLayer.addChild(spot)
        }
        eyeWhite.position.y = bodyHeight * 0.23
        pupil.position.y = bodyHeight * 0.23
    }

    private func addSharkDetails(color: SKColor) {
        let belly = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -bodyWidth * 0.31, y: -bodyHeight * 0.08))
        path.addCurve(
            to: CGPoint(x: bodyWidth * 0.36, y: -bodyHeight * 0.08),
            control1: CGPoint(x: -bodyWidth * 0.08, y: -bodyHeight * 0.42),
            control2: CGPoint(x: bodyWidth * 0.2, y: -bodyHeight * 0.32)
        )
        belly.path = path
        belly.strokeColor = SKColor.white.withAlphaComponent(0.48)
        belly.lineWidth = 1.2
        detailLayer.addChild(belly)
        if definition.id == "hammerhead-shark" {
            let hammer = SKShapeNode(rectOf: CGSize(width: 13, height: 4.2), cornerRadius: 2)
            hammer.position = CGPoint(x: bodyWidth * 0.51, y: bodyHeight * 0.04)
            hammer.fillColor = color.withAlphaComponent(0.86)
            hammer.strokeColor = SKColor.white.withAlphaComponent(0.24)
            detailLayer.addChild(hammer)
        }
        if definition.id == "whale-shark" {
            addTroutSpots(color: SKColor.white.withAlphaComponent(0.68))
        }
    }

    private func addRayDetails(color: SKColor) {
        for sign in [-1, 1] as [CGFloat] {
            let wing = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -bodyWidth * 0.05, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: -bodyWidth * 0.35, y: sign * bodyHeight * 0.72),
                control: CGPoint(x: bodyWidth * 0.16, y: sign * bodyHeight * 0.7)
            )
            path.addLine(to: CGPoint(x: bodyWidth * 0.34, y: 0))
            path.closeSubpath()
            wing.path = path
            wing.fillColor = color.withAlphaComponent(0.34)
            wing.strokeColor = SKColor.white.withAlphaComponent(0.16)
            wing.lineWidth = 0.7
            wing.zPosition = -0.05
            detailLayer.addChild(wing)
        }
        let tailLine = SKShapeNode()
        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -bodyWidth * 0.38, y: 0))
        tailPath.addLine(to: CGPoint(x: -bodyWidth * 0.82, y: -2))
        tailLine.path = tailPath
        tailLine.strokeColor = color.withAlphaComponent(0.8)
        tailLine.lineWidth = 1.5
        tailLine.lineCap = .round
        detailLayer.addChild(tailLine)
    }

    private func addBillfishDetails(color: SKColor) {
        let bill = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: bodyWidth * 0.39, y: -bodyHeight * 0.02))
        path.addLine(to: CGPoint(x: bodyWidth * 0.78, y: 0))
        bill.path = path
        bill.strokeColor = color.withAlphaComponent(0.94)
        bill.lineWidth = 2
        bill.lineCap = .round
        detailLayer.addChild(bill)
    }

    private func variantColor(base: SKColor, accent: Bool) -> SKColor {
        switch variant {
        case .standard:
            return base
        case .albino:
            return base.blended(withFraction: accent ? 0.48 : 0.76, of: .white) ?? base
        case .melanistic:
            return base.blended(withFraction: accent ? 0.46 : 0.72, of: .black) ?? base
        case .gilded:
            let gold = SKColor(calibratedRed: 0.98, green: 0.72, blue: 0.16, alpha: 1)
            return base.blended(withFraction: accent ? 0.74 : 0.58, of: gold) ?? base
        case .iridescent:
            let cyan = accent
                ? SKColor(calibratedRed: 0.94, green: 0.35, blue: 0.92, alpha: 1)
                : SKColor(calibratedRed: 0.24, green: 0.8, blue: 0.9, alpha: 1)
            return base.blended(withFraction: 0.62, of: cyan) ?? base
        case .ancient:
            let jade = SKColor(calibratedRed: 0.16, green: 0.66, blue: 0.49, alpha: 1)
            return base.blended(withFraction: accent ? 0.7 : 0.48, of: jade) ?? base
        }
    }

    private func configureVariantTreatment(accent: SKColor) {
        guard variant != .standard else { return }
        body.glowWidth = variant == .ancient || variant == .iridescent ? 4 : 1.5
        body.strokeColor = accent.withAlphaComponent(0.72)
        let sigil = SKShapeNode(circleOfRadius: max(2.2, bodyHeight * 0.1))
        sigil.position = CGPoint(x: -bodyWidth * 0.05, y: bodyHeight * 0.02)
        sigil.fillColor = .clear
        sigil.strokeColor = accent.withAlphaComponent(0.74)
        sigil.lineWidth = 0.8
        detailLayer.addChild(sigil)
    }

    private func configureLegendaryTreatment(accent: SKColor) {
        guard definition.rarity == .legendary else { return }
        aura.path = CGPath(
            ellipseIn: CGRect(
                x: -bodyWidth * 0.65,
                y: -bodyHeight * 0.75,
                width: bodyWidth * 1.3,
                height: bodyHeight * 1.5
            ),
            transform: nil
        )
        aura.fillColor = .clear
        aura.strokeColor = accent.withAlphaComponent(0.42)
        aura.lineWidth = 1
        aura.glowWidth = 4
        aura.zPosition = -1
        addChild(aura)
        guard !WhyWaitPresentationPreferences.reduceVisualEffects else { return }
        aura.run(
            .repeatForever(
                .sequence([
                    .group([.fadeAlpha(to: 0.38, duration: 0.65), .scale(to: 1.05, duration: 0.65)]),
                    .group([.fadeAlpha(to: 0.86, duration: 0.65), .scale(to: 1, duration: 0.65)])
                ])
            )
        )
    }

    private func startSecondaryAnimation() {
        let reduced = WhyWaitPresentationPreferences.reduceVisualEffects
        let amplitude: CGFloat = reduced ? 0.045 : 0.13
        tail.run(
            .repeatForever(
                .sequence([
                    .rotate(toAngle: amplitude, duration: reduced ? 0.45 : 0.22),
                    .rotate(toAngle: -amplitude, duration: reduced ? 0.45 : 0.22)
                ])
            ),
            withKey: "tail-swim"
        )
        guard !reduced else { return }
        pectoralFin.run(
            .repeatForever(
                .sequence([
                    .rotate(toAngle: 0.08, duration: 0.34),
                    .rotate(toAngle: -0.12, duration: 0.34)
                ])
            ),
            withKey: "fin-swim"
        )
    }

    private func color(red: Double, green: Double, blue: Double, alpha: Double) -> SKColor {
        SKColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}
