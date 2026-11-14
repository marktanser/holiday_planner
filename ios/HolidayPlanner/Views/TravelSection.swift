import SwiftUI

/// The travel between two stays (or from or to home). Holds any number of items,
/// for example a taxi to the airport, then a flight, then a hire car.
struct TravelSection: View {
    let from: String
    let to: String
    let day: Day
    let currency: String
    @Binding var legs: [Leg]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DashedLine()
                .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("\(from) → \(to)")
                        .font(.subheadline.weight(.semibold))
                    Text(day.short)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                ForEach(legs) { leg in
                    LegRow(leg: binding(for: leg), currency: currency) {
                        withAnimation { legs.removeAll { $0.id == leg.id } }
                    }
                }

                Button {
                    withAnimation { legs.append(Leg(mode: legs.isEmpty ? .flight : .transfer)) }
                } label: {
                    Label(legs.isEmpty ? "Add travel" : "Add another travel item", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Travel from \(from) to \(to)")
            }
            .padding(.vertical, 4)
        }
        .padding(.leading, 16)
    }

    /// Looks items up by id, so removing one never leaves a stale index behind.
    private func binding(for leg: Leg) -> Binding<Leg> {
        Binding(
            get: { legs.first { $0.id == leg.id } ?? leg },
            set: { updated in
                if let i = legs.firstIndex(where: { $0.id == leg.id }) { legs[i] = updated }
            }
        )
    }
}

struct LegRow: View {
    @Binding var leg: Leg
    let currency: String
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Picker("How", selection: $leg.mode) {
                        ForEach(TravelMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.symbol).tag(mode)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Label(leg.mode.label, systemImage: leg.mode.symbol)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                }
                .accessibilityLabel("Travel type, \(leg.mode.label)")

                Spacer(minLength: 0)

                MoneyField(currency: currency, value: $leg.cost, width: 64)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(leg.mode.label.lowercased())")
            }

            TextField(leg.mode.placeholder, text: $leg.details, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
