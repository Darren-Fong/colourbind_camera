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
import Vision
import CoreML

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
    @Published var dominantColor: String = "Unknown"
    @Published var recognizedObject: String = ""
    @Published var objectConfidence: Int = 0
    @Published var isObjectRecognitionEnabled: Bool = false {
        didSet {
            if !isObjectRecognitionEnabled {
                // Clear object recognition when disabled
                DispatchQueue.main.async {
                    self.recognizedObject = ""
                    self.objectConfidence = 0
                }
            }
        }
    }
    @Published var useVisionColorDetection: Bool = false // Default to algorithmic (faster)
    
    var delegate: AVCapturePhotoCaptureDelegate?
    private let output = AVCapturePhotoOutput()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.colourblind.processing", qos: .userInitiated)
    
    // Lazy loading for ML models
    private lazy var objectRecognitionModel: VNCoreMLModel? = {
        guard #available(iOS 17.0, *) else { return nil }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine // Use Neural Engine when available
            return try VNCoreMLModel(for: MobileNetV2(configuration: config).model)
        } catch {
            print("Failed to load object recognition model: \(error)")
            return nil
        }
    }()
    
    // Throttling
    private var lastProcessTime: Date = Date.distantPast
    private let minProcessInterval: TimeInterval = 0.15 // Process max 6-7 times per second
    private var isProcessing = false
    
    // Settings
    private var settings = AppSettings.shared
    var colorBlindnessType: ColorBlindnessType {
        get { settings.colorBlindnessType }
        set { settings.colorBlindnessType = newValue }
    }
    
    override init() {
        super.init()
    }
    
    deinit {
        stopSession()
    }
    
    // MARK: - Session Management
    
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
        case .restricted, .denied:
            break
        case .authorized:
            setupCamera(completion: completion)
        @unknown default:
            break
        }
    }
    
    private func setupCamera(completion: @escaping(Error?)->()) {
        // Avoid duplicate sessions
        guard session == nil || session?.isRunning == false else {
            completion(nil)
            return
        }
        
        let newSession = AVCaptureSession()
        newSession.beginConfiguration()
        newSession.sessionPreset = .high // Balance quality and performance
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            completion(NSError(domain: "CameraService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No camera available"]))
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if newSession.canAddInput(input) {
                newSession.addInput(input)
            }
            
            if newSession.canAddOutput(output) {
                newSession.addOutput(output)
            }
            
            // Configure video output for efficient processing
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
            
            if newSession.canAddOutput(videoOutput) {
                newSession.addOutput(videoOutput)
            }
            
            // Set video orientation
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.session = newSession
            
            newSession.commitConfiguration()
            
            // Start session on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                newSession.startRunning()
                DispatchQueue.main.async {
                    self?.session = newSession
                    completion(nil)
                }
            }
        } catch {
            completion(error)
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.session?.stopRunning()
            DispatchQueue.main.async {
                self?.session = nil
            }
        }
    }
    
    func capturePhoto(with settings: AVCapturePhotoSettings = AVCapturePhotoSettings()) {
        guard let delegate = delegate else { return }
        output.capturePhoto(with: settings, delegate: delegate)
    }
    
    // MARK: - Video Frame Processing
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle processing to prevent lag
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= minProcessInterval else { return }
        guard !isProcessing else { return }
        
        isProcessing = true
        lastProcessTime = now
        
        defer { isProcessing = false }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Process color detection (lightweight, always runs)
        processColorDetection(pixelBuffer: pixelBuffer)
        
        // Process object recognition only if enabled (heavier)
        if isObjectRecognitionEnabled {
            processObjectRecognition(pixelBuffer: pixelBuffer)
        }
    }
    
    // MARK: - Color Detection
    
    private func processColorDetection(pixelBuffer: CVPixelBuffer) {
        if useVisionColorDetection {
            performVisionColorDetection(on: pixelBuffer)
        } else {
            performFastColorDetection(on: pixelBuffer)
        }
    }
    
    private func performFastColorDetection(on pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // Fast center sampling - just 13 points
        let centerX = width / 2
        let centerY = height / 2
        let radius = 60
        
        var rTotal: Double = 0
        var gTotal: Double = 0
        var bTotal: Double = 0
        var count = 0
        
        // Sample center point
        let centerOffset = centerY * bytesPerRow + centerX * 4
        rTotal += Double(buffer[centerOffset + 2])
        gTotal += Double(buffer[centerOffset + 1])
        bTotal += Double(buffer[centerOffset])
        count += 3 // Weight center more
        
        // Sample 4 cardinal directions
        let offsets = [(0, radius), (0, -radius), (radius, 0), (-radius, 0)]
        for (dx, dy) in offsets {
            let x = centerX + dx
            let y = centerY + dy
            guard x >= 0, x < width, y >= 0, y < height else { continue }
            
            let offset = y * bytesPerRow + x * 4
            rTotal += Double(buffer[offset + 2])
            gTotal += Double(buffer[offset + 1])
            bTotal += Double(buffer[offset])
            count += 1
        }
        
        // Sample 4 diagonals
        let diagRadius = 42
        let diagOffsets = [(diagRadius, diagRadius), (diagRadius, -diagRadius),
                          (-diagRadius, diagRadius), (-diagRadius, -diagRadius)]
        for (dx, dy) in diagOffsets {
            let x = centerX + dx
            let y = centerY + dy
            guard x >= 0, x < width, y >= 0, y < height else { continue }
            
            let offset = y * bytesPerRow + x * 4
            rTotal += Double(buffer[offset + 2])
            gTotal += Double(buffer[offset + 1])
            bTotal += Double(buffer[offset])
            count += 1
        }
        
        guard count > 0 else { return }
        
        let r = rTotal / Double(count) / 255.0
        let g = gTotal / Double(count) / 255.0
        let b = bTotal / Double(count) / 255.0
        
        let colorName = ColorRecognizer.shared.recognizeColor(r: r, g: g, b: b)
        
        DispatchQueue.main.async {
            self.dominantColor = colorName
        }
    }
    
    // MARK: - Vision-based Color Detection (Simplified)
    private func performVisionColorDetection(on pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Extract center region only
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let centerRect = CGRect(
            x: CGFloat(width) * 0.45,
            y: CGFloat(height) * 0.45,
            width: CGFloat(width) * 0.1,
            height: CGFloat(height) * 0.1
        )
        let croppedImage = ciImage.cropped(to: centerRect)
        
        // Use CIAreaAverage for fast color extraction
        let extent = croppedImage.extent
        let extentVector = CIVector(x: extent.origin.x, y: extent.origin.y,
                                   z: extent.size.width, w: extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage",
                                   parameters: [kCIInputImageKey: croppedImage,
                                              kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else {
            return
        }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any,
                                         .useSoftwareRenderer: false])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)
        
        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        
        let colorName = ColorRecognizer.shared.recognizeColor(r: r, g: g, b: b)
        
        DispatchQueue.main.async {
            self.dominantColor = colorName
        }
    }
    
    // MARK: - Object Recognition (Throttled)
    private func processObjectRecognition(pixelBuffer: CVPixelBuffer) {
        guard let model = objectRecognitionModel else { return }
        
        // Run on lower priority to not block color detection
        processingQueue.async(qos: .utility) { [weak self] in
            guard let self = self else { return }
            
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                guard let self = self,
                      error == nil,
                      let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first,
                      topResult.confidence > 0.2 else {
                    return
                }
                
                let identifier = topResult.identifier
                    .components(separatedBy: ",").first ?? topResult.identifier
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
                
                let confidence = Int(topResult.confidence * 100)
                
                DispatchQueue.main.async {
                    self.recognizedObject = identifier
                    self.objectConfidence = confidence
                }
            }
            
            request.imageCropAndScaleOption = .centerCrop
            
            try? handler.perform([request])
        }
    }
}

