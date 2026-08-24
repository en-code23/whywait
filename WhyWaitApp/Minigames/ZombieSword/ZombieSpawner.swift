import AppKit
import Foundation
import SpriteKit

final class ZombieSpawnWarning: SKNode {
    let type: ZombieType
    let spawnPosition: CGPoint
    private(set) var remaining: TimeInterval

    init(type: ZombieType, position: CGPoint, edge: ZombieSpawnEdge) {
        self.type = type
        spawnPosition = position
        remaining = ZombieSwordTuning.spawnWarningDuration
        super.init()
        self.position = position
        name = "zombie-spawn-warning"
        zPosition = 58

        let markerScale = SwordMath.clamp(type.stats.radius / 23, minimum: 0.78, maximum: 1.3)
        let ring = SKShapeNode(circleOfRadius: 10 * markerScale)
        ring.strokeColor = NSColor.systemOrange.withAlphaComponent(0.76)
        ring.lineWidth = 2
        ring.fillColor = NSColor.systemOrange.withAlphaComponent(0.08)
        ring.glowWidth = WhyWaitPresentationPreferences.reduceVisualEffects ? 0 : 2
        addChild(ring)

        let outerRing = SKShapeNode(circleOfRadius: 15 * markerScale)
        outerRing.strokeColor = NSColor.systemOrange.withAlphaComponent(0.32)
        outerRing.lineWidth = 1
        outerRing.fillColor = .clear
        addChild(outerRing)

        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: -7, y: -6))
        arrowPath.addLine(to: CGPoint(x: 2, y: 0))
        arrowPath.addLine(to: CGPoint(x: -7, y: 6))
        let arrow = SKShapeNode(path: arrowPath)
        arrow.strokeColor = NSColor.systemOrange.withAlphaComponent(0.96)
        arrow.lineWidth = 2.2
        arrow.lineCap = .round
        arrow.lineJoin = .round
        arrow.zRotation = edge.inwardAngle
        addChild(arrow)

        let typeCore = SKShapeNode(
            rectOf: CGSize(width: 4.5 * markerScale, height: 7 * markerScale),
            cornerRadius: 2 * markerScale
        )
        typeCore.position = CGPoint(x: 0, y: -1)
        typeCore.fillColor = type.bodyColor.withAlphaComponent(0.92)
        typeCore.strokeColor = NSColor.white.withAlphaComponent(0.62)
        typeCore.lineWidth = 0.7
        typeCore.zPosition = 2
        addChild(typeCore)

        ring.run(.repeatForever(.sequence([
            .group([.scale(to: 1.45, duration: 0.24), .fadeAlpha(to: 0.25, duration: 0.24)]),
            .group([.scale(to: 0.88, duration: 0), .fadeAlpha(to: 1, duration: 0)])
        ])))
        outerRing.run(.repeatForever(.sequence([
            .group([.scale(to: 1.15, duration: 0.24), .fadeAlpha(to: 0.14, duration: 0.24)]),
            .group([.scale(to: 0.92, duration: 0), .fadeAlpha(to: 0.8, duration: 0)])
        ])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ZombieSpawnWarning does not support NSCoding")
    }

    func update(deltaTime: TimeInterval) -> Bool {
        remaining -= min(max(0, deltaTime), 0.1)
        return remaining <= 0
    }
}

private extension ZombieSpawnEdge {
    var inwardAngle: CGFloat {
        switch self {
        case .left: return 0
        case .right: return .pi
        case .bottom: return .pi / 2
        case .top: return -.pi / 2
        }
    }
}

final class ZombieSpawner {
    private var random: ZombieRandom
    private var previousEdge: ZombieSpawnEdge?

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        random = ZombieRandom(seed: seed)
    }

    func makeWarning(
        type: ZombieType,
        bounds: CGRect,
        playerPosition: CGPoint,
        occupied: [CGPoint],
        archetype: ZombieWaveArchetype?
    ) -> ZombieSpawnWarning {
        let edge = chooseEdge(archetype: archetype)
        let position = safePosition(
            on: edge,
            bounds: bounds,
            playerPosition: playerPosition,
            occupied: occupied
        )
        previousEdge = edge
        return ZombieSpawnWarning(type: type, position: position, edge: edge)
    }

    func reset() {
        previousEdge = nil
    }

    private func chooseEdge(archetype: ZombieWaveArchetype?) -> ZombieSpawnEdge {
        var edges = ZombieSpawnEdge.allCases
        if archetype == .encircle, let previousEdge,
           let index = edges.firstIndex(of: previousEdge) {
            return edges[(index + 1) % edges.count]
        }
        if let previousEdge, edges.count > 1 {
            edges.removeAll { $0 == previousEdge }
        }
        return edges.randomElement(using: &random) ?? .left
    }

    private func safePosition(
        on edge: ZombieSpawnEdge,
        bounds: CGRect,
        playerPosition: CGPoint,
        occupied: [CGPoint]
    ) -> CGPoint {
        let inset: CGFloat = 34
        var best = CGPoint.zero
        var bestClearance: CGFloat = -.infinity
        for _ in 0..<10 {
            let point: CGPoint
            switch edge {
            case .left:
                point = CGPoint(x: inset, y: CGFloat.random(in: inset...max(inset, bounds.height - inset), using: &random))
            case .right:
                point = CGPoint(x: max(inset, bounds.width - inset), y: CGFloat.random(in: inset...max(inset, bounds.height - inset), using: &random))
            case .bottom:
                point = CGPoint(x: CGFloat.random(in: inset...max(inset, bounds.width - inset), using: &random), y: inset)
            case .top:
                point = CGPoint(x: CGFloat.random(in: inset...max(inset, bounds.width - inset), using: &random), y: max(inset, bounds.height - inset))
            }
            let playerClearance = hypot(point.x - playerPosition.x, point.y - playerPosition.y)
            let occupiedClearance = occupied.map { hypot(point.x - $0.x, point.y - $0.y) }.min() ?? .infinity
            let clearance = min(playerClearance - 180, occupiedClearance - 62)
            if clearance > bestClearance {
                best = point
                bestClearance = clearance
            }
            if clearance >= 0 { return point }
        }
        return best
    }
}
