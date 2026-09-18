//
//  FriendBattleSheet.swift
//  Animal Go Proof Of Concept
//
//  Small chooser presented from the Battle tab's "Play a Friend" button:
//  either host a new invite or join one a friend already sent you.
//

import SwiftUI

struct FriendBattleSheet: View {
    let animal: Animal
    let onLaunch: (BattleLaunchRequest) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var joinCode: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        onLaunch(BattleLaunchRequest(animal: animal, kind: .onlineFriendHost))
                    } label: {
                        Label("Create an Invite", systemImage: "plus.message")
                    }
                } footer: {
                    Text("You'll get a code to send your friend however you like — text, AirDrop, whatever.")
                }

                Section {
                    TextField("Enter Code", text: $joinCode)
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        .keyboardType(.asciiCapable)
                        #endif
                        .autocorrectionDisabled()

                    Button {
                        let trimmed = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onLaunch(BattleLaunchRequest(animal: animal, kind: .onlineFriendJoin(code: trimmed)))
                    } label: {
                        Label("Join Friend's Battle", systemImage: "arrow.right.circle")
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Got a code from a friend? Enter it here to battle them directly.")
                }
            }
            .navigationTitle("Play a Friend")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
