//
//  BattleResultView.swift
//  Animal Go Proof Of Concept
//
//  Shown once a battle's phase becomes `.finished`. Same screen for every
//  mode; only the headline/tint changes based on the outcome.
//

import SwiftUI

struct BattleResultView: View {
    let session: BattleSessionState
    let outcome: BattleOutcome
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 72))
                .foregroundStyle(tint)

            VStack(spacing: 8) {
                Text(headline)
                    .font(.largeTitle.bold())
                Text(subheadline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let opponent = session.opponent {
                HStack(spacing: 24) {
                    resultStat(title: session.player.snapshot.name, hp: session.player.currentHP, maxHP: session.player.maxHP)
                    Image(systemName: "bolt.fill").foregroundStyle(.secondary)
                    resultStat(title: opponent.snapshot.name, hp: opponent.currentHP, maxHP: opponent.maxHP)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Spacer()

            Button {
                onExit()
            } label: {
                Text("Back to Battle Menu")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }

    private var iconName: String {
        switch outcome {
        case .win: return "trophy.fill"
        case .loss: return "xmark.circle.fill"
        case .draw: return "equal.circle.fill"
        case .opponentLeft: return "person.fill.xmark"
        }
    }

    private var tint: Color {
        switch outcome {
        case .win: return .yellow
        case .loss: return .red
        case .draw: return .gray
        case .opponentLeft: return .orange
        }
    }

    private var headline: String {
        switch outcome {
        case .win: return "Victory!"
        case .loss: return "Defeated"
        case .draw: return "Draw"
        case .opponentLeft: return "Opponent Left"
        }
    }

    private var subheadline: String {
        switch outcome {
        case .win: return "\(session.player.snapshot.name) won the battle!"
        case .loss: return "\(session.opponentDisplayName) was too strong this time."
        case .draw: return "Both animals went down at the same time."
        case .opponentLeft: return "Your opponent left the match — you win by default."
        }
    }

    private func resultStat(title: String, hp: Int, maxHP: Int) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.headline)
            Text("\(max(0, hp))/\(maxHP) HP")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
