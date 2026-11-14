import Foundation

// The data model matches the web app's saved .json files, so the same plan opens in both.

enum TravelMode: String, CaseIterable, Identifiable, Codable {
    case flight, train, car, drive, bus, ferry, transfer, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flight: return "Flight"
        case .train: return "Train"
        case .car: return "Hire car"
        case .drive: return "Own car"
        case .bus: return "Coach or bus"
        case .ferry: return "Ferry"
        case .transfer: return "Taxi or transfer"
        case .other: return "Other"
        }
    }

    /// Used on the timeline, where space is tight.
    var short: String {
        switch self {
        case .flight: return "Flight"
        case .train: return "Train"
        case .car: return "Hire car"
        case .drive: return "Car"
        case .bus: return "Bus"
        case .ferry: return "Ferry"
        case .transfer: return "Taxi"
        case .other: return "Other"
        }
    }

    var placeholder: String {
        switch self {
        case .flight: return "Flight number, times, e.g. TP1351 07:05 LGW → LIS"
        case .train: return "Service, times, seats"
        case .car: return "Pick-up and drop-off, company, booking ref"
        case .drive: return "Route, rough driving time"
        case .bus: return "Operator, times"
        case .ferry: return "Crossing, times, booking ref"
        case .transfer: return "Pick-up time, company"
        case .other: return "Details"
        }
    }

    var symbol: String {
        switch self {
        case .flight: return "airplane"
        case .train: return "tram.fill"
        case .car: return "car.2.fill"
        case .drive: return "car.fill"
        case .bus: return "bus.fill"
        case .ferry: return "ferry.fill"
        case .transfer: return "car.side.fill"
        case .other: return "ellipsis.circle"
        }
    }
}

/// One piece of travel, such as a flight or a taxi.
struct Leg: Identifiable, Hashable, Codable {
    var id: String = Plan.newID()
    var mode: TravelMode = .flight
    var details: String = ""
    var cost: Double = 0

    init(mode: TravelMode = .flight, details: String = "", cost: Double = 0) {
        self.mode = mode
        self.details = details
        self.cost = cost
    }

    enum CodingKeys: String, CodingKey { case id, mode, details, cost }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = Plan.validID((try? c.decodeIfPresent(String.self, forKey: .id)) ?? nil)
        let raw = (try? c.decodeIfPresent(String.self, forKey: .mode)) ?? nil
        mode = raw.flatMap(TravelMode.init(rawValue:)) ?? .other
        details = ((try? c.decodeIfPresent(String.self, forKey: .details)) ?? nil) ?? ""
        cost = max(0, Plan.decodeNumber(c, .cost) ?? 0)
    }
}

/// A place you stay, with the travel that gets you there.
struct Stop: Identifiable, Hashable, Codable {
    var id: String = Plan.newID()
    var name: String = ""
    var nights: Int = 1
    var cost: Double = 0
    var notes: String = ""
    var color: String = Plan.palette[0]
    /// Travel from the previous stop (or from home, for the first stop) to here.
    var legs: [Leg] = []

    init(name: String = "", nights: Int = 1, cost: Double = 0, notes: String = "", color: String, legs: [Leg] = []) {
        self.name = name
        self.nights = nights
        self.cost = cost
        self.notes = notes
        self.color = color
        self.legs = legs
    }

    enum CodingKeys: String, CodingKey { case id, name, nights, cost, notes, color, legs, travel }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = Plan.validID((try? c.decodeIfPresent(String.self, forKey: .id)) ?? nil)
        name = ((try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil) ?? ""
        nights = max(1, Int((Plan.decodeNumber(c, .nights) ?? 1).rounded()))
        cost = max(0, Plan.decodeNumber(c, .cost) ?? 0)
        notes = ((try? c.decodeIfPresent(String.self, forKey: .notes)) ?? nil) ?? ""
        let hex = ((try? c.decodeIfPresent(String.self, forKey: .color)) ?? nil) ?? ""
        color = Plan.isHexColor(hex) ? hex : ""
        if let list = (try? c.decodeIfPresent([Leg].self, forKey: .legs)) ?? nil {
            legs = list
        } else if let single = (try? c.decodeIfPresent(Leg.self, forKey: .travel)) ?? nil {
            legs = [single] // older web app files kept one travel item per stop
        } else {
            legs = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(nights, forKey: .nights)
        try c.encode(cost, forKey: .cost)
        try c.encode(notes, forKey: .notes)
        try c.encode(color, forKey: .color)
        try c.encode(legs, forKey: .legs)
    }
}

struct Plan: Hashable, Codable {
    var name: String = "My holiday"
    var start: Day = Day.today.adding(30)
    var end: Day = Day.today.adding(37)
    var currency: String = "£"
    var stops: [Stop] = []
    /// Travel from the last stop back home.
    var returnLegs: [Leg] = []

