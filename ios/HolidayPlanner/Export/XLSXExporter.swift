import Foundation

/// Writes the itinerary as an Excel .xlsx file: one row per stay and travel item in date order,
/// with real dates, cost formulas and totals. The layout matches the web app's export.
struct XLSXExporter {
    let plan: Plan
    let includeCosts: Bool

    init(plan: Plan, includeCosts: Bool) {
        self.plan = plan
        self.includeCosts = includeCosts
    }

    // MARK: Styles

    struct Font: Hashable {
        var bold = false
        var size: Double = 11
        var color = "FF17202C"
    }

    enum Border: Hashable { case none, bottomThin, total }

    struct Style: Hashable {
        var font = Font()
        var fill: String?        // ARGB, e.g. "FF2445C4"
        var border = Border.none
        var numberFormat = 0     // 0 general, 164 date, 165 money
        var horizontal: String?  // left, center, right
        var vertical: String? = "top"
        var wrap = false
    }

    /// Collects every distinct style and hands back its index for the cells.
    final class StyleBook {
        private(set) var fonts: [Font] = [Font()]
        private(set) var fills: [String?] = []
        private(set) var styles: [Style] = [Style(vertical: nil)]
        private var styleIndex: [Style: Int] = [:]

        init() { styleIndex[styles[0]] = 0 }

        func index(_ style: Style) -> Int {
            if let i = styleIndex[style] { return i }
            if !fonts.contains(style.font) { fonts.append(style.font) }
            if let fill = style.fill, !fills.contains(fill) { fills.append(fill) }
            styles.append(style)
            styleIndex[style] = styles.count - 1
            return styles.count - 1
        }

        func fontID(_ font: Font) -> Int { fonts.firstIndex(of: font) ?? 0 }
        /// Fill 0 and 1 are reserved by Excel (none and gray125).
        func fillID(_ fill: String?) -> Int {
            guard let fill, let i = fills.firstIndex(of: fill) else { return 0 }
            return i + 2
        }
    }

    enum Value {
        case text(String)
        case number(Double)
        case formula(String, Double)
        case empty
    }

    struct Cell {
        let column: Int   // 0-based
        let value: Value
        let style: Int
    }

    // MARK: Building the sheet

