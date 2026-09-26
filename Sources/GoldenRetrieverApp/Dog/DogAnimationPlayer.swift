import AppKit
import Foundation
import GoldenRetrieverCore

public struct DogAnimationPlayer: Sendable {
    public init() {}

    /// Frames are `<animation>-01.png`, `<animation>-02.png`, … (SwiftPM flattens
    /// the resource folders, so names must be unique). Until an animation has
    /// its frames, the existing single pose for that state is shown.
    public func frames(for animation: DogAnimation) -> [NSImage] {
        Self.cache.value(forKey: animation.rawValue) {
            Self.frameURLs(for: animation).compactMap(NSImage.init(contentsOf:))
        }
    }

    /// Status item buttons draw images at their intrinsic point size, so the
    /// frames must already be menu-bar sized.
    public func menuBarFrames(for animation: DogAnimation, height: CGFloat = 18) -> [NSImage] {
        Self.cache.value(forKey: "\(animation.rawValue)@\(height)") {
            frames(for: animation).compactMap { source in
                guard source.size.height > 0, let image = source.copy() as? NSImage else { return nil }
                let width = (height * source.size.width / source.size.height).rounded()
                image.size = NSSize(width: width, height: height)
                return image
            }
        }
    }

    public func frameDuration(for animation: DogAnimation) -> TimeInterval {
        switch animation {
        case .idle: 0.6
        case .walk: 0.14
        case .run: 0.08
        case .pounce: 0.1
        case .spin: 0.1
        case .rest: 0.5
        case .bellyUp: 0.25
        case .play, .playBall: 0.12
        }
    }

    public static func frameIndex(elapsed: TimeInterval, frameDuration: TimeInterval, frameCount: Int) -> Int {
        guard frameCount > 1, frameDuration > 0 else { return 0 }
        let step = Int((max(0, elapsed) / frameDuration).rounded(.down))
        return step % frameCount
    }

    public static func frameURLs(for animation: DogAnimation) -> [URL] {
        let bundle = resourceBundle()
        let prefix = "\(animation.rawValue)-"
        let sequence = (bundle.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? [])
            .filter { url in
                let name = url.deletingPathExtension().lastPathComponent
                return name.hasPrefix(prefix) && Int(name.dropFirst(prefix.count)) != nil
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if !sequence.isEmpty {
            return sequence
        }
        return bundle.url(forResource: fallbackPoseName(for: animation), withExtension: "png").map { [$0] } ?? []
    }

    public static func canonicalReferenceURL() -> URL? {
        resourceBundle().url(forResource: "golden-retriever-puppy-reference", withExtension: "png")
    }

    private static func fallbackPoseName(for animation: DogAnimation) -> String {
        switch animation {
        case .walk, .spin: "walk"
        case .run: "run"
        case .pounce: "jump"
        case .idle, .rest, .bellyUp: "rest"
        case .play, .playBall: "play"
        }
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
