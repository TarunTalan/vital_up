# Home screen widgets

## Android (built in)

Five widgets, all resizable:

| Widget        | Provider class                 | Shows                                             |
|---------------|--------------------------------|---------------------------------------------------|
| Today         | `VitalUpWidgetProvider`        | Activity, calories, water and sleep vs goals      |
| My metrics    | `CustomWidgetProvider`         | 1-4 metrics chosen in Settings > Widgets          |
| Water         | `HydrationWidgetProvider`      | Water vs goal, +150 / +250 / +500 ml buttons      |
| Mood check-in | `MoodWidgetProvider`           | Five faces to check in, then today's mood         |
| Shortcuts     | `QuickShortcutsWidgetProvider` | Scan, Water, Workout, Vita                        |

Each size the app offers is its own provider (Android can only pin a widget
at its provider's default size, so the Widgets page pins the provider for the
selected size tab): Today and My metrics come in 2×2, 4×2, 4×3 and 4×4; Water
in 2×2 and 4×2; Mood in 4×1 and 4×2; Shortcuts in 2×1 and 4×1. The extra
sizes are subclasses in `WidgetSizes.kt` with their own `res/xml/*_info.xml`
and manifest receiver; every size stays freely resizable once placed.

How it fits together:

- **Dart formats, Kotlin lays out.** `lib/features/home_widget/data/widget_data.dart`
  turns raw numbers (`WidgetInputs`) into display text (`buildTiles`) and saves
  it with `home_widget`. The Kotlin providers
  (`android/app/src/main/kotlin/.../VitalWidget.kt`, `MetricsWidget.kt`, ...)
  only place that text. The in-app previews
  (`presentation/widget_previews.dart`) draw the same text with Flutter copies
  of the layouts, so previews and home screen match. Keep the size thresholds
  in the previews in step with the providers.
- **Refresh.** The app refreshes from its repositories (server data included)
  on start, resume, background, sign-in/out and after anything is logged
  (`HomeWidgetService.refresh`). Widget buttons, and widgets whose data is from
  an earlier day or over 30 minutes old, run `homeWidgetCallback` in a
  background isolate. Refresh starts the app's services there (Supabase +
  `initDependencies`, about 10 s from cold) and runs the same full refresh;
  add-water and mood re-read on-device data (water, meals, mood, weight)
  instantly. If the full refresh can't run (no restored session, error, 25 s
  timeout) the on-device refresh is used instead.
- **Taps.** Widgets open `vitalup://widget/open?route=<name>`. Flutter passes it
  to GoRouter as `/open?route=...`; `HomeWidgetService.handleLink` opens the
  route on top of Home (Back returns Home), or holds it until Home shows on a
  cold start.
- **Theme.** Colours come from `res/values/colors.xml` and
  `res/values-night/colors.xml` (VitalUp tokens), so widgets follow the
  phone's light or dark setting. Text uses SF Pro Rounded from `res/font`.

### Saved keys

| Key                         | Type   | Meaning                                         |
|-----------------------------|--------|-------------------------------------------------|
| `signed_in`                 | Bool   | Someone is signed in                            |
| `user_id`                   | String | Signed-in user id (background actions)          |
| `snapshot_day`              | String | yyyy-MM-dd the figures belong to                |
| `updated_at_ms`             | String | Last refresh, epoch milliseconds                |
| `m_<metric>_label`          | String | e.g. "Steps"                                    |
| `m_<metric>_value`          | String | e.g. "6,240"                                    |
| `m_<metric>_detail`         | String | e.g. "of 8,000 steps"                           |
| `m_<metric>_progress`       | Int    | 0-100, or -1 when there is no goal              |
| `m_<metric>_color`          | String | Accent, "#AARRGGBB"                             |
| `m_<metric>_route`          | String | Route opened when tapped                        |
| `mood_level`                | Int    | Today's check-in 1-5, or 0                      |
| `today_metrics`             | String | Metric ids for Today                            |
| `custom_metrics`            | String | Metric ids for My metrics, in order             |
| `custom_title`              | String | My metrics title                                |
| `in_*`                      | String | Raw inputs for background rebuilds              |
| `refreshing_since_ms`       | String | Refresh running: headers show a spinner (20 s max) |

`<metric>` is one of `activity`, `calories`, `water`, `sleep`, `mood`,
`weight`.

## iOS (not built yet)

iOS widgets need a WidgetKit extension target, which has to be created in
Xcode on a Mac:

1. **Add an App Group.** Runner target > *Signing & Capabilities* >
   *App Groups* > add `group.com.tarunsiddhi.vitalup`.
2. **Create the extension.** *File > New > Target > Widget Extension*, name it
   `VitalUpWidget`, untick *Include Configuration App Intent*, and add the same
   App Group to it.
3. **Point the plugin at the group.** In `HomeWidgetService.start`, call
   `HomeWidget.setAppGroupId('group.com.tarunsiddhi.vitalup')`, make
   `HomeWidgetService.supported` true on iOS, and pass `iOSName:` to
   `HomeWidget.updateWidget` in `updateAllWidgets`.
4. **Read the saved keys** above from
   `UserDefaults(suiteName: "group.com.tarunsiddhi.vitalup")` and lay them out
   in SwiftUI, opening `vitalup://widget/open?route=...` with `.widgetURL`.
5. **Buttons (iOS 17+).** Interactive widgets use an `AppIntent` that calls
   the plugin's background callback (see the *Interactive Widgets* section of
   the `home_widget` README). `homeWidgetCallback` already handles
   `/add-water?ml=`, `/mood?level=`, `/mood-reset` and `/refresh`.