    func render() -> Data {
        let book = StyleBook()
        let ink = "FF17202C", muted = "FF5A6575", line = "FFD9DEE7", accent = "FF2445C4", white = "FFFFFFFF"

        struct Column { let key: String; let title: String; let width: Double; let align: String }
        var columns = [
            Column(key: "start", title: "Date", width: 17, align: "left"),
            Column(key: "end", title: "Until", width: 17, align: "left"),
            Column(key: "type", title: "Type", width: 16, align: "left"),
            Column(key: "where", title: "Where", width: 30, align: "left"),
            Column(key: "nights", title: "Nights", width: 8, align: "center"),
            Column(key: "details", title: "Details and notes", width: 52, align: "left")
        ]
        if includeCosts {
            columns.append(Column(key: "rate", title: "Per night", width: 13, align: "right"))
            columns.append(Column(key: "cost", title: "Cost", width: 13, align: "right"))
        }
        let lastColumn = letter(columns.count - 1)
        func col(_ key: String) -> Int { columns.firstIndex { $0.key == key } ?? 0 }

        var rows: [Int: [Cell]] = [:]
        var rowHeights: [Int: Double] = [:]
        func put(_ row: Int, _ column: Int, _ value: Value, _ style: Style) {
            rows[row, default: []].append(Cell(column: column, value: value, style: book.index(style)))
        }

        // Title and dates
        put(1, 0, .text(plan.name.isEmpty ? "Holiday" : plan.name), Style(font: Font(bold: true, size: 16), vertical: nil))
        rowHeights[1] = 24
        let s = plan.stops.count
        let subtitle = "\(plan.start.long) to \(plan.end.long) · \(plan.totalNights) night\(plan.totalNights == 1 ? "" : "s") · \(s) location\(s == 1 ? "" : "s")"
        put(2, 0, .text(subtitle), Style(font: Font(color: muted), vertical: nil))

        // Heading row
        for (i, c) in columns.enumerated() {
            put(4, i, .text(c.title), Style(font: Font(bold: true, color: white), fill: accent,
                                            horizontal: c.align, vertical: "center"))
        }
        rowHeights[4] = 20

        // Items
        let items = plan.itineraryItems
        let first = 5
        for (j, item) in items.enumerated() {
            let r = first + j
            let stay = item.kind == .stay
            func style(_ key: String, numberFormat: Int = 0) -> Style {
                Style(font: Font(bold: stay && key == "type", color: stay ? ink : muted),
                      border: .bottomThin, numberFormat: numberFormat,
                      horizontal: columns[col(key)].align, vertical: "top",
                      wrap: key == "details" || key == "where")
            }
            put(r, col("start"), .number(Double(item.start.excelSerial)), style("start", numberFormat: 164))
            if let end = item.end {
                put(r, col("end"), .number(Double(end.excelSerial)), style("end", numberFormat: 164))
            } else {
                put(r, col("end"), .empty, style("end"))
            }
            put(r, col("type"), .text(item.type), style("type"))
            if stay, let hex = item.color {
                let fill = "FF" + hex.dropFirst().uppercased()
                put(r, col("where"), .text(item.place),
                    Style(font: Font(bold: true, color: white), fill: fill, border: .bottomThin,
                          horizontal: "left", vertical: "top", wrap: true))
            } else {
                put(r, col("where"), .text(item.place), style("where"))
            }
            if let nights = item.nights {
                put(r, col("nights"), .number(Double(nights)), style("nights"))
            } else {
                put(r, col("nights"), .empty, style("nights"))
            }
            put(r, col("details"), item.details.isEmpty ? .empty : .text(item.details), style("details"))
            if includeCosts {
                let rateCol = letter(col("rate")), nightsCol = letter(col("nights"))
                if stay {
                    let rate = item.rate ?? 0
                    put(r, col("rate"), .number(rate), style("rate", numberFormat: 165))
                    put(r, col("cost"), .formula("\(nightsCol)\(r)*\(rateCol)\(r)", item.cost), style("cost", numberFormat: 165))
                } else {
                    put(r, col("rate"), .empty, style("rate", numberFormat: 165))
                    put(r, col("cost"), .number(item.cost), style("cost", numberFormat: 165))
                }
            }
        }
        let last = max(first, first + items.count - 1)

        // Totals
        if includeCosts {
            let t = last + 2
            let typeCol = letter(col("type")), costCol = letter(col("cost"))
            let range = "\(costCol)\(first):\(costCol)\(last)"
            let totals: [(String, Value)] = [
                ("Stays", .formula("SUMIF(\(typeCol)\(first):\(typeCol)\(last),\"Stay\",\(range))", plan.stayCost)),
                ("Travel", .formula("SUM(\(range))-\(costCol)\(t)", plan.travelCost)),
                ("Total", .formula("SUM(\(range))", plan.totalCost))
            ]
            for (k, total) in totals.enumerated() {
                let isTotal = total.0 == "Total"
                put(t + k, col("rate"), .text(total.0),
                    Style(font: Font(bold: isTotal), horizontal: "right", vertical: nil))
                put(t + k, col("cost"), total.1,
                    Style(font: Font(bold: isTotal), border: isTotal ? .total : .none,
                          numberFormat: 165, horizontal: "right", vertical: nil))
            }
        }

        // Sheet XML
        var sheetData = ""
        let lastRow = rows.keys.max() ?? 1
        for r in rows.keys.sorted() {
            let cells = (rows[r] ?? []).sorted { $0.column < $1.column }
            var attrs = "r=\"\(r)\""
            if let h = rowHeights[r] { attrs += " ht=\"\(h)\" customHeight=\"1\"" }
            sheetData += "<row \(attrs)>"
            for cell in cells {
                let ref = "\(letter(cell.column))\(r)"
                switch cell.value {
                case .text(let text):
                    sheetData += "<c r=\"\(ref)\" s=\"\(cell.style)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xml(text))</t></is></c>"
                case .number(let n):
                    sheetData += "<c r=\"\(ref)\" s=\"\(cell.style)\"><v>\(number(n))</v></c>"
                case .formula(let f, let cached):
                    sheetData += "<c r=\"\(ref)\" s=\"\(cell.style)\"><f>\(xml(f))</f><v>\(number(cached))</v></c>"
                case .empty:
                    sheetData += "<c r=\"\(ref)\" s=\"\(cell.style)\"/>"
                }
            }
            sheetData += "</row>"
        }

        let colsXML = columns.enumerated().map { i, c in
            "<col min=\"\(i + 1)\" max=\"\(i + 1)\" width=\"\(c.width)\" customWidth=\"1\"/>"
        }.joined()
        let filterRef = "A4:\(lastColumn)\(last)"

        let sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>\
        <dimension ref="A1:\(lastColumn)\(lastRow)"/>\
        <sheetViews><sheetView workbookViewId="0">\
        <pane ySplit="4" topLeftCell="A5" activePane="bottomLeft" state="frozen"/>\
        <selection pane="bottomLeft" activeCell="A5" sqref="A5"/>\
        </sheetView></sheetViews>\
        <sheetFormatPr defaultRowHeight="15"/>\
        <cols>\(colsXML)</cols>\
        <sheetData>\(sheetData)</sheetData>\
        <autoFilter ref="\(filterRef)"/>\
        <mergeCells count="2"><mergeCell ref="A1:\(lastColumn)1"/><mergeCell ref="A2:\(lastColumn)2"/></mergeCells>\
        <pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>\
        <pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>\
        </worksheet>
        """

        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheets><sheet name="Itinerary" sheetId="1" r:id="rId1"/></sheets>\
        <definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">\
        Itinerary!$A$4:$\(lastColumn)$\(last)</definedName></definedNames>\
        <calcPr calcId="0" fullCalcOnLoad="1"/>\
        </workbook>
        """

        var zip = ZipWriter()
        zip.add("[Content_Types].xml", contentTypes)
        zip.add("_rels/.rels", rootRels)
        zip.add("xl/workbook.xml", workbook)
        zip.add("xl/_rels/workbook.xml.rels", workbookRels)
        zip.add("xl/styles.xml", stylesXML(book, line: line))
        zip.add("xl/worksheets/sheet1.xml", sheet)
        return zip.finish()
    }

