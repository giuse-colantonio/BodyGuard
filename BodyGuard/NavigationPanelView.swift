import SwiftUI
import MapKit

struct NavigationPanelView: View {
    @EnvironmentObject private var routeManager: RouteManager
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 10) {
            // Header compatto: distanza + durata + orario di arrivo
            header
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        expanded.toggle()
                    }
                }

            // Lista passi solo se espanso
            if expanded {
                stepsList
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pannello navigazione")
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(distanceText(routeManager.distanceRemaining))
                    .font(.title3.weight(.semibold))
                HStack(spacing: 8) {
                    Text(etaDurationText(routeManager.etaRemaining))
                    if let arrival = arrivalTimeText(routeManager.etaRemaining) {
                        Text("• \(arrival)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: expanded ? "chevron.down" : "chevron.up")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(6)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
        }
    }

    private var stepsList: some View {
        Group {
            if routeManager.steps.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Nessun step disponibile")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .font(.subheadline)
                .padding(.top, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(routeManager.steps.enumerated()), id: \.offset) { idx, step in
                            stepRow(index: idx, step: step)
                            if idx < routeManager.steps.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxHeight: 260)
            }
        }
    }

    private func stepRow(index: Int, step: MKRoute.Step) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(step.instructions.isEmpty ? "Prosegui" : step.instructions)
                    .font(.body)
                    .lineLimit(3)
                Text(distanceText(step.distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Formatters
    private func distanceText(_ distance: CLLocationDistance?) -> String {
        guard let d = distance else { return "–" }
        if d < 1000 {
            return "\(Int(d)) m"
        } else {
            let km = d / 1000
            return String(format: "%.1f km", km)
        }
    }

    private func etaDurationText(_ eta: TimeInterval?) -> String {
        guard let t = eta else { return "ETA –" }
        let minutes = Int((t / 60).rounded())
        if minutes < 60 {
            return "ETA \(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "ETA \(hours) h"
            } else {
                return "ETA \(hours) h \(mins) min"
            }
        }
    }

    private func arrivalTimeText(_ eta: TimeInterval?) -> String? {
        guard let t = eta else { return nil }
        let arrivalDate = Date().addingTimeInterval(t)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "Arrivo alle \(formatter.string(from: arrivalDate))"
    }
}
