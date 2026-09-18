//
//  FirestoreMatchModels.swift
//  Animal Go Proof Of Concept
//
//  Wire schema for online battles. Three Firestore collections:
//
//   - "matchmakingQueue": one doc per player waiting for a random opponent.
//   - "friendInvites":    one doc per open invite code, keyed by the code.
//   - "matches":          one doc per in-progress or finished battle.
//
//  Both the random-match and friend-invite flows end the same way: a
//  "matches" doc gets created and both clients switch to observing it.
//  Whoever CREATED the match ("host") is the only client that ever writes
//  a resolved round — see OnlineBattleController for why.
//
//  Requires the Firebase SDK (FirebaseFirestore) via Swift Package
//  Manager — see the setup guide delivered alongside this code.
//

import FirebaseFirestore
import Foundation

enum MatchStatus: String, Codable, Sendable {
    case waiting   // match doc exists but a guest hasn't joined yet (not currently used by the queue/invite flows below, reserved for future host-creates-match-first variants)
    case active
    case finished
}

enum MatchOutcome: String, Codable, Sendable {
    case host
    case guest
    case draw
}

/// The authoritative document for one online battle. Both players read the
/// same doc and derive their own "am I host or guest" perspective from
/// whichever uid matches their own Firebase Auth uid.
struct MatchDocument: Codable, Sendable {
    var hostId: String
    var guestId: String?

    var hostSnapshot: BattleAnimalSnapshot
    var guestSnapshot: BattleAnimalSnapshot?

    var hostHP: Int
    var guestHP: Int
    var hostEnergy: Int
    var guestEnergy: Int

    var round: Int
    var hostMove: AttackMove?
    var guestMove: AttackMove?

    var status: MatchStatus
    var outcome: MatchOutcome?
    /// Set to the uid of whichever player backed out early. The other
    /// player's client treats this as an automatic win.
    var abandonedBy: String?

    var log: [String]

    @ServerTimestamp var updatedAt: Timestamp?

    static func newMatch(hostId: String, hostSnapshot: BattleAnimalSnapshot, guestId: String, guestSnapshot: BattleAnimalSnapshot) -> MatchDocument {
        MatchDocument(
            hostId: hostId,
            guestId: guestId,
            hostSnapshot: hostSnapshot,
            guestSnapshot: guestSnapshot,
            hostHP: hostSnapshot.maxHP,
            guestHP: guestSnapshot.maxHP,
            hostEnergy: 0,
            guestEnergy: 0,
            round: 1,
            hostMove: nil,
            guestMove: nil,
            status: .active,
            outcome: nil,
            abandonedBy: nil,
            log: []
        )
    }
}

/// One player waiting in the random-matchmaking pool.
struct MatchmakingQueueEntry: Codable, Sendable {
    var hostId: String
    var hostSnapshot: BattleAnimalSnapshot
    /// Filled in by whoever claims this entry, pointing the waiting
    /// player at the new "matches" document.
    var matchId: String?
    @ServerTimestamp var createdAt: Timestamp?
}

/// One open "play a friend" invite, keyed by its short code.
struct FriendInviteDocument: Codable, Sendable {
    var hostId: String
    var hostSnapshot: BattleAnimalSnapshot
    var matchId: String?
    var isOpen: Bool
    @ServerTimestamp var createdAt: Timestamp?
}
