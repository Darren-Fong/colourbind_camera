//
//  AppSettings.swift
//  Colourblind Camera
//

import SwiftUI
import Combine

/// Global settings manager for the app
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - Color Vision Settings
    @AppStorage("colorBlindnessType") private var colorBlindnessTypeRaw: String = ColorBlindnessType.normal.rawValue
    @Published var colorBlindnessType: ColorBlindnessType {
        didSet {
            colorBlindnessTypeRaw = colorBlindnessType.rawValue
        }
    }
    
    // MARK: - Appearance Settings
    @AppStorage("largeText") var largeText = false
    @AppStorage("highContrast") var highContrast = false
    
    // MARK: - Accessibility Settings
    @AppStorage("voiceAnnouncements") var voiceAnnouncements = true
    @AppStorage("hapticFeedback") var hapticFeedback = true
    
    // MARK: - Color Processing Settings
    @AppStorage("colorCorrection") var colorCorrection = true
    @AppStorage("enhancedContrast") var enhancedContrast = false
    
    // MARK: - Privacy Settings
    @AppStorage("analytics") var analytics = false
    
    // MARK: - Camera Settings
    @AppStorage("autoWhiteBalance") var autoWhiteBalance = true
    @AppStorage("advancedColorRecognition") var advancedColorRecognition = true
    
    private init() {
        // Load the saved color blindness type
        if let savedType = ColorBlindnessType(rawValue: colorBlindnessTypeRaw) {
            colorBlindnessType = savedType
        } else {
            colorBlindnessType = .normal
        }
    }
    
    /// Clear all user data
    func clearAllData() {
        ColorAlbumManager.shared.clearAllImages()
        // Clear any other user data as needed
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        largeText = false
        highContrast = false
        voiceAnnouncements = true
        hapticFeedback = true
        colorCorrection = true
        enhancedContrast = false
        analytics = false
        autoWhiteBalance = true
        advancedColorRecognition = true
        colorBlindnessType = .normal
    }
}
