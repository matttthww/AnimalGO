//
//  OnlineLobbyView.swift
//  Animal Go Proof Of Concept
//
//  Shown while OnlineBattleController is still connecting: either
//  searching for a random opponent, or waiting for a friend to enter an
//  invite code.
//

import SwiftUI

struct OnlineLobbyView: View {
    let session: BattleSessionState
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .controlSize(.large)

            if let code = session.inviteCode {
                VStack(spacing: 12) {
                    Text("Waiting for your friend...")
                        .font(.title3.bold())

                    if code != "..." {
                        Text(code)
                            .font(.system(.largeTitle, design: .monospaced).bold())
                            .tracking(4)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        ShareLink(item: "Battle me in Animal Go! Join with code \(code)") {
                            Label("Share Invite Code", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("Send them this code and it'll start automatically once they join.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                Text("Finding an opponent...")
                    .font(.title3.bold())
                Text("You'll battle whoever's found first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel", role: .destructive, action: onCancel)
                .padding(.bottom)
        }
        .padding()
    }
}
