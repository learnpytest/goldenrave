import Foundation
import GoldenRetrieverCore

/// Where goldenrave keeps its statistics: its own folder in Application
/// Support, not the shared `default.store` SwiftData picks for any
/// unsandboxed app, which another app could open too.
enum StoreLocation {
    static let fileName = "goldenrave.store"
    static let legacyFileName = "default.store"
    /// SQLite keeps recent writes in -wal until a checkpoint, so all three
    /// files move together or the newest statistics are lost.
    static let sidecarSuffixes = ["-wal", "-shm"]

    static var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    /// Returns the store URL, first copying stats from the old location when
    /// the new one has none. The old files stay until 清除本機資料.
    static func prepare(
        applicationSupport: URL,
        bundleIdentifier: String = AppIdentity.bundleIdentifier,
        fileManager: FileManager = .default
    ) throws -> URL {
        let folder = applicationSupport.appendingPathComponent(bundleIdentifier, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(fileName)
        let legacy = applicationSupport.appendingPathComponent(legacyFileName)
        guard !fileManager.fileExists(atPath: target.path), fileManager.fileExists(atPath: legacy.path) else {
            return target
        }
        for suffix in sidecarSuffixes {
            let destination = URL(fileURLWithPath: target.path + suffix)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            let source = URL(fileURLWithPath: legacy.path + suffix)
            if fileManager.fileExists(atPath: source.path) {
                try fileManager.copyItem(at: source, to: destination)
            }
        }
        // The main file appears last and in one step, so a copy that stops
        // anywhere leaves no store here and the next launch starts over.
        let partial = URL(fileURLWithPath: target.path + ".partial")
        if fileManager.fileExists(atPath: partial.path) {
            try fileManager.removeItem(at: partial)
        }
        try fileManager.copyItem(at: legacy, to: partial)
        try fileManager.moveItem(at: partial, to: target)
        return target
    }

    /// 清除本機資料 also removes the copy left at the old location.
    static func removeLegacy(applicationSupport: URL, fileManager: FileManager = .default) {
        let legacy = applicationSupport.appendingPathComponent(legacyFileName)
        for suffix in [""] + sidecarSuffixes {
            try? fileManager.removeItem(at: URL(fileURLWithPath: legacy.path + suffix))
        }
    }
}
