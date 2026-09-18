//
//  FirebaseBootstrap.swift
//  Animal Go Proof Of Concept
//
//  Configures Firebase exactly once, and only if GoogleService-Info.plist
//  is actually present. Without this guard, calling FirebaseApp.configure()
//  with no config file crashes at launch — which would mean nobody could
//  even build and try CPU battles until Firebase is fully set up. With it,
//  online battles simply fail with a friendly error until you finish the
//  setup guide, and everything else keeps working.
//

import FirebaseCore
import Foundation

enum FirebaseBootstrap {
    private(set) static var isConfigured = false

    static func configureIfAvailable() {
        guard !isConfigured else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("⚠️ GoogleService-Info.plist not found — online battles are disabled until Firebase is set up. See the online-mode setup guide.")
            return
        }
        FirebaseApp.configure()
        isConfigured = true
    }
}
