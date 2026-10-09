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
cd android && ./gradlew.bat :app:compileDebugKotlin        # quick native check
supabase db push               # apply new migrations (outward-facing: ask first)
```

- `lib/core/config/supabase_config.dart` is gitignored (copy the `.example`);
  it also holds the Mapbox token. `android/key.properties` holds release
  signing (the build silently falls back to the debug key without it).
- Legal URLs are placeholders: `lib/core/config/legal_links.dart` and
  `android/app/src/main/res/values/strings.xml` (`privacy_policy_url`).
- `dart analyze lib test` has no warnings; only info lints remain
  (`prefer_initializing_formals`, deprecated `Share` API, a few in
  `activity_tracking_page.dart` / `customize_layout_page.dart`). Keep it
  warning-free.

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
  `test/widget_test.dart` checks every notification/reminder route exists.
- **Layers per feature:** `lib/features/<f>/{data,domain,presentation}`
  (datasources -> repositories -> entities -> cubit/pages/widgets). Errors use
  `dartz` `Either<Failure, T>` (`core/error/failures.dart`).
- **Data (offline first):**
  - Isar (`core/database/isar_service.dart`, `core/database/collections`):
    water, sleep, meals, weight, offline foods, barcode cache, diet plans,
    downloaded tracks.
  - Drift (`core/database/drift_database.dart`, schema v5): workout sessions
    and GPS track points.
  - SharedPreferences: goals, settings, per-user Vita data, reminders.
  - `core/cache/cache_store.dart`: cached server JSON with max ages; offline
    reads return the last copy.
  - `core/sync/sync_service.dart`: backs up logs to Supabase tables
    (`water_logs`, `sleep_logs`, `meal_logs`, `weight_logs`,
    `activity_sessions`) and pulls other devices' rows; `BackupSyncAdapter`
    stores settings/goals/reminders/stress/workout notes/diet plan in
    `user_backups`. `pending_writes.dart` queues offline server writes and
    RPCs (pref `pending_server_writes_v1`).
  - `HabitEvents` (`core/events`) broadcasts "something was logged" (water,
    meal, activity, mood, weight, sleep); reminders and widgets listen.
- **Backend:** Supabase (auth, Postgres + RLS, storage, realtime, pg_cron,
  edge functions). Firebase: FCM push and Crashlytics (Android). Health
  Connect / HealthKit via `health` (read-only everywhere).
- **Bootstrap:** `lib/main.dart` (Supabase, DI, push, reminders, sync,
  foreground task init; global BlocProviders: Auth, Onboarding, ScreenTime,
  Settings; theme mode from `SettingsCubit`; `DevicePreview` only when
  `!kReleaseMode`). `SleepCubit` is provided by the dashboard only (loading
  it earlier would prompt for Health Connect before sign-in). Pages pushed
  through the router can't see dashboard providers: pass cubits as `extra`
  or keep them global.

## Input, sanitising and errors (apply everywhere)

- `lib/core/utils/input_rules.dart` is the single source:
  - `InputLimits`: text lengths (name, username, email, password, search,
    short text, note, chat message, city) and ranges (height, weight, age,
    water, calories, grams, steps goal, sleep goal).
  - `InputFormatters.text(max, multiline:)`: blocks invisible/control
    characters, line breaks on single-line fields, and caps length.
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
  and never emit from a closed cubit.
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
4 Profile (`ProfilePage(onOpenArena:)`). It owns the per-session cubits
(water, sleep, trends, activity goals, gamification, notifications, stress,
diet plan, profile), shows award snackbars, and prompts Google users to
confirm a username.

## UI system (follow it; Figma is the source of truth)

- Tokens: `core/theme/app_colors.dart` (`AppColors`, tracker accents
  `track*`, `stressLevels`, `scoreBonus`...), `app_dimens.dart` (`AppDimens`
  spacing/radii/sizes, `AppShadows`, `AppDurations`), `app_text_styles.dart`,
  `app_theme.dart` (`VitalUpColors` extension). `design/figma_tokens.md` maps
  them to Figma. Font: SF Pro Rounded.
- Lookups: `context.colors`, `context.text`, `context.vColors` (glassFill,
  glassBorder, grayText, primaryFill, track, success, warning, termsLink...),
  `context.gutter` (16dp), `context.w(x)`, `context.safePadding`
  (`theme_context.dart`, `core/utils/responsive.dart`).
- Rules: no hardcoded colours/sizes, 16dp gutter, no emojis (Material/SVG
  icons; icon assets are supplied by the user, never created; `GameIcon`
  falls back to a Material icon when an SVG is missing), Home is health-first
  and calm, gamification lives in Arena, rewards are quiet (snackbars).
- Core widgets (`lib/core/widgets`): `AppScaffold` (background, header,
  scroll, `onRefresh`, `bottomBar`), `AppPageHeader` + `AppHeaderAction`,
  `AppSectionHeader`, `AppCard` (glass card; `AppIconBadge`,
  `AppProgressBar`, `AppCaption`, `AppInfoNote` live in `app_card.dart`),
  `AppListGroup` + `AppListTile`, `AppSegmentedControl`,
  `AppPrimaryButton`/`AppSecondaryButton`, `AppTextField` (+ `.integer`,
  `.decimal`, `AppDropdownField`), `UserAvatar`, `LoadErrorView`,
  `VitalUpLoader`, `AppScoreRing`. Tracker kit in `core/widgets/tracker/`:
  `TrackerMetric` enum (label, icon, colour, route per metric), `TrackerCard`,
  `TrackerFigureRow`, `TrackerStatusChip`, `TrackerQuickAction`,
  `TrackerRing`, `TrackerPrompt`, quick-log hub. Sheets/dialogs/snackbars:
  `core/utils/smooth_ui_helper.dart` (`showAppBottomSheet` pads for the
  keyboard; `showSmoothDialog`, `showSuccessSnackBar`, `showErrorSnackBar`).
- Dashboard cards: `features/dashboard/presentation/widgets/`
  (`today_summary_card.dart` is the Today hero with one insight;
  `dashboard_card_header.dart` has `DashboardCardHeader`,
  `formatDashboardDuration`; `trend_widgets.dart` has `CardLink`,
  `TrendRangeToggle`; `tracker_log_sheets.dart` has the quick log sheets).

## Features

Route names are GoRouter `name`s.

- **auth:** routes `splash`, `onboarding` (intro carousel), `login`,
  `forgot-password`, `verify-otp`, `reset-password`, `reset-completed`.
  Sign in by email or username (`get_email_by_username` RPC), sign up with
  email OTP (taken email/username checked via `email_registered` /
  `signup_username_available` RPCs, never by reading `profiles`), password reset by OTP, Google (`signInWithIdToken`); no Apple.
  Splash -> `dashboard` / `health-onboarding` (by `hasCompletedOnboarding`:
  local flag, then `user_health_data.onboarding_completed`, 8 s timeout,
  offline defaults to true) / `onboarding`. Sign out runs
  `PushService.unregister` -> `SyncService.sync` ->
  `AccountService.clearLocalUserData` (logs, workouts, reminders wiped;
  settings/goals kept). Signup terms: `terms_dialog.dart` + legal links.
- **onboarding:** `health-onboarding` then `health-personal-details`,
  `health-height`, `health-weight`, `health-dietary-preference`,
  `health-goals`, `health-activity`, `health-info-permission`.
  `OnboardingCubit` keeps answers in prefs `onboarding_*`, upserts
  `user_health_data` via `PendingWrites` (works offline). Google users choose
  a username here (`set_username`, `username_available`).
- **profile:** `ProfilePage` (identity card -> Account details, one-line Arena
  strip, `HealthSnapshotCard`, Health and Account groups, Sign out),
  `AccountDetailsPage` (`account-details`; name, `UsernameInput`
  availability check, DOB ddMMyyyy, gender male/female, read-only email,
  export/delete), `HealthDetailsPage` (`health-details`; per-section edit
  sheets; weight via `WeightService` / `showWeightEntrySheet`; units from
  Settings). Helpers: `presentation/utils/body_metrics.dart`. Pass the
  Profile tab's `ProfileCubit` as `extra` (`_withProfileCubit` in the
  router); `ProfileState.shownProfile`; a failed save emits `ProfileError`
  then `ProfileLoaded(previous)`.
- **account:** `AccountService` (`delete-account` function, then wipes the
  device), `DataExportService` (zip of CSV + JSON via share sheet).
- **settings:** Appearance, Units, Notifications, Connected (Health Sync),
  Privacy & security (app lock, leaderboard visibility sheet), About.
  `SettingsEntity`: themeMode, units (`cm`/`in`, `kg`/`lbs`), notification
  and health-sync flags.
- **about:** rate (Play id from `PackageInfo.packageName`), feedback mailto
  `support@vitalup.app`, Legal links (`LegalLinks`).
- **goals:** `my-goals` gathers every goal (plan, weight, activity, water,
  sleep, screen time).
- **dashboard trackers:** routes `water-trends`, `sleep-trends`,
  `screen-time-trends`, `stress-trends`, `diet-progress`, `weight-trends`.
  `TrendsService` / `TrendCubit<T>` are shared by cards and trend pages.
  Water: Isar `WaterLogCache`, goal pref `daily_water_goal`. Screen time:
  pref `daily_screen_time_limit_min`, Usage Access permission, usage channel.
  Mood/stress: `StressCheckInCubit` -> `VitaRepository`.
- **sleep:** `SleepService` (dashboard/data/services) merges Health Connect
  nights (win), saved entries (`SleepLogCache`, source `manual`/`phone`) and
  a screen-off estimate (`domain/sleep_detection.dart`, native
  `getScreenEvents`) that the Home card asks the user to confirm. "Going to
  bed" / "I'm up" taps live in prefs (`sleep_bedtime.dart`); evening sleep
  reminders carry "Going to bed", the in-bed notification carries "I'm up"
  (`reminder_actions.dart` handles both with the app closed).
  `SleepService.changes` reloads `SleepCubit`; saving last night emits
  `Habit.sleep` to quiet morning sleep reminders.
- **weight:** `WeightService`, Isar `WeightLogCache` (always kg), mirrored to
  `user_health_data`; goal weight in CacheStore (legacy pref
  `weight_target_kg` fallback).
- **health_report / weekly_summary:** `health-report`
  (`HealthReportService`, clinical text export); `weekly-summary`
  (`WeeklySummaryService`, computed on device; reports time zone via queued
  `set_my_timezone`; server sends a Sunday 18:00 local push).
- **activity_tracking:** `activity-tracking`, `activity-history`.
  `ActivityTrackingBloc` / `ActivityHistoryBloc` per page; sessions in Drift;
  notes/tags pref `activity_annotations`; workout prefs
  `core/preferences/workout_prefs_notifier.dart`. The bloc checkpoints the
  open session to Drift every 30 s / on pause / on hide and marks it in pref
  `activity_in_progress_v1`; after an app kill the tracking page offers
  Resume / Save / Discard (`WorkoutRecoveryService`, pure rules in
  `domain/services/workout_checkpoint.dart`; older than 12 h is saved at
  startup). GPS runs in a
  `flutter_foreground_task` location service (no battery exemption).
  Mapbox map with offline packs, pedometer with glitch filtering, BLE
  heart-rate straps (`flutter_blue_plus`), TTS voice coach, music/local
  audio. Gotcha: geolocator has one position stream; cancel the map preview
  stream before a workout subscribes.
- **activity_goals:** `activity-goals`; `ActivityGoalsCubit`, pref
  `activity_goals_v1`, one goal per metric and period; daily resets at
  midnight, weekly Monday-Sunday; steps from `HealthVitalsService` + sessions.
- **health_sync:** `HealthImportService` imports weight and workouts when
  Settings > Health Sync is on, at most hourly, on resume, idempotent (pref
  `health_import_last`).
- **food_scanner:** Scan tab, `food-scan`, `meal-log-history`.
  `FoodScanBloc` (photo, barcode, search, edit, label OCR, custom food),
  `MealLogBloc`. Isar `MealLogCache`, `OfflineFood` (synced from
  `proprietary_products`), `BarcodeCache`. `scan-food` responses cached
  (`FoodCacheKeys`); barcode falls back to OpenFoodFacts (read only: user
  products are never uploaded there). 25 free photo scans a day
  (`is_premium_user`, `get_remaining_scans`); no purchase flow in the app
  yet.
- **diet_plan:** `diet-plan-prefs`, `diet-plan-mode`, `diet-plan-goal`,
  `diet-plan-manual`, `diet-plan-edit`, `diet-plan-result`. `DietPlanCubit`,
  Isar `MealPlanModel` by `dateKey`, prefs `active_plan`,
  `active_plan_preferences`. `generate-diet-plan` (75 s timeout, 15/day;
  `instructions` + `basePlan` tweak a plan).
- **vita:** `vita-chat` (extra `VitaChatArgs` or initial prompt String),
  `vita-analysis`, `vita-diet-plan`, `vita-stress`. Prefs
  `vita_{chat|checkins|scores|insights}_<userId>` (chat keeps 50 messages,
  history 90 days). `vita-chat` 45 s timeout, last 12 turns sent, 40 chats
  and 6 insights a day. `HealthSnapshotBuilder` computes numbers on device;
  `StressEstimator` is pure. Stress check-ins: levels 1 very calm to 5 very
  stressed. `HealthVitalsService` only prompts from `connect()`.
- **reminders:** local notifications (`ReminderScheduler`, presets in
  `domain/reminder_presets.dart`, smart skip when the habit is done today).
  `reminder_actions.dart` has background-isolate helpers (add water,
  save/reset mood, bedtime/wake, read today's water and mood) used by
  notifications and widgets. Notification action ids: `log_water`,
  `sleep_bedtime`, `sleep_wake`.
- **notifications:** `notifications`; `NotificationsCubit` reads table
  `notifications` + realtime channel `notifications:<uid>`; mark-read/delete
  queued offline. `PushService` (FCM; `register_push_token`), no-op without
  Firebase config.
- **gamification / community / challenges (Arena):** `friends`,
  `leaderboard` (`/community/:id`), `challenges`, `badges`,
  `points-history`, `activity-calendar`. `GamificationCubit` (stats,
  awards), `ScoreStreakCard`, `CommunityCubit`, `FriendsCubit`,
  `LeaderboardCubit`, `ChallengesCubit`. Scoring is server-side:
  `submit_daily_report` (latest in `20261015_streak_rest_days.sql`) clamps a
  day's metrics, awards points, streaks and badges. Rest days
  (`player_stats.streak_freezes`, one per 7 active days, max 2, spent by the
  hourly `use-streak-freezes` cron, refunded on late sync);
  `get_badge_progress()` for locked badges. Challenges are online-only.
  Rewards: snackbars via `awardMessage`; the dialog only for a level-up in
  Arena.
- **help_support:** `help-support`, `support-chat` (local scripted bot),
  `contact-support` (mailto); static FAQ.
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
  signed-out sign-up checks (`signup_username_available`, `email_registered`;
  anon can't read `profiles`).
- Never edit an applied migration; add a new one. Clients never write
  points/stats/badges directly: everything goes through RPCs.
- Edge functions (`_shared/llm.ts` Gemini -> Groq fallback, `_shared/quota.ts`):
  `scan-food` (image / search / nutrition / barcode), `vita-chat`
  (chat or insights), `generate-diet-plan` (429 at the daily limit, 422 for
  allergy failures), `send-push` (secret header, FCM v1), `delete-account`,
  `revenuecat-webhook` (table `subscriptions`; fails closed without its
  secret); `fatsecret-proxy` is an unused stub that returns 501. All
  validate input with `_shared/validate.ts` and return short JSON errors.
  No deno locally: type-check with tsc + shims.

## Native Android

- `MainActivity` (FlutterFragmentActivity) channels:
  `com.example.vital_up/audio_intent` (`getInstalledAudioApps`,
  `launchAudioApp`, `playAudioImplicitly`) and
  `com.example.vital_up/usage_stats` (`checkUsageStatsPermission`,
  `getExactUsageStats`, `getScreenEvents`).
- `PermissionsRationaleActivity` (+ `ViewPermissionUsageActivity` alias):
  Health Connect privacy policy link.
- Permissions are minimal on purpose (Play review): no background location,
  no battery-optimisation exemption, Health Connect read-only. Usage Access
  and Health Connect need Play Console declarations.

## Tests

`test/core` (sync, backup sync, offline first, load timeout, tracker,
input rules) and `test/features/<f>`. No mocking library: hand-written fakes
per test (`_FakeRemote`, `FakeProfileRepository`...). Patterns:
`SharedPreferences.setMockInitialValues`, `CacheStore(ConnectivityService(),
directory: tmp)`, Drift `NativeDatabase.memory()`. SQL changes can be
checked against a throwaway local Postgres 18 (`C:/Program
Files/PostgreSQL/18/bin`) with stubbed `auth`/`cron` schemas.

## Gotchas

- The shell is Git Bash on Windows: for `adb shell` paths use
  `MSYS_NO_PATHCONV=1`; long inline heredocs with quotes can fail to parse,
  so write scripts to the scratchpad and run them instead.
- Tool inputs turn `\uXXXX` escapes into literal characters: write escapes
  from a script (e.g. `chr(92)`), then check with `grep -P '[^\x00-\x7F]'`.
- Android widgets (RemoteViews): no plain `<View>` (use `FrameLayout`), tint
  dynamically with `setColorFilter`, progress bars are `ImageView` +
  `wg_bar_fill` clip drawable + `setImageLevel`, text sizes are dp.
- Never prompt for permissions from background work or app resume:
  `SleepService.getSleepDataForLastNight(requestPermission: false)`; closing
  a permission screen resumes the app and would loop.
- `setState(() => future = load())` returns a Future and throws; use a block body.
- `UserAvatar` lives in `core/widgets/user_avatar.dart` (re-exported by
  `community_widgets.dart`).
- Saved reminder presets keep their old text; changing a preset's copy only
  reaches new users or reset presets.
