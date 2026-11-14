import Foundation

/// A calendar day with no time of day or time zone, stored as whole days since 1 January 1970.
/// Plans only ever deal in nights, so keeping days as integers avoids daylight-saving surprises.
struct Day: Hashable, Comparable {
    var index: Int

    init(index: Int) {
        self.index = index
    }

    /// Reads "yyyy-MM-dd", the format the web app saves.
    init?(iso: String) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = Day.utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return nil }
        index = Int((date.timeIntervalSince1970 / 86_400).rounded())
    }

    /// The calendar day a date picker shows, whatever the device's time zone.
    init(localDate: Date) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: localDate)
        let date = Day.utc.date(from: DateComponents(year: c.year, month: c.month, day: c.day)) ?? localDate
        index = Int((date.timeIntervalSince1970 / 86_400).rounded())
    }

    static var today: Day { Day(localDate: Date()) }

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }()

    /// Midnight UTC on this day. Use only with the UTC formatters below.
    var utcDate: Date { Date(timeIntervalSince1970: TimeInterval(index) * 86_400) }

    /// Midday on this day in the device's time zone, for date pickers.
    var localDate: Date {
        let c = Day.utc.dateComponents([.year, .month, .day], from: utcDate)
        var local = DateComponents(year: c.year, month: c.month, day: c.day)
        local.hour = 12
        return Calendar.current.date(from: local) ?? utcDate
    }

    var iso: String {
        let c = Day.utc.dateComponents([.year, .month, .day], from: utcDate)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    /// 1 is Sunday, 2 is Monday, and so on.
    var weekday: Int { Day.utc.component(.weekday, from: utcDate) }
    var dayOfMonth: Int { Day.utc.component(.day, from: utcDate) }
    var year: Int { Day.utc.component(.year, from: utcDate) }

    /// Excel stores dates as days since 30 December 1899.
    var excelSerial: Int { index + 25_569 }

    func adding(_ days: Int) -> Day { Day(index: index + days) }

    static func - (lhs: Day, rhs: Day) -> Int { lhs.index - rhs.index }
    static func < (lhs: Day, rhs: Day) -> Bool { lhs.index < rhs.index }

    // MARK: Formatting (British English, as in the web app)

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }
    private static let shortFormatter = formatter("EEE d MMM")
    private static let longFormatter = formatter("d MMM yyyy")
    private static let dayMonthFormatter = formatter("d MMM")
    private static let monthFormatter = formatter("MMM yyyy")

    /// "Sat 15 May"
    var short: String { Day.shortFormatter.string(from: utcDate) }
    /// "15 May 2027"
    var long: String { Day.longFormatter.string(from: utcDate) }
    /// "15 May"
    var dayMonth: String { Day.dayMonthFormatter.string(from: utcDate) }
    /// "May 2027"
    var monthYear: String { Day.monthFormatter.string(from: utcDate) }
}
