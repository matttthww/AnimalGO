//
//  ContentView.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/7/25.
//

import SwiftUI
import UIKit
import PhotosUI
import SwiftData

struct PictureView: View {
    @Binding var vm: NetworkUIModel
    @Binding var gm: ScanGameModel
    @Environment(\.modelContext) var modelContext

    var body: some View {
        
        VStack {
            VStack(spacing: 16) {
                Text("Animal Go")
                    .font(.largeTitle)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                HStack{
                    PhotosPicker(selection: $vm.selectedImage) {
                        VStack(spacing: 8) {
                            Image(systemName: "binoculars")
                                .font(.system(size: 72, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                            Text("Choose a photo")
                                .font(.headline)
                        }
                        .padding(20)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose a photo to analyze")
                    
                    Button {
                        vm.showCamera = true
                    } label: {
                        VStack{
                            Image(systemName: "camera")
                                .font(.system(size:72, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                            Text("Take a pic")
                            .font(.headline)}
                    }
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style:.continuous))
                    .shadow(radius:4, y:2)
                }
                
                if let uiImage = vm.selectedUIImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 240)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                }
                
                if vm.isLoading  {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing photo…")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                } else if vm.selectedUIImage != nil {
                    Button {
                        vm.analyzeImage()
                    } label: {
                        Label("Analyze & Log", systemImage: "pawprint.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)
                    .disabled(vm.selectedUIImage == nil || vm.isLoading)
                }
                
                if !vm.resultText.isEmpty {
                    Text(vm.resultText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
        
            }
            .padding()
           
        }
        .padding(.horizontal)
        .fullScreenCover(isPresented: $vm.showMinigame){
            if let animal = vm.resultAnimal{
                ScanMinigameView(vm: $gm, animal: animal)
                    .onDisappear {
                        gm.caught = false
                        gm.didTimeout = false
                    }
            }
            
            
        }
        .fullScreenCover(isPresented: $vm.showCamera) {
            AVCameraScreen { image in
                vm.selectedUIImage = image
            }
        }
        .onChange(of: gm.caught){oldValue, newValue in
            if newValue == true{
                if let newAnimal = vm.resultAnimal{
                    vm.addAnimal(newAnimal, modelContext: modelContext)
                    vm.resultText = "Success! \(newAnimal.name) added to log."
                }
                vm.showMinigame = false
                vm.showAddAnimal = false
                gm.caught = false
            }
            
        }
        .onChange(of: gm.didTimeout){oldValue, newValue in
            if newValue == true{
                withAnimation(.easeInOut){
                    vm.showMinigame = false
                    vm.resultText = "Time's Up!"}
            }
                
        }
        .background {
                Image("gem_wallpaper")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
        }
        
        
    }
    
   
}
/*
#Preview {
    PictureView()
}
*/
