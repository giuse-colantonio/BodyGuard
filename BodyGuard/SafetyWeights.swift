import Foundation

struct SafetyWeights: Sendable {
    var accidents: Double = 0.4
    var lighting: Double = 0.25
    var crime: Double = 0.25
    var weather: Double = 0.10

    var normalized: SafetyWeights {
        let sum = accidents + lighting + crime + weather
        guard sum > 0 else { return self }
        return SafetyWeights(
            accidents: accidents / sum,
            lighting: lighting / sum,
            crime: crime / sum,
            weather: weather / sum
        )
    }
}
