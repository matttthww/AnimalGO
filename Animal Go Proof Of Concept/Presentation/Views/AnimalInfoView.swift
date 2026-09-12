//
//  AnimalInfoView.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/22/25.
//

import SwiftUI

struct AnimalInfoView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var vm: NetworkUIModel
    let animal: Animal
    var body: some View {
        ScrollView{
            VStack(spacing:5){
                Spacer()
                
                if let imageData = animal.image, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 240)
                        .clipped()
                        .cornerRadius(16)
                        .shadow(radius: 6, y: 3)
                        .overlay(alignment: .bottomLeading) {
                            LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 80)
                                .cornerRadius(16)
                                .overlay(
                                    Text(animal.name)
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                        .padding(),
                                    alignment: .bottomLeading
                                )
                        }
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                }
                
                Spacer()
                   
                HStack{
                    VStack(spacing: 15){
                        Text("Overview")
                            .font(.title).bold()
                        Text("Score: \(animal.score)")
                            .font(.subheadline)
                        HStack{
                            Text("est. Size:")
                                .font(.subheadline)
                            Text(String(format: "%.1f", animal.size_kg))
                                .font(.subheadline)
                            Text("kg")
                                .font(.subheadline)
                            
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    VStack(spacing: 15){
                        Text("Rarity")
                            .font(.title).bold()
                        Text("Species Rarity: \(animal.species_rarity)")
                            .font(.subheadline)
                        Text("Subspecies Rarity: \(animal.subspecies_rarity)")
                            .font(.subheadline)
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    VStack(spacing: 15){
                        Text("Behavior")
                            .font(.title).bold()
                        Text("Temperament: \(animal.temperament)")
                            .font(.subheadline)
                        Text("Defensiveness: \(animal.defensiveness)")
                            .font(.subheadline)
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                  
                }
                Spacer()
                
// Combat Section
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(.secondary)
            Text("Combat")
                .font(.title2).bold()
            Spacer()
            // type symbol should go here
            Text(String(describing: animal.type))
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                .overlay(
                    Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                )
        }
        .padding(.horizontal, 4)
        
    

        if animal.moves.isEmpty {
            Text("No moves available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        } else {
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(animal.moves, id: \.self) { move in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(move.name)
                                .font(.headline)
                                .lineLimit(1)
                            Spacer()
                            Text(String(describing: move.type))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.thinMaterial))
                        }

                        HStack(spacing: 12) {
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                                    Text("Power")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(String(describing: move.power))
                                        .font(.caption)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "scope").foregroundStyle(.blue)
                                    Text("Accuracy")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(String(describing: move.accuracy))
                                        .font(.caption)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "battery.100").foregroundStyle(.green)
                                    Text("Energy")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(String(describing: move.energyCost))
                                        .font(.caption)
                                }
                            }
                            Spacer(minLength: 0)
                        }

                        if !move.description.isEmpty {
                            Text(move.description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.quaternary, lineWidth: 0.5)
                    )
                    .shadow(radius: 2, y: 1)
                }
            }
        }
    }
                
              
            }
        }
        .safeAreaInset(edge: .bottom){
            Button {
                vm.deleteAnimal(animal, modelContext: modelContext)
                dismiss()
            } label: {
                Text("Delete Animal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding()
            .background(.ultraThinMaterial)
        }
    }}
