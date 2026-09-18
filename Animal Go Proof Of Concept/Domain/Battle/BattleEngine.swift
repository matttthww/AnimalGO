//
//  BattleEngine.swift
//  Animal Go Proof Of Concept
//
//  Pure combat math shared by every battle mode (CPU, online random,
//  online friend). Nothing in here touches SwiftData, Firestore, or
//  SwiftUI — it just turns "two combatants + two chosen moves" into a
//  resolved outcome, so CPU battles and online battles produce results
//  the same way.
//
//  Energy model mirrors the moves already defined in Animal_Structs.swift:
//  quick moves are always usable and GENERATE energy equal to their
//  `energyCost`; charged moves REQUIRE that much energy and consume it.
//

import Foundation

enum BattleEngine {
    static let maxEnergy = 100

    /// Derives a battle HP pool from an animal's captured stats. Tuned so
    /// a typical animal lands somewhere in the 90-180 range. This is the
    /// one formula both a real captured `Animal` and a fabricated CPU
    /// opponent go through, so battles stay comparable.
    static func maxHP(defensiveness: Int, size_kg: Double) -> Int {
        let defenseBonus = defensiveness * 6
        let sizeBonus = Int((sqrt(max(1.0, size_kg)) * 8).rounded())
        return max(60, 80 + defenseBonus + sizeBonus)
    }

    /// Whether `move` can legally be used right now given `energy`.
    static func canUse(_ move: AttackMove, withEnergy energy: Int) -> Bool {
        switch move.category {
        case .quick: return true
        case .charged: return energy >= move.energyCost
        }
    }

    /// The outcome of one side's attack within a round.
    struct AttackResult: Sendable {
        let move: AttackMove
        let didFire: Bool      // false only if a charged move was illegally submitted without enough energy
        let didHit: Bool
        let damage: Int
        let effectiveness: Double
        let energyDelta: Int   // signed: +gain for quick, -cost for charged
    }

    /// The full result of resolving one simultaneous round.
    struct RoundResolution: Sendable {
        let round: Int
        let attackerResult: AttackResult   // "player" side's attack, by convention
        let defenderResult: AttackResult   // "opponent" side's attack
        let logText: String
    }

    /// Resolves one round for two combatants attacking each other at the
    /// same time. Mutates `attacker` and `defender` in place (HP + energy)
    /// and returns a description of what happened for the log/UI.
    ///
    /// Naming is positional, not hierarchical — call it once with
    /// (you, yourMove, them, theirMove) and both sides are updated.
    static func resolveRound(
        round: Int,
        attackerName: String,
        attacker: inout CombatantState,
        attackerMove: AttackMove,
        defenderName: String,
        defender: inout CombatantState,
        defenderMove: AttackMove
    ) -> RoundResolution {
        let attackOnDefender = rollAttack(
            move: attackerMove,
            attackerType: attacker.snapshot.type,
            defenderType: defender.snapshot.type,
            currentEnergy: attacker.energy
        )
        let attackOnAttacker = rollAttack(
            move: defenderMove,
            attackerType: defender.snapshot.type,
            defenderType: attacker.snapshot.type,
            currentEnergy: defender.energy
        )

        // Apply simultaneously — order doesn't change the math since each
        // side's damage/energy depends only on the state *entering* the round.
        defender.currentHP = max(0, defender.currentHP - attackOnDefender.damage)
        attacker.currentHP = max(0, attacker.currentHP - attackOnAttacker.damage)
        attacker.energy = clampEnergy(attacker.energy + attackOnDefender.energyDelta)
        defender.energy = clampEnergy(defender.energy + attackOnAttacker.energyDelta)

        let logText = [
            describe(name: attackerName, target: defenderName, result: attackOnDefender),
            describe(name: defenderName, target: attackerName, result: attackOnAttacker),
        ].joined(separator: "\n")

        return RoundResolution(
            round: round,
            attackerResult: attackOnDefender,
            defenderResult: attackOnAttacker,
            logText: logText
        )
    }

    /// Convenience for checking whether a battle has ended after a round.
    static func outcome(player: CombatantState, opponent: CombatantState) -> BattleOutcome? {
        switch (player.isFainted, opponent.isFainted) {
        case (true, true): return .draw
        case (true, false): return .loss
        case (false, true): return .win
        case (false, false): return nil
        }
    }

    // MARK: - Private

    private static func rollAttack(
        move: AttackMove,
        attackerType: AnimalType,
        defenderType: AnimalType,
        currentEnergy: Int
    ) -> AttackResult {
        guard canUse(move, withEnergy: currentEnergy) else {
            // Defensive fallback: an illegal charged-move submission (e.g. a
            // stale/desynced online client) fizzles instead of crashing or
            // granting a free hit.
            return AttackResult(move: move, didFire: false, didHit: false, damage: 0, effectiveness: 1.0, energyDelta: 0)
        }

        let didHit = Double.random(in: 0...1) <= move.accuracy
        let effectiveness = TypeChart.multiplier(attacker: attackerType, defender: defenderType)
        let variance = Double.random(in: 0.9...1.1)
        let damage = didHit ? Int((Double(move.power) * effectiveness * variance).rounded()) : 0

        let energyDelta: Int
        switch move.category {
        case .quick:
            energyDelta = move.energyCost
        case .charged:
            energyDelta = -move.energyCost
        }

        return AttackResult(move: move, didFire: true, didHit: didHit, damage: damage, effectiveness: effectiveness, energyDelta: energyDelta)
    }

    private static func clampEnergy(_ value: Int) -> Int {
        min(maxEnergy, max(0, value))
    }

    private static func describe(name: String, target: String, result: AttackResult) -> String {
        guard result.didFire else {
            return "\(name) tried to use \(result.move.name) but didn't have enough energy!"
        }
        guard result.didHit else {
            return "\(name) used \(result.move.name) on \(target), but it missed!"
        }
        let effectivenessNote = result.effectiveness > 1.0 ? " It's super effective!" : ""
        return "\(name) used \(result.move.name) on \(target) for \(result.damage) damage.\(effectivenessNote)"
    }
}
