public enum TrackingMode: String, Codable, CaseIterable, Hashable, Sendable {
    case privateMode
    case detailed

    public static let defaultMode: TrackingMode = .privateMode
}
