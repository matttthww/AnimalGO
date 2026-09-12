//
//  Tabs.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/10/25.
//

import SwiftUI

struct ContentView: View {
    @State private var vm = NetworkUIModel()
    @State private var gm = ScanGameModel()
    @State private var selectedTab = 1 
 

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CollectionView(vm: $vm)
            }
            .tabItem {
                Label("Collection", systemImage: "sdcard")
            }
            .tag(0)

            NavigationStack {
                PictureView(vm: $vm, gm: $gm)
            }
            .tabItem {
                Label("Picture", systemImage: "camera")
            }
            .tag(1)

            NavigationStack {
                BattleView()
            }
            .tabItem {
                Label("Battle", systemImage: "antenna.radiowaves.left.and.right")
            }
            .tag(2)
        }
    }
}


#Preview {
     ContentView()
}

