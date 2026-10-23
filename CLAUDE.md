# VitalUp

Flutter health app (Android first; iOS builds but has no home screen widget,
push or Crashlytics yet). Tracks activity (GPS workouts), nutrition (AI food
scanner, diet plans), water, sleep, mood/stress, weight and screen time, with
an AI coach (Vita), a gamified Arena (points, badges, streaks, challenges,
friends, leaderboards) and Android home screen widgets.

This file is the project map. Read the files it points to for detail instead
of exploring the tree.

## Commands

```bash
dart analyze <paths>           # prefer paths; `dart analyze lib` takes ~6 min
flutter test                   # all tests; test/ mirrors lib/
flutter test test/features/<feature>
dart run build_runner build --delete-conflicting-outputs   # Isar/Drift codegen
flutter build apk --debug
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols  # Play (APK is ~200 MB universal)
cd android && ./gradlew.bat :app:compileDebugKotlin        # quick native check
supabase db push               # apply new migrations (outward-facing: ask first)
supabase functions deploy <name>
```

- `supabase db push` asks for the database password interactively, which
  hangs inside Claude Code: the user runs it in their own terminal. The CLI
  is logged in, so `supabase functions deploy` / `functions list` work here.
  Deploy migrations before edge functions that depend on them.
- Migrations reach production through `supabase db push` or Supabase's
  GitHub integration on `main` (all applied through `20261030`, Oct 22).
  Never paste a migration into the SQL editor: it isn't recorded in
  `supabase_migrations.schema_migrations`, so the next deploy runs it again
  (`20261021` renames a function and then fails with 42723). To fix the
  history: check what's really in the database, then the user runs
  `supabase migration repair --status applied <version>` for files that
  can't run twice (re-runnable ones can simply run again).
  `supabase migration list` hangs here too ("Initialising login role").

- Environment variables & secrets: `.env` (copy `.env.example`); compiled
  and XOR-obfuscated via `envied` into `lib/core/config/env.dart`
  (`env.g.dart` is gitignored; run build_runner after cloning and after
  every `.env` edit: a build doesn't regenerate it, so the APK keeps the
  old values; a mistyped Mapbox token shows a black map with only the logo
  and scale bar).
  `lib/core/config/supabase_config.dart` delegates to `Env`.
  `android/key.properties` holds release signing (the local build silently
  falls back to the debug key without it; the release workflow refuses).
- Code Push: Shorebird configured in `shorebird.yaml` and `.github/workflows/shorebird_patch.yml`.
- Analytics & Crashlytics: `lib/core/monitoring/analytics_service.dart` (Firebase Analytics)
  and `crash_reporter.dart` (Crashlytics).
- Release Obfuscation: R8 minification enabled in `build.gradle.kts` + Dart
  `--obfuscate --split-debug-info`. Release guide in `docs/PLAY_STORE_PRE_RELEASE_GUIDE.md`.
  Tag `v<pubspec version>` runs `play_store_release.yml` (Shorebird release,
  targetSdk 36); patches must use the same obfuscation flags.
- Legal URLs (vitalup.live): `lib/core/config/legal_links.dart` and
  `android/app/src/main/res/values/strings.xml` (`privacy_policy_url`).
- `dart analyze lib test` has no warnings; only info lints remain
  (`prefer_initializing_formals`, deprecated `Share` API, a few in
  `activity_tracking_page.dart` / `customize_layout_page.dart`). Keep it
  warning-free. `analysis_options.yaml` adds `cancel_subscriptions` and
  `close_sinks` (`unawaited_futures` was tried: too noisy for intentional
  fire-and-forget calls). `test/code_rules_test.dart` fails on
  `setState(() => _future = ...)` (returns a Future, throws at runtime).
  It also fails on a `FittedBox` around `Text` and literal font sizes
  below 12 (use `FitText` and `AppTextStyles`).

## Stack and architecture

- **State:** flutter_bloc Cubits/Blocs. **DI:** hand-written get_it `sl` in
  `lib/core/di/injection_container.dart` (`initDependencies`; `injectable` is
  in pubspec but unused). Most cubits are `registerFactory` (e.g.
  `ProfileCubit`, `AuthCubit`); `SettingsCubit` is a lazy singleton;
  services/repos are lazy singletons. Some Arena cubits are created in the
  router/hub, not DI.
- **Routing:** go_router, `lib/core/router/app_router.dart` (`AppRouter.router`,
  routes by `name`, pages wrapped in `AppPage`). Initial location `/splash`.
  Deep links: `vitalup://` and `/open?route=` (widgets, notifications).
  Read `extra` only through `routeExtra(state)` (`route_extras.dart`): go_router
  rebuilds a pushed page without its `extra` when redirects run again
  (switching light / dark with a leaderboard open showed "This page isn't
  available"); it remembers the last `extra` per location (cleared on
  sign-out). Test: `test/core/router/route_extras_test.dart`.
  Unauthenticated links to non-public pages redirect to `/login` via router guard.
  `test/widget_test.dart` checks every notification/reminder route exists.
- **Layers per feature:** `lib/features/<f>/{data,domain,presentation}`
  (datasources -> repositories -> entities -> cubit/pages/widgets). Errors use
  `dartz` `Either<Failure, T>` (`core/error/failures.dart`).
- **Data (offline first):**
  - Isar (`core/database/isar_service.dart`, `core/database/collections`):
    water, sleep, meals, weight, offline foods, barcode cache, diet plans,
    downloaded tracks.
  - Drift (`core/database/drift_database.dart`, schema v7): workout sessions
    and GPS track points.
  - SharedPreferences: goals, settings, per-user Vita data, reminders.
  - `core/cache/cache_store.dart`: cached server JSON with max ages; offline
    reads return the last copy. Once a request found the server
    unreachable (network up but DNS / server failing:
    `ConnectivityService.isOnline` false), reads return the saved copy at
    once and refresh quietly behind it; that refresh's success marks the
    server reachable again. `changes` / `watch(key)` announce every
    write, update or remove, so any screen can follow a cached value.
  - `core/sync/sync_service.dart`: backs up logs to Supabase tables
    (`water_logs`, `sleep_logs`, `meal_logs`, `weight_logs`,
    `activity_sessions`) and pulls other devices' rows; `BackupSyncAdapter`
    stores settings/goals/reminders/stress/workout notes/diet plan in
    `user_backups`. `pending_writes.dart` queues offline server writes and
    RPCs (pref `pending_server_writes_v1`).
    - `SyncService.pulled` (table names) fires after rows from the server
      are applied; `stop()` (bumps a generation) makes a running sync bail
      before writing anything else; `reset()` clears cursors and
      `backup_state_*` (so the next sign-in restores backups instead of
      uploading an empty device over them).
    - Pulls page by `(updated_at, id)`; `ActivitySyncAdapter` implements
      `SyncSizing` (5 per upload, 20 per page: routes are big).
    - `PendingWrites.hasQueuedFor(userId, tables)`: a refresh must not
      overwrite a local edit still queued (profile, goal weight do this).
      5xx / 429 / PGRST00x throw `ServerUnavailable`: kept without using an
      attempt, sync backs off (only real rejections count toward the 5).
    - Deletes are always recorded (`recordDelete`), synced or not.
  - Profile: `ProfileRepository.changes` follows the profile's CacheStore key,
    so every `ProfileCubit` instance (dashboard, router pages) shows an edit
    made anywhere (account details, onboarding, weight logging, refresh).
    Read profiles via `state.shownProfile`, never one state subclass.
  - `HabitEvents` (`core/events`) broadcasts "something was logged" (water,
    meal, activity, mood, weight, sleep); reminders, widgets and the Home tab
    listen. Not for sync pulls (reminders treat any event as done today).
- **Backend:** Supabase (auth, Postgres + RLS, storage, realtime, pg_cron,
  edge functions). Firebase: FCM push and Crashlytics (Android). Health
  Connect / HealthKit via `health` (read-only everywhere).
- **Bootstrap:** `lib/main.dart` (Supabase, DI, push, reminders, sync,
  foreground task init; global BlocProviders: Auth, Onboarding, ScreenTime,
  Settings; theme mode from `SettingsCubit`; `DevicePreview` only when
  `!kReleaseMode`; `debugPrint` is a no-op in release so server/health text
  never reaches logcat; the Supabase session lives in
  `SecureSessionStorage` (`core/config/secure_session_storage.dart`,
  Keystore-backed; moves an old prefs session over; the widget engine uses
  it too). Mapbox telemetry is switched off in `MainActivity`
  (reflection: the SDK isn't on the app's classpath).) `SleepCubit` is provided by the dashboard only (it reads
  the signed-in user's nights; it never prompts for Health Connect). Pages pushed
  through the router can't see dashboard providers: pass cubits as `extra`
  or keep them global.

## Input, sanitising and errors (apply everywhere)

- `lib/core/utils/input_rules.dart` is the single source:
  - `InputLimits`: text lengths (name, username, email, password, search,
    short text, note, chat message, city) and ranges (height, weight, age,
    water, calories, grams, steps goal, sleep goal).
  - `InputFormatters.text(max, multiline:)`: blocks invisible/control
    characters (but keeps ZWJ/ZWNJ/LRM/RLM: emoji sequences and Indic or
    Persian text need them), line breaks on single-line fields, and caps
    length by characters (never `substring` user text).
  - `sanitizeText` / `sanitizeOptional`: clean typed text before saving or
    sending it anywhere (server, AI, prefs). `parseNumberInRange` for typed
    numbers (accepts `,` decimals, rejects NaN/out of range).
  - `userMessage(error, fallback:)`: the only way to turn an exception into
    user text (offline, timeout, auth, Postgres, function errors).
- Message style: short plain sentence that says what happened and what to do,
  sentence case, no exclamation marks, no technical words, about 60
  characters max (e.g. "Couldn't save your weight. Try again."). Never show
  `e.toString()` to users; log it.
- `AppTextField` always blocks invisible characters (and line breaks when
  single-line); `.integer` / `.decimal` cap at 7 characters, one decimal
  separator, comma becomes dot.
- Feature rule files (pure, unit-tested; extend these instead of inlining
  checks): `auth/domain/auth_rules.dart` (email, password, login id),
  `profile/domain/profile_rules.dart` (name, strict DOB 13-120, height/weight),
  `food_scanner/domain/nutrition_sanity.dart` (clamps server/AI/OCR
  nutrition, portions, barcodes), `dashboard/domain/tracker_input_rules.dart`
  (water, weight, sleep entry 30 min-18 h, goals),
  `reminders/domain/reminder_rules.dart`,
  `activity_tracking/presentation/utils/activity_target_rules.dart`,
  `SupportTicketRules` (`help_support/domain/entities/support_ticket.dart`).
- Load errors: `kLoadErrorMessage` (`core/utils/load_timeout.dart`) +
  `LoadErrorView`. Release builds show `AppErrorFallback` instead of the red
  error screen; unknown routes show a calm page with "Go to Home".
- Guard every submit against double taps, check `mounted` after `await`,
  and never emit from a closed cubit (cubits override `emit` with an
  `isClosed` check).
- Reloads keep data on screen: don't emit a Loading state when one with data
  is already shown (MealLogBloc, DietPlanCubit, ScreenTimeCubit); a failed
  refresh keeps the data and reports a notice. Cap long futures with
  `withLoadTimeout()` (AI pages: 60 s).
- Crash reporting (`core/monitoring/crash_reporter.dart`): `safeError` turns
  Postgrest/Function/Auth exceptions into code-only errors (their details
  carry row data = health data); Flutter framework errors are non-fatal;
  every `onAuthStateChange` listener uses `.handleError` (offline token
  refresh errors are not crashes).
- Server side mirrors the limits: `20261016_input_constraints.sql` (CHECK
  constraints added `NOT VALID`; run its commented checks, then `VALIDATE`)
  and `supabase/functions/_shared/validate.ts` in every edge function. Sync
  sends rows the server refuses (check/length violations) one by one and
  keeps the rejected ones on the device only, so one bad row can't block a
  table. Clamp numbers coming back from AI/servers before saving.

## App shell

`features/dashboard/presentation/pages/dashboard_page.dart` hosts the five
tabs with the floating `AppBottomNav`: 0 Home (`_HomeTab`), 1 Scan
(`FoodScannerPage`), 2 Vita (`VitaHomePage`), 3 Arena (`CommunityHubPage`),
4 Profile (`ProfilePage(onOpenArena:)`). While a workout is under way,
`ActiveWorkoutBar` (`activity_tracking/presentation/widgets/
active_workout_bar.dart`) floats above the nav on every tab (in the
Scaffold's `bottomNavigationBar` slot, so tabs' bottom padding clears it):
the timer's type and live time / Paused (opens `openWorkoutTimer`), or
"Workout stopped" for a GPS checkpoint left by a closed app (opens
`activity-tracking`, which offers Resume / Save / Discard); test
`test/features/activity_tracking/active_workout_bar_test.dart`. Launcher
shortcuts (long-press the app icon: Start workout, Scan food, Water;
`core/services/launcher_shortcuts.dart`, `quick_actions`; icons are
adaptive drawables `res/drawable/shortcut_*.xml` = the widget glyph on the
tracker accent, kept by `res/raw/keep.xml` from resource shrinking) open
through
`HomeWidgetService.openWhenReady`, like widget links. It owns the per-session cubits
(water, sleep, trends, activity goals, gamification, notifications, stress,
diet plan, profile), shows award snackbars, and prompts Google users to
confirm a username. `_HomeTab` re-reads every card each time it is shown
again (`refreshOnShow`), on resume, on `HabitEvents` (notification and
widget logs, Health Connect imports) and on `SyncService.pulled`. Only the
dashboard's `PopScope` handles back for tabs (a tab's own PopScope would
make one back press skip two tabs).

