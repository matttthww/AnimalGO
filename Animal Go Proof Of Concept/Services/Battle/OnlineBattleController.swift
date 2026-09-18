//
//  OnlineBattleController.swift
//  Animal Go Proof Of Concept
//
//  Runs a battle against a real opponent over Firebase — either matched
//  randomly or joined via a friend's invite code. Mirrors
//  CPUBattleController's shape (same BattleController protocol, same
//  BattleSessionState) so LiveBattleView doesn't need to know which one
//  it's looking at.
//
//  Round resolution is "host-authoritative": whichever player's device
//  created the match document (see FirebaseMatchService) is the only one
//  that ever computes and writes a round's outcome. Both players always
//  submit their own move the same way; only the host also calls
//  `resolveRoundIfReady` afterwards. This avoids two clients racing to
//  write conflicting results without needing a real backend.
//

import Foundation

@MainActor
final class OnlineBattleController: BattleController {
    let session: BattleSessionState

    private let service = FirebaseMatchService.shared
    private let localAnimal: Animal
    private let inviteCodeToJoin: String?

    private var matchId: String?
    private var isHost = false
    private var myUid: String?
    private var observeTask: Task<Void, Never>?
    private var roundTimerTask: Task<Void, Never>?
    private var currentRoundHasSubmittedMove = false

    /// - Parameters:
    ///   - mode: `.onlineRandom` to find any opponent, `.onlineFriend` to
    ///     either create an invite (when `joinCode` is nil) or join one.
    ///   - joinCode: pass a code the player typed in to join a friend's
    ///     invite instead of creating a new one.
    init(playerAnimal: Animal, mode: BattleMode, joinCode: String? = nil) {
        precondition(mode != .cpu, "Use CPUBattleController for .cpu battles")
        self.localAnimal = playerAnimal
        self.inviteCodeToJoin = joinCode
        let snapshot = playerAnimal.makeBattleSnapshot(includeImage: true)
        self.session = BattleSessionState(mode: mode, playerSnapshot: snapshot)
    }

    func begin() {
        session.phase = .connecting
        Task { @MainActor [weak self] in
            await self?.connect()
        }
    }

    private func connect() async {
        do {
            let uid = try await service.ensureSignedIn()
            myUid = uid
            let wireSnapshot = localAnimal.makeBattleSnapshot(includeImage: false)

            let resolvedMatchId: String
            switch session.mode {
            case .cpu:
                return // unreachable, guarded in init
            case .onlineRandom:
                let result = try await service.findRandomMatch(playerSnapshot: wireSnapshot)
                resolvedMatchId = result.matchId
                isHost = result.isHost
            case .onlineFriend:
                if let code = inviteCodeToJoin {
                    resolvedMatchId = try await service.joinFriendInvite(code: code, playerSnapshot: wireSnapshot)
                    isHost = false
                } else {
                    session.inviteCode = "..." // shows a "generating..." beat briefly
                    let result = try await service.createFriendInviteAndWait(playerSnapshot: wireSnapshot)
                    resolvedMatchId = result.matchId
                    isHost = true
                }
            }

            matchId = resolvedMatchId
            session.inviteCode = nil
            session.phase = .starting
            startObserving(matchId: resolvedMatchId, myUid: uid)
        } catch {
            session.errorMessage = error.localizedDescription
        }
    }

    private func startObserving(matchId: String, myUid: String) {
        observeTask?.cancel()
        observeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await match in self.service.observeMatch(matchId: matchId) {
                if Task.isCancelled { return }
                self.apply(match, myUid: myUid)
            }
        }
    }

    private func apply(_ match: MatchDocument, myUid: String) {
        let iAmHost = match.hostId == myUid
        let opponentSnapshot = iAmHost ? (match.guestSnapshot ?? match.hostSnapshot) : match.hostSnapshot

        // Preserve the local player's own image (never sent over the
        // wire) rather than clobbering it with the imageless copy that
        // came back from Firestore.
        var myState = CombatantState(snapshot: session.player.snapshot)
        myState.currentHP = iAmHost ? match.hostHP : match.guestHP
        myState.energy = iAmHost ? match.hostEnergy : match.guestEnergy
        session.player = myState

        var opponentState = session.opponent ?? CombatantState(snapshot: opponentSnapshot)
        opponentState.snapshot = opponentSnapshot
        opponentState.currentHP = iAmHost ? match.guestHP : match.hostHP
        opponentState.energy = iAmHost ? match.guestEnergy : match.hostEnergy
        session.opponent = opponentState
        session.opponentDisplayName = opponentSnapshot.name

        session.round = match.round
        session.log = match.log.enumerated().map { BattleLogEntry(round: $0.offset + 1, text: $0.element) }

        if let abandonedBy = match.abandonedBy {
            roundTimerTask?.cancel()
            session.phase = .finished(abandonedBy == myUid ? .loss : .win)
            return
        }

        if let outcome = match.outcome {
            roundTimerTask?.cancel()
            let didHostWin = outcome == .host
            let won = (iAmHost && didHostWin) || (!iAmHost && outcome == .guest)
            session.phase = .finished(outcome == .draw ? .draw : (won ? .win : .loss))
            return
        }

        // A fresh round: both moves are cleared and it's a round we
        // haven't started a timer for yet.
        let myMove = iAmHost ? match.hostMove : match.guestMove
        let opponentMove = iAmHost ? match.guestMove : match.hostMove
        if myMove == nil, opponentMove == nil, session.phase != .selectingMove {
            currentRoundHasSubmittedMove = false
            session.hasSubmittedMoveThisRound = false
            session.phase = .selectingMove
            startRoundTimer()
        } else if myMove != nil, opponentMove == nil {
            session.phase = .resolvingRound // waiting on opponent; UI shows "move locked in"
        }

        // The host is responsible for turning "both moves submitted" into
        // a resolved round.
        if isHost, match.hostMove != nil, match.guestMove != nil, let currentMatchId = matchId {
            Task { @MainActor [weak self] in
                try? await self?.service.resolveRoundIfReady(matchId: currentMatchId)
            }
        }
    }

    private func startRoundTimer() {
        roundTimerTask?.cancel()
        session.secondsRemaining = session.roundDuration
        roundTimerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.session.secondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
                self.session.secondsRemaining -= 0.1
            }
            if !self.currentRoundHasSubmittedMove {
                self.autoSubmit()
            }
        }
    }

    private func autoSubmit() {
        guard let fallback = session.player.snapshot.moves.first(where: { $0.category == .quick }) else { return }
        selectMove(fallback)
    }

    func selectMove(_ move: AttackMove) {
        guard let matchId, !currentRoundHasSubmittedMove else { return }
        guard BattleEngine.canUse(move, withEnergy: session.player.energy) else { return }
        currentRoundHasSubmittedMove = true
        session.hasSubmittedMoveThisRound = true
        roundTimerTask?.cancel()

        let hostFlag = isHost
        Task { @MainActor [weak self] in
            try? await self?.service.submitMove(matchId: matchId, isHost: hostFlag, move: move)
        }
    }

    func leaveBattle() {
        observeTask?.cancel()
        roundTimerTask?.cancel()
        Task { @MainActor [service, matchId, myUid] in
            if let matchId, let myUid {
                await service.leaveMatch(matchId: matchId, uid: myUid)
            } else {
                await service.cancelRandomMatchSearch()
            }
        }
    }

    deinit {
        observeTask?.cancel()
        roundTimerTask?.cancel()
    }
}
