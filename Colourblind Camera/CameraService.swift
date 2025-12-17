//
//  CameraService.swift
//  Colourblind Camera
//
//  Created by Alex Au on 2/12/2024.
//
import SwiftUI
import Foundation
import AVFoundation
import CoreImage

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                  y: inputImage.extent.origin.y,
                                  z: inputImage.extent.size.width,
                                  w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage",
                                  parameters: [kCIInputImageKey: inputImage,
                                             kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255,
                      green: CGFloat(bitmap[1]) / 255,
                      blue: CGFloat(bitmap[2]) / 255,
                      alpha: CGFloat(bitmap[3]) / 255)
    }
    
    // Get dominant color by sampling multiple points and finding most common
    func getDominantColor() -> UIColor? {
        guard let cgImage = self.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard width > 0, height > 0,
              let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return nil
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        var rTotal: CGFloat = 0
        var gTotal: CGFloat = 0
        var bTotal: CGFloat = 0
        var sampleCount = 0
        
        // Sample a grid of points across the image
        let sampleSize = 10
        for row in 0..<sampleSize {
            for col in 0..<sampleSize {
                let x = (col * width) / sampleSize
                let y = (row * height) / sampleSize
                
                let pixelOffset = y * bytesPerRow + x * bytesPerPixel
                
                let r = CGFloat(data[pixelOffset]) / 255.0
                let g = CGFloat(data[pixelOffset + 1]) / 255.0
                let b = CGFloat(data[pixelOffset + 2]) / 255.0
                
                rTotal += r
                gTotal += g
                bTotal += b
                sampleCount += 1
            }
        }
        
        guard sampleCount > 0 else { return nil }
        
        return UIColor(
            red: rTotal / CGFloat(sampleCount),
            green: gTotal / CGFloat(sampleCount),
            blue: bTotal / CGFloat(sampleCount),
            alpha: 1.0
        )
    }
}

extension UIColor {
    func closestColorName() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Apply lighting compensation - normalize based on perceived brightness
        let (normR, normG, normB) = normalizeForLighting(r: r, g: g, b: b)
        
        // Convert normalized RGB to HSL for better color detection
        let (hue, saturation, lightness) = rgbToHSL(r: normR, g: normG, b: normB)
        
        // Also get original HSB for comparison
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        
        let hueAngle = hue * 360
        let sat = saturation * 100
        let light = lightness * 100
        let originalBrightness = br * 100
        
        // Use chroma to detect true grayscale vs colored under bad lighting
        let chroma = max(normR, normG, normB) - min(normR, normG, normB)
        let isGrayscale = chroma < 0.08 || sat < 8
        
        // Handle grayscale/neutral colors
        if isGrayscale {
            if light > 85 || originalBrightness > 90 { return "White" }
            if light > 65 { return "Light Gray" }
            if light > 35 { return "Gray" }
            if light > 15 { return "Dark Gray" }
            return "Black"
        }
        
        // Handle very dark colors - check if it's truly black or just dark colored
        if light < 12 && sat < 20 {
            return "Black"
        }
        
        // Classify by lightness level
        let isVeryLight = light > 75
        let isLight = light > 55
        let isDark = light < 30
        let isVeryDark = light < 18
        let isPale = sat < 30
        let isVivid = sat > 70
        
        // Determine color based on hue with lighting-aware thresholds
        var colorName: String
        
