import SwiftUI
import UIKit
import Vision
import CoreImage

// Graph Line Detector for pattern-coding multi-color lines
class GraphLineDetector {
    
    struct DetectedLine {
        let path: [CGPoint]
        let color: UIColor
        let colorName: String
        let thickness: CGFloat
    }
    
    // Predefined chart colors to look for (common colors used in graphs)
    private let chartColors: [(name: String, color: UIColor, hueRange: ClosedRange<CGFloat>, satMin: CGFloat, brightMin: CGFloat)] = [
        ("Red", UIColor.red, 0.95...1.0, 0.4, 0.3),
        ("Red", UIColor.red, 0.0...0.05, 0.4, 0.3),
        ("Orange", UIColor.orange, 0.05...0.12, 0.4, 0.4),
        ("Yellow", UIColor.yellow, 0.12...0.2, 0.4, 0.5),
        ("Green", UIColor.green, 0.2...0.45, 0.3, 0.3),
        ("Cyan", UIColor.cyan, 0.45...0.55, 0.3, 0.4),
        ("Blue", UIColor.blue, 0.55...0.7, 0.3, 0.3),
        ("Purple", UIColor.purple, 0.7...0.8, 0.3, 0.3),
        ("Magenta", UIColor.magenta, 0.8...0.95, 0.3, 0.3),
    ]
    
    func detectLines(in image: UIImage) -> [DetectedLine] {
        guard let cgImage = image.cgImage else { return [] }
        
        var detectedLines: [DetectedLine] = []
        
        // Scan the image for colored pixels and group them into lines
        let width = cgImage.width
        let height = cgImage.height
        
        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return []
        }
        
        // For each chart color, find continuous horizontal runs of that color
        for chartColor in chartColors {
            var colorPoints: [CGPoint] = []
            
            // Scan image row by row
            for y in stride(from: 0, to: height, by: 2) {
                for x in stride(from: 0, to: width, by: 2) {
                    let pixelInfo = ((width * y) + x) * 4
                    
                    let r = CGFloat(data[pixelInfo]) / 255.0
                    let g = CGFloat(data[pixelInfo + 1]) / 255.0
                    let b = CGFloat(data[pixelInfo + 2]) / 255.0
                    
                    // Convert to HSB
                    var hue: CGFloat = 0, sat: CGFloat = 0, bright: CGFloat = 0
                    UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&hue, saturation: &sat, brightness: &bright, alpha: nil)
                    
                    // Check if this pixel matches the chart color
                    if chartColor.hueRange.contains(hue) && sat >= chartColor.satMin && bright >= chartColor.brightMin {
                        colorPoints.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                    }
                }
            }
            
