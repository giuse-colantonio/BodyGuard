import Foundation
import CoreLocation
import MapKit

protocol SafetyDataProvider: Sendable {
    // Ritorna un rischio [0,1] per la coordinata (0 = sicuro, 1 = molto rischioso)
    func risk(at coordinate: CLLocationCoordinate2D, transport: SafetyTransportContext) async -> SafetyFactors
}

// Fattori elementari [0,1] ciascuno
struct SafetyFactors: Sendable {
    var accidents: Double
    var lighting: Double
    var crime: Double
    var weather: Double
}

// Contesto del trasporto per modulare i dati (es. a piedi vs auto)
enum SafetyTransportContext: Sendable {
    case automobile
    case walking

    init(mkTransport: MKDirectionsTransportType) {
        if mkTransport.contains(.walking) {
            self = .walking
        } else {
            self = .automobile
        }
    }
}

// Un provider mock che genera rischio coerente ma fittizio in base alle coordinate
final class SafetyDataProviderMock: SafetyDataProvider {
    func risk(at coordinate: CLLocationCoordinate2D, transport: SafetyTransportContext) async -> SafetyFactors {
        // Mock: usa funzioni pseudo-deterministiche su lat/long per creare variazione
        let base = normalizedNoise(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let walkingBoost = (transport == .walking) ? 0.15 : 0.0

        // Simula fattori: incidenti più alti vicino a certe long, illuminazione peggiore a lat dispari, ecc.
        let accidents = clamp(base * 0.6 + perlinish(coordinate.longitude) * 0.4)
        let lighting  = clamp(base * 0.5 + perlinish(coordinate.latitude) * 0.5 + walkingBoost)
        let crime     = clamp(0.3 + base * 0.5 + perlinish(coordinate.latitude + coordinate.longitude) * 0.2)
        let weather   = clamp(0.2 + perlinish(coordinate.latitude * 0.5 - coordinate.longitude * 0.3) * 0.6)

        return SafetyFactors(accidents: accidents, lighting: lighting, crime: crime, weather: weather)
    }

    private func perlinish(_ x: Double) -> Double {
        // semplice rumore smooth tra 0 e 1
        let s = sin(x * 1.7) * 0.5 + 0.5
        let c = cos(x * 0.9) * 0.5 + 0.5
        return clamp((s * 0.6 + c * 0.4))
    }

    private func normalizedNoise(latitude: Double, longitude: Double) -> Double {
        let v = sin(latitude * 0.01) * cos(longitude * 0.01)
        return clamp(v * 0.5 + 0.5)
    }

    private func clamp(_ v: Double) -> Double {
        return min(1.0, max(0.0, v))
    }
}
