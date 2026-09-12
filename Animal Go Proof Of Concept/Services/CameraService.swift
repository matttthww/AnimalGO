//
//  CameraModel.swift
//  Animal Go Proof Of Concept
//
//  Created by mattthew on 11/27/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Combine

final class CameraService: NSObject, ObservableObject {
    enum CameraError: Error {
        case deniedAuthorization
        case restrictedAuthorization
        case configurationFailed
        case captureFailed
    }

    @Published var isSessionRunning = false

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?

    private var photoCaptureCompletion: ((Result<UIImage, Error>) -> Void)?

    // Expose the session for preview
    var captureSession: AVCaptureSession { session }

    func checkPermissions() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard granted else { throw CameraError.deniedAuthorization }
        case .denied:
            throw CameraError.deniedAuthorization
        case .restricted:
            throw CameraError.restrictedAuthorization
        @unknown default:
            throw CameraError.restrictedAuthorization
        }
    }

    func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                        for: .video,
                                                        position: .back) else {
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }
        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
        } else {
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }

        // Output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        } else {
            session.commitConfiguration()
            throw CameraError.configurationFailed
        }

        session.commitConfiguration()
    }

    func start() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async { self.isSessionRunning = true }
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isSessionRunning = false }
        }
    }

    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        sessionQueue.async {
            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }
            settings.isHighResolutionPhotoEnabled = true

            self.photoCaptureCompletion = completion
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error = error {
            DispatchQueue.main.async { self.photoCaptureCompletion?(.failure(error)) }
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.photoCaptureCompletion?(.failure(CameraError.captureFailed)) }
            return
        }
        DispatchQueue.main.async { self.photoCaptureCompletion?(.success(image)) }
    }
}
