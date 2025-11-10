import MapKit

enum TransportUI: String, CaseIterable, Hashable {
    case automobile
    case walking

    var label: String {
        switch self {
        case .automobile: return "Car"
        case .walking: return "On foot"
        }
    }

    var mkType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        }
    }

    var iconName: String {
        switch self {
        case .automobile: return "car.fill"
        case .walking: return "figure.walk"
        }
    }
}
