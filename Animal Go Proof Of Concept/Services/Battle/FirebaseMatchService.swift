//
//  FirebaseMatchService.swift
//  Animal Go Proof Of Concept
//
//  All direct Firestore/Firebase Auth traffic for online battles lives
//  here. OnlineBattleController (the thing that actually runs a battle)
//  talks only to this service and to BattleEngine — it never touches
//  Firestore types directly.
//
//  Matchmaking is entirely client-driven (no Cloud Functions): random
//  matching uses a Firestore transaction to atomically claim a waiting
//  player's queue entry, and round resolution uses a transaction so that
//  even if both peers' listeners fire at once, a round is only ever
//  resolved once. That's enough correctness for a couple of friends
//  playing a proof-of-concept; a production version would want Cloud
//  Functions doing resolution server-side instead of trusting the host
//  client (see the setup guide's "Known limitations" section).
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

enum MatchServiceError: Error, LocalizedError {
    case notSignedIn
    case inviteNotFound
    case inviteAlreadyClaimed
    case matchNotFound
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Couldn't sign in to Animal Go Online. Check your connection and try again."
        case .inviteNotFound: return "That invite code doesn't exist or has expired."
        case .inviteAlreadyClaimed: return "That invite has already been used."
        case .matchNotFound: return "This match no longer exists."
        case .decodingFailed: return "Received malformed match data."
        }
    }
}

@MainActor
final class FirebaseMatchService {
    static let shared = FirebaseMatchService()

    private lazy var db = Firestore.firestore()
    private var queueListener: ListenerRegistration?
    private var inviteListener: ListenerRegistration?

    private init() {}

    // MARK: - Auth

