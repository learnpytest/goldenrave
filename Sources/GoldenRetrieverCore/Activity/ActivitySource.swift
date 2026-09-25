import Foundation

public protocol ActivitySource {
    func sample(at date: Date) -> ActivitySample
}
