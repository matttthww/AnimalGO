//
//  CPUBattleController.swift
//  Animal Go Proof Of Concept
//
//  Runs a complete "vs CPU" battle locally: no network, no Firebase, works
//  immediately after building the app. Good default/fallback battle mode,
//  and the easiest way to sanity-check the shared battle UI and engine.
//

import Foundation

@MainActor
final class CPUBattleController: BattleController {
    let session: BattleSessionState

    private var roundTimer: Timer?
    private var pendingCPUMove: AttackMove?
    private var roundResolved = false

    init(playerAnimal: Animal, difficulty: Double = 1.0) {
        let snapshot = playerAnimal.makeBattleSnapshot()
        self.session = BattleSessionState(mode: .cpu, playerSnapshot: snapshot)
        self.difficulty = difficulty
    }

    private let difficulty: Double

    func begin() {
        let opponentSnapshot = CPUOpponentFactory.makeOpponent(matching: session.player.snapshot, difficulty: difficulty)
        session.opponent = CombatantState(snapshot: opponentSnapshot)
        session.opponentDisplayName = opponentSnapshot.name
        session.phase = .starting
        session.appendLog("A wild \(opponentSnapshot.name) (\(opponentSnapshot.type.rawValue.capitalized)) appears!")

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            self?.startRound()
        }
    }

    func selectMove(_ move: AttackMove) {
        guard session.phase == .selectingMove, !session.hasSubmittedMoveThisRound else { return }
        guard BattleEngine.canUse(move, withEnergy: session.player.energy) else { return }
        session.hasSubmittedMoveThisRound = true
        roundTimer?.invalidate()
        resolveRound(playerMove: move)
    }

    func leaveBattle() {
        roundTimer?.invalidate()
    }

    deinit {
        roundTimer?.invalidate()
    }

    // MARK: - Private

    private func startRound() {
        guard let opponent = session.opponent else { return }
        pendingCPUMove = CPUOpponentAI.chooseMove(cpu: opponent, opponent: session.player)
        session.hasSubmittedMoveThisRound = false
        session.secondsRemaining = session.roundDuration
        session.phase = .selectingMove
        startTimer()
    }

    private func startTimer() {
        roundTimer?.invalidate()
        roundResolved = false
        roundTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.session.secondsRemaining -= 0.1
                if self.session.secondsRemaining <= 0 {
                    self.roundTimer?.invalidate()
                    self.autoSubmitIfNeeded()
                }
            }
        }
    }

    private func autoSubmitIfNeeded() {
        guard !roundResolved, session.phase == .selectingMove else { return }
        // Ran out the clock — auto-pick a quick move so the round always advances.
        if let fallback = session.player.snapshot.moves.first(where: { $0.category == .quick }) {
            resolveRound(playerMove: fallback)
        }
    }

    private func resolveRound(playerMove: AttackMove) {
        guard !roundResolved, let cpuMove = pendingCPUMove, var opponent = session.opponent else { return }
        roundResolved = true
        session.phase = .resolvingRound

        var player = session.player
        let resolution = BattleEngine.resolveRound(
            round: session.round,
            attackerName: player.snapshot.name,
            attacker: &player,
            attackerMove: playerMove,
            defenderName: opponent.snapshot.name,
            defender: &opponent,
            defenderMove: cpuMove
        )
        session.player = player
        session.opponent = opponent
        session.appendLog(resolution.logText)

        if let outcome = BattleEngine.outcome(player: player, opponent: opponent) {
            session.phase = .finished(outcome)
            return
        }

        session.round += 1
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            self?.startRound()
        }
    }
}
