import SpriteKit

final class GrappleTrail: SKNode {
    private var history: [CGPoint] = []
    private var segments: [SKShapeNode] = []
    private let trailsEnabled = WhyWaitPresentationPreferences.cursorTrailsEnabled
    private let reduceVisualEffects = WhyWaitPresentationPreferences.reduceVisualEffects

    override init() {
        super.init()
        name = "grapple-player-trail"
        zPosition = 45
        configureSegments()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GrappleTrail does not support NSCoding")
    }

    func update(position: CGPoint, speed: CGFloat) {
        guard trailsEnabled,
              speed >= GrappleTuning.trailMinimumSpeed else {
            history.removeAll(keepingCapacity: true)
            segments.forEach { $0.isHidden = true }
            return
        }

        history.insert(position, at: 0)
        let maximumHistory = GrappleTuning.trailSampleCount * 2 + 2
        if history.count > maximumHistory {
            history.removeLast(history.count - maximumHistory)
        }

        let speedRatio = min(1, speed / GrappleTuning.maximumPlayerSpeed)
        let visibleCount = reduceVisualEffects ? max(3, segments.count / 2) : segments.count
        for (index, segment) in segments.enumerated() {
            let sampleIndex = (index + 1) * 2
            guard index < visibleCount,
                  history.indices.contains(sampleIndex),
                  history.indices.contains(sampleIndex + 1) else {
                segment.isHidden = true
                continue
            }

            let age = CGFloat(index + 1) / CGFloat(visibleCount + 1)
            let path = CGMutablePath()
            path.move(to: history[sampleIndex])
            path.addLine(to: history[sampleIndex + 1])
            segment.path = path
            segment.strokeColor = SKColor(
                calibratedRed: 0.34 + speedRatio * 0.2,
                green: 0.78 + speedRatio * 0.16,
                blue: 1,
                alpha: (0.5 - age * 0.38) * (0.45 + speedRatio * 0.55)
            )
            segment.lineWidth = (5.2 - age * 3.6) * (0.55 + speedRatio * 0.45)
            segment.glowWidth = reduceVisualEffects ? 0 : max(0, speedRatio * 1.8 - age)
            segment.isHidden = false
        }
    }

    func reset(at position: CGPoint? = nil) {
        history.removeAll(keepingCapacity: true)
        if let position {
            history.append(position)
        }
        segments.forEach {
            $0.path = nil
            $0.isHidden = true
        }
    }

    private func configureSegments() {
        for _ in 0..<GrappleTuning.trailSampleCount {
            let segment = SKShapeNode()
            segment.fillColor = .clear
            segment.lineCap = .round
            segment.isHidden = true
            addChild(segment)
            segments.append(segment)
        }
    }
}
