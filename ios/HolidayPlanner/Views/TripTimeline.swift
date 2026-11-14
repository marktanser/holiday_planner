import SwiftUI

/// The bar across the trip: one coloured block per stay, sized by nights, with dividers to drag.
struct TimelineCard: View {
    @Binding var plan: Plan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timeline").font(.headline)
            Text("Drag a divider to move nights between neighbouring stops.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TripTimeline(plan: $plan)
                .padding(.horizontal, 4)
        }
        .card()
    }
}

struct TripTimeline: View {
    @Binding var plan: Plan
    @State private var drag: DragState? = nil

    init(plan: Binding<Plan>) {
        self._plan = plan
    }

    private struct DragState {
        let index: Int
        let base: (Int, Int)
    }

    private struct Mark: Identifiable {
        let id: String
        let text: String
        let anchor: CGFloat
        var center: CGFloat
        var halfWidth: CGFloat
        var dot = false
    }

    private let barHeight: CGFloat = 64
    private let markHeight: CGFloat = 22
    private let axisHeight: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let total = max(plan.totalNights, 1)
            let perDay = width / CGFloat(total)
            let rows = plan.rows

            VStack(alignment: .leading, spacing: 6) {
                travelMarks(rows: rows, perDay: perDay, width: width)
                    .frame(width: width, height: markHeight)

                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach(rows) { row in
                            segment(row, width: CGFloat(row.stop.nights) * perDay)
                        }
                    }
                    .frame(width: width, height: barHeight, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    ForEach(rows.dropLast()) { row in
                        handle(row, perDay: perDay)
                            .position(x: CGFloat(row.before + row.stop.nights) * perDay, y: barHeight / 2)
                    }
                }
                .frame(width: width, height: barHeight)

                axis(perDay: perDay, total: total, width: width)
                    .frame(width: width, height: axisHeight)
            }
        }
        .frame(height: markHeight + barHeight + axisHeight + 12)
        .sensoryFeedback(.selection, trigger: plan.stops.map(\.nights))
    }

    // MARK: Pieces

    private func segment(_ row: StayRow, width: CGFloat) -> some View {
        let showName = width >= 64
        let showNights = width >= 40
        return ZStack(alignment: .leading) {
            Color(hex: row.stop.color)
            if showNights {
                VStack(alignment: showName ? .leading : .center, spacing: 2) {
                    if showName {
                        Text(plan.displayName(row.index))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    Text("\(row.stop.nights)n")
                        .font(.caption.monospacedDigit())
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                // Side padding keeps the words clear of the dividers on the block's edges.
                .padding(.horizontal, showName ? 14 : 4)
                .frame(width: width, alignment: showName ? .leading : .center)
            }
        }
        .frame(width: max(width, 0), height: barHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(plan.displayName(row.index)), \(row.stop.nights) night\(row.stop.nights == 1 ? "" : "s")")
    }

    private func handle(_ row: StayRow, perDay: CGFloat) -> some View {
        let i = row.index
        let active = drag?.index == i
        let next = plan.displayName(i + 1)
        return Capsule()
            .fill(Color(.systemBackground))
            .overlay(Capsule().stroke(Color.primary.opacity(0.85), lineWidth: 1))
            .frame(width: active ? 9 : 7, height: barHeight + 12)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .frame(width: 34, height: barHeight + 12)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if active {
                    Text(row.depart.short)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary))
                        .fixedSize()
                        .offset(y: -30)
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if drag == nil, i + 1 < plan.stops.count {
                            drag = DragState(index: i, base: (plan.stops[i].nights, plan.stops[i + 1].nights))
                        }
                        guard let state = drag, perDay > 0 else { return }
                        let delta = Int((value.translation.width / perDay).rounded())
                        plan.moveBoundary(after: state.index, from: state.base, by: delta)
                    }
                    .onEnded { _ in drag = nil }
            )
            .accessibilityElement()
            .accessibilityLabel("Divider between \(plan.displayName(i)) and \(next)")
            .accessibilityValue("Changeover \(row.depart.short)")
            .accessibilityHint("Swipe up or down to move a night between them.")
            .accessibilityAdjustableAction { direction in
                guard i + 1 < plan.stops.count else { return }
                let base = (plan.stops[i].nights, plan.stops[i + 1].nights)
                switch direction {
                case .increment: plan.moveBoundary(after: i, from: base, by: 1)
                case .decrement: plan.moveBoundary(after: i, from: base, by: -1)
                @unknown default: break
                }
            }
    }

    /// Travel labels above each changeover. Labels that would run into a neighbour become dots.
    private func travelMarks(rows: [StayRow], perDay: CGFloat, width: CGFloat) -> some View {
        var marks: [Mark] = []
        func add(_ legs: [Leg], id: String, at x: CGFloat) {
            guard !legs.isEmpty else { return }
            let labels = legs.map { $0.mode.short }
            let text = labels.count > 2 ? "\(labels[0]) +\(labels.count - 1)" : labels.joined(separator: " + ")
            let half = (CGFloat(text.count) * 6.4 + 16) / 2
            let center = min(max(x, half), max(width - half, half))
            marks.append(Mark(id: id, text: text, anchor: x, center: center, halfWidth: half))
        }
        for row in rows { add(row.stop.legs, id: row.stop.id, at: CGFloat(row.before) * perDay) }
        add(plan.returnLegs, id: "return", at: width)

        for k in marks.indices {
            let left = marks[k].center - marks[k].halfWidth
            let right = marks[k].center + marks[k].halfWidth
            let hitsPrev = k > 0 && left < marks[k - 1].center + marks[k - 1].halfWidth + 4
            let hitsNext = k + 1 < marks.count && right + 4 > marks[k + 1].center - marks[k + 1].halfWidth
            if hitsPrev || hitsNext { marks[k].dot = true }
        }
        for k in marks.indices where marks[k].dot {
            marks[k].center = min(max(marks[k].anchor, 5), width - 5)
        }

        return ZStack(alignment: .topLeading) {
            ForEach(marks) { mark in
                Group {
                    if mark.dot {
                        Circle().fill(Color.secondary).frame(width: 9, height: 9)
                    } else {
                        Text(mark.text)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(.tertiarySystemFill)))
                            .fixedSize()
                    }
                }
                .position(x: mark.center, y: markHeight / 2)
            }
        }
        .accessibilityHidden(true)
    }

    private func axis(perDay: CGFloat, total: Int, width: CGFloat) -> some View {
        let start = plan.start
        return VStack(spacing: 4) {
            Canvas { context, size in
                guard total <= 180 else { return }
                for i in 0...total {
                    let monday = start.adding(i).weekday == 2
                    let x = min(max(CGFloat(i) * perDay, 0.5), size.width - 0.5)
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: monday ? 8 : 4))
                    context.stroke(path, with: .color(Color.secondary.opacity(monday ? 0.7 : 0.35)), lineWidth: 1)
                }
            }
            .frame(height: 9)
            HStack {
                Text(plan.start.dayMonth)
                Spacer()
                Text(plan.end.dayMonth)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}
