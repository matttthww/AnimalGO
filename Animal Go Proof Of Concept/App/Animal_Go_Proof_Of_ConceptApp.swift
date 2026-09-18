//
//  Animal_Go_Proof_Of_ConceptApp.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/7/25.
//
//  MODIFIED to configure Firebase (for online battles) at launch, guarded
//  so the app still runs fine before Firebase is set up — see
//  Services/Battle/FirebaseBootstrap.swift.
//

import SwiftUI
import SwiftData

@main
struct Animal_Go_Proof_Of_ConceptApp: App {
    init() {
        FirebaseBootstrap.configureIfAvailable()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Animal.self])
    }
}
