import UIKit

/// Draws an A4 itinerary: header, summary boxes, timeline bar, a table of every stay and
/// travel item in date order, and totals. Long trips continue onto more pages.
struct PDFExporter {
    let plan: Plan
    let includeCosts: Bool

    init(plan: Plan, includeCosts: Bool) {
        self.plan = plan
        self.includeCosts = includeCosts
    }

    // A4 in points
    private let pageW: CGFloat = 595.28
    private let pageH: CGFloat = 841.89
    private let margin: CGFloat = 40
    private let tableTopFirst: CGFloat = 250
    private let tableTopOther: CGFloat = 46
    private let tableBottom: CGFloat = 841.89 - 52
    private let headRowHeight: CGFloat = 22

    private let ink = UIColor(hex: "#17202c")
    private let muted = UIColor(hex: "#5a6575")
    private let line = UIColor(hex: "#d9dee7")
    private let accent = UIColor(hex: "#2445c4")
    private let field = UIColor(hex: "#f5f7fa")

    private struct Row {
        let kind: ItineraryItem.Kind
        let cells: [String]
        let color: String?
        var height: CGFloat = 0
    }

    private struct Column {
        let title: String
        let width: CGFloat
        let align: NSTextAlignment
    }

    // MARK: Layout

    private var columns: [Column] {
        var fixed: [Column] = [
            Column(title: "Date", width: 85, align: .left),
            Column(title: "Type", width: 68, align: .left),
            Column(title: "Where", width: 108, align: .left)
        ]
        let nights = Column(title: "Nights", width: 40, align: .center)
        let cost = Column(title: "Cost", width: 74, align: .right)
        let used = fixed.reduce(0) { $0 + $1.width } + nights.width + (includeCosts ? cost.width : 0)
        fixed.append(Column(title: "Details and notes", width: pageW - 2 * margin - used, align: .left))
        fixed.append(nights)
        if includeCosts { fixed.append(cost) }
        return fixed
    }

