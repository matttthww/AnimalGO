//
//  BattleSessionState.swift
//  Animal Go Proof Of Concept
//
//  The single piece of observable state that drives the battle UI,
//  regardless of who's actually running the battle underneath. Both
//  `CPUBattleController` and `OnlineBattleController` (Services/Battle)
//  own one of these and mutate it; `LiveBattleView` just reads it. This
//  is what lets one SwiftUI screen serve CPU, random-online, and
//  friend-online battles without three near-duplicate views.
//

import Foundation
import Observation

@MainActor
@Observable
final class BattleSessionState {
    let mode: BattleMode

    var phase: BattlePhase = .connecting
    var round: Int = 1

    var player: CombatantState
    var opponent: CombatantState?
    var opponentDisplayName: String = "Opponent"

    /// Seconds left to lock in a move this round. Purely for the UI
    /// countdown ring; controllers own the actual timer.
    var secondsRemaining: Double = 0
    var roundDuration: Double = 6

    var hasSubmittedMoveThisRound: Bool = false
    var log: [BattleLogEntry] = []

    /// Set while waiting for a friend to join (online-friend mode only).
    var inviteCode: String?

    /// Non-nil when something's gone wrong (lost connection, opponent
    /// left, Firebase not configured, etc). The view surfaces this and
    /// offers a way back out; it does not necessarily end the battle.
    var errorMessage: String?

    init(mode: BattleMode, playerSnapshot: BattleAnimalSnapshot) {
        self.mode = mode
        self.player = CombatantState(snapshot: playerSnapshot)
    }

    var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    func appendLog(_ text: String) {
        log.append(BattleLogEntry(round: round, text: text))
    }
}
