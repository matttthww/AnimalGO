//
//  ScanMinigameView.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/17/25.
//

import SwiftUI

struct ScanMinigameView: View {
    @Binding var vm: ScanGameModel
    let animal: Animal
    
    var body: some View {
        ZStack{
            if !vm.isScanning {
                VStack {
                    Spacer()
                    Text("Tap and hold to start scanning!")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3)) 
                .ignoresSafeArea()
            }
            GeometryReader{ geo in
                Color.black.opacity(0.01)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged{value in
                                
                                if !vm.isScanning{
                                    vm.startScanMiniGame(animalStats: animal, size: geo.size)
                                }
                                vm.scannerPosition = value.location
                            }
                            .onEnded{ _ in
                                vm.stopScanMinigame()}
                    )
                if vm.isScanning{
                    if let image = $vm.wrappedValue.selectedUIImage{
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width:250)
                            .position(vm.targetPosition)
                            .animation(.easeInOut(duration: 0.3), value:vm.targetPosition)
                    }
                    
                    Image(systemName: "scope")
                        .font(.system(size:60))
                        .foregroundColor(.cyan)
                    .position(vm.scannerPosition)}
            }
            .ignoresSafeArea()
            VStack{
                Text(vm.isScanning ? "Scanning ... Keep you scanner on target!" : "Tap and hold to scan.")
                Text(String(format: "%.1f", vm.countdown))
                    .padding()
                    .background(.black.opacity(0.5))
                    .cornerRadius(10)
                ProgressView(value: vm.scanProgress)
                    .padding()
                Spacer()
            }
            .foregroundStyle(.white)
        }
        .onDisappear{
            vm.stopScanMinigame()
        }
    }
}

//#Preview {
//    ScanMinigameView()
//}
