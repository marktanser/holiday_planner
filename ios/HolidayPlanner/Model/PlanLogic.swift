import Foundation

/// A stay with its worked-out dates and cost.
struct StayRow: Identifiable {
    let index: Int
    let stop: Stop
    let arrive: Day
    let depart: Day
    /// Nights before this stay begins.
    let before: Int
    let subtotal: Double
    var id: String { stop.id }
}

/// One line of an exported itinerary: a stay or a single piece of travel.
struct ItineraryItem {
    enum Kind { case stay, travel }
    let kind: Kind
    let start: Day
    let end: Day?
    let type: String
    let place: String
    let nights: Int?
    let details: String
    let rate: Double?
    let cost: Double
    let color: String?
}

extension Plan {
    // MARK: Totals and dates

    var totalNights: Int { stops.reduce(0) { $0 + $1.nights } }
    var tripLength: Int { end - start }

    var rows: [StayRow] {
        var result: [StayRow] = []
        var before = 0
        for i in stops.indices {
            let stop = stops[i]
            let arrive = start.adding(before)
            result.append(StayRow(index: i, stop: stop, arrive: arrive, depart: arrive.adding(stop.nights),
                                  before: before, subtotal: stop.cost * Double(stop.nights)))
            before += stop.nights
        }
        return result
    }

    var stayCost: Double { stops.reduce(0) { $0 + $1.cost * Double($1.nights) } }
    var travelCost: Double {
        stops.reduce(0) { sum, stop in sum + stop.legs.reduce(0) { $0 + $1.cost } }
            + returnLegs.reduce(0) { $0 + $1.cost }
    }
    var totalCost: Double { stayCost + travelCost }

    /// The most nights one stop can have while every other stop keeps at least one.
    var maxNightsPerStop: Int { max(1, totalNights - (stops.count - 1)) }

    func displayName(_ index: Int) -> String {
        guard stops.indices.contains(index) else { return "Untitled" }
        let name = stops[index].name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Untitled" : name
    }

