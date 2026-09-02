import Foundation

enum AerthysMatchDecision {

    static let calibratedThreshold: Double = 18.379

    static let voteK = 5

    static let rejectScoreNearest = 3

    static func decide(
        distances: [(label: AerthysReferenceClass, distance: Double)],
        threshold: Double = calibratedThreshold,
        k: Int = voteK,
        nearestForScore: Int = rejectScoreNearest
    ) -> AerthysMatchOutcome {
        precondition(!distances.isEmpty, "AerthysMatchDecision needs at least one reference distance")

        let sorted = distances.sorted { $0.distance < $1.distance }
        let top = Array(sorted.prefix(k))

        var votes: [AerthysReferenceClass: Int] = [:]
        for entry in top { votes[entry.label, default: 0] += 1 }
        let voted = AerthysReferenceClass.allCases
            .max { (votes[$0] ?? 0) < (votes[$1] ?? 0) }!

        let votedDistances = sorted.filter { $0.label == voted }.map(\.distance)
        let n = min(nearestForScore, votedDistances.count)
        let score = n == 0 ? Double.infinity : votedDistances.prefix(n).reduce(0, +) / Double(n)

        return score <= threshold ? .recognized(voted, score: score) : .rejected(score: score)
    }
}