        // Red range (wraps around 0/360)
        if hueAngle < 12 || hueAngle >= 350 {
            if isVeryLight && isPale { colorName = "Pink" }
            else if isVeryLight { colorName = "Light Red" }
            else if isVeryDark { colorName = "Dark Red" }
            else if isDark && sat < 50 { colorName = "Maroon" }
            else if isPale && isLight { colorName = "Salmon" }
            else { colorName = "Red" }
        }
        // Red-Orange range
        else if hueAngle < 22 {
            if isDark { colorName = "Brown" }
            else if isVeryLight { colorName = "Peach" }
            else { colorName = "Red-Orange" }
        }
        // Orange range
        else if hueAngle < 40 {
            if isVeryDark || (isDark && sat < 50) { colorName = "Brown" }
            else if isVeryLight && isPale { colorName = "Peach" }
            else if isPale { colorName = "Tan" }
            else { colorName = "Orange" }
        }
        // Yellow-Orange range
        else if hueAngle < 50 {
            if isDark { colorName = "Brown" }
            else if isLight && isPale { colorName = "Cream" }
            else { colorName = "Gold" }
        }
        // Yellow range
        else if hueAngle < 70 {
            if isVeryDark { colorName = "Olive" }
            else if isDark { colorName = "Dark Yellow" }
            else if isPale && isLight { colorName = "Cream" }
            else if isPale { colorName = "Beige" }
            else { colorName = "Yellow" }
        }
        // Yellow-Green range
        else if hueAngle < 85 {
            if isDark { colorName = "Olive" }
            else if isPale { colorName = "Light Olive" }
            else { colorName = "Yellow-Green" }
        }
        // Green range
        else if hueAngle < 150 {
            if isVeryLight && isPale { colorName = "Mint" }
            else if isVeryLight { colorName = "Light Green" }
            else if isVeryDark { colorName = "Dark Green" }
            else if isDark { colorName = "Forest Green" }
            else if isPale { colorName = "Sage" }
            else if isVivid { colorName = "Bright Green" }
            else { colorName = "Green" }
        }
        // Cyan-Green range
        else if hueAngle < 170 {
            if isLight { colorName = "Aqua" }
            else if isDark { colorName = "Teal" }
            else { colorName = "Cyan-Green" }
        }
        // Cyan range
        else if hueAngle < 195 {
            if isVeryLight { colorName = "Light Cyan" }
            else if isDark { colorName = "Dark Cyan" }
            else { colorName = "Cyan" }
        }
        // Light Blue range
        else if hueAngle < 220 {
            if isVeryLight && isPale { colorName = "Powder Blue" }
            else if isVeryLight { colorName = "Sky Blue" }
            else if isDark { colorName = "Steel Blue" }
            else { colorName = "Light Blue" }
        }
        // Blue range
        else if hueAngle < 255 {
            if isVeryLight && isPale { colorName = "Periwinkle" }
            else if isVeryDark { colorName = "Navy" }
            else if isDark { colorName = "Dark Blue" }
            else if isVivid { colorName = "Bright Blue" }
            else { colorName = "Blue" }
        }
        // Blue-Purple range
        else if hueAngle < 275 {
            if isVeryLight { colorName = "Lavender" }
            else if isDark { colorName = "Indigo" }
            else { colorName = "Violet" }
        }
        // Purple range
        else if hueAngle < 310 {
            if isVeryLight && isPale { colorName = "Lavender" }
            else if isVeryLight { colorName = "Light Purple" }
            else if isVeryDark { colorName = "Dark Purple" }
            else if isPale { colorName = "Mauve" }
            else { colorName = "Purple" }
        }
        // Magenta/Pink range
        else if hueAngle < 335 {
            if isVeryLight { colorName = "Pink" }
            else if isDark { colorName = "Magenta" }
            else if isPale { colorName = "Rose" }
            else { colorName = "Hot Pink" }
        }
        // Pink-Red range
        else {
            if isVeryLight { colorName = "Light Pink" }
            else if isDark { colorName = "Maroon" }
            else if isPale { colorName = "Dusty Rose" }
            else { colorName = "Pink" }
        }
        
