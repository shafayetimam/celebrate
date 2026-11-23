//  LinearClockWidget.swift
//  A WidgetKit home-screen / lock-screen widget that shows the time as a
//  linear clock: an hour tape and a minute tape slide past a fixed red
//  index line in the middle of the widget.
//
//  Requires iOS 17+ (uses containerBackground / contentMarginsDisabled).

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct ClockEntry: TimelineEntry {
    let date: Date
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: .now))
    }

    /// One entry per minute for the next hour, then WidgetKit asks again.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let now = Date()
        let startOfMinute = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
        let entries = (0..<60).map {
            ClockEntry(date: startOfMinute.addingTimeInterval(Double($0) * 60))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Palette

enum Palette {
    /// Warm paper white in light mode, near-black in dark mode.
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
            : UIColor(red: 0.94, green: 0.925, blue: 0.90, alpha: 1)
    })

    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.93, green: 0.91, blue: 0.88, alpha: 1)
            : UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1)
    })

    static let index = Color(red: 0.89, green: 0.25, blue: 0.18)
}

// MARK: - Sliding tape

/// A horizontal scale whose value at the horizontal centre equals `value`.
struct SlidingTape: View {
    let value: Double        // current position, in the tape's units
    let span: Double         // how many units fit across the width
    let period: Int          // labels wrap at this number (24 for hours, 60 for minutes)
    let minorStep: Double    // units between small ticks
    let majorEvery: Int      // every n-th small tick is a large, labelled tick
    let ink: Color
    let fontSize: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let pxPerUnit = size.width / span
            let mid = size.width / 2
            let first = Int(((value - span / 2) / minorStep).rounded(.down)) - 1
            let last = Int(((value + span / 2) / minorStep).rounded(.up)) + 1

            // Top rule
            var rule = Path()
            rule.move(to: CGPoint(x: 0, y: 0.5))
            rule.addLine(to: CGPoint(x: size.width, y: 0.5))
            ctx.stroke(rule, with: .color(ink), lineWidth: 1)

            for i in first...last {
                let u = Double(i) * minorStep
                let x = mid + (u - value) * pxPerUnit
                let isMajor = i.mod(majorEvery) == 0
                let isHalf = !isMajor && majorEvery % 2 == 0 && i.mod(majorEvery / 2) == 0

                let length = size.height * (isMajor ? 0.40 : (isHalf ? 0.28 : 0.18))
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: 0))
                tick.addLine(to: CGPoint(x: x, y: length))
                ctx.stroke(tick, with: .color(ink), lineWidth: isMajor ? 1.6 : 0.8)

                if isMajor {
                    let label = Int(u.rounded()).mod(period)
                    let text = Text(String(format: "%02d", label))
                        .font(.system(size: fontSize, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundColor(ink)
                    ctx.draw(text, at: CGPoint(x: x, y: size.height * 0.48), anchor: .top)
                }
            }
        }
        // Fade the tape out at both ends, like it disappears into the housing.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.16),
                    .init(color: .black, location: 0.84),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }
}

/// A fixed 00–24 strip with a marker showing how far through the day we are.
struct DayStrip: View {
    let hours: Double
    let ink: Color
    let marker: Color
    let fontSize: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let inset: CGFloat = fontSize
            let w = size.width - inset * 2
            let barY = size.height * 0.30

            var bar = Path()
            bar.move(to: CGPoint(x: inset, y: barY))
            bar.addLine(to: CGPoint(x: inset + w, y: barY))
            ctx.stroke(bar, with: .color(ink.opacity(0.35)), lineWidth: 1)

            var elapsed = Path()
            elapsed.move(to: CGPoint(x: inset, y: barY))
            elapsed.addLine(to: CGPoint(x: inset + w * hours / 24, y: barY))
            ctx.stroke(elapsed, with: .color(ink), lineWidth: 3)

            for h in 0...24 {
                let x = inset + w * Double(h) / 24
                let major = h % 6 == 0
                var t = Path()
                t.move(to: CGPoint(x: x, y: barY - (major ? 5 : 3)))
                t.addLine(to: CGPoint(x: x, y: barY + (major ? 5 : 3)))
                ctx.stroke(t, with: .color(ink), lineWidth: major ? 1.4 : 0.7)
                if h % 3 == 0 {
                    let text = Text(String(format: "%02d", h))
                        .font(.system(size: fontSize, weight: .regular, design: .rounded).monospacedDigit())
                        .foregroundColor(ink.opacity(0.7))
                    ctx.draw(text, at: CGPoint(x: x, y: barY + 9), anchor: .top)
                }
            }

