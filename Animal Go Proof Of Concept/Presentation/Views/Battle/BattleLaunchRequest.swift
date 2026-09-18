//
//  BattleLaunchRequest.swift
//  Animal Go Proof Of Concept
//
//  Everything needed to spin up one battle, bundled so it can drive a
//  single `.fullScreenCover(item:)` from BattleView regardless of which
//  mode was picked.
//

import Foundation

struct BattleLaunchRequest: Identifiable {
    enum Kind {
        case cpu
        case onlineRandom
        case onlineFriendHost
        case onlineFriendJoin(code: String)
    }

    let id = UUID()
    let animal: Animal
    let kind: Kind

    @MainActor
    func makeController() -> any BattleController {
        switch kind {
        case .cpu:
            return CPUBattleController(playerAnimal: animal)
        case .onlineRandom:
            return OnlineBattleController(playerAnimal: animal, mode: .onlineRandom)
        case .onlineFriendHost:
            return OnlineBattleController(playerAnimal: animal, mode: .onlineFriend)
        case .onlineFriendJoin(let code):
            return OnlineBattleController(playerAnimal: animal, mode: .onlineFriend, joinCode: code)
        }
    }
}
