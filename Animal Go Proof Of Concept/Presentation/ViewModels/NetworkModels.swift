//
//  Network.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/7/25.
//

import Foundation
import SwiftUI
import UIKit
import PhotosUI
import Combine
import SwiftData


@Observable
class NetworkUIModel {
    var Animals: [Animal] = []
    var resultText: String = "Click the binoculars to log an animal"
    var isLoading: Bool = false
    var apiKey = KeyManager.apiKey
    var selectedImage: PhotosPickerItem?{
        didSet{
            Task{
                await loadImage(from: selectedImage)
            }
        }
    }
    var selectedUIImage: UIImage?
    var defaultUIImage: UIImage? = nil
    var resultAnimal: Animal?
    var showAddAnimal: Bool = false
    var showMinigame: Bool = false
    var an_image: UIImage = UIImage()
    var showCamera = false
    
    init() {}
    
    func addAnimal(_ animal: Animal, modelContext: ModelContext) {
        Animals.append(animal)
        modelContext.insert(animal)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save animal: \(error)")
        }
    }
    
    func deleteAnimal(_ animal: Animal, modelContext: ModelContext){
        if let index = Animals.firstIndex(where: { $0.id == animal.id }) {
            Animals.remove(at: index)
        }
        modelContext.delete(animal)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete animal: \(error)")
        }
        
    }
    
    func loadImage(from item: PhotosPickerItem?) async {
            guard let item = item else {
             
                self.selectedUIImage = nil
                return
            }
            
            do {
                // Try to load the item's data
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    self.resultText = "Failed to load data from picker item."
                    return
                }
                
                // Convert the data into a UIImage
                guard let uiImage = UIImage(data: data) else {
                    self.resultText = "Failed to convert data to image."
                    return
                }
                
                // Success! Store the converted image and update the text.
                self.selectedUIImage = uiImage
                self.resultText = "Image loaded. Ready to analyze."
                
            } catch {
                self.resultText = "Error loading image: \(error.localizedDescription)"
            }
        }
    
    
    func analyzeImage() {
                
        guard let imageToAnalyze = selectedUIImage else {
                    self.resultText = "Please select an image first."
                    return
                }
        
        isLoading = true
        resultText = "Analyzing..."
        resultAnimal = nil
        
        Task {
            do {
                
                let animal = try await getAnimalScores(image: imageToAnalyze, apiKey: apiKey)
                animal.score = animal.calculateScore()
                animal.image = imageToAnalyze.pngData()
                
                
                self.resultAnimal = animal
                self.resultText = "Analysis Complete!"
                self.showAddAnimal = true
                self.isLoading = false
                self.showMinigame = true
                
            } catch {
                self.resultText = "Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    
}

@Observable
class ScanGameModel{
    private var gameTimer: AnyCancellable?
    var scanProgress: Double = 0.0
    var targetPosition: CGPoint = .zero
    var scannerPosition: CGPoint = .zero
    var isScanning: Bool = false
    var caught: Bool = false
    //targets speed
    private var targetSpeed: Double = 2.0
    //scan duration
    private var scanDuration: Double = 5.0
    private var playAreaSize: CGSize = .zero
    
    var countdown: Double = 0.0
    var didTimeout: Bool = false
    var selectedUIImage: UIImage?
    
    
    func startScanMiniGame(animalStats: Animal, size: CGSize) {
        
        self.playAreaSize = size
        self.scanProgress = 0.0
        self.isScanning = true
        self.caught = false
        self.targetPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        self.scannerPosition = CGPoint(x: 150,y: 150)
        
        
        self.didTimeout = false
        
        let temperament = animalStats.temperament
        let rarity = animalStats.species_rarity + animalStats.subspecies_rarity
        
        self.countdown = Double(rarity)*1.5 + 3
        self.targetSpeed = Double(temperament) * 2.5 + 7.0
        self.scanDuration = Double(rarity) * 0.5 + 3
        self.selectedUIImage = animalStats.uiImage
        
        self.gameTimer = Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink{[weak self] _ in
                self?.gameLoop()
            }
    }
    
    func stopScanMinigame(){
        self.isScanning = false
        self.gameTimer?.cancel()
    }
    private func gameLoop(){
        let randomX = Double.random(in: -targetSpeed...targetSpeed)
        let randomY = Double.random(in: -targetSpeed...targetSpeed)
        
        let newX = min(max(targetPosition.x + randomX, 0), playAreaSize.width)
        let newY = min(max(targetPosition.y + randomY, 0), playAreaSize.height)
        targetPosition = CGPoint(x: newX, y: newY)
        
        let distance = hypot(scannerPosition.x - targetPosition.x, scannerPosition.y - targetPosition.y)
        let isHit = distance < 125
        let progressPerFrame = (1.0/scanDuration) / 60.0
        if isHit{
            scanProgress += progressPerFrame
        }else{
            scanProgress -= progressPerFrame
        }
        
        self.countdown -= 1.0 / 60.0
        if self.countdown <= 0 && scanProgress < 1.0 {
            self.countdown = 0
            stopScanMinigame()
            
            didTimeout = true
            caught = false
            scanProgress = max(scanProgress, 0)
        }
        
        if scanProgress >= 1.0 {
            scanProgress = 1.0
            stopScanMinigame()
            caught = true
            
        }
        
    }
    
    
}