            let mx = inset + w * hours / 24
            let dot = Path(ellipseIn: CGRect(x: mx - 4, y: barY - 4, width: 8, height: 8))
            ctx.fill(dot, with: .color(marker))
        }
    }
}

/// The fixed red index line with a small pointer on top.
struct IndexLine: View {
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(color)
                .frame(width: 9, height: 6)
            Rectangle()
                .fill(color)
                .frame(width: 2)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Widget view

struct LinearClockView: View {
    let date: Date
    @Environment(\.widgetFamily) private var family

    private var time: (hours: Double, minutes: Double) {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let h = Double(c.hour ?? 0), m = Double(c.minute ?? 0), s = Double(c.second ?? 0)
        return (h + m / 60 + s / 3600, m + s / 60)
    }

    private var isAccessory: Bool { family == .accessoryRectangular }
    private var ink: Color { isAccessory ? .primary : Palette.ink }
    private var indexColor: Color { isAccessory ? .primary : Palette.index }

    /// (hour span, minute span, label size, padding) per widget size.
    private var metrics: (hourSpan: Double, minuteSpan: Double, font: CGFloat, padding: CGFloat) {
        switch family {
        case .systemSmall:          return (4, 20, 11, 12)
        case .systemLarge:          return (8, 40, 13, 18)
        case .systemExtraLarge:     return (12, 60, 15, 22)
        case .accessoryRectangular: return (4, 20, 10, 0)
        default:                    return (8, 40, 12, 16)  // medium
        }
    }

    var body: some View {
        let t = time
        let m = metrics

        VStack(alignment: .leading, spacing: isAccessory ? 2 : 8) {
            if !isAccessory {
                header(fontSize: m.font)
            }

            ZStack {
                VStack(spacing: isAccessory ? 2 : 6) {
                    tapeRow(label: "H", font: m.font) {
                        SlidingTape(value: t.hours, span: m.hourSpan, period: 24,
                                    minorStep: 0.25, majorEvery: 4,
                                    ink: ink, fontSize: m.font)
                    }
                    tapeRow(label: "M", font: m.font) {
                        SlidingTape(value: t.minutes, span: m.minuteSpan, period: 60,
                                    minorStep: 1, majorEvery: 5,
                                    ink: ink, fontSize: m.font)
                    }
                }
                IndexLine(color: indexColor)
            }

            if family == .systemLarge || family == .systemExtraLarge {
                Spacer(minLength: 4)
                Text("TODAY")
                    .font(.system(size: m.font - 2, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(ink.opacity(0.6))
                DayStrip(hours: t.hours, ink: ink, marker: indexColor, fontSize: m.font - 2)
                    .frame(height: 36)
            }
        }
        .padding(m.padding)
    }

    @ViewBuilder
    private func header(fontSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .textCase(.uppercase)
                .tracking(1.2)
            Spacer()
            if family != .systemSmall {
                Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .monospacedDigit()
            }
        }
        .font(.system(size: fontSize - 1, weight: .semibold))
        .foregroundStyle(ink.opacity(0.65))
    }

    /// The tape fills the row; a tiny unit label sits at the left on bigger widgets.
    @ViewBuilder
    private func tapeRow<Content: View>(label: String, font: CGFloat,
                                        @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if family != .systemSmall && !isAccessory {
                    Text(label)
                        .font(.system(size: font - 3, weight: .bold))
                        .foregroundStyle(ink.opacity(0.4))
                        .offset(y: -font)
                }
            }
    }
}

// MARK: - Widget

struct LinearClockWidget: Widget {
    let kind = "LinearClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockProvider()) { entry in
            LinearClockView(date: entry.date)
                .containerBackground(for: .widget) { Palette.background }
        }
        .configurationDisplayName("Linear Clock")
        .description("Hours and minutes on sliding tapes under a red index line.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
            .accessoryRectangular,
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Helpers

private extension Int {
    /// Always-positive modulo.
    func mod(_ n: Int) -> Int { ((self % n) + n) % n }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    LinearClockWidget()
} timeline: {
    ClockEntry(date: .now)
    ClockEntry(date: .now.addingTimeInterval(15 * 60))
}

#Preview("Small", as: .systemSmall) {
    LinearClockWidget()
} timeline: {
    ClockEntry(date: .now)
}

#Preview("Large", as: .systemLarge) {
    LinearClockWidget()
} timeline: {
    ClockEntry(date: .now)
}

#Preview("Lock Screen", as: .accessoryRectangular) {
    LinearClockWidget()
} timeline: {
    ClockEntry(date: .now)
}
