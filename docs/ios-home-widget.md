# iOS home screen widget

The Android widget (today's water, streak, points and a "+250 ml" button) is
built in. iOS widgets need a WidgetKit extension target, which has to be
created in Xcode on a Mac. The Dart side is ready: `HomeWidgetService`
(`lib/features/home_widget/home_widget_service.dart`) already writes the
values below whenever water is logged and when the app goes to the background.

| Key             | Type   | Meaning                         |
|-----------------|--------|---------------------------------|
| `signed_in`     | Bool   | Someone is signed in            |
| `user_id`       | String | Signed-in user id               |
| `water_ml`      | Int    | Water logged today              |
| `water_goal_ml` | Int    | Daily water goal                |
| `streak`        | Int    | Current activity streak (days)  |
| `points_today`  | Int    | Points earned today             |

## Steps

1. **Add an App Group** (shared storage between the app and the widget).
   In Xcode, select the *Runner* target → *Signing & Capabilities* →
   *+ Capability* → *App Groups* → add `group.com.tarunsiddhi.vitalup`.

2. **Create the widget extension.** *File → New → Target → Widget Extension*,
   name it `VitalUpWidget`, untick *Include Configuration App Intent*. Add the
   same App Group to the new target. Set its deployment target to the
   Runner's.

3. **Tell the plugin about the group** — in `HomeWidgetService.start`, before
   the first refresh:

   ```dart
   await HomeWidget.setAppGroupId('group.com.tarunsiddhi.vitalup');
   ```

   and remove the `Platform.isAndroid` guard (`_supported`) so iOS gets
   updates too. Pass `iOSName: 'VitalUpWidget'` to `HomeWidget.updateWidget`.

4. **Read the values in Swift** (`VitalUpWidget.swift`):

   ```swift
   import WidgetKit
   import SwiftUI

   struct Entry: TimelineEntry {
     let date: Date
     let waterMl: Int
     let goalMl: Int
     let streak: Int
     let points: Int
   }

   struct Provider: TimelineProvider {
     let defaults = UserDefaults(suiteName: "group.com.tarunsiddhi.vitalup")

     func entry() -> Entry {
       Entry(date: .now,
             waterMl: defaults?.integer(forKey: "water_ml") ?? 0,
             goalMl: max(defaults?.integer(forKey: "water_goal_ml") ?? 2500, 1),
             streak: defaults?.integer(forKey: "streak") ?? 0,
             points: defaults?.integer(forKey: "points_today") ?? 0)
     }
     func placeholder(in context: Context) -> Entry { entry() }
     func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
       completion(entry())
     }
     func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
       completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(1800))))
     }
   }

   struct VitalUpWidgetView: View {
     let entry: Entry
     var body: some View {
       VStack(alignment: .leading, spacing: 8) {
         HStack {
           Text("VitalUp today").font(.headline)
           Spacer()
           if entry.streak > 0 { Text("🔥 \(entry.streak)") }
         }
         Text("\(entry.waterMl) / \(entry.goalMl) ml").font(.title3)
         ProgressView(value: Double(min(entry.waterMl, entry.goalMl)),
                      total: Double(entry.goalMl))
           .tint(Color(red: 0x42/255, green: 0xA5/255, blue: 0xF5/255))
         Text("+\(entry.points) pts today").font(.caption).foregroundStyle(.secondary)
       }
       .widgetURL(URL(string: "vitalup://widget/open?route=water-trends"))
       .containerBackground(.background, for: .widget)
     }
   }

   @main
   struct VitalUpWidget: Widget {
     var body: some WidgetConfiguration {
       StaticConfiguration(kind: "VitalUpWidget", provider: Provider()) {
         VitalUpWidgetView(entry: $0)
       }
       .configurationDisplayName("VitalUp today")
       .description("Today's water, streak and points.")
       .supportedFamilies([.systemSmall, .systemMedium])
     }
   }
   ```

5. **"+250 ml" button (iOS 17+, optional).** Interactive iOS widgets use an
   `AppIntent` that calls the plugin's background callback; follow the
   *Interactive Widgets* section of the `home_widget` README. The Dart callback
   (`homeWidgetCallback`) already handles `vitalup://widget/add-water`.

6. Build and run on a device, long-press the home screen, and add
   *VitalUp today*.