    // MARK: XML pieces

    func stylesXML(_ book: StyleBook, line: String) -> String {
        let moneyFormat = xml("\"\(plan.currency)\"#,##0.00")
        let fonts = book.fonts.map { f in
            "<font>\(f.bold ? "<b/>" : "")<sz val=\"\(number(f.size))\"/><color rgb=\"\(f.color)\"/><name val=\"Calibri\"/><family val=\"2\"/></font>"
        }.joined()
        let fills = "<fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill>"
            + book.fills.compactMap { $0 }.map {
                "<fill><patternFill patternType=\"solid\"><fgColor rgb=\"\($0)\"/><bgColor indexed=\"64\"/></patternFill></fill>"
            }.joined()
        let borders = "<border><left/><right/><top/><bottom/><diagonal/></border>"
            + "<border><left/><right/><top/><bottom style=\"thin\"><color rgb=\"\(line)\"/></bottom><diagonal/></border>"
            + "<border><left/><right/><top style=\"thin\"><color rgb=\"FF17202C\"/></top><bottom style=\"double\"><color rgb=\"FF17202C\"/></bottom><diagonal/></border>"
        let xfs = book.styles.map { s -> String in
            let border: Int
            switch s.border {
            case .none: border = 0
            case .bottomThin: border = 1
            case .total: border = 2
            }
            var attrs = "numFmtId=\"\(s.numberFormat)\" fontId=\"\(book.fontID(s.font))\" fillId=\"\(book.fillID(s.fill))\" borderId=\"\(border)\" xfId=\"0\""
            if s.numberFormat != 0 { attrs += " applyNumberFormat=\"1\"" }
            if s.font != Font() { attrs += " applyFont=\"1\"" }
            if s.fill != nil { attrs += " applyFill=\"1\"" }
            if border != 0 { attrs += " applyBorder=\"1\"" }
            var alignment = ""
            if s.horizontal != nil || s.vertical != nil || s.wrap {
                attrs += " applyAlignment=\"1\""
                alignment = "<alignment"
                if let h = s.horizontal { alignment += " horizontal=\"\(h)\"" }
                if let v = s.vertical { alignment += " vertical=\"\(v)\"" }
                if s.wrap { alignment += " wrapText=\"1\"" }
                alignment += "/>"
            }
            return alignment.isEmpty ? "<xf \(attrs)/>" : "<xf \(attrs)>\(alignment)</xf>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <numFmts count="2"><numFmt numFmtId="164" formatCode="ddd d mmm yyyy"/><numFmt numFmtId="165" formatCode="\(moneyFormat)"/></numFmts>\
        <fonts count="\(book.fonts.count)">\(fonts)</fonts>\
        <fills count="\(book.fills.count + 2)">\(fills)</fills>\
        <borders count="3">\(borders)</borders>\
        <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>\
        <cellXfs count="\(book.styles.count)">\(xfs)</cellXfs>\
        <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>\
        </styleSheet>
        """
    }

    private let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
    <Default Extension="xml" ContentType="application/xml"/>\
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
    <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\
    </Types>
    """

    private let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
    </Relationships>
    """

    private let workbookRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\
    </Relationships>
    """

    // MARK: Helpers

    private func letter(_ column: Int) -> String {
        String(Character(UnicodeScalar(UInt8(65 + column))))
    }

    private func number(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 { return String(Int(value)) }
        return String(format: "%.2f", value)
    }

    private func xml(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "\n", "\t": out.unicodeScalars.append(scalar)
            default:
                // XML 1.0 can't hold other control characters.
                if scalar.value >= 0x20 { out.unicodeScalars.append(scalar) }
            }
        }
        return out
    }
}
