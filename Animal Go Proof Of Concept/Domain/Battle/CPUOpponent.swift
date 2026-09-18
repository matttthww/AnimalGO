//
//  CPUOpponent.swift
//  Animal Go Proof Of Concept
//
//  Everything needed to battle a computer-controlled animal: a factory
//  that fabricates a roughly fair opponent, and a small heuristic AI that
//  picks its move each round. No networking, no SwiftData — CPU battles
//  work completely offline.
//

import Foundation

enum CPUOpponentFactory {
    private static let namePool = [
        "Rocky", "Blaze", "Finn", "Pebbles", "Talon", "Sandy", "Volt", "Boulder",
        "Skipper", "Gale", "Ember", "Rooter", "Sparky", "Crag", "Wisp", "Fang",
    ]

    /// Builds a CPU opponent scaled to roughly match the player's animal,
    /// so early captures fight easy opponents and strong captures get a
    /// real challenge. `difficulty` nudges the opponent's HP up or down
    /// (1.0 = matched, >1.0 = harder).
    static func makeOpponent(matching playerSnapshot: BattleAnimalSnapshot, difficulty: Double = 1.0) -> BattleAnimalSnapshot {
        let type = AnimalType.allCases.randomElement() ?? .fire
        let scaledHP = max(60, Int((Double(playerSnapshot.maxHP) * difficulty).rounded()))

        return BattleAnimalSnapshot(
            id: UUID(),
            name: namePool.randomElement() ?? "Wild Animal",
            type: type,
            maxHP: scaledHP,
            moves: movePair(for: type),
            scoreForDisplay: playerSnapshot.scoreForDisplay,
            imageData: nil
        )
    }

    /// Picks one quick + one charged move for a type, the same way
    /// `MoveAssigner.assignQuickAndCharged(to:)` does for a captured
    /// `Animal` — duplicated here (rather than reused) because that API
    /// takes a full SwiftData `Animal`, and a fabricated CPU opponent
    /// isn't one.
    private static func movePair(for type: AnimalType) -> [AttackMove] {
        let typeMoves = MoveLibrary.moves(for: type)
        let quick = typeMoves.filter { $0.category == .quick }.randomElement()
        let charged = typeMoves.filter { $0.category == .charged }.randomElement()
        return [quick, charged].compactMap { $0 }
    }
}

enum CPUOpponentAI {
    /// Picks the CPU's move for this round. Prefers finishing an opponent
    /// off when it can, otherwise leans on quick moves to build energy
    /// while occasionally firing a charged move when it's available.
    static func chooseMove(cpu: CombatantState, opponent: CombatantState) -> AttackMove {
        let usable = cpu.snapshot.moves.filter { BattleEngine.canUse($0, withEnergy: cpu.energy) }
        guard !usable.isEmpty else {
            // Shouldn't happen (quick moves are always usable), but never
            // leave the CPU without a move.
            return cpu.snapshot.moves.first(where: { $0.category == .quick })
                ?? cpu.snapshot.moves[0]
        }

        let charged = usable.filter { $0.category == .charged }
        let quick = usable.filter { $0.category == .quick }

        // Finish the opponent off if a charged move can plausibly do it.
        if let finisher = charged.first(where: { estimatedDamage($0, cpu: cpu, opponent: opponent) >= opponent.currentHP }) {
            return finisher
        }

        // Otherwise mostly poke with quick moves to build energy, and
        // occasionally cash in a charged move when one's ready.
        if let chargedMove = charged.randomElement(), Double.random(in: 0...1) < 0.35 {
            return chargedMove
        }
        return quick.randomElement() ?? usable[0]
    }

    private static func estimatedDamage(_ move: AttackMove, cpu: CombatantState, opponent: CombatantState) -> Int {
        let effectiveness = TypeChart.multiplier(attacker: cpu.snapshot.type, defender: opponent.snapshot.type)
        return Int((Double(move.power) * effectiveness).rounded())
    }
}
