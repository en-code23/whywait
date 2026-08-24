#if DEBUG
import AppKit
import Foundation

enum ZombieSwordDiagnostics {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func runAll() throws -> [String] {
        var results: [String] = []
        try run("shared-sword-regression", testSharedSword, into: &results)
        try run("sword-dummy-regression", testSwordDummyRegression, into: &results)
        try run("swept-multi-target-collision", testSweptCollision, into: &results)
        try run("scene-multi-target-gating", testSceneMultiTargetGating, into: &results)
        try run("damage-invariants", testDamage, into: &results)
        try run("zombie-behavior", testZombieBehavior, into: &results)
        try run("wave-invariants", testWaves, into: &results)
        try run("extended-bounded-simulation", testExtendedSimulation, into: &results)
        try run("registry-selection", testRegistry, into: &results)
        return results
    }

    private static func run(
        _ name: String,
        _ test: () throws -> Void,
        into results: inout [String]
    ) throws {
        try test()
        results.append("PASS \(name)")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw Failure(description: message) }
    }

    private static func testSharedSword() throws {
        let simulation = SwordPhysicsSimulation(handlePosition: CGPoint(x: 300, y: 300))
        for _ in 0..<900 { simulation.update(deltaTime: 1.0 / 120) }
        try require(simulation.isFinite, "stationary sword became non-finite")
        try require(
            SwordMath.magnitude(simulation.snapshot.linearVelocity) < 1,
            "stationary sword did not settle"
        )

        simulation.setCursorTarget(CGPoint(x: 100_000, y: -100_000))
        for index in 0..<3_000 {
            let angle = CGFloat(index) * 0.035
            simulation.setCursorTarget(
                CGPoint(x: 420 + cos(angle) * 210, y: 320 + sin(angle) * 170)
            )
            simulation.update(deltaTime: index.isMultiple(of: 97) ? 0.4 : 1.0 / 120)
            try require(simulation.isFinite, "sword became non-finite during input spikes")
            try require(
                SwordMath.magnitude(simulation.snapshot.linearVelocity)
                    <= simulation.parameters.maximumLinearSpeed + 0.1,
                "linear speed exceeded cap"
            )
            try require(
                abs(simulation.snapshot.angularVelocity)
                    <= simulation.parameters.maximumAngularSpeed + 0.1,
                "angular speed exceeded cap"
            )
            try require(
                SwordMath.magnitude(simulation.diagnostics.springForce)
                    <= simulation.parameters.maximumForce + 0.1,
                "spring force exceeded cap"
            )
        }
        try require(abs(simulation.snapshot.angularVelocity) > 0.05, "circular input generated no angular motion")
        simulation.reset(handlePosition: CGPoint(x: 220, y: 240))
        try require(simulation.snapshot.linearVelocity == .zero, "reset retained linear velocity")
        try require(simulation.snapshot.angularVelocity == 0, "reset retained angular velocity")

        var stickParameters = SwordPhysicsParameters.standard
        stickParameters.controlMode = .stick
        simulation.configure(parameters: stickParameters)
        simulation.setCursorTarget(CGPoint(x: 430, y: 390), allowTeleport: true)
        simulation.update(deltaTime: 1.0 / 60)
        try require(
            hypot(simulation.snapshot.handlePoint.x - 430, simulation.snapshot.handlePoint.y - 390) < 0.1,
            "stick control mode did not attach handle to cursor target"
        )

        let trail = SwordTrail()
        let first = simulation.snapshot
        var second = first
        second.linearVelocity = CGVector(dx: 1_500, dy: 0)
        second.center.x += 20
        for _ in 0..<100 { trail.update(previous: first, current: second, speed: 1_500) }
        try require(trail.activeNodeCount <= SwordEngineTuning.maximumTrailNodes, "trail exceeded node cap")
    }

    private static func testSwordDummyRegression() throws {
        let torsoID = DummyHitRegionID.torso
        func contact(region: DummyHitRegionID, speed: CGFloat, edge: CGFloat) -> SwordContact {
            SwordContact(
                region: region,
                point: CGPoint(x: 200, y: 200),
                bladeProgress: 0.5,
                contactVelocity: CGVector(dx: speed * (1 - edge), dy: speed * edge),
                impactSpeed: speed,
                edgeAlignment: edge,
                thrustAlignment: 1 - edge,
                isTip: false
            )
        }
        let slow = SwordDamageCalculator.calculate(contact: contact(region: torsoID, speed: 300, edge: 1))
        let broadside = SwordDamageCalculator.calculate(contact: contact(region: torsoID, speed: 1_400, edge: 0))
        let aligned = SwordDamageCalculator.calculate(contact: contact(region: torsoID, speed: 1_400, edge: 1))
        let head = SwordDamageCalculator.calculate(contact: contact(region: .head, speed: 1_400, edge: 1))
        let arm = SwordDamageCalculator.calculate(contact: contact(region: .leftArm, speed: 1_400, edge: 1))
        try require(slow.damage == 0, "Sword Dummy slow-contact regression")
        try require(aligned.damage > broadside.damage, "Sword Dummy edge alignment regression")
        try require(head.damage > aligned.damage, "Sword Dummy head modifier regression")
        try require(arm.damage < aligned.damage, "Sword Dummy arm modifier regression")
        try require(aligned.damage <= SwordDummyTuning.maximumHitDamage, "Sword Dummy damage cap regression")

        let dummy = TrainingDummy()
        dummy.reset(at: CGPoint(x: 500, y: 240))
        try require(dummy.hitRegions().count == 4, "Sword Dummy regions changed during extraction")
        try require(
            dummy.health == SwordDummyTuning.dummyMaximumHealth,
            "Sword Dummy reset health regression"
        )
    }

    private static func testSweptCollision() throws {
        let detector = SwordCollisionDetector<String>()
        let previous = SwordTransformSnapshot(
            center: CGPoint(x: 0, y: 100), angle: 0,
            linearVelocity: CGVector(dx: 3_000, dy: 0), angularVelocity: 0
        )
        let current = SwordTransformSnapshot(
            center: CGPoint(x: 320, y: 100), angle: 0,
            linearVelocity: CGVector(dx: 3_000, dy: 0), angularVelocity: 0
        )
        let regions = [
            SwordHitRegion(id: "a", shape: .circle(center: CGPoint(x: 130, y: 100), radius: 12)),
            SwordHitRegion(id: "b", shape: .circle(center: CGPoint(x: 205, y: 100), radius: 12)),
            SwordHitRegion(id: "c", shape: .circle(center: CGPoint(x: 285, y: 100), radius: 12)),
            SwordHitRegion(id: "miss", shape: .circle(center: CGPoint(x: 210, y: 155), radius: 7))
        ]
        let contacts = detector.contacts(previous: previous, current: current, regions: regions)
        let IDs = Set(contacts.map(\.region))
        try require(IDs.isSuperset(of: ["a", "b", "c"]), "fast sweep missed one or more targets")
        try require(!IDs.contains("miss"), "swept blade registered a narrow miss")

        let handleRegion = SwordHitRegion(
            id: "handle",
            shape: .circle(center: previous.handlePoint, radius: 5)
        )
        try require(
            detector.contacts(previous: previous, current: previous, regions: [handleRegion]).isEmpty,
            "handle-only region registered blade damage"
        )
        try require(
            detector.handleContacts(previous: previous, current: previous, regions: [handleRegion]).contains("handle"),
            "handle contact was not distinguishable"
        )

        guard let contact = contacts.first(where: { $0.region == "a" }) else {
            throw Failure(description: "missing contact for gate test")
        }
        let gate = SwordContactGate<String>()
        try require(gate.canRegister(contact, at: 0, swingID: 1), "first contact was rejected")
        gate.updateOverlaps(["a"])
        try require(!gate.canRegister(contact, at: 0.2, swingID: 1), "continuous overlap repeated")
        gate.updateOverlaps([])
        try require(gate.canRegister(contact, at: 0.4, swingID: 2), "leave/re-enter was not accepted")
    }

    private static func testSceneMultiTargetGating() throws {
        let scene = ZombieSwordScene(size: CGSize(width: 900, height: 650), seed: 21)
        scene.startGame()
        scene.clearEnemies()
        scene.gameState = .playing
        scene.swordControlState = .normal
        let targets = [130.0, 205.0, 285.0].map { x -> Zombie in
            let zombie = Zombie(type: .tank, wave: 1, position: CGPoint(x: x, y: 100))
            scene.zombies.append(zombie)
            scene.addChild(zombie)
            return zombie
        }
        let previous = SwordTransformSnapshot(
            center: CGPoint(x: 0, y: 100), angle: 0,
            linearVelocity: CGVector(dx: 3_000, dy: 0), angularVelocity: 0
        )
        let current = SwordTransformSnapshot(
            center: CGPoint(x: 320, y: 100), angle: 0,
            linearVelocity: CGVector(dx: 3_000, dy: 0), angularVelocity: 0
        )
        scene.swingTracker.update(speed: 3_000, deltaTime: 1.0 / 60)
        scene.processCombat(previous: previous, current: current, currentTime: 1)
        let firstHealth = targets.map(\.health)
        try require(
            zip(firstHealth, targets.map { $0.stats.health }).allSatisfy { $0 < $1 && $0 > 0 },
            "one sweep did not hit all three zombies exactly once"
        )
        scene.processCombat(previous: current, current: current, currentTime: 1.2)
        try require(targets.map(\.health) == firstHealth, "one continuous swing damaged a zombie twice")

        let originalSwingID = scene.swingTracker.activeSwingID
        let exited = SwordTransformSnapshot(
            center: CGPoint(x: 450, y: 100), angle: 0,
            linearVelocity: CGVector(dx: 3_000, dy: 0), angularVelocity: 0
        )
        scene.processCombat(previous: current, current: exited, currentTime: 1.35)
        try require(
            targets.map(\.health) == firstHealth,
            "exiting a prior contact unexpectedly dealt another hit"
        )

        // A fast reversal may never drop below SwordSwingTracker's idle threshold.
        // Full blade exit followed by a distinct re-entry must still be eligible.
        scene.swingTracker.update(speed: 3_000, deltaTime: 1.0 / 60)
        try require(
            scene.swingTracker.activeSwingID == originalSwingID,
            "re-entry regression setup unexpectedly created a new tracker swing"
        )
        let reentered = SwordTransformSnapshot(
            center: CGPoint(x: 0, y: 100), angle: 0,
            linearVelocity: CGVector(dx: -3_000, dy: 0), angularVelocity: 0
        )
        scene.processCombat(previous: exited, current: reentered, currentTime: 1.7)
        let secondHealth = targets.map(\.health)
        try require(
            zip(secondHealth, firstHealth).allSatisfy { $0 < $1 },
            "a full exit and distinct re-entry could not damage again: first=\(firstHealth), second=\(secondHealth), swing=\(String(describing: scene.swingTracker.activeSwingID))"
        )
        scene.stopGame()
    }

    private static func testDamage() throws {
        let zombieID = UUID()
        func impact(
            region: ZombieBodyRegion,
            speed: CGFloat,
            edge: CGFloat,
            thrust: CGFloat = 0,
            tip: Bool = false
        ) -> SwordImpact<ZombieHitRegionID> {
            SwordImpact(
                region: ZombieHitRegionID(zombieID: zombieID, bodyRegion: region),
                point: CGPoint(x: 20, y: 20),
                bladeProgress: tip ? 0.95 : 0.5,
                contactVelocity: CGVector(dx: speed * thrust, dy: speed * max(edge, 0.01)),
                impactSpeed: speed,
                edgeAlignment: edge,
                thrustAlignment: thrust,
                isTip: tip
            )
        }
        let slow = ZombieDamageCalculator.calculate(
            impact: impact(region: .torso, speed: 300, edge: 1), zombieType: .walker, zombieMass: 1
        )
        let broadside = ZombieDamageCalculator.calculate(
            impact: impact(region: .torso, speed: 1_400, edge: 0), zombieType: .walker, zombieMass: 1
        )
        let aligned = ZombieDamageCalculator.calculate(
            impact: impact(region: .torso, speed: 1_400, edge: 1), zombieType: .walker, zombieMass: 1
        )
        let head = ZombieDamageCalculator.calculate(
            impact: impact(region: .head, speed: 1_400, edge: 1), zombieType: .walker, zombieMass: 1
        )
        let arm = ZombieDamageCalculator.calculate(
            impact: impact(region: .leftArm, speed: 1_400, edge: 1), zombieType: .walker, zombieMass: 1
        )
        let armor = ZombieDamageCalculator.calculate(
            impact: impact(region: .torso, speed: 1_400, edge: 0.45), zombieType: .armored, zombieMass: 1.55
        )
        let extreme = ZombieDamageCalculator.calculate(
            impact: impact(region: .head, speed: 1_000_000, edge: 1, thrust: 1, tip: true),
            zombieType: .walker,
            zombieMass: 1
        )
        try require(slow.damage == 0, "slow touch caused damage")
        try require(aligned.damage > broadside.damage, "edge alignment did not improve damage")
        try require(head.damage > aligned.damage, "head modifier did not improve damage")
        try require(arm.damage < aligned.damage, "arm modifier did not reduce damage")
        try require(armor.damage < aligned.damage, "armor did not reduce torso damage")
        try require(extreme.damage <= ZombieSwordTuning.maximumHitDamage, "damage cap failed")
        try require(extreme.damage >= 0, "damage became negative")
    }

    private static func testZombieBehavior() throws {
        let player = CGPoint(x: 500, y: 500)
        let zombie = Zombie(type: .walker, wave: 1, position: CGPoint(x: 100, y: 100))
        let initialDistance = hypot(zombie.position.x - player.x, zombie.position.y - player.y)
        for _ in 0..<120 {
            _ = zombie.update(deltaTime: 1.0 / 60, playerPosition: player, separation: .zero)
        }
        let movedDistance = hypot(zombie.position.x - player.x, zombie.position.y - player.y)
        try require(movedDistance < initialDistance, "zombie did not move toward player")

        let attacker = Zombie(type: .walker, wave: 1, position: CGPoint(x: 500, y: 540))
        var events: [ZombieAttackEvent] = []
        for _ in 0..<180 {
            if let event = attacker.update(deltaTime: 1.0 / 60, playerPosition: player, separation: .zero) {
                events.append(event)
            }
        }
        try require(!events.isEmpty, "near zombie never attacked")
        try require(events.count <= 3, "attack cooldown allowed frame-by-frame damage")

        let second = Zombie(
            type: .runner,
            wave: 1,
            position: CGPoint(x: zombie.position.x + 5, y: zombie.position.y)
        )
        let separation = ZombieSteering.separation(for: zombie, among: [zombie, second])
        try require(SwordMath.magnitude(separation) > 0, "nearby zombies generated no separation")
        try require(
            SwordMath.magnitude(separation) <= ZombieSwordTuning.separationStrength + 0.1,
            "separation exceeded bound"
        )

        let death = ZombieDamageResult(
            damage: 1_000, region: .head, style: .headshot,
            impactDirection: CGVector(dx: 1, dy: 0),
            knockbackVelocity: CGVector(dx: 300, dy: 0),
            impactSpeed: 1_800, edgeAlignment: 1,
            causesStagger: true, staggerDuration: 0.4, wasArmorReduced: false
        )
        try require(attacker.applyHit(death), "fatal hit did not kill")
        try require(attacker.markDeathAwarded(), "death reward was not available once")
        try require(!attacker.markDeathAwarded(), "death reward could be collected twice")
        try require(
            attacker.update(deltaTime: 1, playerPosition: player, separation: .zero) == nil,
            "dead zombie attacked"
        )
    }

    private static func testWaves() throws {
        var random = ZombieRandom(seed: 42)
        var hardTypeCount = 0
        for wave in 1...80 {
            let plan = ZombieWavePlanner.makePlan(wave: wave, random: &random)
            try require(!plan.zombieTypes.isEmpty, "wave was empty")
            try require(
                plan.zombieTypes.count <= ZombieSwordTuning.maximumActiveZombies,
                "wave exceeded enemy cap"
            )
            try require(plan.spawnInterval >= ZombieSwordTuning.minimumSpawnInterval, "spawn interval underflow")
            if wave >= 5 {
                hardTypeCount += plan.zombieTypes.filter { $0 == .tank || $0 == .armored }.count
            }
            if wave.isMultiple(of: 5) {
                try require(
                    plan.zombieTypes.contains(where: { $0 == .tank || $0 == .armored }),
                    "milestone wave had no hard enemy"
                )
            }
        }
        try require(hardTypeCount > 0, "harder types never appeared")

        let controller = ZombieWaveController(seed: 7)
        for _ in 0..<30 {
            let plan = controller.beginNextWave()
            var emitted = 0
            for _ in 0..<500 where controller.hasPendingSpawns {
                if controller.update(deltaTime: 0.1, occupiedSlots: 0) != nil { emitted += 1 }
            }
            try require(emitted == plan.zombieTypes.count, "wave spawn queue leaked or duplicated")
            try require(emitted <= ZombieSwordTuning.maximumActiveZombies, "controller exceeded cap")
        }
        controller.cancelPendingSpawns()
        try require(!controller.hasPendingSpawns, "cancel left stale wave spawns")
    }

    private static func testExtendedSimulation() throws {
        let simulation = SwordPhysicsSimulation(handlePosition: CGPoint(x: 400, y: 300))
        var zombies = (0..<16).map { index in
            Zombie(
                type: ZombieType.allCases[index % ZombieType.allCases.count],
                wave: 18,
                position: CGPoint(x: 60 + CGFloat(index % 4) * 100, y: 70 + CGFloat(index / 4) * 90)
            )
        }
        let player = CGPoint(x: 520, y: 380)
        for tick in 0..<12_000 {
            let phase = CGFloat(tick) * 0.027
            let target = CGPoint(
                x: 420 + cos(phase) * CGFloat(tick.isMultiple(of: 811) ? 50_000 : 260),
                y: 330 + sin(phase * 1.17) * 210
            )
            simulation.setCursorTarget(target)
            simulation.update(deltaTime: tick.isMultiple(of: 509) ? 0.25 : 1.0 / 120)
            try require(simulation.isFinite, "extended sword simulation became non-finite")
            if tick.isMultiple(of: 2) {
                let living = zombies.filter(\.isAlive)
                for zombie in living {
                    let separation = ZombieSteering.separation(for: zombie, among: living)
                    _ = zombie.update(deltaTime: 1.0 / 60, playerPosition: player, separation: separation)
                    try require(SwordMath.isFinite(zombie.position), "zombie position became non-finite")
                    try require(SwordMath.isFinite(zombie.velocity), "zombie velocity became non-finite")
                }
            }
            if tick.isMultiple(of: 1_500) {
                zombies.removeAll()
                zombies = (0..<16).map { index in
                    Zombie(
                        type: ZombieType.allCases[index % ZombieType.allCases.count],
                        wave: 24,
                        position: CGPoint(x: 40 + CGFloat(index) * 13, y: 80 + CGFloat(index % 5) * 52)
                    )
                }
            }
            try require(zombies.count <= ZombieSwordTuning.maximumActiveZombies, "extended simulation leaked zombies")
        }

        let scene = ZombieSwordScene(size: CGSize(width: 1_200, height: 800), seed: 9)
        scene.startGame()
        let injected = Zombie(type: .tank, wave: 4, position: CGPoint(x: 40, y: 40))
        scene.zombies.append(injected)
        scene.addChild(injected)
        scene.resetRun()
        try require(scene.zombies.isEmpty && scene.pendingWarnings.isEmpty, "run reset retained enemies")
        scene.stopGame()
    }

    private static func testRegistry() throws {
        let identifiers = [
            "cursor-golf", "cursor-pong", "fruit-slice", "grapple",
            "fishing", "sword-dummy", "zombie-sword"
        ]
        for identifier in identifiers {
            let game = MinigameRegistry.makeLaunchMinigame(
                arguments: ["whywait", "--minigame=\(identifier)"]
            )
            try require(game?.id == identifier, "registry failed for \(identifier)")
        }
        try require(
            MinigameRegistry.makeLaunchMinigame(arguments: ["whywait"]) == nil,
            "normal launch should not select a default minigame"
        )
    }
}
#endif
