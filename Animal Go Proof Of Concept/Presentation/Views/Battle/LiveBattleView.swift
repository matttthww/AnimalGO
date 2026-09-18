//
//  LiveBattleView.swift
//  Animal Go Proof Of Concept
//
//  The actual combat screen: shared by CPU battles, random online
//  matches, and friend battles alike, since it only ever talks to the
//  `BattleController` protocol and `BattleSessionState`. Rounds are
//  simultaneous — both sides lock in a move within the countdown, then
//  the round resolves and HP/energy update together.
//

import SwiftUI

struct LiveBattleView: View {
    let controller: any BattleController
    let onExit: () -> Void

    @State private var showLeaveConfirmation = false

    private var session: BattleSessionState { controller.session }

    var body: some View {
        VStack(spacing: 16) {
            if let opponent = session.opponent {
                CombatantHeaderView(name: session.opponentDisplayName, combatant: opponent, image: nil, isPlayer: false)
            }

            timerRing

            CombatantHeaderView(name: session.player.snapshot.name, combatant: session.player, image: session.player.snapshot.imageData, isPlayer: true)

            statusLine

            moveButtons

            battleLog
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Leave") { showLeaveConfirmation = true }
            }
        }
        .confirmationDialog("Leave this battle?", isPresented: $showLeaveConfirmation, titleVisibility: .visible) {
            Button("Leave Battle", role: .destructive, action: onExit)
            Button("Keep Battling", role: .cancel) {}
        }
    }

    private var timerRing: some View {
        HStack {
            Spacer()
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0, session.secondsRemaining / max(session.roundDuration, 0.01)))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(session.secondsRemaining.rounded(.up)))")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 44, height: 44)
            .animation(.linear(duration: 0.1), value: session.secondsRemaining)
            Spacer()
        }
    }

    private var statusLine: some View {
        Text(statusText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var statusText: String {
        switch session.phase {
        case .starting: return "Get ready..."
        case .selectingMove: return "Choose your move!"
        case .resolvingRound:
            return session.hasSubmittedMoveThisRound ? "Move locked in — waiting..." : "Resolving round..."
        default: return ""
        }
    }

    private var moveButtons: some View {
        HStack(spacing: 12) {
            ForEach(session.player.snapshot.moves) { move in
                MoveButtonView(
                    move: move,
                    isUsable: BattleEngine.canUse(move, withEnergy: session.player.energy),
                    isLocked: session.hasSubmittedMoveThisRound || session.phase != .selectingMove
                ) {
                    controller.selectMove(move)
                }
            }
        }
    }

    private var battleLog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(session.log) { entry in
                        Text(entry.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .id(entry.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 4)
            .onChange(of: session.log.count) { _, _ in
                if let last = session.log.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
}

private struct CombatantHeaderView: View {
    let name: String
    let combatant: CombatantState
    let image: Data?
    let isPlayer: Bool

    private var alignment: HorizontalAlignment { isPlayer ? .trailing : .leading }

    var body: some View {
        HStack(spacing: 12) {
            if isPlayer {
                stats
                portrait
            } else {
                portrait
                stats
            }
        }
    }

    private var portrait: some View {
        Group {
            if let image, let uiImage = UIImage(data: image) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .background(.thinMaterial, in: Circle())
        .clipShape(Circle())
    }

    private var stats: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(name)
                .font(.headline)
            Text(String(describing: combatant.snapshot.type).capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)

            statBar(value: combatant.currentHP, max: combatant.maxHP, color: .red, label: "HP")
            statBar(value: combatant.energy, max: BattleEngine.maxEnergy, color: .yellow, label: "Energy")
        }
        .frame(maxWidth: .infinity, alignment: isPlayer ? .trailing : .leading)
    }

    private func statBar(value: Int, max: Int, color: Color, label: String) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: isPlayer ? .trailing : .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / CGFloat(Swift.max(max, 1)))
                }
            }
            .frame(height: 8)
            Text("\(label): \(value)/\(max)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 160)
    }
}

private struct MoveButtonView: View {
    let move: AttackMove
    let isUsable: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(move.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(move.category == .quick ? "Quick" : "Charged")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Label("\(move.power)", systemImage: "bolt.fill")
                    Label(move.category == .quick ? "+\(move.energyCost)" : "-\(move.energyCost)", systemImage: "battery.100")
                }
                .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                (isUsable ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1)),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isUsable ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .disabled(!isUsable || isLocked)
        .buttonStyle(.plain)
    }
}
