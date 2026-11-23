//  LinearClockWidget.swift
//  A WidgetKit widget styled like an LED bar-graph clock: a black display in
//  an aluminium housing, a 0–24 scale across the top, and green LED segments
//  that light up as the day goes by (one segment per half hour).
//
//  Requires iOS 17+ (uses containerBackground / contentMarginsDisabled).

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct ClockEntry: TimelineEntry {
    let date: Date
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: .now) }

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

// MARK: - Style

struct LEDStyle {
    let lit: Color
    let litTop: Color
    let unlit: Color
    let label: Color
    let glow: Bool

    /// Colours of the physical device: green LEDs, white scale on black glass.
    static let device = LEDStyle(
        lit: Color(red: 0.05, green: 0.84, blue: 0.40),
        litTop: Color(red: 0.32, green: 1.00, blue: 0.60),
        unlit: Color(red: 0.13, green: 0.08, blue: 0.09),
        label: Color(red: 0.97, green: 0.93, blue: 0.98),
        glow: true
    )

    /// Lock Screen: iOS tints everything, so just use primary at two strengths.
    static let accessory = LEDStyle(
        lit: .primary, litTop: .primary, unlit: .primary.opacity(0.2),
        label: .primary, glow: false
    )
}

enum Housing {
    static let aluminium = LinearGradient(
        colors: [Color(red: 0.55, green: 0.57, blue: 0.61), Color(red: 0.38, green: 0.40, blue: 0.44)],
        startPoint: .top, endPoint: .bottom
    )
    static let glass = Color(red: 0.02, green: 0.02, blue: 0.02)
}

// MARK: - LED bar

/// One row of the display: numbered scale, tick marks, then LED segments.
/// Segment i covers [start + i*segment, start + (i+1)*segment) and is lit once
/// that span has begun.
struct LEDBar: View {
    let start: Double
    let end: Double
    let segment: Double      // units per LED segment
    let labelEvery: Double   // units between numbered (long) ticks
    let value: Double        // current time in the bar's units
    var style: LEDStyle = .device

    var body: some View {
        Canvas { ctx, size in
            let H = size.height
            let units = end - start
            let labelSpacing = (size.width / units) * labelEvery
            let fs = min(H * 0.24, labelSpacing * 0.85)  // label font size
            let inset = fs * 0.45
            let w = size.width - inset * 2
            let count = Int((units / segment).rounded())
            let step = w / CGFloat(count)
            func x(_ u: Double) -> CGFloat { inset + CGFloat((u - start) / units) * w }

            // Vertical layout, all derived from the label size.
            let labelBottom = fs * 1.05
            let longTop = labelBottom + fs * 0.15
            let shortTop = labelBottom + fs * 0.38
            let tickBottom = labelBottom + fs * 0.65
            let segTop = tickBottom + fs * 0.35

            // Scale: a tick at every segment boundary, long + numbered at labelEvery.
            for i in 0...count {
                let u = start + Double(i) * segment
                let ratio = u / labelEvery
                let isLabel = abs(ratio.rounded() - ratio) < 0.001
                let px = x(u)

                var tick = Path()
                tick.move(to: CGPoint(x: px, y: isLabel ? longTop : shortTop))
                tick.addLine(to: CGPoint(x: px, y: tickBottom))
                ctx.stroke(tick, with: .color(style.label), lineWidth: isLabel ? 1.4 : 1)

                if isLabel {
                    let text = Text("\(Int(u.rounded()))")
                        .font(.system(size: fs, weight: .medium).width(.compressed))
                        .foregroundColor(style.label)
                    ctx.draw(text, at: CGPoint(x: px, y: labelBottom), anchor: .bottom)
                }
            }

            // LED segments.
            let gap = max(1, step * 0.24)
            var glowCtx = ctx
            if style.glow {
                glowCtx.addFilter(.shadow(color: style.lit.opacity(0.75), radius: max(2, step * 0.5)))
            }
            for i in 0..<count {
                let u = start + Double(i) * segment
                let rect = CGRect(x: x(u) + gap / 2, y: segTop, width: step - gap, height: H - segTop)
                if u < value {
                    glowCtx.fill(
                        Path(rect),
                        with: .linearGradient(
                            Gradient(colors: [style.litTop, style.lit]),
                            startPoint: CGPoint(x: rect.midX, y: rect.minY),
                            endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                        )
                    )
                } else {
                    ctx.fill(Path(rect), with: .color(style.unlit))
                }
            }
        }
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

    var body: some View {
        let t = time

        if family == .accessoryRectangular {
            // Lock Screen: one 24-segment bar, numbered every 6 hours.
            LEDBar(start: 0, end: 24, segment: 1, labelEvery: 6, value: t.hours, style: .accessory)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Housing.glass)
                .overlay {
                    rows(t)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                }
                .padding(9)
        }
    }

    @ViewBuilder
    private func rows(_ t: (hours: Double, minutes: Double)) -> some View {
        switch family {
        case .systemSmall:
            // The day split over two rows, one segment per hour.
            VStack(spacing: 10) {
                LEDBar(start: 0, end: 12, segment: 1, labelEvery: 1, value: t.hours)
                LEDBar(start: 12, end: 24, segment: 1, labelEvery: 1, value: t.hours)
            }
        case .systemLarge, .systemExtraLarge:
            // The day over two rows of half-hour segments, plus the current hour.
            VStack(spacing: 14) {
                LEDBar(start: 0, end: 12, segment: 0.5, labelEvery: 1, value: t.hours)
                LEDBar(start: 12, end: 24, segment: 0.5, labelEvery: 1, value: t.hours)
                LEDBar(start: 0, end: 60, segment: 2.5, labelEvery: 5, value: t.minutes)
            }
        default:
            // Medium: the full 0–24 bar like the real clock, minutes underneath.
            VStack(spacing: 10) {
                LEDBar(start: 0, end: 24, segment: 0.5, labelEvery: 1, value: t.hours)
                LEDBar(start: 0, end: 60, segment: 2.5, labelEvery: 5, value: t.minutes)
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
                .containerBackground(for: .widget) { Housing.aluminium }
        }
        .configurationDisplayName("Linear Clock")
        .description("The day as a row of green LEDs, one per half hour.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
            .accessoryRectangular,
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    LinearClockWidget()
} timeline: {
    ClockEntry(date: .now)
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
