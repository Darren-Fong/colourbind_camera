import SwiftUI
import AVFoundation

struct LiveColorView: View {
    @StateObject private var cameraService = CameraService()
    @ObservedObject private var settings = AppSettings.shared
    @State private var showFilterSettings = false
    @State private var showColorText = true
    @State private var showObjectRecognition = false
    @State private var cameraPermissionDenied = false
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    let filterOptions = [
        "Normal": (color: Color("Normal"), opacity: 0.0),
        "Deuteranopia": (color: Color("Deuteranopia"), opacity: 0.3),
        "Protanopia": (color: Color("Protanopia"), opacity: 0.3),
        "Trianopia": (color: Color("Trianopia"), opacity: 0.3)
    ]
    
    private var selectedFilter: String {
        switch settings.colorBlindnessType {
        case .normal: return "Normal"
        case .protanopia: return "Protanopia"
        case .deuteranopia: return "Deuteranopia"
        case .tritanopia: return "Trianopia"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera preview
                if cameraService.session != nil {
                    CameraPreview(session: cameraService.session!)
                        .edgesIgnoringSafeArea(.all)
                } else if cameraPermissionDenied {
                    // Show permission denied message
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Camera Access Required")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Please enable camera access in Settings to use this feature.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else {
                    // Loading state
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Starting Camera...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                    }
                }
                
                // Color Filter Overlay
                if let filter = filterOptions[selectedFilter] {
                    GlobalColorFilter(color: filter.color, opacity: filter.opacity)
                }
                
                VStack {
                    // Top Controls
                    HStack {
                        // Filter Button
                        Button(action: {
                            showFilterSettings = true
                        }) {
                            HStack {
                                Image(systemName: "eye.fill")
                                Text(selectedFilter)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        // Object Recognition Toggle
                        Button(action: {
                            withAnimation {
                                showObjectRecognition.toggle()
                                cameraService.isObjectRecognitionEnabled = showObjectRecognition
                            }
                        }) {
                            Image(systemName: showObjectRecognition ? "viewfinder.circle.fill" : "viewfinder.circle")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(showObjectRecognition ? .green : .white)
                                .cornerRadius(20)
                        }
                        
                        // Color Tag Overlay Button
                        NavigationLink(destination: ColorTagOverlayView(cameraService: cameraService)) {
                            Image(systemName: "tag.fill")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                        
                        // Toggle Color Text Button
                        Button(action: {
                            withAnimation {
                                showColorText.toggle()
                            }
                        }) {
                            Image(systemName: showColorText ? "text.bubble.fill" : "text.bubble")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                        
                        // Vision/Algorithm Toggle
                        Button(action: {
                            withAnimation {
                                cameraService.useVisionColorDetection.toggle()
                            }
                        }) {
                            Image(systemName: cameraService.useVisionColorDetection ? "cpu.fill" : "function")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(cameraService.useVisionColorDetection ? .blue : .purple)
                                .cornerRadius(20)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Information Display
                    VStack(spacing: 16) {
                        // Color Display
                        if showColorText {
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Text("Current Color")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    // Mode indicator
                                    HStack(spacing: 4) {
                                        Image(systemName: cameraService.useVisionColorDetection ? "cpu" : "function")
                                            .font(.caption2)
                                        Text(cameraService.useVisionColorDetection ? "Vision" : "Algorithm")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Text(cameraService.dominantColor)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(15)
                            }
                            .transition(.move(edge: .bottom))
                        }
                        
                        // Object Recognition Display
                        if showObjectRecognition && !cameraService.recognizedObject.isEmpty {
                            VStack(spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                    Text("AI Detection")
                                        .font(.caption)
                                }
                                .foregroundColor(.white.opacity(0.8))
                                
                                Text(cameraService.recognizedObject)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(cameraService.objectConfidence > 70 ? Color.green : cameraService.objectConfidence > 40 ? Color.orange : Color.yellow)
                                        .frame(width: 6, height: 6)
                                    Text("\(cameraService.objectConfidence)% confident")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.purple.opacity(0.7))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFilterSettings) {
                FilterSettingsView()
            }
            .onAppear {
                startCamera()
            }
            .onDisappear {
                // Stop camera to prevent lag when switching tabs
                cameraService.stopSession()
            }
        }
    }
    
    private func startCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraService.checkPermissions()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        cameraService.checkPermissions()
                    } else {
                        cameraPermissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                cameraPermissionDenied = true
            }
        @unknown default:
            break
        }
    }
}

struct FilterSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.presentationMode) var presentationMode
    
    let filters: [(type: ColorBlindnessType, description: String)] = [
        (.normal, "No color adjustment"),
        (.protanopia, "For red-green color blindness (red weak)"),
        (.deuteranopia, "For red-green color blindness (green weak)"),
        (.tritanopia, "For blue-yellow color blindness")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filters, id: \.type) { filter in
                    Button(action: {
                        settings.colorBlindnessType = filter.type
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(filter.type.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(filter.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if settings.colorBlindnessType == filter.type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Color Filters")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}