        return colorName
    }
    
    // Normalize RGB values to compensate for lighting conditions
    private func normalizeForLighting(r: CGFloat, g: CGFloat, b: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        // Calculate perceived luminance
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        
        // If image is very dark or very bright, normalize
        if luminance < 0.01 {
            return (r, g, b) // Too dark to normalize
        }
        
        // Gray world assumption - assume average should be neutral gray
        let avgColor = (r + g + b) / 3.0
        
        // Only normalize if there's significant color cast from lighting
        if avgColor > 0.05 {
            // Calculate scaling factors to normalize toward gray
            let scaleR = avgColor / max(r, 0.01)
            let scaleG = avgColor / max(g, 0.01)
            let scaleB = avgColor / max(b, 0.01)
            
            // Blend between original and normalized (50% blend to preserve some original)
            let blendFactor: CGFloat = 0.4
            let normR = min(1.0, r * (1 + (scaleR - 1) * blendFactor))
            let normG = min(1.0, g * (1 + (scaleG - 1) * blendFactor))
            let normB = min(1.0, b * (1 + (scaleB - 1) * blendFactor))
            
            return (normR, normG, normB)
        }
        
        return (r, g, b)
    }
    
    // Convert RGB to HSL (Hue, Saturation, Lightness) - better for color perception
    private func rgbToHSL(r: CGFloat, g: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, l: CGFloat) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        // Lightness
        let l = (maxC + minC) / 2.0
        
        // Saturation
        var s: CGFloat = 0
        if delta > 0 {
            s = delta / (1 - abs(2 * l - 1))
        }
        
        // Hue
        var h: CGFloat = 0
        if delta > 0 {
            if maxC == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6
            if h < 0 { h += 1 }
        }
        
        return (h, min(1, max(0, s)), l)
    }
}

class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
    @Published var session: AVCaptureSession?
    var delegate: AVCapturePhotoCaptureDelegate?
    
    let output = AVCapturePhotoOutput()
    let previewLayer = AVCaptureVideoPreviewLayer()
    let videoOutput = AVCaptureVideoDataOutput()
    let processingQueue = DispatchQueue(label: "com.colourblind.processing")
    
    @Published var dominantColor: String = "Unknown"
    
    // Use shared settings instead of local state
    private var settings = AppSettings.shared
    var colorBlindnessType: ColorBlindnessType {
        get { settings.colorBlindnessType }
        set { settings.colorBlindnessType = newValue }
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera { _ in }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera { _ in }
                    }
                }
            }
        case .denied, .restricted:
            print("Camera access denied")
        @unknown default:
            break
        }
    }
    
    func start(delegate: AVCapturePhotoCaptureDelegate, completion: @escaping (Error?)->()) {
        self.delegate = delegate
        checkPermission(completion: completion)
    }
    
    private func checkPermission(completion: @escaping(Error?)->()) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        self?.setupCamera(completion: completion)
                    }
                }
            case .restricted:
                break
            case .denied:
                break
            case .authorized:
                setupCamera(completion: completion)
            @unknown default:
                break
        }
    }
    
    private func setupCamera(completion: @escaping(Error?)->()) {
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
                
                videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                }
                
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session
                
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                    DispatchQueue.main.async {
                        self.session = session
                        completion(nil)
                    }
                }
            } catch {
                completion(error)
            }
        }
    }
    
    func capturePhoto(with settings: AVCapturePhotoSettings = AVCapturePhotoSettings()) {
        output.capturePhoto(with: settings, delegate: delegate!)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Lock the buffer for reading
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // Sample center region (larger area for better averaging)
        let centerX = width / 2
        let centerY = height / 2
        let sampleRadius = 80 // Sample a 160x160 pixel area
        
        var rTotal: Double = 0
        var gTotal: Double = 0
        var bTotal: Double = 0
        var sampleCount = 0
        
        // Sample points in the center region
        for dy in stride(from: -sampleRadius, to: sampleRadius, by: 8) {
            for dx in stride(from: -sampleRadius, to: sampleRadius, by: 8) {
                let x = centerX + dx
                let y = centerY + dy
                
                guard x >= 0, x < width, y >= 0, y < height else { continue }
                
                // BGRA format (most common for camera)
                let pixelOffset = y * bytesPerRow + x * 4
                let b = Double(buffer[pixelOffset]) / 255.0
                let g = Double(buffer[pixelOffset + 1]) / 255.0
                let r = Double(buffer[pixelOffset + 2]) / 255.0
                
                rTotal += r
                gTotal += g
                bTotal += b
                sampleCount += 1
            }
        }
        
        guard sampleCount > 0 else { return }
        
        let avgR = rTotal / Double(sampleCount)
        let avgG = gTotal / Double(sampleCount)
        let avgB = bTotal / Double(sampleCount)
        
        // Get color name with advanced algorithm
        let colorName = ColorRecognizer.shared.recognizeColor(r: avgR, g: avgG, b: avgB)
        
        DispatchQueue.main.async {
            self.dominantColor = colorName
        }
    }
}

