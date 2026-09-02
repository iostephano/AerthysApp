import Foundation

enum AerthysMatcherError: Error, Equatable {
    case referencesNotFound
    case noReferencePrints
    case featurePrintFailed
    case visionFailed(String)
    case deallocated
}
