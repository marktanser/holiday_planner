import SwiftUI

/// Trip name, the fixed arrive and leave dates, and the currency.
struct TripHeader: View {
    @Binding var plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Trip name", text: $plan.name)
                .font(.title2.bold())
                .submitLabel(.done)

            Divider()

            DatePicker("Arrive",
                       selection: Binding(get: { plan.start.localDate },
                                          set: { plan.setStart(Day(localDate: $0)) }),
                       in: ...plan.latestStart.localDate,
                       displayedComponents: .date)

            DatePicker("Leave",
                       selection: Binding(get: { plan.end.localDate },
                                          set: { plan.setEnd(Day(localDate: $0)) }),
                       in: plan.earliestEnd.localDate...,
                       displayedComponents: .date)

            Text("Your arrive and leave dates are fixed. Changing a stay moves nights to or from the others.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Currency", selection: $plan.currency) {
                ForEach(Plan.currencies, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .card()
    }
}

/// Dates, nights, locations and cost at a glance.
struct SummaryCard: View {
    let plan: Plan

    private var countdown: String {
        let until = plan.start - Day.today
        if until > 0 { return "Starts in \(until) day\(until == 1 ? "" : "s")" }
        return plan.end - Day.today > 0 ? "Under way" : "Finished"
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .topLeading)],
                  alignment: .leading, spacing: 14) {
            stat("Dates", "\(plan.start.dayMonth) → \(plan.end.long)", countdown)
            stat("Nights", "\(plan.totalNights)", "Fixed by your dates")
            stat("Locations", "\(plan.stops.count)",
                 String(format: "About %.1f nights each", Double(plan.totalNights) / Double(max(plan.stops.count, 1))))
            stat("Total cost", plan.money(plan.totalCost),
                 "\(plan.money(plan.stayCost)) stays · \(plan.money(plan.travelCost)) travel")
        }
        .card()
    }

    private func stat(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