    static let currencies = ["£", "€", "$"]
    static let palette = ["#2f6bd8", "#d9622b", "#16927f", "#b8418f", "#b88a0e",
                          "#6a55cc", "#3b8f3b", "#cc3f4a", "#2a8fb0", "#8a6a4a"]

    init() {}

    enum CodingKeys: String, CodingKey { case name, start, end, currency, stops, returnLegs, returnTravel }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = ((try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil) ?? "My holiday"
        let startText = ((try? c.decodeIfPresent(String.self, forKey: .start)) ?? nil) ?? ""
        let endText = ((try? c.decodeIfPresent(String.self, forKey: .end)) ?? nil) ?? ""
        let cur = ((try? c.decodeIfPresent(String.self, forKey: .currency)) ?? nil) ?? "£"
        currency = Plan.currencies.contains(cur) ? cur : "£"
        stops = try c.decode([Stop].self, forKey: .stops)
        start = Day(iso: startText) ?? Day.today
        // Older files had no leave date: work it out from the nights.
        end = Day(iso: endText) ?? start.adding(stops.reduce(0) { $0 + $1.nights })
        if let list = (try? c.decodeIfPresent([Leg].self, forKey: .returnLegs)) ?? nil {
            returnLegs = list
        } else if let single = (try? c.decodeIfPresent(Leg.self, forKey: .returnTravel)) ?? nil {
            returnLegs = [single]
        }
        normalise()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(start.iso, forKey: .start)
        try c.encode(end.iso, forKey: .end)
        try c.encode(currency, forKey: .currency)
        try c.encode(stops, forKey: .stops)
        try c.encode(returnLegs, forKey: .returnLegs)
    }

    // MARK: Helpers used while decoding

    static func newID() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<7).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }

    static func validID(_ value: String?) -> String {
        guard let value, !value.isEmpty, value.count <= 20,
              value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) })
        else { return newID() }
        return value
    }

    static func isHexColor(_ value: String) -> Bool {
        guard value.count == 7, value.first == "#" else { return false }
        return value.dropFirst().allSatisfy { $0.isHexDigit }
    }

    /// Numbers in the web app's files may be whole or decimal.
    static func decodeNumber<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }
}

// MARK: - Saved file format

/// The wrapper the web app writes: { app, version, savedAt, plan }.
private struct PlanFile: Codable {
    var app: String = "holiday-planner"
    var version: Int = 2
    var savedAt: String
    var plan: Plan
}

private struct PlanFileProbe: Decodable {
    let plan: Plan?
}

enum PlanFileError: LocalizedError {
    case notAPlan
    var errorDescription: String? { "This file doesn't contain a holiday plan." }
}

extension Plan {
    static func decodeFile(_ data: Data) throws -> Plan {
        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(PlanFileProbe.self, from: data), let plan = wrapped.plan {
            return plan
        }
        // Very early web app files were the plan on its own.
        if let plan = try? decoder.decode(Plan.self, from: data) {
            return plan
        }
        throw PlanFileError.notAPlan
    }

    func encodeFile() throws -> Data {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(PlanFile(savedAt: stamp, plan: self))
    }
}

// MARK: - Starting plans

extension Plan {
    /// What a new document starts with: one stop filling a week, a month from now.
    static var starter: Plan {
        var plan = Plan()
        plan.name = "New holiday"
        plan.start = Day.today.adding(30)
        plan.end = plan.start.adding(7)
        plan.stops = [Stop(name: "", nights: 7, color: palette[0])]
        return plan
    }

    static var example: Plan {
        var plan = Plan()
        plan.name = "Portugal & Spain, spring 2027"
        plan.start = Day(iso: "2027-05-15") ?? Day.today
        plan.end = plan.start.adding(13)
        plan.returnLegs = [Leg(mode: .transfer, details: "Metro to Barajas T4", cost: 5),
                           Leg(mode: .flight, details: "MAD → LGW, evening", cost: 110)]
        plan.stops = [
            Stop(name: "Lisbon", nights: 4, cost: 140, notes: "Alfama, Belém, day trip to Sintra", color: palette[0],
                 legs: [Leg(mode: .train, details: "Gatwick Express to the airport", cost: 22),
                        Leg(mode: .flight, details: "LGW → LIS, morning", cost: 120)]),
            Stop(name: "Porto", nights: 3, cost: 115, notes: "Port lodges in Gaia", color: palette[1],
                 legs: [Leg(mode: .train, details: "Alfa Pendular from Santa Apolónia, about 3 hours", cost: 35)]),
            Stop(name: "Douro Valley", nights: 2, cost: 180, notes: "Quinta stay, river cruise", color: palette[2],
                 legs: [Leg(mode: .car, details: "Pick up in Porto, return at Porto airport", cost: 160)]),
            Stop(name: "Madrid", nights: 4, cost: 150, notes: "Prado, Retiro Park", color: palette[3],
                 legs: [Leg(mode: .flight, details: "OPO → MAD", cost: 90),
                        Leg(mode: .transfer, details: "Taxi to the hotel", cost: 30)])
        ]
        return plan
    }
}
