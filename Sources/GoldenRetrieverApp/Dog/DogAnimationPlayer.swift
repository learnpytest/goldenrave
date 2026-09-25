import AppKit
import GoldenRetrieverCore
import SwiftUI

public struct DogAnimationPlayer: Sendable {
    public init() {}

    public func frames(for state: DogState) -> [Image] {
        guard let image = loadImage(for: state) else { return [] }
        return [Image(nsImage: image)]
    }

    public func frameDuration(for state: DogState) -> Duration {
        switch state {
        case .idle:
            .milliseconds(1_400)
        case .walk:
            .milliseconds(240)
        case .run:
            .milliseconds(120)
        case .play:
            .milliseconds(350)
        case .jump:
            .milliseconds(400)
        case .rest:
            .seconds(2)
        }
    }

    public static func resourceURL(for state: DogState) -> URL? {
        resourceBundle().url(
            forResource: resourceName(for: state),
            withExtension: "png"
        )
    }

    public static func canonicalReferenceURL() -> URL? {
        resourceBundle().url(forResource: "golden-retriever-puppy-reference", withExtension: "png")
    }

    private func loadImage(for state: DogState) -> NSImage? {
        guard let url = Self.resourceURL(for: state) else { return nil }
        return NSImage(contentsOf: url)
    }

    private static func resourceName(for state: DogState) -> String {
        switch state {
        case .idle:
            "golden-retriever-puppy-reference"
        case .walk:
            "walk"
        case .run:
            "run"
        case .play:
            "play"
        case .jump:
            "jump"
        case .rest:
            "rest"
        }
    }

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
