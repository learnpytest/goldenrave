import Foundation
import GoldenRetrieverCore

public struct AvailableUpdate: Equatable, Sendable {
    public let version: String
    public let pageURL: URL
    public let downloadURL: URL?

    public init(version: String, pageURL: URL, downloadURL: URL? = nil) {
        self.version = version
        self.pageURL = pageURL
        self.downloadURL = downloadURL
    }
}

/// Asks GitHub for the latest published release and reports it when it is
/// newer than the running app.
public struct UpdateChecker: Sendable {
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/learnpytest/goldenrave/releases/latest")!
    /// Checked at launch, then at most once a day, plus whenever settings open.
    public static let interval: TimeInterval = 24 * 60 * 60

    public let currentVersion: String

    public init(currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0") {
        self.currentVersion = currentVersion
    }

    public func check() async -> AvailableUpdate? {
        var request = URLRequest(url: Self.latestReleaseURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return Self.update(fromLatestRelease: data, currentVersion: currentVersion)
    }

    static func update(fromLatestRelease data: Data, currentVersion: String) -> AvailableUpdate? {
        struct Release: Decodable {
            let tag_name: String
            let html_url: URL
            let assets: [Asset]?
        }
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }
        guard let release = try? JSONDecoder().decode(Release.self, from: data),
              AppVersion.isUpdate(latestTag: release.tag_name, current: currentVersion) else { return nil }
        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        let downloadURL = release.assets?.first(where: { $0.name == "goldenrave.dmg" })?.browserDownloadURL
        return AvailableUpdate(version: version, pageURL: release.html_url, downloadURL: downloadURL)
    }
}