// MARK: - Advanced Color Recognizer
class ColorRecognizer {
    static let shared = ColorRecognizer()
    
    // Adaptive white balance reference (updated over time)
    private var whiteBalanceR: Double = 1.0
    private var whiteBalanceG: Double = 1.0
    private var whiteBalanceB: Double = 1.0
    private var sampleHistory: [(r: Double, g: Double, b: Double)] = []
    private let maxHistorySize = 30
    
    func recognizeColor(r: Double, g: Double, b: Double) -> String {
        // Update sample history for adaptive white balance
        updateSampleHistory(r: r, g: g, b: b)
        
        // Apply white balance correction
        let (corrR, corrG, corrB) = applyWhiteBalance(r: r, g: g, b: b)
        
        // Convert to HSL
        let (hue, saturation, lightness) = rgbToHSL(r: corrR, g: corrG, b: corrB)
        
        // Also calculate chroma for better detection
        let maxRGB = max(corrR, corrG, corrB)
        let minRGB = min(corrR, corrG, corrB)
        let chroma = maxRGB - minRGB
        
        // Convert to degrees and percentages
        let h = hue * 360
        let s = saturation * 100
        let l = lightness * 100
        
        // Detect grayscale - use chroma and saturation together
        let isNeutral = chroma < 0.12 && s < 15
        
        if isNeutral {
            return classifyGrayscale(lightness: l)
        }
        
        // Classify chromatic colors
        return classifyChromatic(hue: h, saturation: s, lightness: l, chroma: chroma)
    }
    
    private func updateSampleHistory(r: Double, g: Double, b: Double) {
        sampleHistory.append((r: r, g: g, b: b))
        if sampleHistory.count > maxHistorySize {
            sampleHistory.removeFirst()
        }
        
        // Update white balance based on history (gray world assumption)
        if sampleHistory.count >= 10 {
            let avgR = sampleHistory.map { $0.r }.reduce(0, +) / Double(sampleHistory.count)
            let avgG = sampleHistory.map { $0.g }.reduce(0, +) / Double(sampleHistory.count)
            let avgB = sampleHistory.map { $0.b }.reduce(0, +) / Double(sampleHistory.count)
            
            let grayTarget = (avgR + avgG + avgB) / 3.0
            
            if grayTarget > 0.05 {
                // Smoothly adjust white balance
                let smoothing = 0.1
                whiteBalanceR = whiteBalanceR * (1 - smoothing) + (grayTarget / max(avgR, 0.01)) * smoothing
                whiteBalanceG = whiteBalanceG * (1 - smoothing) + (grayTarget / max(avgG, 0.01)) * smoothing
                whiteBalanceB = whiteBalanceB * (1 - smoothing) + (grayTarget / max(avgB, 0.01)) * smoothing
                
                // Clamp to reasonable range
                whiteBalanceR = max(0.5, min(2.0, whiteBalanceR))
                whiteBalanceG = max(0.5, min(2.0, whiteBalanceG))
                whiteBalanceB = max(0.5, min(2.0, whiteBalanceB))
            }
        }
    }
    
