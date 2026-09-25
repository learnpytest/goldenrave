public enum TrackingMode: String, Codable, CaseIterable, Sendable {
    case privateMode
    case detailed

    public static let defaultMode: TrackingMode = .privateMode
}
