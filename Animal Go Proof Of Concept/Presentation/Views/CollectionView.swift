//
//  CollectionView.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/10/25.
//

import SwiftUI
import SwiftData

struct CollectionView: View {
    @Query(sort: \Animal.name) private var fetchedAnimals: [Animal]
    @Binding var vm: NetworkUIModel
    
    let columns = [
        GridItem(.adaptive(minimum: 140),spacing:16),
        
    ]
    
    var body: some View {
        ScrollView {
            
            if vm.Animals.isEmpty{
                ContentUnavailableView(
                    "No Animals Yet",
                    systemImage: "pawprint",
                    description: Text("Log some animals")
                )
            }else{
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(vm.Animals) { animal in
                        NavigationLink {
                            AnimalInfoView(vm: $vm, animal: animal)
                        } label: {
                            AnimalCard(animal: animal)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .navigationBarTitle("Animals")
            }}
                .onChange(of: fetchedAnimals) { _, newValue in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        vm.Animals = newValue}
                }
                .task {
                    vm.Animals = fetchedAnimals
                
        }
    }}
/*#Preview {
    CollectionView()
}
*/