// MARK: - Advanced Color Recognizer with Temporal Smoothing
class ColorRecognizer {
    static let shared = ColorRecognizer()
    
    // Temporal smoothing for stable color detection
    private var colorHistory: [String] = []
    private let historySize = 5
    
    // Auto white balance with better adaptation
    private var referenceWhite = (r: 1.0, g: 1.0, b: 1.0)
    private var calibrationSamples: [(r: Double, g: Double, b: Double)] = []
    private let maxCalibrationSamples = 60
    
    // Color cache for performance
    private var lastColor: String = "Unknown"
    private var colorStability = 0
    
    func recognizeColor(r: Double, g: Double, b: Double) -> String {
        // Auto white balance calibration
        updateWhiteBalance(r: r, g: g, b: b)
        
        // Apply auto white balance
        let (balR, balG, balB) = applyAutoWhiteBalance(r: r, g: g, b: b)
        
        // Gamma correction for better perception
        let (gammaR, gammaG, gammaB) = applyGammaCorrection(r: balR, g: balG, b: balB)
        
        // Convert to multiple color spaces for robust detection
        let (hue, sat, light) = rgbToHSL(r: gammaR, g: gammaG, b: gammaB)
        let (L, a, bComp) = rgbToLAB(r: gammaR, g: gammaG, b: gammaB)
        
        // Calculate chroma and other perceptual metrics
        let maxRGB = max(gammaR, gammaG, gammaB)
        let minRGB = min(gammaR, gammaG, gammaB)
        let chroma = maxRGB - minRGB
        
        // Classify the color
        let detectedColor: String
        
        // Detect neutral colors (grays) using multiple criteria
        let isNeutral = (chroma < 0.08 && sat < 12) || 
                       (abs(a) < 8 && abs(bComp) < 8 && L > 20) ||
                       (sat < 8)
        
        if isNeutral {
            detectedColor = classifyNeutral(L: L, lightness: light)
        } else {
            detectedColor = classifyChromatic(h: hue * 360, s: sat * 100, l: light * 100, 
                                            L: L, a: a, b: bComp, chroma: chroma)
        }
        
        // Apply temporal smoothing for stability
        return applyTemporalSmoothing(color: detectedColor)
    }
    
