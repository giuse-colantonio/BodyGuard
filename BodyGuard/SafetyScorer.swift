import Foundation
import MapKit
import CoreLocation

extension MKPolyline {
    /// Calcola la lunghezza della polyline in metri
    func totalLength() -> CLLocationDistance {
        let pts = self.points()
        let n = self.pointCount
        guard n > 1 else { return 0 }
        var sum: CLLocationDistance = 0
        for i in 0..<(n - 1) {
            let a = pts[i]
            let b = pts[i + 1]
            sum += a.distance(to: b)
        }
        return sum
    }
}

struct SafetyScorer: Sendable {
    let provider: SafetyDataProvider
    let weights: SafetyWeights
    let sampleDistanceMeters: CLLocationDistance

    init(provider: SafetyDataProvider,
         weights: SafetyWeights = SafetyWeights(),
         sampleDistanceMeters: CLLocationDistance = 150) {
        self.provider = provider
        self.weights = weights.normalized
        self.sampleDistanceMeters = max(30, sampleDistanceMeters) // evita passo troppo corto
    }

    // Calcola uno score medio [0,1] per l’intera route: più basso = più sicura
    func score(for route: MKRoute, transport: MKDirectionsTransportType) async -> Double {
        let polyline = route.polyline
        let totalLen = polyline.totalLength()                // <--- usa la nuova funzione
        guard totalLen > 0 else { return 1.0 }

        // Campiona punti lungo la polyline ogni sampleDistanceMeters
        let samples = sampleCoordinates(along: polyline, step: sampleDistanceMeters)
        guard !samples.isEmpty else { return 1.0 }

        let context = SafetyTransportContext(mkTransport: transport)

        // Parallelizza le richieste al provider
        let factors: [SafetyFactors] = await withTaskGroup(of: SafetyFactors.self, returning: [SafetyFactors].self) { group in
            for coord in samples {
                group.addTask {
                    await provider.risk(at: coord, transport: context)
                }
            }
            var arr: [SafetyFactors] = []
            for await f in group { arr.append(f) }
            return arr
        }

        // Media pesata
        let w = weights
        let scores = factors.map { f in
            w.accidents * f.accidents +
            w.lighting  * f.lighting  +
            w.crime     * f.crime     +
            w.weather   * f.weather
        }
        let avg = scores.reduce(0, +) / Double(scores.count)
        return avg
    }

    private func sampleCoordinates(along polyline: MKPolyline, step: CLLocationDistance) -> [CLLocationCoordinate2D] {
        let pts = polyline.points()
        let count = polyline.pointCount
        guard count > 1 else { return [] }

        var coords: [CLLocationCoordinate2D] = []
        var distanceSinceLastSample: CLLocationDistance = 0

        // inizializza con il primo punto
        coords.append(pts[0].coordinate)

        var _: CLLocationDistance = 0

        for i in 0..<(count - 1) {
            let a = pts[i]
            let b = pts[i + 1]
            let segmentLen = a.distance(to: b)
            if segmentLen <= 0 { continue }

            var remainingSegLen = segmentLen
            // posizione base lungo il segmento (in map-point space)
            let startMapPoint = a
            let dx = b.x - a.x
            let dy = b.y - a.y

            // quanti metri servono ancora per arrivare al prossimo sample
            var need = step - distanceSinceLastSample

            // se serve più di questo segmento, accumuliamo e passiamo al prossimo
            if need >= segmentLen {
                distanceSinceLastSample += segmentLen
                continue
            }

            // altrimenti inseriamo uno o più sample in questo segmento
            var traveledInThisSegment: CLLocationDistance = 0
            while need <= remainingSegLen {
                // rapporto t lungo il segmento (0..1)
                let t = (traveledInThisSegment + need) / segmentLen
                let mapX = startMapPoint.x + dx * t
                let mapY = startMapPoint.y + dy * t
                let mp = MKMapPoint(x: mapX, y: mapY)
                coords.append(mp.coordinate)

                // dopo aver piazzato un sample, resettiamo need e aggiorniamo le lunghezze
                traveledInThisSegment += need
                remainingSegLen = segmentLen - traveledInThisSegment
                distanceSinceLastSample = 0
                need = step
            }

            // se non abbiamo raggiunto un sample completo in questo segmento,
            // aumentiamo distanceSinceLastSample con quello che resta del segmento
            distanceSinceLastSample += remainingSegLen
        }

        // assicurati di includere l’ultimo punto
        let last = pts[count - 1].coordinate
        if coords.last?.latitude != last.latitude || coords.last?.longitude != last.longitude {
            coords.append(last)
        }
        return coords
    }
}
