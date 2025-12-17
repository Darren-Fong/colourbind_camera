import SwiftUI
import UIKit
import Vision
import CoreImage

// Graph Line Detector for pattern-coding multi-color lines
class GraphLineDetector {
    
    struct DetectedLine {
        let path: [CGPoint]
        let color: UIColor
        let thickness: CGFloat
    }
    
    func detectLines(in image: UIImage) -> [DetectedLine] {
        guard let ciImage = CIImage(image: image) else { return [] }
        
        var detectedLines: [DetectedLine] = []
        
        // Use Vision framework to detect lines
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.5
        request.detectsDarkOnLight = true
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try handler.perform([request])
            
            if let results = request.results {
                for observation in results {
                    let contour = observation.normalizedPath
                    let points = convertPathToPoints(contour, imageSize: image.size)
                    
                    if let color = sampleColorAlongPath(points, in: image) {
                        let line = DetectedLine(
                            path: points,
                            color: color,
                            thickness: estimateLineThickness(points)
                        )
                        detectedLines.append(line)
                    }
                }
            }
        } catch {
            print("Failed to detect lines: \(error)")
        }
        
        return groupSimilarLines(detectedLines)
    }
    
    func applyPatternCodingToGraph(image: UIImage, lines: [DetectedLine]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // Draw original image
            image.draw(at: .zero)
            
            let ctx = context.cgContext
            
            // Define different shape markers for each color group
            let shapeStyles: [ShapeMarkerStyle] = [.circle, .square, .triangle, .diamond, .cross, .star]
            
            // Group lines by color - only process significant lines
            let significantLines = lines.filter { $0.path.count >= 5 && isSignificantLine($0) }
            
            let groupedLines = Dictionary(grouping: significantLines) { line in
                quantizeColor(line.color)
            }
            
            var shapeIndex = 0
            
            for (colorKey, colorLines) in groupedLines {
                let shape = shapeStyles[shapeIndex % shapeStyles.count]
                let lineColor = colorLines.first?.color ?? .black
                
                for line in colorLines {
                    // Draw shape markers along the line path
                    drawShapeMarkersAlongPath(
                        path: line.path,
                        shape: shape,
                        color: lineColor,
                        context: ctx
                    )
                }
                
                shapeIndex += 1
            }
        }
    }
    
    private func isSignificantLine(_ line: DetectedLine) -> Bool {
        // Filter out noise - only keep lines with meaningful length
        guard line.path.count >= 3 else { return false }
        
        var totalLength: CGFloat = 0
        for i in 0..<line.path.count - 1 {
            let dx = line.path[i+1].x - line.path[i].x
            let dy = line.path[i+1].y - line.path[i].y
            totalLength += sqrt(dx*dx + dy*dy)
        }
        
        // Line should be at least 50 pixels long
        return totalLength >= 50
    }
    
    enum ShapeMarkerStyle {
        case circle
        case square
        case triangle
        case diamond
        case cross
        case star
    }
    
    private func drawShapeMarkersAlongPath(path: [CGPoint], shape: ShapeMarkerStyle, color: UIColor, context: CGContext) {
        guard path.count >= 2 else { return }
        
        // Calculate total path length
        var totalLength: CGFloat = 0
        for i in 0..<path.count - 1 {
            let dx = path[i+1].x - path[i].x
            let dy = path[i+1].y - path[i].y
            totalLength += sqrt(dx*dx + dy*dy)
        }
        
        // Place markers every ~40 pixels along the path
        let markerSpacing: CGFloat = 40
        let numMarkers = max(3, Int(totalLength / markerSpacing))
        
        let markerSize: CGFloat = 12
        
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.5)
        
        for i in 0..<numMarkers {
            let t = CGFloat(i) / CGFloat(numMarkers - 1)
            let point = pointAlongPath(path: path, t: t)
            
            drawShape(shape, at: point, size: markerSize, context: context)
        }
        
        context.restoreGState()
    }
    
    private func pointAlongPath(path: [CGPoint], t: CGFloat) -> CGPoint {
        guard path.count >= 2 else { return path.first ?? .zero }
        
        let index = Int(t * CGFloat(path.count - 1))
        let clampedIndex = min(index, path.count - 1)
        return path[clampedIndex]
    }
    
    private func drawShape(_ shape: ShapeMarkerStyle, at center: CGPoint, size: CGFloat, context: CGContext) {
        let halfSize = size / 2
        
        switch shape {
        case .circle:
            let rect = CGRect(x: center.x - halfSize, y: center.y - halfSize, width: size, height: size)
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
            
        case .square:
            let rect = CGRect(x: center.x - halfSize, y: center.y - halfSize, width: size, height: size)
            context.fill(rect)
            context.stroke(rect)
            
        case .triangle:
            context.beginPath()
            context.move(to: CGPoint(x: center.x, y: center.y - halfSize))
            context.addLine(to: CGPoint(x: center.x - halfSize, y: center.y + halfSize))
            context.addLine(to: CGPoint(x: center.x + halfSize, y: center.y + halfSize))
            context.closePath()
            context.fillPath()
            context.beginPath()
            context.move(to: CGPoint(x: center.x, y: center.y - halfSize))
            context.addLine(to: CGPoint(x: center.x - halfSize, y: center.y + halfSize))
            context.addLine(to: CGPoint(x: center.x + halfSize, y: center.y + halfSize))
            context.closePath()
            context.strokePath()
            
        case .diamond:
            context.beginPath()
            context.move(to: CGPoint(x: center.x, y: center.y - halfSize))
            context.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))
            context.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))
            context.addLine(to: CGPoint(x: center.x - halfSize, y: center.y))
            context.closePath()
            context.fillPath()
            context.beginPath()
            context.move(to: CGPoint(x: center.x, y: center.y - halfSize))
            context.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))
            context.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))
            context.addLine(to: CGPoint(x: center.x - halfSize, y: center.y))
            context.closePath()
            context.strokePath()
            
        case .cross:
            let armWidth: CGFloat = size / 4
            context.setLineWidth(armWidth)
            context.beginPath()
            context.move(to: CGPoint(x: center.x - halfSize, y: center.y))
            context.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))
            context.move(to: CGPoint(x: center.x, y: center.y - halfSize))
            context.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))
            context.strokePath()
            context.setLineWidth(1.5)
            
        case .star:
            let innerRadius = halfSize * 0.4
            context.beginPath()
            for i in 0..<10 {
                let radius = i % 2 == 0 ? halfSize : innerRadius
                let angle = CGFloat(i) * .pi / 5 - .pi / 2
                let point = CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
                if i == 0 {
                    context.move(to: point)
                } else {
                    context.addLine(to: point)
                }
            }
            context.closePath()
            context.fillPath()
            context.beginPath()
            for i in 0..<10 {
                let radius = i % 2 == 0 ? halfSize : innerRadius
                let angle = CGFloat(i) * .pi / 5 - .pi / 2
                let point = CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
                if i == 0 {
                    context.move(to: point)
                } else {
                    context.addLine(to: point)
                }
            }
            context.closePath()
            context.strokePath()
        }
    }
    
    private func convertPathToPoints(_ path: CGPath, imageSize: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        
        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint, .addLineToPoint:
                let point = element.points[0]
                // Convert from normalized coordinates
                let scaledPoint = CGPoint(
                    x: point.x * imageSize.width,
                    y: (1 - point.y) * imageSize.height
                )
                points.append(scaledPoint)
            case .addQuadCurveToPoint:
                let point = element.points[1]
                let scaledPoint = CGPoint(
                    x: point.x * imageSize.width,
                    y: (1 - point.y) * imageSize.height
                )
                points.append(scaledPoint)
            case .addCurveToPoint:
                let point = element.points[2]
                let scaledPoint = CGPoint(
                    x: point.x * imageSize.width,
                    y: (1 - point.y) * imageSize.height
                )
                points.append(scaledPoint)
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        
        return points
    }
    
    private func sampleColorAlongPath(_ points: [CGPoint], in image: UIImage) -> UIColor? {
        guard !points.isEmpty,
              let cgImage = image.cgImage,
              let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return nil
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        var sampleCount = 0
        
        // Sample color at multiple points along the path
        let samplePoints = stride(from: 0, to: points.count, by: max(1, points.count / 10))
        
        for index in samplePoints {
            let point = points[index]
            let x = Int(point.x)
            let y = Int(point.y)
            
            guard x >= 0, x < width, y >= 0, y < height else { continue }
            
            let pixelInfo = ((width * y) + x) * 4
            
            r += CGFloat(data[pixelInfo]) / 255.0
            g += CGFloat(data[pixelInfo + 1]) / 255.0
            b += CGFloat(data[pixelInfo + 2]) / 255.0
            sampleCount += 1
        }
        
        guard sampleCount > 0 else { return nil }
        
        return UIColor(
            red: r / CGFloat(sampleCount),
            green: g / CGFloat(sampleCount),
            blue: b / CGFloat(sampleCount),
            alpha: 1.0
        )
    }
    
    private func estimateLineThickness(_ points: [CGPoint]) -> CGFloat {
        // Estimate based on density of points
        guard points.count >= 2 else { return 2.0 }
        
        var totalDistance: CGFloat = 0
        for i in 0..<points.count-1 {
            let dx = points[i+1].x - points[i].x
            let dy = points[i+1].y - points[i].y
            totalDistance += sqrt(dx*dx + dy*dy)
        }
        
        let avgSegmentLength = totalDistance / CGFloat(points.count - 1)
        return max(2.0, min(8.0, avgSegmentLength / 10))
    }
    
    private func quantizeColor(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let red = Int(r * 255)
        let green = Int(g * 255)
        let blue = Int(b * 255)
        
        // Quantize to major color groups
        if red > 200 && green < 100 && blue < 100 { return "red" }
        if green > 200 && red < 100 && blue < 100 { return "green" }
        if blue > 200 && red < 100 && green < 100 { return "blue" }
        if red > 200 && green > 200 && blue < 100 { return "yellow" }
        if red < 100 && green < 100 && blue < 100 { return "black" }
        if red > 200 && green > 200 && blue > 200 { return "white" }
        
        return "color_\(red/50)_\(green/50)_\(blue/50)"
    }
    
    private func groupSimilarLines(_ lines: [DetectedLine]) -> [DetectedLine] {
        // Remove duplicate or very similar lines
        var uniqueLines: [DetectedLine] = []
        
        for line in lines {
            let isDuplicate = uniqueLines.contains { existingLine in
                areLinesSimiular(line, existingLine)
            }
            
            if !isDuplicate {
                uniqueLines.append(line)
            }
        }
        
        return uniqueLines
    }
    
    private func areLinesSimiular(_ line1: DetectedLine, _ line2: DetectedLine) -> Bool {
        guard line1.path.count > 0, line2.path.count > 0 else { return false }
        
        // Check if start and end points are close
        let start1 = line1.path.first!
        let start2 = line2.path.first!
        let end1 = line1.path.last!
        let end2 = line2.path.last!
        
        let threshold: CGFloat = 10
        
        let startDistance = sqrt(pow(start1.x - start2.x, 2) + pow(start1.y - start2.y, 2))
        let endDistance = sqrt(pow(end1.x - end2.x, 2) + pow(end1.y - end2.y, 2))
        
        return startDistance < threshold && endDistance < threshold
    }
}
