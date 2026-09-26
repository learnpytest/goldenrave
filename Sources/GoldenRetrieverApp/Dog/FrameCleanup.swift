import AppKit
import CoreGraphics

/// Frames were cut from larger sheets, so some carry slivers of the
/// neighbouring pose along the canvas edge; animated, they flash as thin
/// yellow lines. Small edge-touching fragments are removed, and frames are
/// cropped to a shared box so the dog fills the menu bar.
enum FrameCleanup {
    struct PixelRect: Equatable {
        var minX: Int
        var minY: Int
        var maxX: Int
        var maxY: Int

        func union(_ other: PixelRect) -> PixelRect {
            PixelRect(
                minX: min(minX, other.minX),
                minY: min(minY, other.minY),
                maxX: max(maxX, other.maxX),
                maxY: max(maxY, other.maxY)
            )
        }
    }

    static let alphaThreshold: UInt8 = 24
    static let fragmentShareOfLargest = 0.25

    static func keepMask(alpha: [UInt8], width: Int, height: Int) -> [Bool] {
        var label = [Int](repeating: -1, count: alpha.count)
        var areas: [Int] = []
        var touchesEdge: [Bool] = []
        var stack: [Int] = []

        for start in alpha.indices where alpha[start] >= alphaThreshold && label[start] < 0 {
            let component = areas.count
            var area = 0
            var edge = false
            label[start] = component
            stack.append(start)
            while let index = stack.popLast() {
                area += 1
                let x = index % width
                let y = index / width
                if x == 0 || y == 0 || x == width - 1 || y == height - 1 { edge = true }
                for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                where nx >= 0 && ny >= 0 && nx < width && ny < height {
                    let neighbour = ny * width + nx
                    if label[neighbour] < 0, alpha[neighbour] >= alphaThreshold {
                        label[neighbour] = component
                        stack.append(neighbour)
                    }
                }
            }
            areas.append(area)
            touchesEdge.append(edge)
        }

        let largest = areas.max() ?? 0
        let keepComponent = areas.indices.map { component in
            areas[component] == largest
                || !touchesEdge[component]
                || Double(areas[component]) >= Double(largest) * fragmentShareOfLargest
        }
        return label.map { $0 >= 0 && keepComponent[$0] }
    }

    static func boundingBox(of keep: [Bool], width: Int, height: Int) -> PixelRect? {
        var box: PixelRect?
        for index in keep.indices where keep[index] {
            let point = PixelRect(minX: index % width, minY: index / width, maxX: index % width, maxY: index / width)
            box = box?.union(point) ?? point
        }
        return box
    }

    /// Returns the cleaned image and the bounding box of what was kept
    /// (top-left origin, in pixels).
    static func clean(_ image: NSImage) -> (image: NSImage, box: PixelRect?)? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let data = context.data else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let alpha = (0..<(width * height)).map { pixels[$0 * 4 + 3] }
        let keep = keepMask(alpha: alpha, width: width, height: height)
        for index in keep.indices where !keep[index] {
            for channel in 0..<4 { pixels[index * 4 + channel] = 0 }
        }
        guard let cleaned = context.makeImage() else { return nil }
        let result = NSImage(cgImage: cleaned, size: image.size)
        return (result, boundingBox(of: keep, width: width, height: height))
    }
}
