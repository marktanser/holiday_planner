import SwiftUI

/// One stay: its name, dates, nights slider, cost and notes.
struct StopCard: View {
    let number: Int
    @Binding var stop: Stop
    /// Setting this goes through the plan's rebalancing, so the trip length stays fixed.
    @Binding var nights: Int
    let arrive: Day
    let depart: Day
    let maxNights: Int
    let currency: String
    let subtotal: String
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canRemove: Bool
    var focusNameOnAppear = false
    let onMove: (Int) -> Void
    let onRemove: () -> Void

    @FocusState private var nameFocused: Bool

    private var title: String {
        stop.name.trimmingCharacters(in: .whitespaces).isEmpty ? "this stop" : stop.name
    }

    var body: some View {
        let color = Color(hex: stop.color)
        HStack(spacing: 0) {
            color.frame(width: 6)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("\(number)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(color))
                        .accessibilityHidden(true)

                    TextField("Where to?", text: $stop.name)
                        .font(.title3.bold())
                        .focused($nameFocused)
                        .submitLabel(.done)

                    Menu {
                        Button { onMove(-1) } label: { Label("Move earlier", systemImage: "arrow.up") }
                            .disabled(!canMoveUp)
                        Button { onMove(1) } label: { Label("Move later", systemImage: "arrow.down") }
                            .disabled(!canMoveDown)
                        Divider()
                        Button(role: .destructive) { onRemove() } label: { Label("Remove", systemImage: "trash") }
                            .disabled(!canRemove)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Options for \(title)")
                }

                HStack(spacing: 8) {
                    DatePill(arrive.short)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePill(depart.short)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(arrive.short) to \(depart.short)")

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Nights here")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Stepper("\(nights) night\(nights == 1 ? "" : "s")", value: $nights, in: 1...max(maxNights, 1))
                            .fixedSize()
                            .monospacedDigit()
                    }
                    Slider(value: Binding(get: { Double(nights) },
                                          set: { nights = Int($0.rounded()) }),
                           in: 1...Double(max(maxNights, 2)),
                           step: 1)
                        .tint(color)
                        .disabled(maxNights <= 1)
                        .accessibilityLabel("Nights in \(title)")
                        .accessibilityValue("\(nights)")
                }

                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Per night").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        MoneyField(currency: currency, value: $stop.cost)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subtotal").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(subtotal)
                            .font(.body.monospacedDigit())
                            .padding(.vertical, 7)
                    }
                    Spacer(minLength: 0)
                }

                TextField("Notes: hotel, bookings, ideas", text: $stop.notes, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear {
            if focusNameOnAppear { nameFocused = true }
        }
    }
}
