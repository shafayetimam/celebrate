# Linear Clock widget (iOS)

A WidgetKit widget styled like an LED bar-graph clock. A black display in an aluminium housing has a 0–24 scale across the top, and green LED segments light up as the day goes by, one per half hour.

- **Small:** the day over two rows (0–12, 12–24), one segment per hour.
- **Medium:** the full 0–24 bar, with a 0–60 minute bar under it.
- **Large / Extra Large:** two half-hour rows for the day, plus the minute bar.
- **Lock Screen (rectangular):** one 24-segment bar in the lock screen's tint.

Requires iOS 17+.

Open `preview.html` in a browser to see a live mock-up.

## Add it to an app in Xcode

1. Open (or create) an iOS app project in Xcode.
2. **File → New → Target… → Widget Extension**, name it `LinearClockWidget`, and untick "Include Configuration App Intent".
3. Delete the Swift files Xcode generated in the new target. Drag in `LinearClockWidget.swift` and `LinearClockWidgetBundle.swift`, with only the widget target ticked.
4. Run the app on your iPhone. Long-press the Home Screen, tap **Edit → Add Widget**, search for **Linear Clock** and pick a size.

The widget refreshes once a minute. iOS doesn't allow widgets to animate continuously.
