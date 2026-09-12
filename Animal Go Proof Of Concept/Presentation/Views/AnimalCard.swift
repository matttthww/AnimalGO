//
//  AnimalCard.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/11/25.
//

import SwiftUI
import UIKit
import SwiftData

struct AnimalCard: View {
    let animal: Animal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let imageData = animal.image, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                }
                  
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(animal.name)
                .font(.headline)
                .lineLimit(1)

            
            Text("\(animal.score)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .hoverEffect(.lift) // iOS/iPadOS
        }
        
    }


#Preview {
    let previewAnimal = Animal(
        name: "Capuchin Monkey",
        type: .ground,
        species_rarity: 4,
        subspecies_rarity: 4,
        temperament: 5,
        defensiveness: 4,
        size_kg: 3.0,
        score: 100,
        image: UIImage(named: "MyAnimalImage")?.pngData() 
    )
    
}