    func money(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "en_GB")
        return currency + (f.string(from: NSNumber(value: value.rounded())) ?? "0")
    }

    // MARK: Changing nights while the dates stay fixed

    /// Grows or shrinks the trip to `newTotal` nights, changing the last stop (or the first, when `atStart`).
    mutating func resizeTotal(to newTotal: Int, atStart: Bool = false) {
        guard !stops.isEmpty else { return }
        var diff = newTotal - totalNights
        var order = Array(stops.indices)
        if !atStart { order.reverse() }
        if diff > 0 { stops[order[0]].nights += diff }
        for j in order where diff < 0 {
            let take = min(-diff, stops[j].nights - 1)
            stops[j].nights -= take
            diff += take
        }
    }

    /// Sets one stop's nights and keeps the trip length fixed. Nights come from (or go to)
    /// the following stops first, nearest first, then the earlier ones.
    mutating func setNights(at index: Int, to wanted: Int) {
        guard stops.indices.contains(index) else { return }
        let n = stops.count
        let want = max(1, min(totalNights - (n - 1), wanted))
        var delta = want - stops[index].nights
        if delta == 0 { return }
        stops[index].nights = want
        var order: [Int] = []
        if index + 1 < n { order += Array((index + 1)..<n) }
        if index > 0 { order += Array((0..<index).reversed()) }
        guard let first = order.first else { return }
        if delta < 0 {
            stops[first].nights -= delta
            return
        }
        for j in order {
            let take = min(delta, stops[j].nights - 1)
            stops[j].nights -= take
            delta -= take
            if delta == 0 { break }
        }
    }

    /// Moves the divider after stop `index` by `delta` nights, starting from the nights the two
    /// neighbours had when the drag began.
    mutating func moveBoundary(after index: Int, from base: (Int, Int), by delta: Int) {
        guard index >= 0, index + 1 < stops.count else { return }
        let (a0, b0) = base
        let d = max(1 - a0, min(b0 - 1, delta))
        stops[index].nights = a0 + d
        stops[index + 1].nights = b0 - d
    }

    // MARK: Changing the dates

    /// The earliest leave date allowed: one night per stop.
    var earliestEnd: Day { start.adding(stops.count) }
    /// The latest arrive date allowed: one night per stop.
    var latestStart: Day { end.adding(-stops.count) }

    mutating func setStart(_ day: Day) {
        let nights = end - day
        guard nights >= stops.count else { return }
        start = day
        resizeTotal(to: nights, atStart: true)
    }

    mutating func setEnd(_ day: Day) {
        let nights = day - start
        guard nights >= stops.count else { return }
        end = day
        resizeTotal(to: nights)
    }

    // MARK: Adding, removing and reordering stops

    func nextColor() -> String {
        let used = Set(stops.map(\.color))
        return Plan.palette.first { !used.contains($0) } ?? Plan.palette[stops.count % Plan.palette.count]
    }

    /// Adds a stop that borrows up to three nights, one at a time from the longest stay.
    /// Returns nil when every stop is already down to one night.
    @discardableResult
    mutating func addStop() -> String? {
        var got = 0
        while got < 3 {
            guard let longest = stops.indices.max(by: { stops[$0].nights < stops[$1].nights }),
                  stops[longest].nights > 1 else { break }
            stops[longest].nights -= 1
            got += 1
        }
        guard got > 0 else { return nil }
        let stop = Stop(name: "", nights: got, color: nextColor())
        stops.append(stop)
        return stop.id
    }

    /// Removes a stop and gives its nights to the stop before it (or after, for the first).
    mutating func removeStop(id: String) {
        guard stops.count > 1, let i = stops.firstIndex(where: { $0.id == id }) else { return }
        let gone = stops.remove(at: i)
        stops[max(0, i - 1)].nights += gone.nights
    }

    mutating func moveStop(id: String, by offset: Int) {
        guard let i = stops.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        guard stops.indices.contains(j) else { return }
        stops.swapAt(i, j)
    }

    // MARK: Tidying a plan from a file

    /// Fills gaps and makes sure the stops exactly fill the dates.
    mutating func normalise() {
        if stops.isEmpty { stops = [Stop(name: "", nights: 1, color: Plan.palette[0])] }
        for i in stops.indices where !Plan.isHexColor(stops[i].color) {
            stops[i].color = nextColor()
        }
        if tripLength < stops.count { end = start.adding(stops.count) }
        if tripLength != totalNights { resizeTotal(to: tripLength) }
    }

    // MARK: Itinerary

    /// Every stay and travel item in date order, for exports.
    var itineraryItems: [ItineraryItem] {
        var items: [ItineraryItem] = []
        func addLegs(_ legs: [Leg], from: String, to: String, on day: Day) {
            for leg in legs {
                items.append(ItineraryItem(kind: .travel, start: day, end: nil, type: leg.mode.label,
                                           place: "\(from) → \(to)", nights: nil, details: leg.details,
                                           rate: nil, cost: leg.cost, color: nil))
            }
        }
        for row in rows {
            addLegs(row.stop.legs, from: row.index == 0 ? "Home" : displayName(row.index - 1),
                    to: displayName(row.index), on: row.arrive)
            items.append(ItineraryItem(kind: .stay, start: row.arrive, end: row.depart, type: "Stay",
                                       place: displayName(row.index), nights: row.stop.nights,
                                       details: row.stop.notes, rate: row.stop.cost, cost: row.subtotal,
                                       color: row.stop.color))
        }
        addLegs(returnLegs, from: displayName(stops.count - 1), to: "Home", on: end)
        return items
    }

    /// Plain text for pasting into a message or note.
    func itineraryText() -> String {
        var lines = [name.isEmpty ? "Holiday" : name]
        var head = "\(start.short) – \(end.short) \(end.year) · \(totalNights) night\(totalNights == 1 ? "" : "s")"
        if totalCost > 0 {
            head += " · \(money(totalCost)) total (\(money(stayCost)) stays, \(money(travelCost)) travel)"
        }
        lines.append(head)
        lines.append("")
        func legLines(_ legs: [Leg], from: String, to: String, on day: Day) {
            guard !legs.isEmpty else { return }
            lines.append("   \(day.short) · \(from) → \(to)")
            for leg in legs {
                var line = "     - \(leg.mode.label)"
                if !leg.details.isEmpty { line += ": \(leg.details)" }
                if leg.cost > 0 { line += " · \(money(leg.cost))" }
                lines.append(line)
            }
        }
        for row in rows {
            legLines(row.stop.legs, from: row.index == 0 ? "Home" : displayName(row.index - 1),
                     to: displayName(row.index), on: row.arrive)
            var line = "\(row.index + 1). \(displayName(row.index)): \(row.arrive.short) → \(row.depart.short)"
            line += " (\(row.stop.nights) night\(row.stop.nights == 1 ? "" : "s"))"
            if row.subtotal > 0 { line += " · \(money(row.subtotal))" }
            lines.append(line)
            if !row.stop.notes.isEmpty { lines.append("   \(row.stop.notes)") }
        }
        legLines(returnLegs, from: displayName(stops.count - 1), to: "Home", on: end)
        return lines.joined(separator: "\n")
    }

    /// A safe file name from the trip name, e.g. "portugal-spain-spring-2027".
    var fileSlug: String {
        let lower = name.lowercased()
        var out = ""
        var lastDash = false
        for ch in lower {
            if ch.isASCII && (ch.isLetter || ch.isNumber) {
                out.append(ch)
                lastDash = false
            } else if !lastDash && !out.isEmpty {
                out.append("-")
                lastDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "holiday-plan" : String(out.prefix(60))
    }
}
