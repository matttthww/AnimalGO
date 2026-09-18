//
//  BattleView.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/11/25.
//
//  REPLACED the placeholder stub with the real Battle tab: pick one of
//  your captured animals, then battle a CPU, find a random online
//  opponent, or play a specific friend.
//

import SwiftUI
import SwiftData

struct BattleView: View {
    @Query(sort: \Animal.score, order: .reverse) private var animals: [Animal]
    @State private var selectedAnimal: Animal?
    @State private var launchRequest: BattleLaunchRequest?
    @State private var showFriendSheet = false

    var body: some View {
        Group {
            if animals.isEmpty {
                ContentUnavailableView(
                    "No Animals Yet",
                    systemImage: "pawprint",
                    description: Text("Capture an animal on the Picture tab before you can battle with it.")
                )
            } else {
                battleMenu
            }
        }
        .navigationTitle("Battle")
        .onAppear {
            if selectedAnimal == nil || !animals.contains(where: { $0.id == selectedAnimal?.id }) {
                selectedAnimal = animals.first
            }
        }
        .fullScreenCover(item: $launchRequest) { request in
            BattleContainerView(request: request)
        }
        .sheet(isPresented: $showFriendSheet) {
            if let selectedAnimal {
                FriendBattleSheet(animal: selectedAnimal) { request in
                    showFriendSheet = false
                    launchRequest = request
                }
            }
        }
    }

    private var battleMenu: some View {
        ScrollView {
            VStack(spacing: 20) {
                animalPicker

                VStack(spacing: 12) {
                    battleModeButton(
                        title: "Practice vs CPU",
                        subtitle: "Battle a computer-controlled animal. Works offline.",
                        systemImage: "cpu",
                        tint: .blue
                    ) {
                        if let selectedAnimal {
                            launchRequest = BattleLaunchRequest(animal: selectedAnimal, kind: .cpu)
                        }
                    }

                    battleModeButton(
                        title: "Quick Match",
                        subtitle: "Get matched with a random opponent online.",
                        systemImage: "antenna.radiowaves.left.and.right",
                        tint: .green
                    ) {
                        if let selectedAnimal {
                            launchRequest = BattleLaunchRequest(animal: selectedAnimal, kind: .onlineRandom)
                        }
                    }

                    battleModeButton(
                        title: "Play a Friend",
                        subtitle: "Create or join a private match with an invite code.",
                        systemImage: "person.2.fill",
                        tint: .purple
                    ) {
                        showFriendSheet = true
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private var animalPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Battler")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(animals) { animal in
                        Button {
                            selectedAnimal = animal
                        } label: {
                            AnimalCard(animal: animal)
                                .frame(width: 140)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(selectedAnimal?.id == animal.id ? Color.accentColor : .clear, lineWidth: 3)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func battleModeButton(title: String, subtitle: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.15), in: Circle())
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(selectedAnimal == nil)
    }
}

#Preview {
    NavigationStack {
        BattleView()
    }
}
