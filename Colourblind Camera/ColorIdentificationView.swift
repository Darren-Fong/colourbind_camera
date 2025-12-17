//
//  ColorIdentificationView.swift
//  Colourblind Camera
//

import SwiftUI
import AVFoundation

struct ColorIdentificationView: View {
    @StateObject private var cameraService = CameraService()
    private let speechSynthesizer = AVSpeechSynthesizer()
    @State private var lastSpokenColor: String = ""
    @State private var showColorInfo = false
    @State private var isAutoSpeakEnabled = false
    @State private var showingHelp = false
    @State private var showingColorSettings = false
    
    var body: some View {
        ZStack {
            // Camera preview
            if let session = cameraService.session {
                CameraPreview(session: session)
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Crosshair Overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                        )
                    Spacer()
                }
                Spacer()
            }
            
            // Color information overlay
            VStack {
                // Top Controls
                HStack {
                    HStack(spacing: 16) {
                        Button(action: { showingHelp = true }) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(GlassBackground())
                        }
                        
                        Button(action: { showingColorSettings = true }) {
                            Image(systemName: "eye.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(GlassBackground())
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            isAutoSpeakEnabled.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isAutoSpeakEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            Text(isAutoSpeakEnabled ? "Auto" : "Manual")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(GlassBackground())
                    }
                }
                .padding()
                
                Spacer()
                
                // Color Info Panel
                if showColorInfo {
                    ColorInfoView(dominantColor: cameraService.dominantColor)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Bottom Controls
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation(.spring()) {
                            showColorInfo.toggle()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: showColorInfo ? "eye.slash.fill" : "eye.fill")
                                .font(.title2)
                            Text(showColorInfo ? "Hide Info" : "Show Info")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(GlassBackground())
                        .cornerRadius(12)
                    }
                    
                    if !isAutoSpeakEnabled {
                        Button(action: { speakCurrentColor() }) {
                            VStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.title2)
                                Text("Speak")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(GlassBackground())
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingHelp) {
            ColorIdentificationHelpView()
        }
        .sheet(isPresented: $showingColorSettings) {
            ColorSettingsView()
        }
        .onAppear {
            cameraService.checkPermissions()
            DispatchQueue.global(qos: .userInitiated).async {
                startColorTracking()
            }
        }
        .onDisappear {
            stopColorTracking()
            DispatchQueue.global(qos: .userInitiated).async {
                cameraService.session?.stopRunning()
            }
        }
    }
    
    private func startColorTracking() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let currentColor = cameraService.dominantColor
            if currentColor != lastSpokenColor {
                lastSpokenColor = currentColor
                if showColorInfo {
                    speakCurrentColor()
                }
            }
        }
    }
    
    private func stopColorTracking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    private func speakCurrentColor() {
        let utterance = AVSpeechUtterance(string: cameraService.dominantColor)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)
    }
}

struct ColorInfoView: View {
    let dominantColor: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Color Name
            VStack(spacing: 8) {
                Text("Detected Color")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(dominantColor)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Color Swatch
            RoundedRectangle(cornerRadius: 12)
                .fill(getColorFromName(dominantColor))
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: getColorFromName(dominantColor).opacity(0.5), radius: 10)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
        .background(GlassBackground())
        .cornerRadius(20)
    }
    
    private func getColorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "purple": return .purple
        case "orange": return .orange
        case "brown": return .brown
        case "pink": return .pink
        case "gray": return .gray
        case "black": return .black
        case "white": return .white
        default: return .gray
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}