import SwiftUI
import UIKit

struct PlanView: View {
    @Binding var document: PlanDocument

    @AppStorage("exportIncludeCosts") private var includeCosts = true
    @State private var sharedFile: SharedFile? = nil
    @State private var message: String? = nil
    @State private var newStopID: String? = nil

    init(document: Binding<PlanDocument>) {
        self._document = document
    }

    private var plan: Plan { document.plan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TripHeader(plan: $document.plan)
                SummaryCard(plan: plan)
                TimelineCard(plan: $document.plan)

                Text("Stays and travel")
                    .font(.title3.bold())
                    .padding(.top, 8)

                ForEach(plan.rows) { row in
                    stayRow(row)
                }

                TravelSection(from: plan.displayName(plan.stops.count - 1),
                              to: "Home",
                              day: plan.end,
                              currency: plan.currency,
                              legs: $document.plan.returnLegs)

                Button(action: addStop) {
                    Label("Add location", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)

                Text("Changes save automatically to this plan's file. Keep plans in iCloud Drive to open them on your other devices or in the web app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { exportMenu }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .sheet(item: $sharedFile) { file in
            ShareSheet(items: [file.url])
                .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .bottom) {
            if let message {
                ToastView(text: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: One stay and the travel that leads to it

    @ViewBuilder
    private func stayRow(_ row: StayRow) -> some View {
        TravelSection(from: row.index == 0 ? "Home" : plan.displayName(row.index - 1),
                      to: plan.displayName(row.index),
                      day: row.arrive,
                      currency: plan.currency,
                      legs: legsBinding(row.stop.id))

        StopCard(number: row.index + 1,
                 stop: stopBinding(row.stop.id),
                 nights: nightsBinding(row.stop.id),
                 arrive: row.arrive,
                 depart: row.depart,
                 maxNights: plan.maxNightsPerStop,
                 currency: plan.currency,
                 subtotal: plan.money(row.subtotal),
                 canMoveUp: row.index > 0,
                 canMoveDown: row.index < plan.stops.count - 1,
                 canRemove: plan.stops.count > 1,
                 focusNameOnAppear: row.stop.id == newStopID,
                 onMove: { offset in
                     withAnimation { document.plan.moveStop(id: row.stop.id, by: offset) }
                 },
                 onRemove: {
                     withAnimation { document.plan.removeStop(id: row.stop.id) }
                 })
    }

    // MARK: Export

    private var exportMenu: some View {
        Menu {
            Toggle("Include costs", isOn: $includeCosts)
            Divider()
            Button { export(.pdf) } label: { Label("PDF document", systemImage: "doc.richtext") }
            Button { export(.excel) } label: { Label("Excel spreadsheet", systemImage: "tablecells") }
            Divider()
            Button(action: copyItinerary) { Label("Copy itinerary", systemImage: "doc.on.doc") }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
    }

    private enum ExportKind { case pdf, excel }

    private func export(_ kind: ExportKind) {
        dismissKeyboard()
        let base = plan.fileSlug + (includeCosts ? "" : "-no-costs")
        do {
            let data: Data
            let ext: String
            switch kind {
            case .pdf:
                data = PDFExporter(plan: plan, includeCosts: includeCosts).render()
                ext = "pdf"
            case .excel:
                data = XLSXExporter(plan: plan, includeCosts: includeCosts).render()
                ext = "xlsx"
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("\(base).\(ext)")
            try data.write(to: url, options: .atomic)
            sharedFile = SharedFile(url: url)
        } catch {
            show("The export couldn't be made. \(error.localizedDescription)")
        }
    }

    private func copyItinerary() {
        UIPasteboard.general.string = plan.itineraryText()
        show("Itinerary copied. Paste it into a message or note.")
    }

    private func addStop() {
        dismissKeyboard()
        var updated = document.plan
        if let id = updated.addStop() {
            withAnimation { document.plan = updated }
            newStopID = id
        } else {
            show("Every stop is down to one night. Move your leave date later to add another location.")
        }
    }

    private func show(_ text: String) {
        withAnimation { message = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            await MainActor.run {
                if message == text { withAnimation { message = nil } }
            }
        }
    }

    // MARK: Bindings by stop id
    // Looking stops up by id (not position) keeps edits safe while stops are added, moved or removed.

    private func stopBinding(_ id: String) -> Binding<Stop> {
        Binding(
            get: { document.plan.stops.first { $0.id == id } ?? Stop(color: Plan.palette[0]) },
            set: { updated in
                guard let i = document.plan.stops.firstIndex(where: { $0.id == id }) else { return }
                // Nights only change through nightsBinding, which keeps the dates fixed.
                var copy = updated
                copy.nights = document.plan.stops[i].nights
                document.plan.stops[i] = copy
            }
        )
    }

    private func nightsBinding(_ id: String) -> Binding<Int> {
        Binding(
            get: { document.plan.stops.first { $0.id == id }?.nights ?? 1 },
            set: { value in
                guard let i = document.plan.stops.firstIndex(where: { $0.id == id }) else { return }
                document.plan.setNights(at: i, to: value)
            }
        )
    }

    private func legsBinding(_ id: String) -> Binding<[Leg]> {
        Binding(
            get: { document.plan.stops.first { $0.id == id }?.legs ?? [] },
            set: { legs in
                guard let i = document.plan.stops.firstIndex(where: { $0.id == id }) else { return }
                document.plan.stops[i].legs = legs
            }
        )
    }
}
