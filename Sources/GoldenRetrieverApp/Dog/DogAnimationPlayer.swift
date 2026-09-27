import AppKit
import Foundation
import GoldenRetrieverCore

public struct DogAnimationPlayer: Sendable {
    public init() {}

    /// Frames are `<animation>-01.png`, `<animation>-02.png`, … (SwiftPM flattens
    /// the resource folders, so names must be unique). Until an animation has
    /// its frames, the existing single pose for that state is shown.
    public func frames(for animation: DogAnimation) -> [NSImage] {
        Self.cleanedFrames(for: animation).map(\.image)
    }

    /// The menu bar is 22pt thick; 20pt leaves room so nothing is clipped.
    public static let menuBarHeight: CGFloat = 20
    public static let menuBarMaxWidth: CGFloat = 40

    /// Status item buttons draw images at their intrinsic point size, so the
    /// frames must already be menu-bar sized. They are cropped to the box the
    /// dog uses across the whole animation (so it fills the menu bar without
    /// jumping between frames) and rasterized at @2x once: keeping the 512px
    /// source and only shrinking `size` made every frame swap downsample the
    /// full bitmap (19% CPU measured 2026-09-26).
    public func menuBarFrames(for animation: DogAnimation) -> [NSImage] {
        fittedFrames(for: animation, height: Self.menuBarHeight, maxWidth: Self.menuBarMaxWidth)
    }

    public static let popoverSide: CGFloat = 150

    /// The popover redraws every frame; drawing the 512px sources each time
    /// cost ~8% CPU while it was open, so it gets pre-scaled frames too.
    public func popoverFrames(for animation: DogAnimation) -> [NSImage] {
        fittedFrames(for: animation, height: Self.popoverSide, maxWidth: Self.popoverSide)
    }

    private func fittedFrames(for animation: DogAnimation, height targetHeight: CGFloat, maxWidth: CGFloat) -> [NSImage] {
        Self.cache.value(forKey: "\(animation.rawValue)@\(targetHeight)x\(maxWidth)") {
            let cleaned = Self.cleanedFrames(for: animation)
            guard let box = cleaned.compactMap(\.box).reduce(nil, { partial, next in partial?.union(next) ?? next })
            else { return [] }
            let boxWidth = CGFloat(box.maxX - box.minX + 1)
            let boxHeight = CGFloat(box.maxY - box.minY + 1)
            var size = NSSize(width: (targetHeight * boxWidth / boxHeight).rounded(), height: targetHeight)
            if size.width > maxWidth {
                size = NSSize(width: maxWidth, height: (maxWidth * boxHeight / boxWidth).rounded())
            }
            return cleaned.compactMap { frame in
                let pixelHeight = frame.pixelHeight
                let pointsPerPixel = frame.image.size.height / CGFloat(pixelHeight)
                let crop = NSRect(
                    x: CGFloat(box.minX) * pointsPerPixel,
                    y: CGFloat(pixelHeight - box.maxY - 1) * pointsPerPixel,
                    width: boxWidth * pointsPerPixel,
                    height: boxHeight * pointsPerPixel
                )
                return Self.rasterize(frame.image, crop: crop, to: size, scale: 2)
            }
        }
    }

    private struct CleanFrame {
        let image: NSImage
        let box: FrameCleanup.PixelRect?
        let pixelHeight: Int
    }

    private static let cleanCache = CleanFrameCache()

    private static func cleanedFrames(for animation: DogAnimation) -> [CleanFrame] {
        cleanCache.value(forKey: animation.rawValue) {
            frameURLs(for: animation).compactMap { url in
                guard let source = NSImage(contentsOf: url),
                      let pixelHeight = source.representations.first?.pixelsHigh, pixelHeight > 0 else { return nil }
                guard let cleaned = FrameCleanup.clean(source) else {
                    return CleanFrame(image: source, box: nil, pixelHeight: pixelHeight)
                }
                return CleanFrame(image: cleaned.image, box: cleaned.box, pixelHeight: pixelHeight)
            }
        }
    }

