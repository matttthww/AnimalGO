//
//  BattleContainerView.swift
//  Animal Go Proof Of Concept
//
//  Owns the actual BattleController for one battle (created once, kept
//  alive for the life of this screen) and routes to the right sub-view
//  based on BattleSessionState.phase. This is the one place that needs to
//  know both CPUBattleController and OnlineBattleController exist —
//  everything below it just sees `any BattleController`.
//

import SwiftUI

struct BattleContainerView: View {
    let request: BattleLaunchRequest

    @Environment(\.dismiss) private var dismiss
    @State private var controller: (any BattleController)?

    var body: some View {
        Group {
            if let controller {
                BattleFlowView(controller: controller, onExit: exit)
            } else {
                ProgressView("Preparing battle...")
            }
        }
        .task {
            guard controller == nil else { return }
            let newController = request.makeController()
            controller = newController
            newController.begin()
        }
    }

    private func exit() {
        controller?.leaveBattle()
        dismiss()
    }
}

/// Routes to connecting/lobby, live combat, or the result screen based on
/// the session's current phase.
private struct BattleFlowView: View {
    let controller: any BattleController
    let onExit: () -> Void

    private var session: BattleSessionState { controller.session }

    var body: some View {
        Group {
            switch session.phase {
            case .connecting:
                OnlineLobbyView(session: session, onCancel: onExit)
            case .starting, .selectingMove, .resolvingRound:
                LiveBattleView(controller: controller, onExit: onExit)
            case .finished(let outcome):
                BattleResultView(session: session, outcome: outcome, onExit: onExit)
            }
        }
        .alert(
            "Battle Error",
            isPresented: Binding(
                get: { session.errorMessage != nil },
                set: { if !$0 { session.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { onExit() }
        } message: {
            Text(session.errorMessage ?? "")
        }
    }
}
