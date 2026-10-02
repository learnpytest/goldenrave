import Foundation

public enum UpdateInstallError: LocalizedError, Equatable, Sendable {
    case noDownload
    case unexpectedResponse
    case appLocationNotWritable
    case couldNotStartHelper

    public var errorDescription: String? {
        switch self {
        case .noDownload:
            return "找不到可下載的更新檔"
        case .unexpectedResponse:
            return "更新檔下載失敗"
        case .appLocationNotWritable:
            return "目前 app 所在的位置無法寫入，請先把它放進「應用程式」"
        case .couldNotStartHelper:
            return "無法啟動更新程序"
        }
    }
}

/// Downloads and stages a release DMG, then lets a separate process replace the
/// running app after it exits. The helper verifies the app before replacement.
public struct UpdateInstaller: Sendable {
    public static let expectedBundleIdentifier = "com.rachelchen.GoldenRetriever"

    public init() {}

    public func install(
        downloadURL: URL?,
        appURL: URL,
        expectedVersion: String,
        parentProcessID: Int32 = ProcessInfo.processInfo.processIdentifier
    ) async throws {
        guard let downloadURL else { throw UpdateInstallError.noDownload }
        guard downloadURL.scheme?.lowercased() == "https",
              FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path) else {
            throw UpdateInstallError.appLocationNotWritable
        }
        var request = URLRequest(url: downloadURL, timeoutInterval: 120)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw UpdateInstallError.unexpectedResponse
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
        let downloadPath = temporaryDirectory.appendingPathComponent("goldenrave-update-\(UUID().uuidString).dmg")
        let helperPath = temporaryDirectory.appendingPathComponent("goldenrave-update-\(UUID().uuidString).sh")
        try FileManager.default.moveItem(at: temporaryURL, to: downloadPath)
        try Self.helperScript.write(to: helperPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helperPath.path)

        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/bash")
        helper.arguments = [helperPath.path, downloadPath.path, appURL.path, expectedVersion, String(parentProcessID)]
        helper.standardInput = FileHandle.nullDevice
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice
        do {
            try helper.run()
        } catch {
            try? FileManager.default.removeItem(at: downloadPath)
            try? FileManager.default.removeItem(at: helperPath)
            throw UpdateInstallError.couldNotStartHelper
        }
    }

    private static let helperScript = """
    #!/bin/bash
    set -euo pipefail

    DMG_PATH="$1"
    TARGET_APP="$2"
    EXPECTED_VERSION="$3"
    PARENT_PID="$4"
    MOUNT_DIR="$(mktemp -d -t goldenrave-update)"
    STAGED_APP="${TARGET_APP}.new-${PARENT_PID}"
    BACKUP_APP="${TARGET_APP}.before-update-${PARENT_PID}"

    cleanup() {
        /usr/bin/hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
        /bin/rm -rf "$MOUNT_DIR" "$STAGED_APP" "$DMG_PATH" "$0"
    }
    trap cleanup EXIT

    while /bin/kill -0 "$PARENT_PID" 2>/dev/null; do
        /bin/sleep 0.25
    done

    /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_DIR" "$DMG_PATH" >/dev/null
    SOURCE_APP="$MOUNT_DIR/goldenrave.app"
    test -d "$SOURCE_APP"
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/Info.plist")
    test "$BUNDLE_ID" = "\(Self.expectedBundleIdentifier)"
    BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_APP/Contents/Info.plist")
    test "$BUNDLE_VERSION" = "$EXPECTED_VERSION"
    /usr/bin/codesign --verify --deep --strict "$SOURCE_APP"
    /usr/bin/ditto "$SOURCE_APP" "$STAGED_APP"
    /usr/bin/codesign --verify --deep --strict "$STAGED_APP"

    /bin/mv "$TARGET_APP" "$BACKUP_APP"
    if ! /bin/mv "$STAGED_APP" "$TARGET_APP"; then
        /bin/mv "$BACKUP_APP" "$TARGET_APP"
        exit 1
    fi
    /bin/rm -rf "$BACKUP_APP"
    /usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" || true
    /usr/bin/open "$TARGET_APP"
    """
}
