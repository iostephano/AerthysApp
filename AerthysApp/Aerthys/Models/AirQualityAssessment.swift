import Foundation

enum AirQualityAssessment: Equatable {
    case low
    case moderate
    case high

    init(_ referenceClass: AerthysReferenceClass) {
        switch referenceClass {
        case .low: self = .low
        case .moderate: self = .moderate
        case .high: self = .high
        }
    }
}
