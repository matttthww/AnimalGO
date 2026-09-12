import SwiftUI
import AVFoundation

struct AVCameraScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()
    let onCapture: (UIImage) -> Void

    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if camera.isSessionRunning {
                CameraPreviewView(session: camera.captureSession)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white, .black.opacity(0.2))
                    }
                    .padding()
                    Spacer()
                }
                Spacer()

                Button {
                    camera.capturePhoto { result in
                        switch result {
                        case .success(let image):
                            onCapture(image)
                            dismiss()
                        case .failure(let error):
                            errorMessage = "Capture failed: \(error.localizedDescription)"
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                        Circle()
                            .strokeBorder(.white.opacity(0.6), lineWidth: 4)
                            .frame(width: 86, height: 86)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .task {
            do {
                try await camera.checkPermissions()
                try camera.configureSession()
                camera.start()
            } catch {
                errorMessage = friendlyError(for: error)
            }
        }
        .onDisappear { camera.stop() }
        .alert("Camera Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func friendlyError(for error: Error) -> String {
        if let e = error as? CameraService.CameraError {
            switch e {
            case .deniedAuthorization:
                return "Camera access was denied. Enable it in Settings > Privacy > Camera."
            case .restrictedAuthorization:
                return "Camera access is restricted."
            case .configurationFailed:
                return "Failed to configure the camera."
            case .captureFailed:
                return "Failed to capture photo."
            }
        }
        return error.localizedDescription
    }
}
