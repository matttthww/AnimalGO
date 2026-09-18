//
//  BattleTypes.swift
//  Animal Go Proof Of Concept
//
//  Shared, wire-friendly battle data types. These are intentionally
//  independent of the SwiftData `Animal` model so they can be sent over
//  Firestore (for online battles) and fabricated locally (for CPU
//  opponents) without dragging SwiftData or UIKit along.
//

import Foundation

/// A lightweight, Codable stand-in for an `Animal` that's safe to persist
/// to Firestore or hand to a CPU opponent factory. `maxHP` is computed once
/// (see `BattleEngine.maxHP(for:)`) and baked in here so both sides of an
/// online battle always agree on it, even though it's a derived value.
struct BattleAnimalSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var type: AnimalType
    var maxHP: Int
    var moves: [AttackMove]

    /// Local-only display polish (never synced online — see `imageData`).
    var scoreForDisplay: Int

    /// Only ever populated for the *local* player's own animal, so their
    /// captured photo shows up in the battle UI. Never sent to Firestore
    /// for the opponent side — keeps match documents small and avoids
    /// shipping another player's photo across the wire.
    var imageData: Data?
}

extension Animal {
    /// Builds the wire-safe snapshot used to drive a battle, computing HP
    /// from this animal's stats via `BattleEngine.maxHP(for:)`.
    func makeBattleSnapshot(includeImage: Bool = true) -> BattleAnimalSnapshot {
        BattleAnimalSnapshot(
            id: id,
            name: name,
            type: type,
            maxHP: BattleEngine.maxHP(defensiveness: defensiveness, size_kg: size_kg),
            moves: moves.isEmpty ? MoveAssigner.assignQuickAndCharged(to: self) : moves,
            scoreForDisplay: score,
            imageData: includeImage ? image : nil
        )
    }
}

/// Which kind of opponent a battle session is fighting.
enum BattleMode: String, Codable, Sendable, Identifiable {
    case cpu
    case onlineRandom
    case onlineFriend

    var id: String { rawValue }
}

/// How a battle session is currently progressing.
enum BattlePhase: Equatable, Sendable {
    /// Online only: waiting on matchmaking or on a friend to join.
    case connecting
    /// A short "battle starting" beat before the first round.
    case starting
    /// A round is open — players may lock in a move.
    case selectingMove
    /// Both moves are in; briefly showing the round's outcome.
    case resolvingRound
    /// The battle is over.
    case finished(BattleOutcome)

    static func == (lhs: BattlePhase, rhs: BattlePhase) -> Bool {
        switch (lhs, rhs) {
        case (.connecting, .connecting), (.starting, .starting),
             (.selectingMove, .selectingMove), (.resolvingRound, .resolvingRound):
            return true
        case let (.finished(a), .finished(b)):
            return a == b
        default:
            return false
        }
    }
}

enum BattleOutcome: Equatable, Sendable {
    case win
    case loss
    case draw
    /// Online only: the opponent disconnected/left before a result.
    case opponentLeft
}

/// Live, mutable state for one combatant during a battle.
struct CombatantState: Identifiable, Sendable {
    var id: UUID { snapshot.id }
    var snapshot: BattleAnimalSnapshot
    var currentHP: Int
    var energy: Int = 0

    var maxHP: Int { snapshot.maxHP }
    var isFainted: Bool { currentHP <= 0 }

    init(snapshot: BattleAnimalSnapshot) {
        self.snapshot = snapshot
        self.currentHP = snapshot.maxHP
    }
}

/// A single completed round, kept for the battle log.
struct BattleLogEntry: Identifiable, Sendable {
    let id = UUID()
    let round: Int
    let text: String
}

/// Type effectiveness chart. Values are attacker -> defender multipliers;
/// anything not listed defaults to neutral (1.0). Deliberately soft
/// (1.5x, not 2x) since a match is only ever a handful of rounds between
/// two 2-move animals — this keeps a type mismatch meaningful without
/// making it a coin flip. Rebalance freely; it's just data.
enum TypeChart {
    private static let superEffective: [AnimalType: Set<AnimalType>] = [
        .fire: [.grass],
        .grass: [.water, .ground],
        .water: [.fire, .rock],
        .electric: [.water, .flying],
        .rock: [.fire, .flying],
        .ground: [.fire, .electric, .rock],
        .flying: [.grass, .fighting],
        .fighting: [.rock],
    ]

    static func multiplier(attacker: AnimalType, defender: AnimalType) -> Double {
        superEffective[attacker]?.contains(defender) == true ? 1.5 : 1.0
    }
}
