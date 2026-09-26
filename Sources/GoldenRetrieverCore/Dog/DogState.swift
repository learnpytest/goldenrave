public enum DogState: Equatable, CaseIterable, Sendable {
    case idle
    case walk
    case run
    case pounce
    case rest
    /// Reminders are paused: the puppy keeps itself busy quietly.
    case relaxing
}
