import Foundation
import XCTest
@testable import GoldenRetrieverApp

final class StoreLocationTests: XCTestCase {
    private var support: URL!
    private let bundle = "com.rachelchen.GoldenRetriever"

    override func setUpWithError() throws {
        support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: support)
    }

    private func write(_ text: String, _ name: String) throws {
        try Data(text.utf8).write(to: support.appendingPathComponent(name))
    }

    private func read(_ url: URL, suffix: String = "") throws -> String {
        String(decoding: try Data(contentsOf: URL(fileURLWithPath: url.path + suffix)), as: UTF8.self)
    }

    func testTheStoreLivesInTheAppsOwnFolder() throws {
        let url = try StoreLocation.prepare(applicationSupport: support, bundleIdentifier: bundle)

        XCTAssertEqual(url, support.appendingPathComponent(bundle).appendingPathComponent("goldenrave.store"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "nothing to copy on a fresh install")
    }

    func testOldStatsAreCopiedWithTheirWriteAheadLogAndKeptInPlace() throws {
        try write("main", "default.store")
        try write("wal", "default.store-wal")
        try write("shm", "default.store-shm")

        let url = try StoreLocation.prepare(applicationSupport: support, bundleIdentifier: bundle)

        XCTAssertEqual(try read(url), "main")
        XCTAssertEqual(try read(url, suffix: "-wal"), "wal")
        XCTAssertEqual(try read(url, suffix: "-shm"), "shm")
        XCTAssertTrue(FileManager.default.fileExists(atPath: support.appendingPathComponent("default.store").path))
    }

    func testAnExistingStoreIsNeverOverwritten() throws {
        try write("old", "default.store")
        let url = try StoreLocation.prepare(applicationSupport: support, bundleIdentifier: bundle)
        try Data("current".utf8).write(to: url)

        _ = try StoreLocation.prepare(applicationSupport: support, bundleIdentifier: bundle)

        XCTAssertEqual(try read(url), "current")
    }

    func testACopyThatFailsLeavesNoStoreSoTheNextLaunchRedoesIt() throws {
        try write("main", "default.store")
        try write("wal", "default.store-wal")
        let failing = FailingSecondCopy()

        XCTAssertThrowsError(try StoreLocation.prepare(applicationSupport: support, bundleIdentifier: bundle, fileManager: failing))
        let target = support.appendingPathComponent(bundle).appendingPathComponent("goldenrave.store")
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path), "the main file must never exist without its log")

        let url = try StoreLocation.prepare(applicationSupport: support, bundleIdentifier: bundle)
        XCTAssertEqual(try read(url), "main")
        XCTAssertEqual(try read(url, suffix: "-wal"), "wal")
    }

    func testClearingDataRemovesTheOldCopyToo() throws {
        try write("main", "default.store")
        try write("wal", "default.store-wal")
        try write("shm", "default.store-shm")

        StoreLocation.removeLegacy(applicationSupport: support)

        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: support.appendingPathComponent(name).path), name)
        }
    }

    func testAHalfFinishedCopyIsRedoneOnTheNextLaunch() throws {
        try write("main", "default.store")
        try write("wal", "default.store-wal")
        let folder = support.appendingPathComponent(bundle)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: folder.appendingPathComponent("goldenrave.store-wal"))

        let url = try StoreLocation.prepare(applicationSupport: support, bundleIdentifier: bundle)

        XCTAssertEqual(try read(url), "main")
        XCTAssertEqual(try read(url, suffix: "-wal"), "wal")
    }
}

/// Fails the second copy, as if the app were stopped between two files.
private final class FailingSecondCopy: FileManager {
    private var copies = 0

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copies += 1
        if copies == 2 { throw CocoaError(.fileWriteUnknown) }
        try super.copyItem(at: srcURL, to: dstURL)
    }
}
