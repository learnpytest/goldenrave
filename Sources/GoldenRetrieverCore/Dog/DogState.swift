public enum DogState: Equatable, CaseIterable, Sendable {
    case idle
    case walk
    case run
    case pounce
    case rest
    /// The puppy has kept working past the invitation and is visibly out of energy.
    case depleted
    /// Reminders are paused: the puppy keeps itself busy quietly.
    case relaxing
}