    // MARK: - White Balance
    private func updateWhiteBalance(r: Double, g: Double, b: Double) {
        calibrationSamples.append((r: r, g: g, b: b))
        if calibrationSamples.count > maxCalibrationSamples {
            calibrationSamples.removeFirst(10)
        }
        
        // Update white balance reference using gray world assumption
        if calibrationSamples.count >= 30 {
            let avgR = calibrationSamples.map { $0.r }.reduce(0, +) / Double(calibrationSamples.count)
            let avgG = calibrationSamples.map { $0.g }.reduce(0, +) / Double(calibrationSamples.count)
            let avgB = calibrationSamples.map { $0.b }.reduce(0, +) / Double(calibrationSamples.count)
            
            let grayTarget = (avgR + avgG + avgB) / 3.0
            
            if grayTarget > 0.1 {
                let smoothing = 0.05 // Slow adaptation
                referenceWhite.r = referenceWhite.r * (1 - smoothing) + (grayTarget / max(avgR, 0.01)) * smoothing
                referenceWhite.g = referenceWhite.g * (1 - smoothing) + (grayTarget / max(avgG, 0.01)) * smoothing
                referenceWhite.b = referenceWhite.b * (1 - smoothing) + (grayTarget / max(avgB, 0.01)) * smoothing
                
                // Clamp to reasonable range
                referenceWhite.r = max(0.7, min(1.5, referenceWhite.r))
                referenceWhite.g = max(0.7, min(1.5, referenceWhite.g))
                referenceWhite.b = max(0.7, min(1.5, referenceWhite.b))
            }
        }
    }
    
    private func applyAutoWhiteBalance(r: Double, g: Double, b: Double) -> (Double, Double, Double) {
        let balR = min(1.0, r * referenceWhite.r)
        let balG = min(1.0, g * referenceWhite.g)
        let balB = min(1.0, b * referenceWhite.b)
        return (balR, balG, balB)
    }
    
    // MARK: - Gamma Correction
    private func applyGammaCorrection(r: Double, g: Double, b: Double, gamma: Double = 2.2) -> (Double, Double, Double) {
        let corrR = pow(r, 1.0 / gamma)
        let corrG = pow(g, 1.0 / gamma)
        let corrB = pow(b, 1.0 / gamma)
        return (corrR, corrG, corrB)
    }
    
    // MARK: - Color Space Conversions
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
    