    private func applyWhiteBalance(r: Double, g: Double, b: Double) -> (Double, Double, Double) {
        let corrR = min(1.0, r * whiteBalanceR)
        let corrG = min(1.0, g * whiteBalanceG)
        let corrB = min(1.0, b * whiteBalanceB)
        return (corrR, corrG, corrB)
    }
    
    private func rgbToHSL(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        let l = (maxC + minC) / 2.0
        
        var s: Double = 0
        if delta > 0.001 {
            s = delta / (1 - abs(2 * l - 1))
            s = min(1.0, max(0, s))
        }
        
        var h: Double = 0
        if delta > 0.001 {
            if maxC == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6
            if h < 0 { h += 1 }
        }
        
        return (h, s, l)
    }
    
    private func classifyGrayscale(lightness: Double) -> String {
        if lightness > 92 { return "White" }
        if lightness > 78 { return "Off-White" }
        if lightness > 65 { return "Light Gray" }
        if lightness > 45 { return "Gray" }
        if lightness > 28 { return "Dark Gray" }
        if lightness > 12 { return "Charcoal" }
        return "Black"
    }
    
    private func classifyChromatic(hue: Double, saturation: Double, lightness: Double, chroma: Double) -> String {
        // Lightness classifications
        let isVeryLight = lightness > 80
        let isLight = lightness > 62
        let isMediumLight = lightness > 45
        let isMedium = lightness > 32
        let isDark = lightness < 32
        let isVeryDark = lightness < 20
        
        // Saturation classifications
        let isVeryPale = saturation < 20
        let isPale = saturation < 35
        let isMuted = saturation < 50
        let isVivid = saturation > 70
        let isVeryVivid = saturation > 85
        
        // Hue-based classification with detailed ranges
        
        // RED (345-360, 0-10)
        if hue >= 345 || hue < 10 {
            if isVeryLight && isVeryPale { return "White-Pink" }
            if isVeryLight { return "Light Pink" }
            if isLight && isPale { return "Rose" }
            if isLight && isMuted { return "Salmon" }
            if isLight { return "Coral" }
            if isVeryDark { return "Dark Red" }
            if isDark && isMuted { return "Maroon" }
            if isDark { return "Burgundy" }
            if isVeryVivid { return "Bright Red" }
            if isVivid { return "Red" }
            if isMuted { return "Brick Red" }
            return "Red"
        }
        
        // RED-ORANGE (10-25)
        if hue < 25 {
            if isVeryDark { return "Brown" }
            if isDark { return "Dark Brown" }
            if isVeryLight && isPale { return "Peach" }
            if isVeryLight { return "Light Coral" }
            if isLight { return "Coral" }
            if isMuted { return "Rust" }
            return "Red-Orange"
        }
        
        // ORANGE (25-42)
        if hue < 42 {
            if isVeryDark { return "Dark Brown" }
            if isDark && isMuted { return "Brown" }
            if isDark { return "Burnt Orange" }
            if isVeryLight && isVeryPale { return "Cream" }
            if isVeryLight { return "Peach" }
            if isLight && isPale { return "Apricot" }
            if isLight { return "Light Orange" }
            if isPale { return "Tan" }
            if isVeryVivid { return "Bright Orange" }
            return "Orange"
        }
        
        // GOLD/YELLOW-ORANGE (42-52)
        if hue < 52 {
            if isVeryDark { return "Brown" }
            if isDark { return "Olive Brown" }
            if isVeryLight && isPale { return "Cream" }
            if isVeryLight { return "Light Gold" }
            if isPale { return "Khaki" }
            if isVivid { return "Gold" }
            return "Golden Yellow"
        }
        
        // YELLOW (52-68)
        if hue < 68 {
            if isVeryDark { return "Olive" }
            if isDark { return "Dark Olive" }
            if isVeryLight && isVeryPale { return "Ivory" }
            if isVeryLight { return "Light Yellow" }
            if isPale && isLight { return "Cream" }
            if isPale { return "Beige" }
            if isVeryVivid { return "Bright Yellow" }
            if isVivid { return "Yellow" }
            if isMuted { return "Mustard" }
            return "Yellow"
        }
        
        // YELLOW-GREEN (68-85)
        if hue < 85 {
            if isVeryDark { return "Dark Olive" }
            if isDark { return "Olive" }
            if isVeryLight { return "Light Lime" }
            if isPale { return "Pale Green" }
            if isVivid { return "Lime" }
            return "Yellow-Green"
        }
        
        // GREEN (85-155)
        if hue < 155 {
            if isVeryLight && isVeryPale { return "Mint" }
            if isVeryLight && isPale { return "Pale Mint" }
            if isVeryLight { return "Light Green" }
            if isLight && isPale { return "Sage" }
            if isLight { return "Spring Green" }
            if isVeryDark { return "Dark Green" }
            if isDark && isMuted { return "Forest Green" }
            if isDark { return "Hunter Green" }
            if isVeryVivid { return "Bright Green" }
            if isVivid { return "Green" }
            if isMuted { return "Olive Green" }
            if hue > 140 && isMedium { return "Teal Green" }
            return "Green"
        }
        
        // CYAN-GREEN (155-175)
        if hue < 175 {
            if isVeryLight { return "Aqua" }
            if isLight { return "Seafoam" }
            if isDark { return "Dark Teal" }
            if isVivid { return "Turquoise" }
            return "Teal"
        }
        
        // CYAN (175-195)
        if hue < 195 {
            if isVeryLight { return "Light Cyan" }
            if isLight { return "Sky Blue" }
            if isDark { return "Dark Cyan" }
            if isVeryVivid { return "Bright Cyan" }
            return "Cyan"
        }
        
        // LIGHT BLUE (195-215)
        if hue < 215 {
            if isVeryLight && isVeryPale { return "Ice Blue" }
            if isVeryLight { return "Powder Blue" }
            if isLight { return "Sky Blue" }
            if isDark { return "Steel Blue" }
            return "Light Blue"
        }
        
        // BLUE (215-250)
        if hue < 250 {
            if isVeryLight && isVeryPale { return "Periwinkle" }
            if isVeryLight { return "Light Blue" }
            if isLight && isPale { return "Cornflower Blue" }
            if isLight { return "Medium Blue" }
            if isVeryDark { return "Navy" }
            if isDark { return "Dark Blue" }
            if isVeryVivid { return "Bright Blue" }
            if isVivid { return "Blue" }
            if isMuted { return "Slate Blue" }
            return "Blue"
        }
        
        // BLUE-PURPLE (250-275)
        if hue < 275 {
            if isVeryLight { return "Lavender" }
            if isLight { return "Periwinkle" }
            if isDark { return "Indigo" }
            if isVivid { return "Violet" }
            return "Blue-Violet"
        }
        
        // PURPLE (275-310)
        if hue < 310 {
            if isVeryLight && isVeryPale { return "Pale Lavender" }
            if isVeryLight { return "Light Purple" }
            if isLight && isPale { return "Lilac" }
            if isLight { return "Orchid" }
            if isVeryDark { return "Dark Purple" }
            if isDark { return "Plum" }
            if isVeryVivid { return "Bright Purple" }
            if isVivid { return "Purple" }
            if isMuted { return "Mauve" }
            return "Purple"
        }
        
        // MAGENTA/PINK (310-345)
        if hue < 345 {
            if isVeryLight && isVeryPale { return "Blush" }
            if isVeryLight { return "Light Pink" }
            if isLight && isPale { return "Rose Pink" }
            if isLight { return "Pink" }
            if isDark && isMuted { return "Plum" }
            if isDark { return "Magenta" }
            if isVeryVivid { return "Hot Pink" }
            if isVivid { return "Fuchsia" }
            if isMuted { return "Dusty Rose" }
            return "Magenta"
        }
        
        return "Unknown"
    }
}