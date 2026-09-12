//
//  Animal_Structs.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 12/1/25.
//

import SwiftUI

import Foundation
import SwiftUI
import UIKit
import PhotosUI
import Combine
import SwiftData


@Model final class Animal: Decodable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var type: AnimalType
    var species_rarity: Int
    var subspecies_rarity: Int
    var temperament: Int
    var defensiveness: Int
    var size_kg: Double
    
    var score: Int
    var image: Data?
    var moves: [AttackMove] = []
    
    var uiImage: UIImage? {
        get { image.flatMap { UIImage(data: $0) } }
        set { image = newValue?.pngData() }
    }

    required init(from decoder: Decoder) throws {
        self.id = UUID()
        let container = try decoder.container(keyedBy: CodingKeys.self)
                
        self.name = try container.decode(String.self, forKey: .name)
        let typeString = try container.decode(String.self, forKey: .type)
        self.type = AnimalType(rawValue: typeString.lowercased()) ?? .ground
        self.species_rarity = try container.decode(Int.self, forKey: .species_rarity)
        self.subspecies_rarity = try container.decode(Int.self, forKey: .subspecies_rarity)
        
        self.temperament = try container.decode(Int.self, forKey: .temperament)
        self.defensiveness = try container.decode(Int.self, forKey: .defensiveness)
        self.size_kg = try container.decode(Double.self, forKey: .size_kg)
                
        self.score = 0
        self.image = nil
        self.moves = MoveAssigner.assignQuickAndCharged(to: self)
    }
    enum CodingKeys: String, CodingKey{
        case name
        case type
        case species_rarity
        case subspecies_rarity
        case temperament
        case defensiveness
        case size_kg
    }
    init(id: UUID = UUID(), name: String, type: AnimalType, species_rarity: Int, subspecies_rarity: Int, temperament: Int, defensiveness: Int, size_kg: Double, score: Int, image: Data?) {
        self.id = id
        self.name = name
        self.type = type
        self.species_rarity = species_rarity
        self.subspecies_rarity = subspecies_rarity
        self.temperament = temperament
        self.defensiveness = defensiveness
        self.size_kg = size_kg
        self.score = score
        self.image = image
        self.moves = MoveAssigner.assignQuickAndCharged(to: self)
    }
    
    func calculateScore() -> Int{
        let rarityScore = (Double(species_rarity + subspecies_rarity) * 100.0)
        let difficultyScore = (Double(temperament + defensiveness) * 10.0)
        let sizeBonus = sqrt(max(1.0, size_kg))
        let total = rarityScore + difficultyScore + sizeBonus
                
        return Int(total)
    }
    
    static func == (lhs: Animal, rhs: Animal) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum AnimalType: String, Codable, CaseIterable, Sendable {
    case fire
    case water
    case grass
    case electric
    case rock
    case flying
    case ground
    case fighting
    
}

enum MoveLibrary {
    static let allMoves: [AttackMove] = [
        AttackMove(name: "Flame Burst", type: .fire, power: 55, accuracy: 0.95, energyCost: 25, description: "A quick burst of flame.", category: .quick),
        AttackMove(name: "Inferno Spin", type: .fire, power: 80, accuracy: 0.80, energyCost: 40, description: "A powerful spiraling blaze.", category: .charged),
        AttackMove(name: "Water Jet", type: .water, power: 50, accuracy: 0.98, energyCost: 20, description: "A pressurized jet of water.", category: .quick),
        AttackMove(name: "Tidal Crash", type: .water, power: 85, accuracy: 0.75, energyCost: 45, description: "A crushing wave attack.", category: .charged),
        AttackMove(name: "Leaf Slash", type: .grass, power: 50, accuracy: 0.95, energyCost: 20, description: "A slicing leaf attack.", category: .quick),
        AttackMove(name: "Vine Crush", type: .grass, power: 75, accuracy: 0.85, energyCost: 35, description: "Crushing vines entangle the foe.", category: .charged),
        AttackMove(name: "Thunder Jolt", type: .electric, power: 55, accuracy: 0.90, energyCost: 25, description: "A jolt of electricity.", category: .quick),
        AttackMove(name: "Lightning Strike", type: .electric, power: 90, accuracy: 0.70, energyCost: 50, description: "A devastating bolt from above.", category: .charged),
        AttackMove(name: "Pebble Flick", type: .rock, power: 52, accuracy: 0.96, energyCost: 22, description: "A rapid flick of small stones.", category: .quick),
        AttackMove(name: "Boulder Crash", type: .rock, power: 88, accuracy: 0.76, energyCost: 48, description: "A massive boulder slams into the foe.", category: .charged),
        AttackMove(name: "Gale Peck", type: .flying, power: 53, accuracy: 0.94, energyCost: 24, description: "A swift strike riding the wind.", category: .quick),
        AttackMove(name: "Sky Dive", type: .flying, power: 86, accuracy: 0.78, energyCost: 44, description: "A high-altitude plunge attack.", category: .charged),
        AttackMove(name: "Dust Kick", type: .ground, power: 50, accuracy: 0.97, energyCost: 20, description: "A blinding kick of dust.", category: .quick),
        AttackMove(name: "Quake Breaker", type: .ground, power: 90, accuracy: 0.72, energyCost: 50, description: "A bone-rattling ground quake.", category: .charged),
        AttackMove(name: "Jab Flurry", type: .fighting, power: 56, accuracy: 0.92, energyCost: 26, description: "A rapid series of precise jabs.", category: .quick),
        AttackMove(name: "Crushing Uppercut", type: .fighting, power: 92, accuracy: 0.70, energyCost: 52, description: "A devastating rising punch.", category: .charged),
    ]

    static func moves(for type: AnimalType) -> [AttackMove] {
        allMoves.filter { $0.type == type }
    }
}

enum MoveCategory: String, Codable, Sendable { case quick, charged }

struct AttackMove: Identifiable, Hashable, Codable, Sendable {
    let id: UUID = UUID()
    let name: String
    let type: AnimalType
    let power: Int
    let accuracy: Double
    let energyCost: Int
    let description: String
    let category: MoveCategory
}

struct MoveAssigner {
    static func assignQuickAndCharged(to animal: Animal) -> [AttackMove] {
        let typeMoves = MoveLibrary.moves(for: animal.type)
        let quick = typeMoves.filter { $0.category == .quick }.randomElement()
        let charged = typeMoves.filter { $0.category == .charged }.randomElement()
        return [quick, charged].compactMap { $0 }
    }
}

