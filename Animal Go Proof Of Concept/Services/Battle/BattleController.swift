//
//  BattleController.swift
//  Animal Go Proof Of Concept
//
//  Common interface for whatever is actually running a battle. LiveBattleView
//  only ever talks to this protocol, so it doesn't need to know or care
//  whether it's fighting a CPU or a real opponent over Firebase.
//

import Foundation

@MainActor
protocol BattleController: AnyObject {
    var session: BattleSessionState { get }

    /// Kicks the battle off: for CPU, spawns an opponent immediately; for
    /// online modes, starts matchmaking / waits for a friend to join.
    func begin()

    /// Locks in the local player's move for the current round. Ignored if
    /// the round isn't currently accepting a move, or the move isn't
    /// currently usable (not enough energy for a charged move).
    func selectMove(_ move: AttackMove)

    /// Tears down timers/listeners. Call when the player backs out of the
    /// battle screen, win or lose.
    func leaveBattle()
}