    /// Every player is an anonymous Firebase Auth user — enough to have a
    /// stable uid for the duration this app is installed, with no sign-up
    /// flow to build. Good enough for matchmaking; not an account system.
    func ensureSignedIn() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }
        return try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signInAnonymously { result, error in
                if let uid = result?.user.uid {
                    continuation.resume(returning: uid)
                } else {
                    continuation.resume(throwing: error ?? MatchServiceError.notSignedIn)
                }
            }
        }
    }

    // MARK: - Random matchmaking

    /// Either claims another waiting player and creates the match
    /// immediately, or joins the queue and suspends until someone else
    /// claims *this* player. Either way, returns once a match exists.
    func findRandomMatch(playerSnapshot: BattleAnimalSnapshot) async throws -> (matchId: String, isHost: Bool) {
        let uid = try await ensureSignedIn()
        let queueRef = db.collection("matchmakingQueue")

        // Look for a handful of recent waiting players and try to claim
        // the first one that isn't us. (Not filtering `hostId != uid` in
        // the query itself avoids needing a composite index for a POC.)
        let candidates = try await queueRef
            .order(by: "createdAt", descending: false)
            .limit(to: 10)
            .getDocuments()

        for doc in candidates.documents where doc.documentID != uid {
            if let matchId = try? await claimQueueEntry(doc.reference, joinerId: uid, joinerSnapshot: playerSnapshot) {
                return (matchId, false)
            }
            // Someone else claimed it first, or it was stale — try the next candidate.
        }

        // Nobody to match with right now — wait in the queue ourselves.
        // Using our own uid as the document ID keeps this idempotent if
        // the caller retries.
        let ownEntryRef = queueRef.document(uid)
        try ownEntryRef.setData(from: MatchmakingQueueEntry(hostId: uid, hostSnapshot: playerSnapshot, matchId: nil))

        let matchId = try await waitForMatchId(on: ownEntryRef)
        try? await ownEntryRef.delete()
        return (matchId, true)
    }

    /// Cancels a pending random-match search (call if the player backs out
    /// of the "Finding opponent..." screen).
    func cancelRandomMatchSearch() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        queueListener?.remove()
        queueListener = nil
        try? await db.collection("matchmakingQueue").document(uid).delete()
    }

    private func claimQueueEntry(_ ref: DocumentReference, joinerId: String, joinerSnapshot: BattleAnimalSnapshot) async throws -> String {
        let matchRef = db.collection("matches").document()

        return try await withCheckedThrowingContinuation { continuation in
            db.runTransaction({ transaction, errorPointer in
                do {
                    let snapshot = try transaction.getDocument(ref)
                    guard let entry = try? snapshot.data(as: MatchmakingQueueEntry.self),
                          entry.matchId == nil, entry.hostId != joinerId else {
                        return nil // already claimed, stale, or somehow us — skip it
                    }
                    let match = MatchDocument.newMatch(
                        hostId: entry.hostId,
                        hostSnapshot: entry.hostSnapshot,
                        guestId: joinerId,
                        guestSnapshot: joinerSnapshot
                    )
                    try transaction.setData(from: match, forDocument: matchRef)
                    transaction.updateData(["matchId": matchRef.documentID], forDocument: ref)
                    return matchRef.documentID
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let matchId = result as? String {
                    continuation.resume(returning: matchId)
                } else {
                    continuation.resume(throwing: MatchServiceError.matchNotFound)
                }
            }
        }
    }

    // MARK: - Friend invites

    /// Creates a short invite code the host can share out-of-band (text,
    /// AirDrop, whatever) and waits until a friend joins it.
    func createFriendInviteAndWait(playerSnapshot: BattleAnimalSnapshot) async throws -> (code: String, matchId: String) {
        let uid = try await ensureSignedIn()
        let code = Self.makeInviteCode()
        let ref = db.collection("friendInvites").document(code)
        try ref.setData(from: FriendInviteDocument(hostId: uid, hostSnapshot: playerSnapshot, matchId: nil, isOpen: true))

        let matchId = try await waitForMatchId(on: ref)
        return (code, matchId)
    }

    func cancelFriendInvite(code: String) async {
        inviteListener?.remove()
        inviteListener = nil
        try? await db.collection("friendInvites").document(code).delete()
    }

    /// Joins a friend's open invite by code, creating the match.
    func joinFriendInvite(code: String, playerSnapshot: BattleAnimalSnapshot) async throws -> String {
        let uid = try await ensureSignedIn()
        let ref = db.collection("friendInvites").document(code.uppercased())
        let matchRef = db.collection("matches").document()

        return try await withCheckedThrowingContinuation { continuation in
            db.runTransaction({ transaction, errorPointer in
                do {
                    let snapshot = try transaction.getDocument(ref)
                    guard snapshot.exists, let invite = try? snapshot.data(as: FriendInviteDocument.self) else {
                        errorPointer?.pointee = MatchServiceError.inviteNotFound as NSError
                        return nil
                    }
                    guard invite.isOpen, invite.matchId == nil else {
                        errorPointer?.pointee = MatchServiceError.inviteAlreadyClaimed as NSError
                        return nil
                    }
                    let match = MatchDocument.newMatch(
                        hostId: invite.hostId,
                        hostSnapshot: invite.hostSnapshot,
                        guestId: uid,
                        guestSnapshot: playerSnapshot
                    )
                    try transaction.setData(from: match, forDocument: matchRef)
                    transaction.updateData(["matchId": matchRef.documentID, "isOpen": false], forDocument: ref)
                    return matchRef.documentID
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let matchId = result as? String {
                    continuation.resume(returning: matchId)
                } else {
                    continuation.resume(throwing: MatchServiceError.matchNotFound)
                }
            }
        }
    }

    // MARK: - Match sync

    /// Streams every update to a match document until the stream is
    /// cancelled (e.g. the view disappears). Wraps Firestore's
    /// callback-based listener as an AsyncStream so callers can just
    /// `for await`.
    func observeMatch(matchId: String) -> AsyncStream<MatchDocument> {
        let ref = db.collection("matches").document(matchId)
        return AsyncStream { continuation in
            let listener = ref.addSnapshotListener { snapshot, error in
                guard let snapshot, let match = try? snapshot.data(as: MatchDocument.self) else { return }
                continuation.yield(match)
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func submitMove(matchId: String, isHost: Bool, move: AttackMove) async throws {
        let field = isHost ? "hostMove" : "guestMove"
        let data = try Firestore.Encoder().encode(move)
        try await db.collection("matches").document(matchId).updateData([field: data])
    }

    /// Attempts to resolve the current round. Safe to call from both
    /// clients — see the file header for why this can't double-resolve —
    /// but in practice only the host ever calls it (`OnlineBattleController`
    /// enforces that) since the guest doesn't need to.
    @discardableResult
    func resolveRoundIfReady(matchId: String) async throws -> Bool {
        let ref = db.collection("matches").document(matchId)
        return try await withCheckedThrowingContinuation { continuation in
            db.runTransaction({ transaction, errorPointer in
                do {
                    let snapshot = try transaction.getDocument(ref)
                    guard var match = try? snapshot.data(as: MatchDocument.self),
                          match.status == .active,
                          let hostMove = match.hostMove,
                          let guestMove = match.guestMove else {
                        return false
                    }

                    var host = CombatantState(snapshot: match.hostSnapshot)
                    host.currentHP = match.hostHP
                    host.energy = match.hostEnergy
                    var guest = CombatantState(snapshot: match.guestSnapshot ?? match.hostSnapshot)
                    guest.currentHP = match.guestHP
                    guest.energy = match.guestEnergy

                    let resolution = BattleEngine.resolveRound(
                        round: match.round,
                        attackerName: match.hostSnapshot.name,
                        attacker: &host,
                        attackerMove: hostMove,
                        defenderName: match.guestSnapshot?.name ?? "Opponent",
                        defender: &guest,
                        defenderMove: guestMove
                    )

                    match.hostHP = host.currentHP
                    match.guestHP = guest.currentHP
                    match.hostEnergy = host.energy
                    match.guestEnergy = guest.energy
                    match.hostMove = nil
                    match.guestMove = nil
                    match.log.append(resolution.logText)

                    if let outcome = BattleEngine.outcome(player: host, opponent: guest) {
                        match.status = .finished
                        match.outcome = outcome == .win ? .host : (outcome == .loss ? .guest : .draw)
                    } else {
                        match.round += 1
                    }

                    try transaction.setData(from: match, forDocument: ref)
                    return true
                } catch {
                    errorPointer?.pointee = error as NSError
                    return false
                }
            }) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (result as? Bool) ?? false)
                }
            }
        }
    }

    /// Marks the match abandoned by the local player so the opponent's
    /// client can declare itself the winner instead of hanging forever.
    func leaveMatch(matchId: String, uid: String) async {
        try? await db.collection("matches").document(matchId).updateData([
            "abandonedBy": uid,
            "status": MatchStatus.finished.rawValue,
        ])
    }

    // MARK: - Private helpers

    private func waitForMatchId(on ref: DocumentReference) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let listener = ref.addSnapshotListener { snapshot, error in
                guard !didResume else { return }
                if let error {
                    didResume = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot, snapshot.exists,
                      let matchId = snapshot.get("matchId") as? String else { return }
                didResume = true
                continuation.resume(returning: matchId)
            }
            // Keep a reference so it isn't deallocated mid-wait; whichever
            // caller invoked us is responsible for tearing it down via
            // cancelRandomMatchSearch()/cancelFriendInvite() if they give up.
            if ref.parent.path.hasPrefix("matchmakingQueue") {
                self.queueListener = listener
            } else {
                self.inviteListener = listener
            }
        }
    }

    private static func makeInviteCode(length: Int = 6) -> String {
        // Excludes visually-ambiguous characters (0/O, 1/I/L) since this is
        // meant to be read off one phone and typed into another.
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }
}