    // Convert RGB to LAB color space for perceptually uniform color detection
    private func rgbToLAB(r: Double, g: Double, b: Double) -> (L: Double, a: Double, b: Double) {
        // First convert to XYZ
        var rLin = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4) : r / 12.92
        var gLin = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4) : g / 12.92
        var bLin = b > 0.04045 ? pow((b + 0.055) / 1.055, 2.4) : b / 12.92
        
        rLin *= 100
        gLin *= 100
        bLin *= 100
        
        // Observer = 2°, Illuminant = D65
        var X = rLin * 0.4124564 + gLin * 0.3575761 + bLin * 0.1804375
        var Y = rLin * 0.2126729 + gLin * 0.7151522 + bLin * 0.0721750
        var Z = rLin * 0.0193339 + gLin * 0.1191920 + bLin * 0.9503041
        
        // D65 reference white point
        X /= 95.047
        Y /= 100.000
        Z /= 108.883
        
        // Convert to LAB
        X = X > 0.008856 ? pow(X, 1.0/3.0) : (7.787 * X) + (16.0 / 116.0)
        Y = Y > 0.008856 ? pow(Y, 1.0/3.0) : (7.787 * Y) + (16.0 / 116.0)
        Z = Z > 0.008856 ? pow(Z, 1.0/3.0) : (7.787 * Z) + (16.0 / 116.0)
        
        let L = max(0, (116.0 * Y) - 16.0)
        let a = 500.0 * (X - Y)
        let bValue = 200.0 * (Y - Z)
        
        return (L, a, bValue)
    }
    
    // MARK: - Temporal Smoothing
    private func applyTemporalSmoothing(color: String) -> String {
        colorHistory.append(color)
        if colorHistory.count > historySize {
            colorHistory.removeFirst()
        }
        
        // Return most common color in history for stability
        if colorHistory.count >= 3 {
            let colorCounts = colorHistory.reduce(into: [:]) { counts, color in
                counts[color, default: 0] += 1
            }
            
            if let mostCommon = colorCounts.max(by: { $0.value < $1.value }) {
                if mostCommon.value >= 2 || colorHistory.count >= historySize {
                    return mostCommon.key
                }
            }
        }
        
        return color
    }
    
    // MARK: - Color Classification
    private func classifyNeutral(L: Double, lightness: Double) -> String {
        // Use LAB lightness for more accurate perception
        if L > 95 { return "White" }
        if L > 85 { return "Off-White" }
        if L > 70 { return "Light Gray" }
        if L > 50 { return "Gray" }
        if L > 30 { return "Dark Gray" }
        if L > 15 { return "Charcoal" }
        return "Black"
    }
    
    private func classifyChromatic(h: Double, s: Double, l: Double, 
                                   L: Double, a: Double, b: Double, chroma: Double) -> String {
        // Use both HSL and LAB for robust classification
        // LAB a: green(-) to red(+)
        // LAB b: blue(-) to yellow(+)
        
        // Classify by lightness groups for better naming
        let veryLight = L > 80
        let light = L > 62
        let medium = L > 40
        let dark = L < 35
        let veryDark = L < 20
        
        // Classify by saturation
        let veryPale = s < 18
        let pale = s < 32
        let muted = s < 48
        let vivid = s > 72
        let veryVivid = s > 88
        
        // Use hue for basic color determination with refined ranges
        var baseColor = ""
        
        // RED (345-360, 0-15)
        if h >= 345 || h < 15 {
            if veryLight && veryPale { return "Pale Pink" }
            if veryLight && pale { return "Light Pink" }
            if veryLight { return "Pink" }
            if light && pale { return "Rose" }
            if light && muted { return "Salmon" }
            if light { return "Coral" }
            if veryDark { return "Dark Red" }
            if dark && pale { return "Maroon" }
            if dark { return "Burgundy" }
            if veryVivid { return "Bright Red" }
            if vivid { return "Red" }
            if muted { return "Brick Red" }
            return "Red"
        }
        
        // RED-ORANGE (15-28)
        if h < 28 {
            if veryDark || (dark && s < 40) { return "Brown" }
            if veryLight && pale { return "Peach" }
            if veryLight { return "Light Coral" }
            if light { return "Coral" }
            if muted && medium { return "Terracotta" }
            return "Red-Orange"
        }
        
        // ORANGE (28-45)
        if h < 45 {
            if veryDark { return "Dark Brown" }
            if dark && s < 50 { return "Brown" }
            if dark { return "Burnt Orange" }
            if veryLight && veryPale { return "Cream" }
            if veryLight && pale { return "Peach" }
            if veryLight { return "Light Orange" }
            if light && pale { return "Apricot" }
            if pale && medium { return "Tan" }
            if veryVivid { return "Bright Orange" }
            if vivid { return "Orange" }
            return "Orange"
        }
        
        // GOLD/AMBER (45-55)
        if h < 55 {
            if veryDark { return "Olive Brown" }
            if dark { return "Dark Mustard" }
            if veryLight && pale { return "Cream" }
            if veryLight { return "Light Gold" }
            if pale { return "Khaki" }
            if vivid { return "Gold" }
            return "Amber"
        }
        
        // YELLOW (55-70)
        if h < 70 {
            if veryDark { return "Dark Olive" }
            if dark { return "Olive" }
            if veryLight && veryPale { return "Ivory" }
            if veryLight { return "Light Yellow" }
            if light && pale { return "Cream" }
            if pale { return "Beige" }
            if veryVivid { return "Bright Yellow" }
            if vivid || s > 60 { return "Yellow" }
            if muted { return "Mustard" }
            return "Yellow"
        }
        
        // YELLOW-GREEN/LIME (70-88)
        if h < 88 {
            if veryDark { return "Dark Olive" }
            if dark { return "Olive" }
            if veryLight { return "Light Lime" }
            if light && pale { return "Pale Green" }
            if vivid { return "Lime" }
            return "Yellow-Green"
        }
        
        // GREEN (88-160)
        if h < 160 {
            if veryLight && veryPale { return "Mint" }
            if veryLight && pale { return "Pale Mint" }
            if veryLight { return "Light Green" }
            if light && pale { return "Sage" }
            if light && h > 145 { return "Seafoam" }
            if light { return "Spring Green" }
            if veryDark { return "Dark Green" }
            if dark && muted { return "Forest Green" }
            if dark && h > 145 { return "Dark Teal" }
            if dark { return "Hunter Green" }
            if veryVivid { return "Bright Green" }
            if vivid { return "Green" }
            if h > 145 && medium { return "Teal" }
            if muted { return "Olive Green" }
            return "Green"
        }
        
        // CYAN/TURQUOISE (160-190)
        if h < 190 {
            if veryLight && pale { return "Pale Aqua" }
            if veryLight { return "Light Cyan" }
            if light { return "Aqua" }
            if dark { return "Dark Teal" }
            if vivid { return "Turquoise" }
            return "Cyan"
        }
        
        // LIGHT BLUE (190-220)
        if h < 220 {
            if veryLight && veryPale { return "Ice Blue" }
            if veryLight { return "Powder Blue" }
            if light && pale { return "Sky Blue" }
            if light { return "Light Blue" }
            if dark { return "Steel Blue" }
            if vivid { return "Sky Blue" }
            return "Light Blue"
        }
        
        // BLUE (220-255)
        if h < 255 {
            if veryLight && veryPale { return "Periwinkle" }
            if veryLight { return "Light Blue" }
            if light && pale { return "Cornflower" }
            if light { return "Medium Blue" }
            if veryDark { return "Navy" }
            if dark { return "Dark Blue" }
            if veryVivid { return "Bright Blue" }
            if vivid { return "Blue" }
            if muted { return "Slate Blue" }
            return "Blue"
        }
        
        // INDIGO/VIOLET (255-280)
        if h < 280 {
            if veryLight { return "Lavender" }
            if light { return "Periwinkle" }
            if veryDark { return "Deep Indigo" }
            if dark { return "Indigo" }
            if vivid { return "Violet" }
            return "Blue-Violet"
        }
        
        // PURPLE (280-315)
        if h < 315 {
            if veryLight && veryPale { return "Pale Lavender" }
            if veryLight { return "Light Purple" }
            if light && pale { return "Lilac" }
            if light { return "Orchid" }
            if veryDark { return "Deep Purple" }
            if dark { return "Plum" }
            if veryVivid { return "Bright Purple" }
            if vivid { return "Purple" }
            if muted { return "Mauve" }
            return "Purple"
        }
        
        // MAGENTA/PINK (315-345)
        if h < 345 {
            if veryLight && veryPale { return "Blush" }
            if veryLight { return "Light Pink" }
            if light && pale { return "Rose Pink" }
            if light { return "Pink" }
            if dark && muted { return "Plum" }
            if dark { return "Deep Magenta" }
            if veryVivid { return "Hot Pink" }
            if vivid { return "Fuchsia" }
            if muted { return "Dusty Rose" }
            return "Magenta"
        }
        
        return "Unknown"
    }
}