## UI system (follow it; Figma is the source of truth)

- Tokens: `core/theme/app_colors.dart` (`AppColors`, tracker accents
  `track*`, `stressLevels`, `scoreBonus`...), `app_dimens.dart` (`AppDimens`
  spacing/radii/sizes, `AppShadows`, `AppDurations`), `app_text_styles.dart`,
  `app_theme.dart` (`VitalUpColors` extension). `design/figma_tokens.md` maps
  them to Figma. Font: Nunito (SIL OFL; replaced SF Pro Rounded, whose
  Apple licence doesn't allow Android), weights 300-700 subset to Latin +
  punctuation + currency (`assets/fonts`, widgets use `res/font/nunito_*`);
  captions use JetBrains Mono bundled in `assets/google_fonts` (runtime
  fetching off in `main.dart`). Figma must use Nunito too. Arrows and
  geometric symbols aren't in the subset (system font fallback).
- Lookups: `context.colors`, `context.text`, `context.vColors` (glassFill,
  glassBorder, grayText, primaryFill, track, success, warning, termsLink,
  `accentText` = primary as readable text, deeper in light mode...),
  `context.gutter` (16dp), `context.w(x)`, `context.safePadding`
  (`theme_context.dart`, `core/utils/responsive.dart`).
- Contrast: never use `colors.primary`, `rankGold` or `streak` as text
  (about 2:1 on light); use `vColors.accentText` / `onSurface` and keep
  brand colours for fills, rings and icons. Dark `grayText` is #A3A3A3.
- Text size: honour the system setting, capped at 0.85-1.5 (`ResponsiveTextScale`) through `AppTextScaler`
  (`core/utils/responsive.dart`): body text gets the full factor, larger
  styles less (Android 14 curve, every platform). Size boxes with
  `context.textScaled(x)` (body rate, never below `x`), never
  `textScaler.scale(height)`. From 1.2 (`context.isLargeText`)
  `TrackerFigureRow` / `AdaptiveRow` have two a row; bottom nav labels
  stop growing at 1.2. Home cards never switch on `isLargeText`: each one
  reflows only when its own content stops fitting (so 1.15 and 1.25 look
  alike), see the Home notes below.
  Card figures use `AppTextStyles.metric` at one size everywhere:
  `TrackerProgress` always puts the goal on its own line ("of 8h": `formatDashboardDuration` drops "0m" everywhere, "7h 12m", "30m"), so
  side-by-side tiles read alike; the mood label wraps to two lines.
  Half-width tiles show a met goal / today logged as a check on the
  badge corner (`_DoneMark`), never beside the title, so it shows at any
  width or text size.
  `TrackerCard` centres its child in a fixed-height slot (tile pairs) and
  takes its natural height otherwise (pass the content, never `Expanded`);
  stacked tile pairs have no fixed height. Home reflows by fit, never by
  one text-size switch, and adapts content before layout: card figures
  use `figureSpan` (number in the metric style, unit small grey: "72.4
  kg", "7h 12m"); a `TrackerQuickAction` drops its icon when the label
  wouldn't fit whole with it; a tile's done check gives way to its title;
  rings grow like the metric style (`metricGrowth`), not body text. Only
  then: tile pairs stack when a tile is under `dashboardTileMinWidth`
  (130dp, room for "229.9 lbs") x `metricGrowth` (360dp stacks at 1.5,
  not 1.3); button pairs stack when a label wouldn't fit whole
  (`TrackerQuickAction.widthFor`); rings go above their details when
  details would get under 124dp body-scaled; the Today card goes 2 x 2
  when four columns would cut a label (360dp at 1.0 does); the insight
  button (sized to its label) moves under the message when the message
  would get under 160dp. Home header: greeting on a grey `bodyMedium`
  line, first name under it in `headlineSmall` (greeting alone when
  there's no name).
  Rows of 3+ stats use `AdaptiveRow` (`core/widgets/adaptive_row.dart`:
  two a row at large text or under 72dp a column); Home tile pairs are
  `TrackerTilePair`; tile headers move the status chip under the title
  when both don't fit; buttons grow with text; `TrendBarChart` sizes its
  label rows from the line height and picks one date form that fits every
  bar ("Mon 12 Oct" > "Mon 12" > "M 12"). One bar is selected (today by
  default): coloured, its value in the row above all bars; the rest grey.
  A tap selects a bar, a second tap goes back to today; bars use the full
  width and the goal line is named in a legend under the dates ("Goal 10K",
  "Limit 2h"). Detail pages use
  `TrendChartCard` (title = `TrendRange.caption` "Last 7 days" over a grey
  caption = `TrendRange.detail` (activity: "Steps · each day"), compact
  `TrendRangeToggle` beside it or wrapped under it when both don't fit;
  chart, divider, `TrendStatsRow`) for the same spacing everywhere.
  Every tracker detail page (`TrackerDetailScaffold`, `ActivityGoalsPage`)
  has History in the header (`TrackerHeaderActions`: the page's own
  action, then History) and "See all" on its log section.
  Every history entry, on detail pages and history pages alike, is a
  `LogHistoryCard` (`core/widgets/tracker/log_history_card.dart`: tinted
  icon badge, title (never cut), grey subtitle (time, source), main value
  on the right (moves under the title when the title would get under
  140dp), grey bin that asks first (`deleteNoun`), optional note, optional
  `LogFigure` columns under a hairline). `ActivityHistoryCard` and
  `MealLogCard` (`food_scanner/presentation/widgets/meal_log_card.dart`)
  build on it. History lists (`TrackerLogsPage`, meal and activity
  history) group by day with `groupLogsByDay` + `LogDayHeader` (day via
  `formatLogDay`, optional total: water ml, meal kcal, activity count;
  `TrackerDetailScaffold.daySummary`). Test:
  `test/features/dashboard/tracker_detail_layout_test.dart`
  (`HOME_SHOTS=1` writes `build/detail_shots/`). Tests: `truncatedTexts(tester, previews:)` in
  `test/helpers/pump_app.dart` lists cut, clipped or too-wide text; every
  largest-text page test and `test/core/widgets/text_fit_test.dart` expect
  it empty (only free-text previews allowed).
- Tappable vs static (whole app): anything that opens a page or sheet
  ends in `AppChevron` (`app_card.dart`: grey, iconMd; the only card/row
  chevron): `AppCard(onTap:, showChevron: true)` draws it centred at the
  trailing edge, rows (`AppListTile`, `LogHistoryCard` with `onTap`,
  `TrackerCardHeader`, rank and
  award rows) draw their own. Cards that pick something keep their radio /
  checkbox / "Use" and no chevron; grid tiles (badges, shortcuts, quick
  log, friend chips) are tappable by shape. Static cards show no chevron,
  ripple or accent link text. Text links ("See all ›") keep their accent
  chevron. `AppChevron` takes `AppChevron.width` (14dp: the glyph's
  blank side is drawn into the padding, so the arrow lines up with the
  content edge). Half-width Home tiles show it on the title's line at
  every tested size; only a title that couldn't fit beside it would move
  under the badge row (`TrackerTilePair` decides for both tiles,
  `_TileScope.titlesUnder`; never with today's titles).
- Rules: no hardcoded colours/sizes, 16dp gutter, no emojis (Material/SVG
  icons; icon assets are supplied by the user, never created; `GameIcon`
  falls back to a Material icon when an asset isn't bundled, without
  trying to load it: `BundledAssets` reads the asset manifest at launch,
  since failed SVG loads report uncaught errors; community icons
  `assets/icons/communities/{global,local,strength,dieting,mindful}.svg`
  aren't supplied yet), Home is health-first
  and calm, gamification lives in Arena, rewards are quiet (snackbars).
- Header buttons are one set: 48dp flat circles. `BackIcon` = neutral
  (glass fill + hairline, arrow in `onSurface`), `AppHeaderAction` = cyan
  tint + border with an `accentText` icon. Only over media (the scan
  camera) is the back button `elevated` (translucent white + shadow);
  `RoundIconButton` (solid, shadow) is for map / timer screens.
- Core widgets (`lib/core/widgets`): `AppScaffold` (background, header,
  scroll, `onRefresh`, `bottomBar`), `AppPageHeader` + `AppHeaderAction`,
  `AppSectionHeader`, `AppCard` (glass card; `AppIconBadge`,
  `AppProgressBar`, `AppCaption`, `AppInfoNote` live in `app_card.dart`),
  `AppListGroup` + `AppListTile`, `AppSegmentedControl`,
  `AppPrimaryButton`/`AppSecondaryButton`, `AppTextField` (+ `.integer`,
  `.decimal`, `AppDropdownField`), `UserAvatar`, `LoadErrorView`,
  `VitalUpLoader`, `AppScoreRing`, `FitText` (text that shrinks to fit
  down to `AppTextStyles.minFontSize` 12 or 75% of a larger style, then
  ellipsis; use it instead of `FittedBox` around text). It is built on
  `MeasuredLayoutBuilder` (`core/widgets/measured_layout_builder.dart`), a
  LayoutBuilder that reports intrinsic sizes, so it works inside
  `IntrinsicWidth`/`IntrinsicHeight` (a plain LayoutBuilder throws there).
  `AppSegmentedControl` sizes segments by label (plus a shared base) and
  keeps labels on one line. Numbers in tight
  spots use `formatCompactCount` (`core/utils/number_formats.dart`:
  exact below 10,000, then "12.5K"). Tracker kit in `core/widgets/tracker/`:
  `TrackerMetric` enum (label, icon, colour, route per metric), `TrackerCard`,
  `TrackerFigureRow`, `TrackerStatusChip`, `TrackerQuickAction`,
  `TrackerRing`, `TrackerPrompt`, quick-log hub. Sheets/dialogs/snackbars:
  `core/utils/smooth_ui_helper.dart` (`showAppBottomSheet` pads for the
  keyboard; `showSmoothDialog`, `showSuccessSnackBar`, `showErrorSnackBar`).
- Home sections: `AppSectionHeader` ("Today" with a date `note` and
  History, "Nutrition & activity", "Body & wellbeing"); card titles are
  not repeated as section titles. Tracker labels are sentence case.
  `test/features/dashboard/home_cards_screenshot_test.dart` renders the
  Home feed (typical, longest values (lbs, 10h 45m, "Very stressed") and
  empty data; 360/384/412 dp; text 1.0 to 1.5; dark) and fails on any
  cut text, overflow or text `FitText` had to shrink (`shrunkTexts`); `HOME_SHOTS=1` writes PNGs to
  `build/home_shots/` (keep its `homeFeed()` in step with `_HomeTab`;
  the insight shown depends on the time of day).
- Home Nutrition and Activity cards (the MVP cards) lead with a
  `TrackerHeroRing` inside `TrackerHeroLayout` (ring beside the details,
  centred above them at large text or when details would get under
  150dp). Nutrition: kcal left (or eaten / over) in the ring, macro bars
  beside it, one `TrackerSummaryLine` ("1,240 of 2,000 kcal · 2 of 4
  meals"), Log meal + Diet plan. Every bar on Home is `AppProgressBar` at
  its defaults (8dp, grey `vColors.track`) and rings use the same grey
  track; don't give one card thinner or tinted bars.
  Home spacing: every card's content sits 16dp from its edge (Today card:
  12 + 4dp figure tap padding); 12dp between cards, between a card's
  header, body and actions, and between rows/columns of figures or goal
  lines; 16dp ring-to-details; 6dp small label to bar, 8dp big figure to
  bar and bar to caption; 24dp between sections. Stick to 4/8/12/16.
  Home type tiers: card title `titleSmall` (16/500); hero figure
  `AppTextStyles.metric` (light) with its "of goal" line in grey
  `bodyMedium`; compact figures (Today card, rings, Screen time row)
  `titleMedium` w600 with 12 grey captions; bar rows (`TrackerBarRow`:
  macros, secondary goals) name `bodyMedium` + figure grey `bodySmall`;
  eyebrow labels and summary lines grey 12. No new sizes or weights.
  Figures never round up (`formatMl` shows "1.25 L" / "2.96 L" exactly,
  `GoalMetric.format` and percents round down) so
  progress never reads as the goal before it's met; goals of 0 are no
  goal (`calorieGoalFor`, `macroTargets`); weekly goals use
  `TrackerStatus.weekPace` and say "this week"; "1 workout"; sleep and
  water nudges wait for 4 am / 7 am; water Undo removes the drink its
  snackbar named (`WaterIntakeLoaded.addedLogId`). Edge cases:
  `test/features/dashboard/tracker_edge_cases_test.dart`.
  Home icons: asset SVG when one exists (`TrackerMetric.iconAsset` /
  `logIconAsset`, `TrackerIcons`: edit, add (plus), goal (target), plan
  (vita); `GoalMetricIcon`: steps, workouts (barbell), calories (flame)),
  Material otherwise (play, retry, review, chips, chevrons). An action
  never reuses its tracker's icon (log water / sleep / weight = plus).
  Tints: `context.iconTint(accent)` (same hue, 3:1 on a card in either
  theme, `AppColors.readableOn`); glyphs inside `AppIconBadge` use
  `AppIconBadge.glyphColor` (3:1 on the tinted circle); never tint an
  icon with a raw accent. `test/core/theme/icon_contrast_test.dart`. Activity: the ring is that goal's % with one
  goal; with several, "1 of 2 goals met" over the average progress (the
  status chip uses the same average); beside it `ActivityGoalsState.headline`
  (daily steps, else the first goal) with its figure; met goals get a
  check in their `TrackerBarRow`;
  up to two more goals as lines (`GoalMetricIcon`: SVG when the
  metric has one, steps and workouts), Start activity.
- Dashboard cards: `features/dashboard/presentation/widgets/`
  (`today_summary_card.dart` is the Today hero with one insight;
  `dashboard_card_header.dart` has `DashboardCardHeader`,
  `formatDashboardDuration`; `trend_widgets.dart` has `CardLink`,
  `TrendRangeToggle`; `tracker_log_sheets.dart` has the quick log sheets).

## Features

Route names are GoRouter `name`s.

- **auth:** routes `splash`, `onboarding` (intro carousel), `login`,
  `forgot-password`, `verify-otp`, `reset-password`, `reset-completed`.
  Sign in by email or username (`login_email(username, password)` RPC: returns
  the email only with the right password, throttled; never expose emails by
  username), sign up with
  email OTP (taken email/username checked via `email_registered` /
  `signup_username_available` RPCs, never by reading `profiles`), password reset by OTP, Google (`signInWithIdToken`); no Apple.
  Splash -> `dashboard` / `health-onboarding` (by `hasCompletedOnboarding`:
  local flag, then `user_health_data.onboarding_completed` (skipped
  without a network, no automatic retries, 5 s timeout),
  offline defaults to true) / `onboarding`. Sign out (Profile) first
  uploads anything pending (`SyncService.pendingCount`, button spinner) and
  warns "Sign out anyway" if some entries couldn't be backed up; then
  `PushService.unregister` -> `SyncService.sync` ->
  `AccountService.clearLocalUserData` (`SyncService.stop` first; logs,
  workouts (and a running workout timer), reminders, onboarding answers, backup markers and queued
  server writes, goals wiped; settings kept). Signup terms: `terms_dialog.dart` + legal links.
- **onboarding:** one page, `OnboardingFlowPage(initialStep:)`
  (`presentation/pages/onboarding_flow_page.dart`); every `health-*` step
  route builds it at that step and `health-onboarding`
  (`OnboardingEntryPoint`) calls `OnboardingCubit.reload()` (the cubit is
  global: a new account must not see the last one's answers) and opens the
  saved step (`OnboardingStep` enum in `domain/onboarding_step.dart`: ids
  saved in `onboarding_current_step`, unknown ids start over). Steps (About
  you, height, weight, diet, goal, activity, privacy) are widgets whose
  state mixes in `OnboardingStepState.submit()` (check + save on Continue;
  false stays). Shared-axis slide between steps, fixed header (back,
  segmented `OnboardingProgress`, Skip on middle steps), pinned Continue,
  staggered `OnboardingReveal`, `OnboardingChoiceTile` for single choices
  (`presentation/widgets/onboarding_widgets.dart`); height / weight / target
  use `ValueRuler` (`labelFor` gives "5 ft" marks); ends on a "You're all
  set" screen listing the user's goals (calories + starting goals, Adjust
  opens `my-goals`). Finish saves `StartingGoals`
  (`domain/usecases/starting_goals.dart`: water 35 ml/kg in 250 ml steps,
  1.5-4 L; steps / weekly workouts by activity level; sleep 8 h, 9 h under
  18; skipped answers keep the defaults) through `StartingGoalsWriter`
  (`data/starting_goals_writer.dart`), which never replaces a goal already
  saved (by hand or a restored backup) and saves screen time as no limit.
  Users who finished onboarding before keep the defaults. System back on a later step goes back
  a step. Weight stays empty when skipped (no made-up 70 kg). The privacy
  step's analytics and health sync switches are the real settings
  (`SettingsCubit`, `HealthImportService.connect`); reminders turn on after
  the save. `OnboardingCubit` keeps answers in prefs `onboarding_*`
  (device-wide, cleared on sign-out), upserts `user_health_data` via
  `PendingWrites` (works offline). Google users choose a username here
  (`set_username`, `username_available`). Test:
  `test/features/onboarding/onboarding_flow_test.dart` (`HOME_SHOTS=1`
  writes `build/onboarding_shots/`).
- **profile:** `ProfilePage` (identity card -> Account details, one-line Arena
  strip, `HealthSnapshotCard`, Health and Account groups, Sign out),
  `AccountDetailsPage` (`account-details`; name, `UsernameInput`
  availability check, DOB ddMMyyyy, gender male/female, read-only email,
  export/delete), `HealthDetailsPage` (`health-details`; per-section edit
  sheets; the Body sheet has Height / Weight tiles over one `ValueRuler` for the selected one, a moved weight scale logs a weigh-in through `WeightService`; also `showWeightEntrySheet`; units from
  Settings). Helpers: `presentation/utils/body_metrics.dart`. Pass the
  Profile tab's `ProfileCubit` as `extra` (`_withProfileCubit` in the
  router); `ProfileState.shownProfile`; a failed save emits `ProfileError`
  then `ProfileLoaded(previous)`. The profile's own email comes from the
  session (`profiles.email` isn't readable by clients).
- **account:** `AccountService` (`delete-account` function, then wipes the
  device), `DataExportService` (zip of CSV + JSON via share sheet; profile
  by named columns, full points history paged by `fetchEvents`; `app_data.json`
  = settings, goals, Vita history, workout notes, diet plan; `arena.json` =
  stats, badges, reports, communities, friends, awards, challenges,
  notifications, weekly summaries; the zip is deleted after sharing).
  `clearLocalUserData` also deletes meal photos, temp files (picker/camera
  photos, exports, reports, share_plus copies) and `vita_*_<uid>` history.
- **settings:** Appearance, Units, Notifications, Connected (Health Sync),
  Privacy & security (app lock, leaderboard visibility sheet, AI coach data,
  "Share usage analytics"), About.
  Units also has Distance (km / mi, `DistanceUnitNotifier`, pref
  `activity_distance_unit`, read by the workout screens).
  `SettingsEntity`: themeMode, units (`cm`/`in`, `kg`/`lbs`; height defaults to `in` = ft / in), notification,
  health-sync and analytics flags (`settings_analytics_enabled`, read by
  `AnalyticsService.init` before DI; off clears the user id and data).
  Analytics sends only automatic events: never log health figures, food
  names, free text or Health Connect data.
- **about:** rate (Play id from `PackageInfo.packageName`), feedback mailto
  `support@vitalup.live`, Legal links (`LegalLinks`).
- **goals:** `my-goals` gathers every goal (plan, weight, activity, water,
  sleep, screen time). Water, sleep, screen time and weight goals can be
  removed: the goal sheet's "Remove goal" (`onRemove`, asks first with
  `removeMessage`) saves 0 in the goal pref (`clearDailyGoal`, `clearGoal`,
  `clearDailyLimit`; weight `clearTarget` nulls `target_weight`), so the
  getters return null (a missing pref is still the default). Without a
  goal: cards and widgets show the amount with "today" / "last night", no
  bar or ring, "Logged" instead of Behind; no chart goal line, no sleep
  debt, no water nudge; `waterGoalMet` is false (no Arena water points or
  water badge days, the remove dialog says so); the weekly summary shows
  "Water logged" days. Test: `test/features/dashboard/remove_goal_test.dart`
  and the `nogoals` Home scenario. Goal sheet `showTrackerGoalSheet` (`tracker_sheet.dart`):
  weight uses `ValueRuler` (leave as is); water / screen time use
  `GoalSlider` and sleep `SleepGoalDial` (`core/widgets/tracker/goal_controls.dart`:
  grey track, metric accent the only colour, sheet-coloured knob with an
  accent ring that lifts while dragged, recommended range as a light band,
  square-root scale for water / screen time, labels dropped when crowded,
  grey `GoalNote` under it; quick picks are wrapping `GoalPresetChip`s
  (tint + hairline when selected, label in the text colour). Haptics match
  `ValueRuler` everywhere: selection click + `UiSounds.tick` per step,
  firmer on labelled marks; the ruler and controls give their own, so
  callers pass a setter without haptics; +/- and chips give a selection
  click). Test:
  `test/core/tracker/goal_controls_layout_test.dart` (`HOME_SHOTS=1` writes
  `build/goal_shots/`).
- **dashboard trackers:** routes `water-trends`, `sleep-trends`,
  `screen-time-trends`, `stress-trends`, `diet-progress`, `weight-trends`.
  `TrendsService` / `TrendCubit<T>` are shared by cards and trend pages.
  Water: Isar `WaterLogCache`, goal pref `daily_water_goal` (0 = no goal). Screen time:
  pref `daily_screen_time_limit_min` (0 = no limit: new users start there,
  `getDailyLimitMinutes()` is null, the card shows today's time with "Set
  a limit"; never saved = the old 4 h default), Usage Access permission,
  usage channel.
  Android keeps usage events ~10 days (`ScreenTimeService.systemDays`), so
  every finished day with usage is saved on read (pref
  `screen_time_days_v1`, 400 days, top 10 apps) and read from there after;
  `history()` = system days + saved ones (the history page); wiped on
  sign-out. Test: `test/features/dashboard/screen_time_history_test.dart`.
  Mood/stress: `StressCheckInCubit` -> `VitaRepository`.
- **sleep:** log sheet `SleepLogSheet` uses `CircularSleepClockPicker`
  (`core/widgets/circular_sleep_clock.dart`: drag moon / sun, or the arc
  to move the whole night; handles stop at 30 min / 18 h (`clampSleepGap`,
  the save rules; pushed past each other they stick to the side they came
  from); the middle shows the sheet's figure (`duration:` = Save's real
  elapsed time on the night's dates, so a daylight-saving night reads 7 or
  9 h on both), so dial, middle and Save always agree; a future wake-up shows its
  error live and turns Save off; opened before 7 am it starts at wake =
  now, bed = goal earlier; a phone estimate keeps its time asleep (dial,
  Save, saved `asleep:` and source) until the times change; band shades night (sleep) to morning
  (primary), handles are flat sheet-coloured circles inside the band ends,
  the dragged one larger with a glow; middle shows the duration and "Goal met" /
  "35m under your 8h goal" from `goal`, shown only when it fits the dial;
  bed / wake cards: icon + label + pencil over the time, side by side at
  every tested size (stack only if a time can't fit half the width)). A touch on a handle or
  the band wins the gesture at once (`_GrabPanRecognizer`), so vertical
  drags never scroll or close the sheet. The sheet doesn't scroll
  (`TrackerSheet(scrollable: false)`): the clock takes the room left (max
  280dp, min `minClockSize` 200dp); only if 200dp didn't fit would the
  sheet grow by the difference and scroll (360x640 at 1.5 still fits: keep the subtitle one line there, "Drag to
  set your night", and the day chip compact). `test/features/dashboard/log_sheets_screenshot_test.dart`
  checks both sheets (sizes, text scales, dark) and the scale's gestures
  and feedback; `HOME_SHOTS=1` writes `build/sheet_shots/`.
  `SleepService` (dashboard/data/services) merges Health Connect
  nights (win), saved entries (`SleepLogCache`, source `manual`/`phone`) and
  a screen-off estimate (`domain/sleep_detection.dart`, native
  `getScreenEvents`) that the Home card asks the user to confirm. "Going to
  bed" / "I'm up" taps live in prefs (`sleep_bedtime.dart`); evening sleep
  reminders carry "Going to bed", the in-bed notification carries "I'm up"
  (`reminder_actions.dart` handles both with the app closed).
  `SleepService.changes` reloads `SleepCubit`; saving last night emits
  `Habit.sleep` to quiet morning sleep reminders.
  Home card states: estimate (figure + "Estimate" chip, Review = Looks
  right / Adjust; left unreviewed it's saved automatically by
  `saveUnreviewedEstimates` on the next load: yesterday's, and today's
  after 2 pm when it can't change), in bed, prompt, and a
  saved night (done status: "Goal met" or "Logged"; Edit, or Details for
  Health Connect nights).
- **weight:** log sheet `WeightEntrySheet` (`showWeightEntrySheet`): big
  readout over `ValueRuler` (`core/widgets/value_ruler.dart`: drag / fling
  / tap, snaps to 0.1, haptic + `UiSounds.tick` per step, firmer and
  deeper per whole unit, max one per 35 ms of frame time; slider
  semantics), "0.7 kg less
  than 14 Oct · 2.4 kg to your goal", "Type instead" keyboard mode; starts
  at the latest weight, else `BodyWeightSource`, else 70 kg.
  Card and page show the latest weigh-in ever and progress from the first
  (`WeightLatestBuilder`, `weightGoalProgress`: full only at the goal),
  "Goal 65.0 kg"; one `weightGoalReachedKg` (0.5) everywhere.
  `WeightService`, Isar `WeightLogCache` (always kg), mirrored to
  `user_health_data`; goal weight in CacheStore (legacy pref
  `weight_target_kg` fallback).
- **health_report / weekly_summary:** `health-report`
  (`HealthReportService`, clinical text export; page: 7/30/90-day picker,
  one `_ReportSection` card per area with equal `AdaptiveRow` figures,
  share pinned as the bottom bar); `weekly-summary`
  (`WeeklySummaryService`, computed on device; reports time zone via queued
  `set_my_timezone`; server sends a Sunday 18:00 local push).
- **activity_tracking:** `activity-tracking`, `activity-history`.
  One activity screen, two modes: `ActivityTrackingPage` (bloc at page
  level) shows `_ActivityTrackingView` (GPS: map, location service,
  recovery; its logic is unchanged by the modes) for outdoor types and
  `WorkoutTimerPage` (timer cubit) for workouts. Picking a workout on the
  GPS view (tiles or More) switches to the timer; an outdoor tile on the
  timer switches back (`initialType`, wins over the goal's pick). A
  running timer always opens the timer. Route `workout-timer` builds the
  same page with `workout:`; `openWorkoutTimer` pops back to an open
  `activity-tracking` or `workout-timer` instead of stacking. Every
  activity (GPS, timed, logged) shows one `ActivitySummary`
  (`widgets/activity_summary.dart`: type and date, main figure = km or
  time, equal neutral figures, target result) on `ActivityCompletionPage`
  (after GPS and timed workouts alike) and in the history detail sheet.
  Settings follow the type (`ActivitySettingsPage(activityType:)`):
  workouts get a Time (minutes, `WorkoutTargetType.duration`) or calories
  target kept apart from GPS targets (`timerTargetType/Value`, prefs
  `workout_timer_target_*`, cleared after finish or discard, saved on the
  session), no metrics layout or map rows; with none set the timer starts
  with `timerTargetFromGoals` (today's active minutes left, else calories).
  `ActivityType`: five GPS types (`ActivityType.outdoor`: walk, run, cycle,
  trekking, climbing) and workouts without a route (`ActivityType.workouts`:
  strength, yoga, hiit, swimming, dance, sports, other). Stored by name;
  read with `ActivityType.fromName` (unknown -> other). GPS pickers list
  outdoor types only; `session.hasDistance` hides distance/pace for
  workouts. History (`activity-history`) is laid out like meal history (no
  summary card): an All / Outdoor / Workouts `AppSegmentedControl` and a
  search button (type, tag or note) as the first list item, then days
  (`LogDayHeader`) of `ActivityHistoryCard`s (a `LogHistoryCard`: icon,
  type, start time, grey delete button, the tag, then three neutral equal
  columns: km / time / calories, or time / calories / effort). Meal
  history uses `MealLogCard` the same way. Live workout stats
  default to `defaultStatsFor(type)` (steps on foot, pace for runs, speed
  for rides) until the user saves a layout. The GPS screen opens with
  `activityForGoals` (steps goal: walk; distance or calories goal: run;
  else the last GPS activity, then walk) and, with no target set by hand,
  starts with `targetFromGoals` (what's left of today's distance goal,
  else calories goal) in `activity_target_rules.dart`; the old "Daily
  target", "Default activity type", soundtrack and distance-unit settings
  are gone (prefs removed on load). Both workout screens share
  `StartPauseControl` (music / start / settings, slide to unlock, finish /
  lock / pause), `ActivitySelector` above it (walk / run / cycle + More
  with every activity and "Log a past workout", in both modes), the `CountdownOverlay` 3-2-1 on Start
  (countdown also on the timer's settings page) and `WorkoutMusic` + `WorkoutMusicBar`
  (`widgets/workout_music.dart`); both open the same
  `ActivitySettingsPage`; the timer has the GPS view's top (round back and
  history buttons while idle, no title) and its card
  shows live calories (`WorkoutTimerState.caloriesSoFar`, moderate effort).
  Workouts are logged two ways, both through `LogWorkout` (same
  repository, so sync, goals, challenges and badges count them):
  `workout-timer` (`WorkoutTimerPage` / `WorkoutTimerCubit`, extra
  `ActivityType`; wall-clock `WorkoutTimer` in pref `workout_timer_v1`, so
  it survives app kills with no foreground service; caps at 6 h; unlike a
  GPS workout it can be left while running (Back or the down arrow "Leave
  it running"; its music keeps playing; `ActiveWorkoutBar` on Home and the
  tray bring it back); controls need a slide to unlock (`SlidingButton`);
  the tracking page reopens it; ongoing tray notification with a system
  chronometer and Pause / Resume (`LocalWorkoutTimerNotifier`, channel
  `vitalup_workout_timer`; actions `workout_pause` / `workout_resume`
  handled by `handleWorkoutTimerAction` in both the foreground handler and
  `reminderActionBackground`. On Android the buttons always run in a
  separate engine, even with the app open, so that isolate pings the app
  through `WorkoutTimerStore.notifyOtherIsolates` (IsolateNameServer;
  the app reloads prefs); actions use `cancelNotification: false`; the page
  also reloads on resume. Notification taps go through `openWorkoutTimer`
  (brings an open timer back instead of stacking a second one, so Back
  returns to the page below)) and `showLogWorkoutSheet` (history header +,
  More activities dialog). Rules in `domain/services/workout_log_rules.dart`
  (1 min-6 h, past only, 30 days back; calories = MET x `WorkoutIntensity`
  factor x weight x hours). Intensity is stored on the session (Drift v7).
  `ActivityTrackingBloc` / `ActivityHistoryBloc` per page; sessions in Drift;
  notes/tags pref `activity_annotations`; workout prefs
  `core/preferences/workout_prefs_notifier.dart`. The bloc checkpoints the
  open session to Drift every 30 s / on pause / on hide and marks it in pref
  `activity_in_progress_v1`; after an app kill the tracking page offers
  Resume / Save / Discard (`WorkoutRecoveryService`, pure rules in
  `domain/services/workout_checkpoint.dart`; older than 12 h is saved at
  startup; if reading it fails, startup closes nothing rather than the
  workout to resume). At launch only (`main()`, never the widget engine,
  which also runs `initDependencies`), `clearStaleWorkoutNotifications`
  stops a GPS workout's leftover foreground service and cancels the timer
  notification when no timer is saved; deleting a session from history
  clears its resume point (`DeleteActivitySession.afterDelete`). GPS runs in a
  `flutter_foreground_task` location service (no battery exemption;
  `ForegroundServiceManager`). Its notification has Pause / Resume
  buttons: the task isolate forwards presses with `sendDataToMain`,
  `ForegroundServiceManager.buttonPresses` delivers them to the tracking
  page, which runs the same pause/resume as its controls (audio, voice
  coach); `update(text, paused:)` picks the button. Only works while the
  app process lives (the workout itself runs in the app isolate). That
  service is for workouts only: it's declared `location`, and starting it
  for anything else (audio downloads did) crashes on Android 14+ without
  location permission. Downloads therefore use no foreground service:
  workout audio goes through `background_downloader` (WorkManager jobs,
  "Downloads" channel with progress; `InAppAudioDownloader.start()` at
  Home's deferred start settles ones that finished with the app closed;
  its `dataSync` UIDTJobService is stripped in the manifest), and the
  offline map pack shows progress via `MapDownloadNotifier` (channel
  `vitalup_map_downloads`) while the process lives. `getSessions` / `GetActivityHistory` load no GPS
  routes unless `withRoutes: true` (only the data export asks); always
  pass `since:` (track points are read per session id in SQL). The
  tracking page updates the route/puck annotations in place and holds map
  calls while hidden. The activity calendar reads a month at once
  (`DailyMetricsCollector.collectDays`).
  GPS calories: `estimateGpsCalories` (`domain/services/activity_calories.dart`,
  ACSM: 1 MET of rest for the active time + `kcalPerKgPerKm` x km +
  `kcalPerKgPerClimbMeter` x climb; climbing uses MET x time; never drops
  as time passes). Weight for all workout calories comes from
  `BodyWeightSource` (latest weight entry, else profile weight, else 70 kg;
  auth metadata has no weight). `TrackPointFilter` re-anchors after 3
  consistent fixes that all jump from the last accepted one (bad cold-start
  fix); the bloc then moves the first route point instead of drawing a spike.
  Offline maps (Oct 22; GPS, timer and saving never need a network, only
  the map): `OfflineMapService` (`data/services/offline_map_service.dart`,
  state `OfflineMapsState` ValueNotifier; one queue, one download at a
  time, any network incl. mobile data). "Around you" (id
  `local_workout_region_10k`, 20 x 20 km, pref `offline_map_auto_v1`
  switch) from Home's deferred start (`prefetchAtStartup`: only with
  location already allowed, last known position; also resumes stopped
  downloads) and the tracking screen's first fix (`ensureAround`, skipped
  when any complete area `covers` the spot with 3 km to spare). Picked
  areas (max 10): `offline-maps` (`OfflineMapsPage`, from Activity
  settings > Offline maps; status, progress, Resume, delete asks first)
  and `offline-map-picker` (`OfflineMapPickerPage`: the square in the
  frame downloads, pan and zoom to choose; opens at zoom 13 on the last
  known fix with the location dot, then eases to a fresh fix unless the
  user has moved the map; 2-30 km a side
  (`OfflineMapRules`), size from `estimateBytes`, needs a connection).
  Downloads cut off resume when `ConnectivityService.onlineChanges` goes
  online, or at the next start; the SDK can't cancel one, so a running
  area has no delete. Areas are Mapbox tile regions with metadata (lat,
  lng, radiusKm, kind auto/saved, name, savedAt), zoom 10-16, one shared
  `MAPBOX_STREETS` style pack (deleted with the last area); the map
  widgets load that style directly. Sign-out deletes every area
  (`AccountService` `clearOfflineMaps`). Offline with no area here, the
  tracking screen shows `OfflineMapNote` under the stats. Test:
  `test/features/activity_tracking/offline_maps_test.dart`.
  Timed workouts speak through `TimerVoiceCoach`
  (`services/timer_voice_coach.dart`, started at Home's deferred start and
  by the timer page): app-wide, it follows `WorkoutTimerStore` (also the
  notification's Pause / Resume and a timer left running) and every 5 s
  picks a `timerCue` (`domain/services/timer_coach_rules.dart`: goal
  reached > halfway > every 5 min time, calories, left of the goal); the
  page says the finish summary and calls `skipNextChange` before Finish's
  own pause. Test: `test/features/activity_tracking/timer_voice_coach_test.dart`.
  Voice coach (`VoiceCoachService`, shared singleton): `init()` once (Home
  deferred start and both workout screens), cues speak with no per-cue
  setup, `stop()` cancels a cue still being prepared; music never silences
  it; the countdown uses it too (a second `FlutterTts` steals the plugin's
  callbacks). Screens stop it on dispose and when leaving the result page.
  Mapbox map with offline packs, pedometer with glitch filtering, BLE
  heart-rate straps (`flutter_blue_plus`), TTS voice coach, music/local
  audio. Gotcha: geolocator has one position stream; cancel the map preview
  stream before a workout subscribes.
- **activity_goals:** `activity-goals` (the Home Activity card's page:
  goals, the selected goal's chart, "Today" as `ActivityHistoryCard`s
  without delete that open `showActivitySummarySheet`). Every goal uses
  the activity accent (`GoalMetricStyle.color`, also on the Today card and
  widgets); the icon tells metrics apart. `ActivityGoalsCubit`, pref
  `activity_goals_v1`, one goal per metric and period; daily resets at
  midnight, weekly Monday-Sunday; steps from `HealthVitalsService` + sessions.
- **health_sync:** `HealthImportService` imports weight and workouts (every
  exercise type: `workoutTypeFor` maps gym/yoga/sports, others -> other) when
  Settings > Health Sync is on, at most hourly, on resume, idempotent (pref
  `health_import_last`). `connect()` also asks for sleep
  (`SleepService.healthTypes`) in the same screen: Health Connect grants
  per type, so Home's sleep card would otherwise prompt again.
- **food_scanner:** Scan tab, `food-scan`, `meal-log-history`.
  `FoodScanBloc` (photo, barcode, search, edit, label OCR, custom food),
  `MealLogBloc`. Isar `MealLogCache`, `OfflineFood` (synced from
  `proprietary_products`), `BarcodeCache`. `scan-food` responses cached
  (`FoodCacheKeys`); barcode falls back to OpenFoodFacts (read only: user
  products are never uploaded there). The camera reads EAN/UPC and GS1
  Digital Link QR codes (`normalizeProductBarcode`, check digit) only inside
  the scan frame (`presentation/utils/scan_frame.dart`, shared with the
  overlay and photo crop); gallery photos are checked for a barcode before
  going to the AI; the camera is let go in the background. Photo scans: 5 a day free, 100 with
  Pro (`get_remaining_scans`); a 429 opens the Pro sheet (`offerProForLimit`).
  Vita chats and AI diet plans show `AiQuotaLine` ("12 of 15 messages
  left today · Get more with Pro"; free users only; Pro link where Pro
  can be bought): `AiQuotaService` (`subscription/data/services`) starts
  from the user's own `ai_usage_daily` row (owner-readable) for today's
  server day (`serverQuotaDay`, IST) and takes `remaining` from each
  `vita-chat` / `generate-diet-plan` answer (0 on a daily-limit 429);
  CacheStore key `ai_left_<feature>_<uid>`. At 0 the chat composer
  locks ("No messages left today"; Pro unlocks it at once). Vita tab:
  the line under "Chat with Vita" and a Pro header action (`vitalup-pro`).
  Diet plans: above Regenerate and under "Create my diet plan".
  Free users see `ScansLeftHint` above Capture ("3 photo scans left today";
  follows `SubscriptionRepository.remainingScansChanges`; at zero a tap
  offers Pro; hidden with Pro or while unknown).
- **diet_plan:** `diet-plan-prefs`, `diet-plan-mode`, `diet-plan-goal`,
  `diet-plan-manual`, `diet-plan-edit`, `diet-plan-result`. `DietPlanCubit`,
  Isar `MealPlanModel` by `dateKey`, prefs `active_plan`,
  `active_plan_preferences`. `generate-diet-plan` (75 s timeout, 3/day free, 20 Pro;
  `instructions` + `basePlan` tweak a plan). The result page asks before
  leaving mid-generation (it would waste a generation).
  Alternatives (Oct 21): every meal comes with up to 2 other dishes
  (`Meal.alternatives`, `MealOption`; Isar `MealOptionModel`, null on
  older plans) in the same AI call. `generate-diet-plan/plan.ts`
  (`node --test .../plan.test.ts`) drops alternatives that repeat a dish,
  name an allergen or are over 25% off the meal's calories (the prompt asks
  10%); totals count main dishes. A swap (`MealAlternativesLink` ->
  `showMealAlternativesSheet` -> `DietPlanCubit.chooseAlternative`) needs
  no AI call: the old dish becomes an option, totals move by the
  difference; the active plan saves at once with its preferences kept (a
  failed save puts the dish back), a new plan waits for "Set as active".
  Editing a meal keeps its alternatives. Vita's snapshot sends main dishes
  only. Tests: `test/features/diet_plan/meal_alternatives_test.dart`.
- **vita:** UI (Oct 21): every page uses `AppPageHeader` (tab "Vita"
  like Arena / Profile, then "Ask Vita", "Health analysis", "Diet plan",
  "Stress guide"), default card padding and 12dp card gaps; Vita's chat
  bubbles are glass (theme-aware), the user's deep teal; suggestions are
  outlined chips shown until the first question; day labels via
  `formatLogDay`; "Clear chat" asks first (`VitaChatCubit.clear`);
  `VitaAvatar` is an `AppIconBadge`; `VitaColors.accent` is never text.
  Stress guide check-in reuses Home's `MoodLevelPicker`. Tests:
  `test/features/vita/vita_pages_test.dart` (1.0 / 1.5, light / dark).
  Chat (Oct 21): a reply outlives the page (`VitaChatCubit._pending`,
  static: saved when it lands unless the account changed
  (`VitaRepository.chatOwnerId`); a chat opened meanwhile shows the
  typing dots); the list is `reverse` (offset 0 = latest) and opens at
  the saved spot via `initialScrollOffset` (pref `vita_chatscroll_<uid>`,
  saved on scroll end and leave; null at the end), so it's in place on
  the first frame; failed messages show "Not sent" + Retry; long press
  deletes a message (asks first; not while a reply is coming).
  `vita-chat` (extra `VitaChatArgs` or initial prompt String),
  `vita-analysis`, `vita-diet-plan`, `vita-stress`. Prefs
  `vita_{chat|checkins|scores|insights}_<userId>` (chat keeps 50 messages,
  history 90 days). `vita-chat` 45 s timeout, last 12 turns sent, chats
  15 / Pro 150 and insights 3 / Pro 20 a day. `HealthSnapshotBuilder` computes numbers on device
  (profile from `ProfileRepository` first, onboarding answers as fallback);
  `StressEstimator` is pure. Stress check-ins: levels 1 very calm to 5 very
  stressed. `HealthVitalsService` only prompts from `connect()`.
  AI consent (`VitaAiConsent`, prefs `vita_ai_consent_v1_<uid>`,
  `vita_ai_health_connect_v1_<uid>`; `ensureVitaAiConsent` shows a short
  first-use sheet; Settings > Privacy & security opens the `ai-coach-data`
  page (`VitaAiDataPage`: switches that save at once, what's sent, who
  gets it)): nothing
  goes to vita-chat or generate-diet-plan before the user accepts, and
  `HealthSnapshot.forAi` drops Health Connect vitals, steps, sleep and
  imported workouts unless "Include Health Connect readings" is on.
  Quota messages show the reset time from `core/utils/quota_reset.dart`
  (server days are IST).
  Scope and abuse guards (`supabase/functions/vita-chat/guard.ts`, tests
  `node --test supabase/functions/vita-chat/guard.test.ts`): Vita answers
  only the user's health data, general health/nutrition/fitness and how to
  use VitalUp; rules go in a real system instruction and the chat as real
  provider turns (`ChatTurn`, `system` / `turns` in `_shared/llm.ts`), the
  snapshot and history are labelled data. Obvious jailbreaks / coding jobs
  get `SCOPE_REFUSAL` with no model call and no quota (patterns are
  high-confidence only: add a false-positive case to the test with every
  new one); a reply the model marks `offTopic`, or one that leaks the
  per-request canary or code, is replaced by the same text (`offTopic:
  true` in the body). Per-minute cap `ai_burst_allowed` (6 chats / 3
  insights, env `VITA_CHAT_PER_MINUTE` / `VITA_INSIGHTS_PER_MINUTE`, fails
  open) answers 429 `too_fast` (app: `VitaException.tooFast`, no Pro
  offer). Transcript capped at 6,000 chars. App how-to questions
  (`asksAboutApp`) also get `APP_GUIDE` (~700 tokens; keep it in step
  with the app and the FAQ).
- **reminders:** local notifications (`ReminderScheduler`, presets in
  `domain/reminder_presets.dart`, smart skip when the habit is done today).
  Notification text: `reminderMessage` (`domain/reminder_copy.dart`, 2-5
  short variants per preset picked by time slot and day, no "Going to
  bed" wording without that button; custom reminders keep their words).
  Large icons: `NotificationIcons.largeIcon` (`core/services/
  notification_icons.dart`: an app SVG in white on the tracker accent,
  cached, 3 s cap for engines that can't draw; also feature tips and the
  in-bed notification). Test: `test/features/reminders/reminder_copy_test.dart`.
  `reminder_actions.dart` has background-isolate helpers (add water,
  save/reset mood, bedtime/wake, read today's water and mood) used by
  notifications and widgets (they also refresh the widgets afterwards).
  Notification action ids: `log_water`, `sleep_bedtime`, `sleep_wake`, `workout_pause`, `workout_resume`.
- **notifications:** `notifications`; `NotificationsCubit` reads table
  `notifications` + realtime channel `notifications:<uid>`; mark-read/delete
  queued offline. `PushService` (FCM; `register_push_token`), no-op without
  Firebase config.
- **feature_tips:** how users hear of features (Oct 22). Notifications:
  `FeatureTipsService` (`data/feature_tips_service.dart`) +
  `LocalTipScheduler` (channel `vitalup_feature_tips`, low importance,
  large icon = the tip's SVG in white on a brand circle, payload `route`,
  routes must be in `notificationLinkableRoutes`). Catalogue and rules in
  `domain/feature_tip.dart` (`featureTips`, `FeatureTipRules.next`: not in
  the first 3 days, at most one a week, each tip once, random time 11:00-
  19:00 local, at least 30 min ahead). Scheduled ahead at Home's deferred
  start (`reschedule`: a planned time that has passed counts as sent;
  a planned tip whose feature got used, tips off, or notifications blocked
  is cancelled). Visiting a tip's `usedRoutes` marks it used
  (`attach(AppRouter.router)` in `main()`, listens to the router delegate).
  Settings > Notifications > Feature tips (pref `feature_tips_enabled_v1`).
  Keep copy short: hook title, one-line body, no emojis or "!".
  In-app: `FeatureTipCard` (`core/widgets/feature_tip_card.dart`; full
  card with action + "Not now", or "Got it" alone; `.compact` one row with
  a close button; `overlay` = opaque over a map or camera), each shown
  until answered once (keys in `presentation/feature_tip_keys.dart`,
  `featureTipsOrNull()` = no tip in page tests without the service):
  GPS workout screen while idle ("Going somewhere without signal?", until
  an area is saved), sleep sheet (compact, "Drag the arc to move your
  whole night", also gone after a save; fits 360x640 at 1.5). The Scan
  tab has none (its hints under the frame cover barcodes). Test:
  `tip_placements_test.dart`. The
  "Offline map ready" notification and the tracking screen's
  `OfflineMapNote` (idle only) open `offline-maps`. Vita's `APP_GUIDE`
  covers offline maps, shortcuts and tips (deployed Oct 22).
  Test: `test/features/feature_tips/feature_tips_test.dart`.
- **gamification / community / challenges (Arena):** `friends`,
  `leaderboard` (`/community/:id`), `challenges`, `badges`,
  `points-history`, `activity-calendar`. `GamificationCubit` (stats,
  awards), `ScoreStreakCard`, `CommunityCubit`, `FriendsCubit`,
  `LeaderboardCubit`, `ChallengesCubit`. Scoring is server-side:
  `submit_daily_report` (wrapper in `20261021_...`, core logic
  `_submit_daily_report_core`, both last redefined in
  `20261023_per_user_days.sql`) clamps a day's metrics, awards points,
  streaks and badges. Accepts IST today -3 to +1 (client
  `maxBackfillDays = 3`); returns `capped` when figures exceed the uploaded
  logs, and the client then doesn't record the day as sent (resent after
  the logs upload). Streaks, rest days and cheers use the user's own day
  (`user_today(profiles.timezone)`, IST fallback). Rest days
  (`player_stats.streak_freezes`, one per 7 active days, max 2, spent by the
  hourly `use-streak-freezes` cron, refunded on late sync);
  `get_badge_progress()` for locked badges. Challenges are online-only.
  Challenges (`ChallengeMetric`, `challenges_repository.dart`): 1, 3, 7 or
  14 days; points, healthy eating (nutrition) points, steps, active
  minutes, workouts, distance, wellbeing (lifestyle) points. Workout
  metrics roll from now to now + days; daily ones (`isDaily`) count
  today and the next days - 1 in each person's own time zone and end at
  the creator's midnight (`challengeDays` rounds up, `challengeDayLabel`
  counts calendar days). Points exclude bonus (streaks, badges).
  Rewards: snackbars via `awardMessage`; celebration dialog in Arena.
  - **Offline (Oct 22):** every Arena read has a saved copy (profiles
    too, 2 min); the hub draws `CommunityRepository.savedHub()` at once,
    then refreshes (a failed refresh keeps it). City and leaderboard
    visibility queue offline; points reports wait for the connection;
    join / leave, friend requests, cheers and challenges are online only
    ("You're offline. Try again when connected."): they involve others or
    must not replay out of order. Test:
    `test/features/community/arena_offline_test.dart`.
  - **Who sees what (Oct 22):** every member opens one page,
    `PlayerProfilePage.open` (`community/presentation/pages/
    player_profile_page.dart`; replaced the two profile sheets) from
    leaderboards, champions, friends and the hub's friends row; your own
    row / place opens yours ("This is how other members see you", no
    actions). Top down: avatar, name, @username, level; actions (Add
    friend + "Friends can cheer, compare and challenge each other." /
    Accept + Decline / Request sent / friend: Challenge, then Cheer +
    Compare; Remove friend in the header's ⋮ menu, asks first); one
    stats card (Points, Streak, Badges); Awards (`AwardsSummaryCard`,
    more than one opens `PlayerAwardsPage`: summary, then
    `AwardsByPeriod`, one section per week / month, newest first);
    Recent badges (`BadgeEmblem`, tap for details); Points by area for
    friends and yourself only (`PlayerProfile.isFriend`). Hidden members:
    a lock note. Your own awards: Achievements page (`MyCommunityAwards`:
    one summary card under the badge summary, never the whole list),
    celebration dialog, `award` notification. Others: their profile, hub
    `ChampionsCard` (crown badge in the title: the rows carry the medals),
    each leaderboard's `LeaderboardAwardsCard` (champions rows open it);
    friends get `friend_award`. Tests: `test/features/community/champions_test.dart`,
    `player_profile_page_test.dart`.
  - **Achievements page** (route `badges`, kept for links; was "Badges"):
    "N of M badges" summary, Awards card, "Badges earned", "Badges to
    unlock". Arena hub shortcuts: Achievements and Points (the activity
    calendar lives on Home: Today > History); square tiles while every
    label fits whole at the text size, else full-width rows with a
    chevron (`_Shortcuts`, measured, never shrunk).
  - **Arena UI (Oct 21):** hub order = level card + shortcuts (Achievements, Points),
    `PointGoalsNudge` (only while a goal that points need is missing:
    `PointGoal` water / calories / activity, `DailyMetricsCollector
    .missingPointGoals`; "Set goals" opens `my-goals`, "Not now" hides it
    until a different set is missing; the Points page puts "Set a water
    goal to earn these" under those rules), Challenges (at most 2 on the hub: open invites first as one-line
    `_InviteRow`s with Join (under the text when beside it would get
    narrow; Decline on the Challenges page), then running ones, then a
    "+ New challenge" text link (lighter than a full-width button); the
    title counts all when some are left out), Friends, Leaderboards, then
    `ChampionsCard` only when there are winners: one row per community
    (Global, your city) with its winner, "You 2nd" when you placed, a
    chevron to that leaderboard (which lists the top 3); Week / Month
    switch when both, opens on the one announced last via
    `latestChampionsPeriod` / `awardAnnouncedAt`. Kept to about 1.5
    screens at 1.0 text: add sections as summaries with "See all".
    `ChallengeTile`: running = brand icon badge + time bar ("Day 6 of 7 ·
    1 day left"); finished / left = grey badge + `TrackerStatusChip`
    ("You won", "Finished", "You left"); rank + score sit in the footer
    (wraps under at large text). Challenges page sections: Invites,
    Active, Finished. Leaderboards list only players with points that
    period (never hidden profiles), so the page explains the gap under
    the board (`LeaderboardState.coverageNote`: "8 of 23 members have
    points this week..."); the global member count is every profile.
    Friend requests put Decline / Accept under the name. Badges: no
    separate "closest" card, locked grid sorted by progress; gold is never
    text (icons via `iconTint`, labels grey). Points: hero in a card,
    `AppSectionHeader`s, days via `formatLogDay`, rule points under the
    rule. Shots: `HOME_SHOTS=1 flutter test
    test/features/community/arena_pages_layout_test.dart` ->
    `build/arena_shots/` (hub, leaderboard, challenges, friends, badges,
    points; 360 / 412, 1.0 / 1.5, dark).
  - **Achievement Badges (32):** shipped as lossless WebP in
    `assets/images/badges/` (converted pixel-identical from the source SVGs
    in `assets/icons/badges/`, which stay in the repo but out of
    pubspec; re-run the conversion if the SVGs change). 3D
    photorealistic badges with transparent backgrounds across streaks (`streak_3`,
    `streak_7`, `streak_30`, `streak_100`, `streak_365`), steps (`steps_10k`,
    `steps_20k`, `steps_30k`), workouts (`workouts_1`, `workouts_25`,
    `workouts_50`, `workouts_100`, `workouts_200`), nutrition/water/habits
    (`water_days_7`, `water_days_30`, `water_days_100`, `diet_days_7`,
    `diet_days_30`, `food_days_30`, `calorie_master`), lifestyle
    (`sleep_days_7`, `sleep_days_30`, `checkin_days_14`, `mindful_30`,
    `streak_shield`), and levels (`level_5`, `level_10`, `level_15`,
    `level_20`, `points_1000`, `goal_days_30`).
  - **Badge Architecture:** Built as standalone SVGs embedding base64 high-res
    PNGs to preserve raytraced 3D glassmorphism, neon glows, and specular
    lighting without path degradation. `GameIcon` (`game_icon.dart`) renders
    SVGs, PNGs and WebP (raster decoded at shown size), never tinting
    badge/award art.
  - **Badge Widgets:** `lib/features/gamification/presentation/widgets/badge_widgets.dart`
    provides `BadgeEmblem` (greyscale + reduced opacity when locked), `BadgeTile`,
    `showBadgeDetailSheet`, and responsive `_BadgeGrid`.
  - **Activity Calendar:** `activity_calendar_page.dart` (monthly navigation,
    Move/Rest/Fuel/Vitals sections) shows the month with `MonthCalendarGrid`
    (`gamification/presentation/widgets/month_calendar_grid.dart`, Figma
    track/calender 1297:18016): Sun-first weekdays (single letters when the
    names don't fit), square glass cells sized from the width (44dp on 412),
    taller with large text, `CalendarDayGrade` bar, selected day filled.
  - **Levels:** 20 levels by lifetime points (`levels` table); titles mirrored
    in `levelTitles` (`player_stats.dart`, test checks the seed). No tiers.
  - **Community awards:** top 3 of every community win weekly medals
    (Gold/Silver/Bronze Medal) and monthly trophies (Trophy Cup 1st, Tropy
    Star 2nd/3rd) from `assets/icons/awards/` (multi-colour, never tinted).
    Importance: global monthly > local monthly > interest monthly > weekly
    (`awardPrestige`). Entities, `AwardRules` and the countdown
    (`nextAwardCountdown`) in `community/domain/entities/community_award.dart`;
    UI in `award_widgets.dart` (Arena `ChampionsCard`, leaderboard
    `LeaderboardAwardsCard`, profile awards card, Achievements page
    section, `showAwardRulesSheet`) and `award_celebration.dart` (one-time
    dialog for a new trophy, pref `community_award_seen_<uid>`).
- **subscription (VitalUp Pro):** `vitalup-pro` (`ProPage`: plan, Manage
  subscription, Restore for Pro users; the paywall otherwise), Profile
  `ProPlanSection` (hidden where Pro can't be bought and the user isn't
  Pro). Pro raises the daily AI caps only (`domain/pro_limits.dart`, keep in
  step with the edge function defaults); tracking, trends, reports, sync
  and Arena stay free. RevenueCat (`purchases_flutter`) over Google Play
  Billing: `RevenueCatBilling` (`data/services/store_billing.dart`) is off
  without `REVENUECAT_GOOGLE_API_KEY` in `.env` (optional envied field) and
  on iOS; the RevenueCat app user id is the Supabase user id; entitlement
  `pro`; offering `current` with `$rc_annual` / `$rc_monthly` packages
  (prices, trials and offers live in Play Console, never in code).
  `SubscriptionRepositoryImpl`: Pro if the store or `is_premium_user` says
  so (CacheStore, offline last copy); after a purchase / restore it calls
  `sync-subscription` so the AI functions see Pro before the webhook.
  Paywall look (`pro_paywall.dart`): centred hero (badge in a soft brand
  glow; Pro users see "You're on VitalUp Pro" + plan there), a Free / Pro
  "Daily limits" card (`ProLimitsList`: rows stack to "Free 5 · Pro up to
  100" when the columns would squeeze names), plan tiles side by side when
  half the width is `proPlanTileMinWidth` x text scale (else stacked),
  selected = brand border + `primaryFill`. Shots: `HOME_SHOTS=1 flutter
  test test/features/subscription` -> `build/pro_shots/`.
  `SubscriptionCubit` is a lazy singleton provided in `main.dart`, follows
  auth (`logIn` / `logOut`), loads plans on demand. Gates: scan 429
  (`ScanQuotaExceededFailure`), Vita `limitReached`, `DietPlanError
  .limitReached` -> `offerProForLimit` / `showProPaywall(reason:)` (free
  users who can buy) else the plain message; a purchase from a gate retries
  the action. The paywall shows price, period, trial and "Renews
  automatically until you cancel in Google Play" (Play policy).
- **help_support:** `help-support` (FAQ `kFaqDatabase` in
  `data/datasources/faq_data.dart`: plain text, paths checked against the
  app, `actionRoute`s that open without `extra` (`faq_data_test.dart`);
  `searchFaqs` matches each word by its start; no results -> "Ask Vita"
  sends the search to `vita-chat`; the top card is Ask Vita; thumbs down
  opens the contact form), `contact-support`
  (`EmailService.submitSupportTicket` -> `send-email`, signed-in only;
  mailto fallback). The scripted `support-chat` bot was removed (Oct 21):
  Vita answers app questions with `APP_GUIDE`.
- **home_widget (Android):** Today (4 sizes), My metrics / Custom (3 sizes,
  `custom-widget-builder`), Water, Mood check-in, Shortcuts (2 sizes each).
  Dart formats everything (`data/widget_data.dart`: `WidgetInputs` ->
  `buildTiles` -> `publishWidgets`), Kotlin only lays it out
  (`android/app/src/main/kotlin/.../*Widget*.kt`, layouts
  `res/layout/wg_*.xml`), `presentation/widget_previews.dart` mirrors the
  layouts. Keep size thresholds identical on both sides. Full refresh in
  `HomeWidgetService.refresh`; buttons run `homeWidgetCallback`
  (`data/widget_background.dart`). Taps go through `/open?route=` ->
  `HomeWidgetService.handleLink`. Each offered size is its own provider
  (`WidgetSizes.kt`, `res/xml/*_info.xml`). Details: `docs/ios-home-widget.md`.
  Security: providers are exported (launcher), so button intents carry a
  per-install token (`Wg.isOwnAction`); `HomeWidgetBackgroundReceiver` is not
  exported. The background engine initialises Supabase with
  `autoRefreshToken: false` and skips the full refresh with an expired
  session (refresh tokens are single use; rotating one there would sign the
  app out). Health Connect can't be read in the background, so the refresh
  keeps the last step count instead of dropping to workout-only steps.

## Backend (supabase/)

- Migrations (in order): food scan tables + quota RPCs; AI daily quota
  (`consume_ai_quota`, IST days); avatars bucket; gamification (points,
  levels, badges, communities, leaderboards); friends; notifications
  (+ triggers, `broadcast_notification`); push tokens (pg_net trigger ->
  `send-push`, vault secrets `push_webhook_url`/`push_webhook_secret`);
  `ensure_profile`; username confirmation; synced log tables; weekly
  summary (cron `weekly-summaries`); challenges (scored from
  `activity_sessions`); user backups; leave challenge; friend profiles and
  cheers; private profiles; streak rest days + badge progress (cron
  `use-streak-freezes`); input constraints (`20261016_input_constraints.sql`);
  signed-out sign-up checks (`signup_username_available`, `email_registered`);
  friend ranks inside communities
  (`get_community_friend_ranks`, `get_my_community_standings`; friends who
  hide from leaderboards are left out); community awards
  (`20261019_community_awards.sql`: `community_awards`, hourly cron
  `finalize-community-awards` at :35 UTC = :05 IST finalises a period once
  late reports close, i.e. Thursday / the 4th since `20261023`; min 5 players; ties share a
  place; `get_community_awards`, `get_player_awards`; notification type
  `award`); security hardening (`20261020_security_hardening.sql`,
  `20261021_profile_login_report_hardening.sql`): service-only tables
  (subscriptions, scan_usage, recognition_logs, food_search_cache,
  email_send_log, login_attempts) have no client policies; signed-in RPCs
  revoke EXECUTE from PUBLIC (not just anon); a trigger keeps
  `profiles.email` / `username_confirmed` server-owned and limits
  `avatar_url` to the user's storage folder or Google; `submit_daily_report`
  is a wrapper that caps water / meal / workout figures at synced logs
  before `_submit_daily_report_core`; AI refunds capped at 3 a day; bad
  `profiles.timezone` refused by trigger; impossible workouts refused
  (`activity_sessions_sane_figures`, NOT VALID); avatars readable through
  the API only in the owner's folder.
  `20261022_profiles_private_email.sql`: anon has no access to `profiles`;
  authenticated gets a column grant of everything except `email` (a new
  profiles column is private until granted; never `select('*')` profiles,
  and read the user's own email from the session).
  `20261023_per_user_days.sql`: per-user days (above), live leaderboards
  end at the period's end, weekly summary falls back to IST, daily cron
  `prune-email-send-log` keeps 2 days.
  `20261024_challenge_request_id.sql`: `create_challenge(..., p_request_id)`
  is idempotent per creator (client `ChallengeRequestIds`).
  `20261025_login_push_hardening.sql`: `login_email` throttles per
  username + caller address (`_request_caller()` from the gateway headers;
  10 per 15 min) with a 50 per username cap, raising `too_many_attempts`
  (app: "Sign in with your email instead"); `register_push_token` may take
  another account's token at most 3 times a day
  (`push_token_takeovers`, service only).
  `20261026_vitalup_pro.sql`: `subscriptions.source` / `will_renew` /
  `last_event_at`; `consume_ai_quota(..., p_pro_limit DEFAULT NULL)` (NULL
  = Pro unlimited for old functions; functions now pass Pro fair-use caps);
  `get_remaining_scans` free limit 5, -1 for Pro. Deploy it before the
  functions that pass `p_pro_limit`.
  `20261028_ai_burst_limit.sql` (applied): `ai_burst_allowed`
  per-minute window on `ai_usage_daily` (`window_start`, `window_count`;
  rows it creates have `use_count` 0); service role only.
  `20261029_friend_request_expiry.sql` (applied): hourly cron
  `expire-friend-requests` (:25) deletes pending requests older than 30
  days (the trigger removes their notification).
  `20261030_vita_chat_refunds.sql` (applied Oct 22): `refund_ai_quota(...,
  p_max_refunds DEFAULT 3)` returns whether it refunded; vita-chat passes
  the daily chat limit, so a chat only counts when it gets a real answer
  (errors, off-topic and replaced replies are refunded); vita-chat using
  it is deployed (Oct 22).
  `20261031_public_profiles_friend_awards.sql` (NOT pushed yet; tested on
  local Postgres): `get_player_profile` for any signed-in member, adds
  `friend`; members on leaderboards share points, streaks, badge count and
  6 recent badges, points by area only for the caller and friends; hidden
  members name / avatar / level only (no more `not_friends` error; cheers
  and challenges still check friendship). Notification type
  `friend_award`: a deferred constraint trigger on `community_awards`
  tells each accepted friend of the winner's best award per period
  (global > local > interest, then place; once, `actor_id` + username /
  avatar in data; hidden winners not told). Push it with the app update
  (older apps show these as plain announcements).
  `20261032_challenge_day_metrics.sql` (NOT pushed yet; tested on local
  Postgres): `challenges.days`, new metrics and 1-day length in
  `create_challenge` / `_challenge_score` (points from `point_events`,
  steps from `daily_reports`). Push it with the app update (older apps
  show new metrics as active minutes).
- Never edit an applied migration; add a new one. Clients never write
  points/stats/badges directly: everything goes through RPCs.
- Edge functions (`_shared/llm.ts` Gemini -> Groq fallback, `_shared/quota.ts`):
  `scan-food` (image / search / nutrition / barcode), `vita-chat`
  (chat or insights), `generate-diet-plan` (429 at the daily limit, 422 for
  allergy failures), `send-push` (secret header, FCM v1), `send-email`
  (Resend; only the Auth hook (Standard Webhooks signature,
  `SEND_EMAIL_HOOK_SECRET`), signed-in support tickets (sender from the JWT)
  and the website deletion form; 3 mails per recipient a day; no free-form
  sending),
  `delete-account` (purges auth.users, avatar files, cascades DB rows,
  audits to privacy@vitalup.live & support@vitalup.live),
  `revenuecat-webhook` (table `subscriptions`; fails closed without its
  secret; with `REVENUECAT_SECRET_API_KEY` it re-reads the customer from
  RevenueCat's REST API on every event, so order doesn't matter; without
  it, the event is applied and older events are ignored; CANCELLATION keeps
  Pro until expiry), `sync-subscription` (signed-in; same re-read for the
  caller, 15 s throttle), `_shared/revenuecat.ts`; `delete-account` also
  deletes the RevenueCat customer. Free / Pro caps are env-overridable
  (`FREE_DAILY_SCANS` / `PRO_DAILY_SCANS`, `VITA_CHAT_DAILY_LIMIT` /
  `PRO_VITA_CHAT_DAILY_LIMIT`, ...); 429 bodies carry `pro` and
  `upgradable`. `fatsecret-proxy` is an unused stub that returns 501.
  `_shared/quota.ts` fails closed. AI nutrition estimates are never written
  to the shared `proprietary_products` catalogue. All
  validate input with `_shared/validate.ts` and return short JSON errors.
  No deno locally: type-check with tsc + shims (see Tests).
- Not in any migration (created in the dashboard): `profiles`,
  `user_health_data`, `proprietary_products`, `get_email_by_username`
  (closed). `20261027_core_tables_rls.sql` (written Oct 20, applied by
  Oct 22: anon gets 42501 on profiles / user_health_data) enables RLS on the three tables with permissive + RESTRICTIVE
  policies (restrictive ones cap any dashboard policy): profiles readable
  by signed-in users, insert/update own row, no client delete;
  `user_health_data` own row only; `proprietary_products` readable by all,
  clients may only add new barcodes (`PendingWrite.insertIfMissing`, an
  upsert with `ignoreDuplicates`: a plain upsert needs UPDATE rights).
  `_protect_profile_columns` now also pins `id`, `city`, `country_code`
  and `timezone` on client updates (set through `set_my_city` /
  `set_my_timezone`). Tested on local Postgres. After pushing, probe the
  live API with the publishable key (curl `rest/v1/<table>`).

## Website & Legal Suite (vitalup.live)

- **Static Pages:** `website/` hosted on Cloudflare Pages (or Vercel) at `https://vitalup.live`
  (redesigned Oct 22 in the app's look: Nunito + JetBrains Mono self-hosted as
  WOFF2 in `assets/fonts` (no Google Fonts call), app tokens, glass cards, blurred
  ring backdrop, light / dark following the system with a toggle, pref
  `vitalup-theme`). Shared `assets/site.css` + `site.js` (menu, reveal on scroll,
  TOC highlight, carousel); `assets/icons.css` is generated (app SVGs from
  `assets/icons` + Material paths as CSS masks; regenerate rather than edit).
  SEO (Oct 23): links and assets are root-relative clean URLs (`/privacy`,
  `/assets/...`, matching each page's canonical), so preview with a server
  that maps clean URLs (`npx serve website`), not `file://` or `http.server`.
  Every page head has title / description / canonical / Open Graph / Twitter
  tags and a JSON-LD `@graph` (Organization, WebSite, WebPage; home adds
  MobileApplication (no rating until real reviews exist) and FAQPage built
  from the visible FAQ, keep them in step; legal pages add BreadcrumbList).
  `robots.txt`, `sitemap.xml` (bump `lastmod` on content changes),
  `site.webmanifest`, `404.html` (noindex) and `_headers` (Cloudflare cache
  and security headers). Hero isn't scroll-revealed (it's the LCP).
  - `index.html` (+ `assets/home.css`): hero with phones, stats, tracker bento,
    feature rows, screenshot carousel, privacy band, reviews (hidden markup to fill
    with real Play reviews; a "Rate on Google Play" card meanwhile), Free / Pro
    limits (no prices: they're per country in Play), FAQ, CTA. Play link
    `play.google.com/store/apps/details?id=com.vitalup.app`. Screens in
    `assets/screens/*.webp` (600 wide; Home / Arena / water from the test
    renders in `build/*_shots`, the rest from `assets/screenshots`), share image
    `assets/og-image.png`.
  - `privacy.html`: Play + Health Connect privacy policy (section ids kept for
    links: `health-connect`, `ai-processing`, `arena`, `retention-deletion`...).
  - `terms.html`: Terms of Service (last updated Oct 22: adds AI, Arena conduct,
    ending your account, changes).
  - `delete-account.html`: in-app steps (Profile > Account details > Delete
    account) and the web request form (`send-email` `account_deletion_request`,
    same body as before; 429 / 400 messages shown, mailto fallback otherwise).
  - Keep `assets/vitalup_light_logo.png`: email templates load it from the site.
- **Routing & Clean URLs:** Cloudflare Pages natively maps clean URLs (e.g., `/privacy` -> `privacy.html`). Do not use `_redirects` mapping to `.html` (causes a 307 redirect loop). `vercel.json` uses `"cleanUrls": true`.
- **Assets & Favicons:** the site logo and favicon are the `app_icon_black`
  mark with no background (heart cut out): vector `website/assets/logo-mark.svg`
  (from `assets/icons/app/app_icon.svg`, heart as a mask). `favicon.ico`
  (16-64), `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png` and
  `android-chrome-*.png` are transparent renders of it; re-render them if the
  mark changes.

## Email & Support Infrastructure (Resend)

- **Service:** `EmailService` (`lib/core/services/email_service.dart`) calls `send-email` Edge Function. Registered in DI (`initDependencies`).
- **Templates (Oct 22):** one layout for every email in `supabase/functions/_shared/email.ts`
  (`renderEmail` + `block.code/button/note/details/quote/list`, app tokens, light with a
  `prefers-color-scheme` dark version, 560px column that fills phones, MSO fallbacks, plain-text
  twin; no emojis). Auth code copy per `email_action_type` in `renderAuthEmail` (`CODE_EXPIRY`
  must match Auth > Email OTP expiry). Function emails in `send-email/templates.ts` and
  `delete-account/templates.ts` (pure, previewable in Node). Dashboard templates
  `supabase/email_templates/*.html` are generated: `node supabase/email_templates/build.ts`
  (prints each subject), then paste into Auth > Emails.
- **Provider:** Resend REST API (secret `RESEND_API_KEY` stored in Supabase secrets).
- **Domains & Senders:**
  - `support@vitalup.live`: In-app support tickets (from `ContactSupportPage`) delivered to support desk with user diagnostics, and branded confirmation email sent to user.
  - `privacy@vitalup.live`: Receives audit alerts for all mobile and web account deletion requests.
  - `noreply@vitalup.live`: Transactional authentication emails (signup confirmation, magic link, password recovery in `supabase/email_templates/`).
- **Inbox Avatars:** Custom domain Google Accounts configured for `support@vitalup.live` and `privacy@vitalup.live` to show the VitalUp app logo as sender profile picture in Gmail.
- **Account Deletion Flow:**
  - In-App: `Profile` -> `Settings` -> `Account` -> `Delete Account`. Invokes `delete-account` Edge Function: removes user avatar storage objects, deletes `auth.users` (cascading all RLS-bound records), emails user confirmation, and dispatches audit log to both `privacy@vitalup.live` and `support@vitalup.live`.
  - Web: Form on `vitalup.live/delete-account` submits to `send-email` Edge Function, dispatches receipt to user, and delivers deletion action item to privacy desk.

## What is Done & Remaining

### Completed:
1. **Autonomous Support Desk:** In-app ticket form with diagnostic attachment, direct Resend email delivery to `support@vitalup.live`, and user confirmation receipt.
2. **End-to-End Account Deletion:** Mobile app database purge + avatar cleanup + dual audit email dispatch; web deletion portal with modal confirmation and API/mailto failover.
3. **Legal Compliance Suite:** Published Privacy Policy, Terms of Service, and Account Deletion portal at `vitalup.live`.
4. **Branded Email Suite:** one shared app-themed layout (light + dark) for Supabase Auth codes, support tickets and receipts, and deletion requests and confirmations (`_shared/email.ts`).
5. **Favicon & Asset Fixes:** Multi-resolution icons, embedded SVG data URI fallback, removed logo glow shadow, fixed Cloudflare Pages 307 redirect loops.
6. **Security & Secrets:** Verified zero secrets or API keys in git history or client code; `RESEND_API_KEY` secured in Supabase server secrets.
7. **App-Wide Loading States:** Centered loaders across all full pages in `AppScaffold` with modernized `VitalUpLoader` design.
8. **Nutrition Navigation Split:** Dashboard Nutrition section routes to `meal-log-history` for complete chronological meal history; `DietProgressPage` focuses on today's logged meals.
9. **Modern 3D Achievement Badges (32 SVGs):** Extracted, alpha-keyed, and deployed full 32-badge asset suite with standalone SVGs embedding base64 high-res graphics without vector distortion.
10. **Gamification Badge UI:** Reusable `BadgeEmblem`, `BadgeTile`, `showBadgeDetailSheet`, and responsive grid integrated into `BadgesPage` (Achievements), `PlayerProfilePage`, and reward dialogs.
11. **Tracker Trends & Sleep Insights:** Modernized `TrendBarChart`, detailed sleep card metrics, and proportional status bars in `ActivityCalendarPage`.
12. **Play Store Pre-Release Suite:** Renamed application package to `com.vitalup.app`, upgraded to target SDK 36, enabled R8 minification with ProGuard keep rules, NDK symbol tables, GitHub Actions CI/CD workflows for release and Shorebird patches, and comprehensive `docs/PLAY_STORE_PRE_RELEASE_GUIDE.md`.
13. **Play App Signing & Android OAuth Clients:** Registered Google Play App Signing key SHA-1 (`F9:63:25:22:11:92:D8:2E:5D:DA:DC:F7:10:FA:D1:07:91:54:7C:0C`), Upload key SHA-1/256, and local Debug keystore SHA-1/256 to Firebase `com.vitalup.app`, auto-provisioning Google Cloud OAuth clients.
14. **Google Play Reviewer Account & 7-Day Seeded Dataset:** Created and email-confirmed `reviewer@vitalup.live` (username `vitalup_reviewer`; password kept only in Play Console > App access, never in the repo) with complete 7-day tracking records (49 water logs, 7 sleep logs, 28 macro-detailed meal logs, 7 GPS workouts, 7 weight check-ins, Level 3 / 620 points, 6 badges).
15. **Dashboard & Stale Data Synchronization:** `CacheStore.changes` / `ProfileRepository.changes` keep every screen's profile current; Home re-reads on show, resume, habit events and sync pulls; reloads keep data on screen; Weight card shows "Logged today" with "Update"; "Start activity" label.
16. **Pre-Release Security & Privacy Hardening:** Android data extraction rules (`data_extraction_rules.xml`) exclude health DBs/sharedprefs from cloud backup & device transfer; biometric app lock enforces `FLAG_SECURE` (`com.vitalup.app/window`) to hide recents previews and prevent screenshots; unused merged permissions (`RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE`, `AD_ID`) stripped; widget actions authenticated via per-install `action_token`; GoRouter protects deep links against unauthenticated access; Supabase migrations harden RLS on service-only tables, add `email_send_log` rate limiting, protect `login_email` RPC against username harvesting, and cap daily report stats.

17. **Pre-release audits (Oct 2026):** data/storage, sync, widgets, error handling and loading states audited and fixed; server security (areas 1), release build (2) and async patterns (6) done and deployed (migrations `20261020`-`20261022`, edge functions redeployed and probed live). Fixed the open `send-email` relay, self-granted premium, public `profiles` emails, sign-out data loss / cross-account leaks, the Android 14 download-service crash and the `setState`-returns-Future crashes.

### Pre-release audit plan (status):
- Done: 1 server security, 2 release build (except a full release-build
  pass on a device and Play Console declarations), 6 async patterns.
- Done (Oct 18; `20261023` and the scan-food logs deployed Oct 19):
  4 dates & time (midnight reload on Home, nights across
  midnight, DST-safe day math via `date_range_utils.dart` `nextDay` /
  `previousDay` / `calendarDaysBetween`, future timestamps count as stale
  via `isWithinLast`, per-user server days) and 8 privacy (AI consent +
  Health Connect opt-in, analytics opt-out, export/deletion completeness,
  secure session, Mapbox telemetry off, privacy.html rewritten; website
  not yet redeployed).
- Partial: 3 lifecycle/process death (code fixes; device tests pending).
- Done (Oct 18): 9 tests: Drift v1-v6 -> v7 migration test, page state
  tests (loading/error/empty/loaded + max text (1.5) on 360 dp), in-process flow
  tests (`test/flows/`: offline -> online, two devices, sign-out, startup
  routing, midnight). No on-device `integration_test/` yet.
- Done in code (Oct 18, device checks pending; `20261024` applied Oct 19):
  5 input & display (system text size honoured up to 2.0 in
  `ResponsiveTextScale`, scrolling sheets/dialogs, text shrinks to a readable floor then ellipsis (`FitText`), names or
  stats, `NameWithYouTag`, meal macros summed, two-device merges in
  `PrefsBackupSource`, profile saves send changed columns only, session
  errors queued, timeouts on server writes) and 7 performance (startup
  in parallel and deferred, Home reloads throttled to 30 s, no GPS routes
  in history reads, camera NV21 without copies, image `cacheWidth`, fewer
  blurs, Nunito instead of SF Pro (0.4 MB vs 28 MB), ML Kit from Play
  Services, `device_preview` only in debug; arm64 download ~29 MB est.).
- Decide: 10 iOS gaps (no Crashlytics, push or widgets).
- Fixed Oct 20: widgets redraw just after midnight (`WidgetMidnight.kt`,
  inexact alarm re-armed on every widget update, plus TIME_SET /
  TIMEZONE_CHANGED); water / mood / sleep logged from widgets or
  notification actions quiet that habit's reminders
  (`markRemindersDoneInBackground`; `RemindersService` reloads prefs
  before skipping or resyncing so it doesn't write over them); background
  isolates report to Crashlytics (`CrashReporter.initBackground` in the
  GPS service, widget callback and notification actions); sign-in wipes
  another account's leftover data before the first sync
  (`AccountService.claimDevice`, pref `local_data_owner_id`, via
  `SyncService.beforeFirstSync`); sign-out also clears `weight_target_kg`,
  `health_import_last`, `sleep_bedtime_*` and
  `screen_time_days_v1`; export pages
  `daily_reports` and `notifications` and gives points 60 s; food scan
  says "This can take up to a minute" and asks before leaving mid-scan
  (`confirmLeaveFoodScan`, dashboard via `FoodScannerPage.busy`); label
  OCR loader is an in-page overlay; meal / activity history pull spinners
  wait for the load (`done` Completer on the event) and activity history
  keeps the list and filters while reloading; leaderboard reload bar sits
  in a fixed gap; points history keeps its data on refresh.
- Known leftovers: AI keys are one per function for every user (no
  Pro routing; free-tier Gemini may use prompts); backup conflicts
  use device clocks; other offline GETs take ~7 s to fail where no
  connectivity check comes first (postgrest retries 1+2+4 s); no skeleton
  loaders (needs a Figma design); meals/workouts have no user id column
  locally (the device-owner wipe covers it); iOS has no Firebase config
  (no Crashlytics); Health Connect steps can't be read in the background
  (needs READ_HEALTH_DATA_IN_BACKGROUND + a Play declaration); 50 wrong
  guesses in 15 min from many addresses still block username sign-in
  (email still works).

### Remaining:
1. **Production Release Review:** Initial bundle and all required declarations (Health apps / Health Connect, Usage Access video, Location foreground service video, Data safety form) submitted to Google Play Console; currently under review.
2. **VitalUp Pro setup:** Play Console subscription `vitalup_pro` (monthly + yearly with 7-day trial) and RevenueCat configuration (app, entitlement `pro`, default offering packages, webhook) are set up. `REVENUECAT_GOOGLE_API_KEY` is in `.env` and built into `env.g.dart`. `REVENUECAT_WEBHOOK_SECRET` is set in Supabase. Remaining: generate the secret key (`sk_...`) under RevenueCat Secret API keys and run `supabase secrets set REVENUECAT_SECRET_API_KEY=sk_...`; add `REVENUECAT_GOOGLE_API_KEY` to GitHub Actions `ENV_CONTENT` secret; declare "Purchase history" in Play Console Data safety form.
3. **Deploy Website to Production:** Re-upload the clean `website/` directory to Cloudflare Pages (or push to git).


## Native Android

- `UiSounds` (`core/services/ui_sounds.dart` -> `UiSounds.kt`, channel
  `com.vitalup.app/feedback`: `prepare`, `tick(strong)`): SoundPool with
  `res/raw/scale_tick.wav` (generated 18 ms click), sonification usage (no
  audio focus, music keeps playing), only with the ringer on (silent /
  vibrate stay quiet), whatever the Touch sounds setting; other platforms
  use the system click.
- `MainActivity` (FlutterFragmentActivity) channels:
  `com.example.vital_up/audio_intent` (`getInstalledAudioApps`,
  `launchAudioApp`, `playAudioImplicitly`),
  `com.example.vital_up/usage_stats` (`checkUsageStatsPermission`,
  `getExactUsageStats`, `getScreenEvents`), and
  `com.vitalup.app/window` (`setSecure` toggling `FLAG_SECURE` for biometric lock privacy).
- `PermissionsRationaleActivity` (+ `ViewPermissionUsageActivity` alias):
  Health Connect privacy policy link.
- Permissions are minimal on purpose (Play review): no background location,
  no battery-optimisation exemption, Health Connect read-only; unused library permissions
  (`RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE`, `AD_ID`) stripped via `tools:node="remove"`.
  `data_extraction_rules.xml` excludes internal databases and preferences from cloud backup
  and device-to-device transfers. Widget buttons carry a private `action_token`. Usage Access
  and Health Connect need Play Console declarations.

## Tests

`test/core` (sync, backup sync, offline first, load timeout, tracker,
input rules) and `test/features/<f>`. No mocking library: hand-written fakes
per test (`_FakeRemote`, `FakeProfileRepository`...). Patterns:
`SharedPreferences.setMockInitialValues`, `CacheStore(ConnectivityService(),
directory: tmp)`, Drift `NativeDatabase.memory()`. `test/code_rules_test.dart`
scans `lib` for patterns the analyzer misses.

- `test/core/database/drift_migration_test.dart` builds every old schema
  (v1-v6) and upgrades it; a schema change needs a new version there plus
  `dart run drift_dev schema dump lib/core/database/drift_database.dart
  drift_schemas/`.
- `test/helpers/pump_app.dart` (`pumpPage`, `kSmallPhone`,
  `kMaxTextScale`): page state tests (`*_states_test.dart`) check each
  state and no overflow at max text (`kMaxTextScale` = 1.5). `testWidgets` takes only `skip: true`.
- `test/flows/` run real services, Isar, Drift and the Supabase client
  against `support/fake_backend.dart` (HTTP fake with RLS-like rules);
  `support/test_device.dart` is one simulated phone. Isar loads the
  Windows/Linux lib from `isar_community_flutter_libs` (skips if missing).

SQL changes: run every migration on a throwaway local Postgres 18
(`C:/Program Files/PostgreSQL/18/bin`; `initdb -A trust`, start on a spare
port) after a stubs file that creates roles `anon` / `authenticated` /
`service_role`, schemas `auth` (users with email, encrypted_password,
email_confirmed_at, raw_*_meta_data; `uid()` / `role()` / `jwt()` reading
`request.jwt.claim.sub` / `request.jwt.claims`), `storage` (buckets, objects,
`foldername`), `cron`, `net`, `vault`, `extensions` (+ pgcrypto), the
dashboard tables (`profiles`, `user_health_data`, `proprietary_products`)
and publication `supabase_realtime`. Run migrations without ON_ERROR_STOP
(pg_cron / pg_net lines fail locally), then test as `SET ROLE` + set_config
claims.

Edge functions: `npx -p typescript@5.6.3 tsc --noEmit --strict
--noImplicitAny false --module es2022 --moduleResolution bundler
--allowImportingTsExtensions --target es2022 --lib es2022,dom,dom.iterable --skipLibCheck
shims.d.ts <files>`, with shims declaring `Deno` (env, serve) and the
`https://` imports as `any`.

## Gotchas

- The app ships in every country: handle daylight saving and time zones.
  Calendar steps use `DateTime(y, m, d ± n)` / `nextDay` / `previousDay`,
  day counts `calendarDaysBetween` (never `Duration(days:)` on local
  midnights or `difference().inDays`, which are an hour / a day off across
  a clock change); durations are real elapsed time between dates. Server
  "days" in IST (quotas, report fallback) are a known design.

- The shell is Git Bash on Windows: for `adb shell` paths use
  `MSYS_NO_PATHCONV=1`; long inline heredocs with quotes can fail to parse,
  so write scripts to the scratchpad and run them instead.
- Tool inputs turn `\uXXXX` escapes into literal characters: write escapes
  from a script (e.g. `chr(92)`), then check with `grep -P '[^\x00-\x7F]'`.
- Android widgets (RemoteViews): no plain `<View>` (use `FrameLayout`), tint
  dynamically with `setColorFilter`, progress bars are `ImageView` +
  `wg_bar_fill` clip drawable + `setImageLevel`, text sizes are dp.
- Never prompt for permissions from background work, app resume or just
  opening a page: `SleepService.getSleepDataForLastNight()` never asks;
  the sleep card's "Log sleep" sheet offers "Connect Health Connect"
  (`SleepNeedsManualEntry.canConnect`, `SleepCubit.connectHealth`).
  Closing a permission screen resumes the app and would loop.
- System permission dialogs can't be styled: ask with the permission card
  first (`core/permissions/permission_card.dart`: `ensurePermission(context,
  PermissionAsk(main:, also:, title:, message:, onceKey:, alsoOnceKey:))`;
  nothing when allowed, card then the system dialog on Allow, "Open
  settings" when blocked; `onceKey` asks once for optional ones).
  `AppPermission` = notifications, location, activity, camera. Uses: Home
  "Stay on track" notifications card once (`askForNotificationsOnce`,
  replaces the old automatic prompt; onboarding's reminders switch marks
  it asked), Scan tab camera card (`CameraPermissionSheet`: drawn like a sheet along
  the bottom over the camera area, capture controls hidden, second button
  "Pick from gallery"), GPS
  workout screen: on its first open (the one page that asks on open: its
  map is about where you are; `onceKey` `workout_screen_open`, after an
  interrupted workout's choice) and at Start / resume (location + steps +
  notifications; extras offered on a card aren't asked again alone;
  repositories' `hasPermission()` only check), timer Start and audio downloads
  (notifications, once). Explicit switches (Settings, reminders) still go
  straight to the system dialog. Health Connect and Usage Access open
  their own screens from explicit taps. Test:
  `test/core/permissions/permission_card_test.dart` (`HOME_SHOTS=1` writes
  `build/permission_shots/`).
- `setState(() => future = load())` returns a Future and throws; use a block body
  (also never call setState in `didUpdateWidget`: a build follows anyway).
- Never `select('*')` from `profiles` (column grant without `email`).
- A `try` doesn't catch an un-awaited future's error: await it or `.ignore()`.
- Postgres doesn't short-circuit `AND` in CHECKs: guard casts with `CASE`
  (a cast error is 22P02, which sync can't set aside like a 23514).
- `CASE x WHEN NULL` never matches; use `CASE WHEN x IS NULL`.
- A trigger that must tell client writes from SECURITY DEFINER functions
  can't be SECURITY DEFINER itself (`current_user` becomes the owner).
- Never add a plugin that starts its own engine on the default entrypoint
  (`audio_service` via `just_audio_background` did, unused: it ran
  `main()` twice, two Supabase clients, and the copy stole IsolateNameServer
  ports such as the GPS service's). One "Supabase init completed" per
  launch in logcat. `ForegroundServiceManager.start` re-claims its port.
- `UserAvatar` lives in `core/widgets/user_avatar.dart` (re-exported by
  `community_widgets.dart`).
- Preset reminders' words come from the app (`mergeWithPresets` takes
  title/body from `reminderPresets`; users set only times), and the
  notification text is a rotating variant from `presetMessages`
  (`reminder_copy.dart`): edit copy there, it reaches everyone.
