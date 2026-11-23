# Linear Clock widget (iOS)

A WidgetKit widget that shows the time on two sliding tapes, hours on top and minutes below. The tapes move past a fixed red index line.

Sizes: Small, Medium, Large (adds a 00–24 "today" strip), Extra Large (iPad) and Lock Screen rectangular.
Light and dark mode are both supported. Requires iOS 17+.

Open `preview.html` in a browser to see a live mock-up.

## Add it to an app in Xcode

1. Open (or create) an iOS app project in Xcode.
2. **File → New → Target… → Widget Extension**, name it `LinearClockWidget`, and untick "Include Configuration App Intent".
3. Delete the Swift files Xcode generated in the new target. Drag in `LinearClockWidget.swift` and `LinearClockWidgetBundle.swift`, with only the widget target ticked.
4. Run the app on your iPhone. Long-press the Home Screen, tap **Edit → Add Widget**, search for **Linear Clock** and pick a size.

The widget refreshes once a minute. iOS doesn't allow widgets to animate continuously.
