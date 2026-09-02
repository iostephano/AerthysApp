import Foundation

enum AerthysReferenceClass: String, CaseIterable, Sendable {
    case low
    case moderate
    case high
}

enum AerthysMatchOutcome: Equatable, Sendable {
    case recognized(AerthysReferenceClass, score: Double)
    case rejected(score: Double)
}
