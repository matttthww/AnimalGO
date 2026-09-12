//
//  Animal_Go_Proof_Of_ConceptApp.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/7/25.
//

import SwiftUI
import SwiftData

@main
struct Animal_Go_Proof_Of_ConceptApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Animal.self])
    }
}