            // If we found enough points of this color, create line segments
            if colorPoints.count >= 20 {
                let lines = extractLinesFromPoints(colorPoints, color: chartColor.color, colorName: chartColor.name, imageSize: image.size)
                detectedLines.append(contentsOf: lines)
            }
        }
        
        return detectedLines
    }
    
    private func extractLinesFromPoints(_ points: [CGPoint], color: UIColor, colorName: String, imageSize: CGSize) -> [DetectedLine] {
        guard !points.isEmpty else { return [] }
        
        // Sort points by x coordinate to form a line path
        let sortedPoints = points.sorted { $0.x < $1.x }
        
        // Group points into continuous segments
        var segments: [[CGPoint]] = []
        var currentSegment: [CGPoint] = []
        
        for point in sortedPoints {
            if currentSegment.isEmpty {
                currentSegment.append(point)
            } else {
                let lastPoint = currentSegment.last!
                let distance = sqrt(pow(point.x - lastPoint.x, 2) + pow(point.y - lastPoint.y, 2))
                
                // If points are close enough, add to current segment
                if distance < 30 {
                    currentSegment.append(point)
                } else {
                    // Start a new segment
                    if currentSegment.count >= 10 {
                        segments.append(currentSegment)
                    }
                    currentSegment = [point]
                }
            }
        }
        
        if currentSegment.count >= 10 {
            segments.append(currentSegment)
        }
        
        // Convert segments to lines, simplifying the path
        return segments.map { segment in
            let simplifiedPath = simplifyPath(segment, tolerance: 5)
            return DetectedLine(
                path: simplifiedPath,
                color: color,
                colorName: colorName,
                thickness: 3.0
            )
        }
    }
    
    private func simplifyPath(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        // Use Douglas-Peucker algorithm to simplify
        var simplified: [CGPoint] = []
        let step = max(1, points.count / 50) // Keep around 50 points max
        
        for i in stride(from: 0, to: points.count, by: step) {
            simplified.append(points[i])
        }
        
        if let last = points.last, simplified.last != last {
            simplified.append(last)
        }
        
        return simplified
    }
    
    func applyPatternCodingToGraph(image: UIImage, lines: [DetectedLine]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        return renderer.image { context in
            // Draw original image first (preserves text, labels, etc.)
            image.draw(at: .zero)
            
            let ctx = context.cgContext
            
            // Define different shape markers for each color
            let shapeStyles: [ShapeMarkerStyle] = [.circle, .square, .triangle, .diamond, .cross, .star, .hexagon, .plus]
            
            // Group lines by color name
            let groupedLines = Dictionary(grouping: lines) { $0.colorName }
            
            var shapeIndex = 0
            
            for (colorName, colorLines) in groupedLines.sorted(by: { $0.key < $1.key }) {
                let shape = shapeStyles[shapeIndex % shapeStyles.count]
                
                for line in colorLines {
                    // Draw shape markers along the line path
                    drawShapeMarkersAlongPath(
                        path: line.path,
                        shape: shape,
                        color: line.color,
                        context: ctx
                    )
                }
                
                shapeIndex += 1
            }
            
            // Draw legend in top-right corner
            drawLegend(groupedLines: groupedLines, shapeStyles: shapeStyles, context: ctx, imageSize: image.size)
        }
    }
    
    private func drawLegend(groupedLines: [String: [DetectedLine]], shapeStyles: [ShapeMarkerStyle], context: CGContext, imageSize: CGSize) {
        guard !groupedLines.isEmpty else { return }
        
        let sortedColors = groupedLines.keys.sorted()
        let legendX = imageSize.width - 120
        var legendY: CGFloat = 20
        let itemHeight: CGFloat = 25
        
        // Draw legend background
        let legendHeight = CGFloat(sortedColors.count) * itemHeight + 20
        context.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        context.fill(CGRect(x: legendX - 10, y: 10, width: 120, height: legendHeight))
        context.setStrokeColor(UIColor.gray.cgColor)
        context.setLineWidth(1)
        context.stroke(CGRect(x: legendX - 10, y: 10, width: 120, height: legendHeight))
        
        for (index, colorName) in sortedColors.enumerated() {
            guard let line = groupedLines[colorName]?.first else { continue }
            let shape = shapeStyles[index % shapeStyles.count]
            
            // Draw shape
            context.saveGState()
            context.setFillColor(line.color.cgColor)
            context.setStrokeColor(UIColor.black.cgColor)
            context.setLineWidth(1)
            drawShape(shape, at: CGPoint(x: legendX + 10, y: legendY + 8), size: 14, context: context)
            context.restoreGState()
            
            // Draw color name
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            let text = colorName as NSString
            text.draw(at: CGPoint(x: legendX + 25, y: legendY), withAttributes: attributes)
            
            legendY += itemHeight
        }
    }
    
    enum ShapeMarkerStyle {
        case circle
        case square
        case triangle
        case diamond
        case cross
        case star
        case hexagon
        case plus
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
        
        guard totalLength > 0 else { return }
        
        // Place markers every ~60 pixels along the path
        let markerSpacing: CGFloat = 60
        let numMarkers = max(2, min(20, Int(totalLength / markerSpacing)))
        
        let markerSize: CGFloat = 14
        
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.5)
        
        for i in 0..<numMarkers {
            let t = CGFloat(i) / CGFloat(max(1, numMarkers - 1))
            let point = pointAlongPath(path: path, t: t)
            
            drawShape(shape, at: point, size: markerSize, context: context)
        }
        
        context.restoreGState()
    }
    
    private func pointAlongPath(path: [CGPoint], t: CGFloat) -> CGPoint {
        guard path.count >= 2 else { return path.first ?? .zero }
        
        // Calculate total length
        var totalLength: CGFloat = 0
        var segmentLengths: [CGFloat] = []
        
        for i in 0..<path.count - 1 {
            let dx = path[i+1].x - path[i].x
            let dy = path[i+1].y - path[i].y
            let len = sqrt(dx*dx + dy*dy)
            segmentLengths.append(len)
            totalLength += len
        }
        
        guard totalLength > 0 else { return path.first ?? .zero }
        
        // Find point at distance t * totalLength along the path
        let targetDistance = t * totalLength
        var accumulatedDistance: CGFloat = 0
        
        for i in 0..<segmentLengths.count {
            let segmentLength = segmentLengths[i]
            
            if accumulatedDistance + segmentLength >= targetDistance {
                let segmentT = (targetDistance - accumulatedDistance) / segmentLength
                let p1 = path[i]
                let p2 = path[i + 1]
                return CGPoint(
                    x: p1.x + (p2.x - p1.x) * segmentT,
                    y: p1.y + (p2.y - p1.y) * segmentT
                )
            }
            
            accumulatedDistance += segmentLength
        }
        
        return path.last ?? .zero
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
            let path = CGMutablePath()
            path.move(to: CGPoint(x: center.x, y: center.y - halfSize))
            path.addLine(to: CGPoint(x: center.x - halfSize, y: center.y + halfSize))
            path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y + halfSize))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            context.addPath(path)
            context.strokePath()
            
        case .diamond:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: center.x, y: center.y - halfSize))
            path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))
            path.addLine(to: CGPoint(x: center.x - halfSize, y: center.y))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            context.addPath(path)
            context.strokePath()
            
        case .cross:
            let armLength = halfSize * 0.8
            let armWidth = size * 0.25
            context.setLineWidth(armWidth)
            context.move(to: CGPoint(x: center.x - armLength, y: center.y - armLength))
            context.addLine(to: CGPoint(x: center.x + armLength, y: center.y + armLength))
            context.move(to: CGPoint(x: center.x + armLength, y: center.y - armLength))
            context.addLine(to: CGPoint(x: center.x - armLength, y: center.y + armLength))
            context.strokePath()
            context.setLineWidth(1.5)
            
        case .plus:
            let armWidth = size * 0.3
            context.setLineWidth(armWidth)
            context.move(to: CGPoint(x: center.x - halfSize, y: center.y))
            context.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))
            context.move(to: CGPoint(x: center.x, y: center.y - halfSize))
            context.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))
            context.strokePath()
            context.setLineWidth(1.5)
            
        case .star:
            let innerRadius = halfSize * 0.4
            let path = CGMutablePath()
            for i in 0..<10 {
                let radius = i % 2 == 0 ? halfSize : innerRadius
                let angle = CGFloat(i) * .pi / 5 - .pi / 2
                let point = CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                )
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            context.addPath(path)
            context.strokePath()
            
        case .hexagon:
            let path = CGMutablePath()
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3 - .pi / 6
                let point = CGPoint(
                    x: center.x + halfSize * cos(angle),
                    y: center.y + halfSize * sin(angle)
                )
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            context.addPath(path)
            context.strokePath()
        }
    }
}