    private final class CleanFrameCache: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String: [CleanFrame]] = [:]

        func value(forKey key: String, make: () -> [CleanFrame]) -> [CleanFrame] {
            lock.lock()
            if let cached = storage[key] {
                lock.unlock()
                return cached
            }
            lock.unlock()
            let made = make()
            lock.lock()
            storage[key] = made
            lock.unlock()
            return made
        }
    }

    private static func rasterize(_ source: NSImage, crop: NSRect, to size: NSSize, scale: CGFloat) -> NSImage? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        // The context's coordinates are the bitmap's pixels, so fill the pixel
        // rect; drawing into the point rect filled only the bottom-left quarter.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let pixelRect = NSRect(x: 0, y: 0, width: CGFloat(rep.pixelsWide), height: CGFloat(rep.pixelsHigh))
        source.draw(in: pixelRect, from: crop, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        rep.size = size

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    public func frameDuration(for animation: DogAnimation) -> TimeInterval {
        switch animation {
        case .idle: 0.6
        case .walk: 0.14
        case .run: 0.08
        case .pounce: 0.1
        case .spin: DogAnimationDirector.spinDuration / 12
        case .rest: 0.5
        case .depleted: 0.8
        case .bellyUp: 0.25
        case .play, .playBall: 0.12
        case .stroll: 0.16
        case .cuddle: 0.2
        case .waiting: 0.32
        case .timeWatch: 0.6
        }
    }

    public static let menuBarMinimumFrameDuration: TimeInterval = 0.15

    /// Each status item image swap is replicated to Control Center on macOS 26
    /// (NSStatusItem _windowNeedsReplicantUpdate dominated a 2026-09-26 sample),
    /// so the menu bar runs slower than the popover. Spin keeps its timing so it
    /// still finishes within the spin moment.
    public func menuBarFrameDuration(for animation: DogAnimation) -> TimeInterval {
        let duration = frameDuration(for: animation)
        return animation == .spin ? duration : max(duration * 1.5, Self.menuBarMinimumFrameDuration)
    }

    /// Spin ends lying down, so it plays once and holds its last frame.
    public func loops(_ animation: DogAnimation) -> Bool {
        animation != .spin
    }

    /// Seconds until the next frame is due, so a timer can fire exactly then.
    /// Sampling on a fixed 0.1s tick made 0.15s run frames alternate 0.1s/0.2s
    /// holds and gave the 0.21s walk a 0.3s hitch about once a loop.
    public static func secondsUntilNextFrame(elapsed: TimeInterval, frameDuration: TimeInterval) -> TimeInterval {
        guard frameDuration > 0 else { return 0.5 }
        // The epsilon keeps 0.3 / 0.15 from landing on 1.999… and scheduling a 0s wait.
        let step = (max(0, elapsed) / frameDuration + 1e-9).rounded(.down)
        return (step + 1) * frameDuration - max(0, elapsed)
    }

    public static func frameIndex(
        elapsed: TimeInterval,
        frameDuration: TimeInterval,
        frameCount: Int,
        loops: Bool = true
    ) -> Int {
        guard frameCount > 1, frameDuration > 0 else { return 0 }
        let step = Int((max(0, elapsed) / frameDuration).rounded(.down))
        return loops ? step % frameCount : min(step, frameCount - 1)
    }

    /// Every animation ships its own numbered frames.
    public static func frameURLs(for animation: DogAnimation) -> [URL] {
        sequenceURLs(prefix: animation.rawValue)
    }

    private static func sequenceURLs(prefix name: String) -> [URL] {
        let prefix = "\(name)-"
        return (resourceBundle().urls(forResourcesWithExtension: "png", subdirectory: nil) ?? [])
            .filter { url in
                let name = url.deletingPathExtension().lastPathComponent
                return name.hasPrefix(prefix) && Int(name.dropFirst(prefix.count)) != nil
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public static func canonicalReferenceURL() -> URL? {
        resourceBundle().url(forResource: "golden-retriever-puppy-reference", withExtension: "png")
    }

    private static let cache = FrameCache()

    private static func resourceBundle() -> Bundle {
        let bundleName = "GoldenRetriever_GoldenRetrieverApp.bundle"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent(bundleName)
        ].compactMap { $0 }

        for candidate in candidates {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        return Bundle.module
    }
}

private final class FrameCache: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: [NSImage]] = [:]

    func value(forKey key: String, make: () -> [NSImage]) -> [NSImage] {
        lock.lock()
        if let cached = storage[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let made = make()
        lock.lock()
        storage[key] = made
        lock.unlock()
        return made
    }
}