    private func padding(column: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: 6.8, left: column == 0 ? 11.3 : 5.7, bottom: 6.8, right: 5.7)
    }

    private func cellFont(_ row: Row, column: Int) -> UIFont {
        if row.kind == .travel { return .systemFont(ofSize: 8.5) }
        return .systemFont(ofSize: 9, weight: (column == 1 || column == 2) ? .semibold : .regular)
    }

    private func attributes(_ font: UIFont, _ color: UIColor, align: NSTextAlignment = .left,
                            truncate: Bool = false) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        style.lineBreakMode = truncate ? .byTruncatingTail : .byWordWrapping
        return [.font: font, .foregroundColor: color, .paragraphStyle: style]
    }

    private func textHeight(_ text: String, width: CGFloat, _ attrs: [NSAttributedString.Key: Any]) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let rect = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                   options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                   attributes: attrs, context: nil)
        return ceil(rect.height)
    }

    private func textWidth(_ text: String, _ attrs: [NSAttributedString.Key: Any]) -> CGFloat {
        ceil((text as NSString).size(withAttributes: attrs).width)
    }

    private func draw(_ text: String, in rect: CGRect, _ attrs: [NSAttributedString.Key: Any]) {
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                attributes: attrs, context: nil)
    }

    private func buildRows() -> [Row] {
        plan.itineraryItems.map { item in
            var cells: [String]
            switch item.kind {
            case .stay:
                let dates = item.end.map { "\(item.start.short)\nto \($0.short)" } ?? item.start.short
                cells = [dates, item.type, item.place, item.details, item.nights.map { String($0) } ?? ""]
                if includeCosts {
                    let rate = item.rate ?? 0
                    cells.append(rate > 0 ? "\(plan.money(item.cost))\n\(plan.money(rate)) a night" : "")
                }
            case .travel:
                cells = [item.start.short, item.type, item.place, item.details, ""]
                if includeCosts { cells.append(item.cost > 0 ? plan.money(item.cost) : "") }
            }
            return Row(kind: item.kind, cells: cells, color: item.color)
        }
    }

    private func measure(_ rows: [Row]) -> [Row] {
        let cols = columns
        return rows.map { row in
            var r = row
            var tallest: CGFloat = 0
            for (i, text) in row.cells.enumerated() where i < cols.count {
                let pad = padding(column: i)
                let attrs = attributes(cellFont(row, column: i), ink, align: cols[i].align)
                tallest = max(tallest, textHeight(text, width: cols[i].width - pad.left - pad.right, attrs))
            }
            r.height = max(tallest, 11) + 13.6
            return r
        }
    }

    /// Splits rows into pages. Returns the rows on each page and whether the totals need their own page.
    private func paginate(_ rows: [Row]) -> (pages: [[Row]], totalsOnNewPage: Bool) {
        var pages: [[Row]] = [[]]
        var y = tableTopFirst + headRowHeight
        for row in rows {
            if y + row.height > tableBottom, !(pages.last?.isEmpty ?? true) {
                pages.append([])
                y = tableTopOther + headRowHeight
            }
            pages[pages.count - 1].append(row)
            y += row.height
        }
        let totalsOnNewPage = includeCosts && y + 22 + 62 > tableBottom
        return (pages, totalsOnNewPage)
    }

    // MARK: Drawing

    func render() -> Data {
        let rows = measure(buildRows())
        let layout = paginate(rows)
        let pageCount = layout.pages.count + (layout.totalsOnNewPage ? 1 : 0)
        let title = plan.name.isEmpty ? "Holiday" : plan.name

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title,
                               kCGPDFContextCreator as String: "Holiday Planner"]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH), format: format)

        return renderer.pdfData { context in
            var lastY: CGFloat = 0
            for (p, pageRows) in layout.pages.enumerated() {
                context.beginPage()
                if p == 0 {
                    drawHeader(title: title)
                    drawStats()
                    drawTimeline(context.cgContext)
                }
                lastY = drawTable(pageRows, top: p == 0 ? tableTopFirst : tableTopOther, context: context.cgContext)
                drawFooter(title: title, page: p + 1, of: pageCount, context: context.cgContext)
            }
            if includeCosts {
                if layout.totalsOnNewPage {
                    context.beginPage()
                    drawFooter(title: title, page: pageCount, of: pageCount, context: context.cgContext)
                    lastY = tableTopOther
                }
                drawTotals(top: lastY + 22, context: context.cgContext)
            }
        }
    }

    private func drawHeader(title: String) {
        accent.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: pageW, height: 96))
        draw(title, in: CGRect(x: margin, y: 26, width: pageW - 2 * margin, height: 28),
             attributes(.systemFont(ofSize: 20, weight: .bold), .white, truncate: true))
        let dates = "\(plan.start.short) \(plan.start.year) to \(plan.end.short) \(plan.end.year)"
        draw(dates, in: CGRect(x: margin, y: 60, width: pageW - 2 * margin, height: 16),
             attributes(.systemFont(ofSize: 10.5), .white))
    }

    private func drawStats() {
        var stats: [(String, String)] = [("NIGHTS", "\(plan.totalNights)"), ("LOCATIONS", "\(plan.stops.count)")]
        if includeCosts {
            stats += [("STAYS", plan.money(plan.stayCost)), ("TRAVEL", plan.money(plan.travelCost)),
                      ("TOTAL", plan.money(plan.totalCost))]
        }
        let gap: CGFloat = 11
        let boxW = (pageW - 2 * margin - gap * CGFloat(stats.count - 1)) / CGFloat(stats.count)
        for (i, stat) in stats.enumerated() {
            let box = CGRect(x: margin + CGFloat(i) * (boxW + gap), y: 119, width: boxW, height: 48)
            let path = UIBezierPath(roundedRect: box, cornerRadius: 6)
            field.setFill()
            path.fill()
            line.setStroke()
            path.lineWidth = 0.8
            path.stroke()
            draw(stat.0, in: CGRect(x: box.minX + 11, y: box.minY + 9, width: boxW - 18, height: 11),
                 attributes(.systemFont(ofSize: 7.5, weight: .medium), muted, truncate: true))
            draw(stat.1, in: CGRect(x: box.minX + 11, y: box.minY + 22, width: boxW - 18, height: 18),
                 attributes(.systemFont(ofSize: 13, weight: .bold), ink, truncate: true))
        }
    }

    private func drawTimeline(_ cg: CGContext) {
        let bar = CGRect(x: margin, y: 190, width: pageW - 2 * margin, height: 31)
        let total = CGFloat(max(plan.totalNights, 1))
        cg.saveGState()
        UIBezierPath(roundedRect: bar, cornerRadius: 4).addClip()
        var x = bar.minX
        for row in plan.rows {
            let w = CGFloat(row.stop.nights) / total * bar.width
            UIColor(hex: row.stop.color).setFill()
            UIRectFill(CGRect(x: x, y: bar.minY, width: w, height: bar.height))
            let nameAttrs = attributes(.systemFont(ofSize: 8, weight: .bold), .white, truncate: true)
            let nightsAttrs = attributes(.systemFont(ofSize: 8), .white)
            if w > 20 {
                draw(plan.displayName(row.index), in: CGRect(x: x + 4, y: bar.minY + 4, width: w - 8, height: 11), nameAttrs)
                let nights = "\(row.stop.nights) night\(row.stop.nights == 1 ? "" : "s")"
                let label = textWidth(nights, nightsAttrs) <= w - 8 ? nights : "\(row.stop.nights)n"
                if textWidth(label, nightsAttrs) <= w - 8 {
                    draw(label, in: CGRect(x: x + 4, y: bar.minY + 16, width: w - 8, height: 11), nightsAttrs)
                }
            }
            if row.index > 0 {
                UIColor.white.setStroke()
                let sep = UIBezierPath()
                sep.move(to: CGPoint(x: x, y: bar.minY))
                sep.addLine(to: CGPoint(x: x, y: bar.maxY))
                sep.lineWidth = 1.7
                sep.stroke()
            }
            x += w
        }
        cg.restoreGState()
        let small = attributes(.systemFont(ofSize: 7.5), muted)
        draw(plan.start.short, in: CGRect(x: margin, y: bar.maxY + 5, width: 120, height: 11), small)
        draw(plan.end.short, in: CGRect(x: pageW - margin - 120, y: bar.maxY + 5, width: 120, height: 11),
             attributes(.systemFont(ofSize: 7.5), muted, align: .right))
    }

    /// Draws the heading row and the rows for one page. Returns the y where the table ends.
    private func drawTable(_ rows: [Row], top: CGFloat, context cg: CGContext) -> CGFloat {
        let cols = columns
        let left = margin
        let width = pageW - 2 * margin

        accent.setFill()
        UIRectFill(CGRect(x: left, y: top, width: width, height: headRowHeight))
        var x = left
        for (i, col) in cols.enumerated() {
            let pad = padding(column: i)
            draw(col.title, in: CGRect(x: x + pad.left, y: top + 6, width: col.width - pad.left - pad.right, height: 12),
                 attributes(.systemFont(ofSize: 9, weight: .bold), .white, align: col.align, truncate: true))
            x += col.width
        }

        var y = top + headRowHeight
        for row in rows {
            x = left
            for (i, col) in cols.enumerated() where i < row.cells.count {
                let pad = padding(column: i)
                let color = row.kind == .travel ? muted : ink
                draw(row.cells[i], in: CGRect(x: x + pad.left, y: y + pad.top,
                                              width: col.width - pad.left - pad.right,
                                              height: row.height - pad.top - pad.bottom + 2),
                     attributes(cellFont(row, column: i), color, align: col.align))
                x += col.width
            }
            if row.kind == .stay, let hex = row.color {
                UIColor(hex: hex).setFill()
                UIRectFill(CGRect(x: left, y: y + 2.3, width: 4, height: row.height - 4.6))
            }
            line.setStroke()
            let rule = UIBezierPath()
            rule.move(to: CGPoint(x: left, y: y + row.height))
            rule.addLine(to: CGPoint(x: left + width, y: y + row.height))
            rule.lineWidth = 0.6
            rule.stroke()
            y += row.height
        }
        return y
    }

    private func drawTotals(top: CGFloat, context cg: CGContext) {
        let right = pageW - margin
        let labelX = right - 130
        var y = top
        let lines: [(String, Double)] = [("Stays", plan.stayCost), ("Travel", plan.travelCost), ("Total", plan.totalCost)]
        for (label, value) in lines {
            let isTotal = label == "Total"
            if isTotal {
                ink.setStroke()
                let rule = UIBezierPath()
                rule.move(to: CGPoint(x: labelX, y: y - 4))
                rule.addLine(to: CGPoint(x: right, y: y - 4))
                rule.lineWidth = 0.8
                rule.stroke()
            }
            let size: CGFloat = isTotal ? 11 : 9.5
            let font = UIFont.systemFont(ofSize: size, weight: isTotal ? .bold : .regular)
            draw(label, in: CGRect(x: labelX, y: y, width: 70, height: size + 5),
                 attributes(font, isTotal ? ink : muted))
            draw(plan.money(value), in: CGRect(x: right - 110, y: y, width: 110, height: size + 5),
                 attributes(font, ink, align: .right))
            y += isTotal ? 20 : 17
        }
    }

    private func drawFooter(title: String, page: Int, of count: Int, context cg: CGContext) {
        line.setStroke()
        let rule = UIBezierPath()
        rule.move(to: CGPoint(x: margin, y: pageH - 34))
        rule.addLine(to: CGPoint(x: pageW - margin, y: pageH - 34))
        rule.lineWidth = 0.6
        rule.stroke()
        let small = attributes(.systemFont(ofSize: 8), muted, truncate: true)
        draw(title, in: CGRect(x: margin, y: pageH - 27, width: 340, height: 12), small)
        draw("Page \(page) of \(count)", in: CGRect(x: pageW - margin - 120, y: pageH - 27, width: 120, height: 12),
             attributes(.systemFont(ofSize: 8), muted, align: .right))
    }
}
