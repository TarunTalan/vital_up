# VitalUp

Flutter health app (Android first; iOS builds but has no home screen widget
yet). Tracks activity, nutrition (AI food scanner), water, sleep, mood/stress,
weight and screen time, with an AI coach (Vita), a gamified Arena (points,
badges, challenges, friends, leaderboards) and Android home screen widgets.

This file is the project map. Read the files it points to for detail instead
of exploring the tree.

## Commands

```bash
dart analyze <paths>           # prefer paths; `dart analyze lib` takes ~6 min
flutter test                   # all tests; test/ mirrors lib/
flutter test test/features/<feature>
dart run build_runner build --delete-conflicting-outputs   # Isar/Drift/injectable codegen
flutter build apk --debug
cd android && ./gradlew.bat :app:compileDebugKotlin        # quick native check
```

`lib/core/config/supabase_config.dart` is gitignored (copy the `.example`).
Known pre-existing analyzer warnings (not ours to fix unless asked):
`screen_time_card.dart`, `sleep_card.dart`, `water_intake_card.dart`,
`home_widget_service.dart` in `features/home_widget` is clean; elsewhere
various `prefer_initializing_formals` infos.

## Stack and architecture

- **State:** flutter_bloc Cubits/Blocs. **DI:** get_it `sl` in
  `lib/core/di/injection_container.dart` (`initDependencies`). Most cubits are
  `registerFactory` (e.g. `ProfileCubit`); services/repos are lazy singletons.
- **Routing:** go_router, `lib/core/router/app_router.dart` (`AppRouter.router`,
  routes by `name`, pages wrapped in `AppPage` for transitions). Initial
  location `/splash` → `onboarding` / `health-onboarding` / `dashboard`.
- **Layers per feature:** `lib/features/<f>/{data,domain,presentation}` (clean
  architecture: datasources → repositories → entities/usecases → cubit/pages/widgets).
  Errors use `dartz` `Either<Failure, T>` (`core/error`).
- **Data:** offline first. Isar (`core/database/isar_service.dart`,
  collections in `core/database/collections`) for logs; SharedPreferences for
  goals/settings; `core/cache/cache_store.dart` for cached server JSON;
  `core/sync/sync_service.dart` backs up logs to Supabase and pulls other
  devices' entries; `pending_writes.dart` queues offline server writes;
  `HabitEvents` (`core/events`) broadcasts "something was logged".
- **Backend:** Supabase (auth, Postgres, storage, realtime, edge functions in
  `supabase/functions`: scan-food, vita-chat, generate-diet-plan, send-push,
  delete-account, fatsecret-proxy, revenuecat-webhook). Firebase for push
  (FCM) and Crashlytics. Health Connect / HealthKit via `health`.
- **Bootstrap:** `lib/main.dart` (Supabase, DI, push, reminders, sync; global
  BlocProviders: Auth, Onboarding, ScreenTime, Sleep, Settings; theme mode
  from `SettingsCubit`; wrapped in `DevicePreview` for development).

## App shell

`features/dashboard/presentation/pages/dashboard_page.dart` hosts the five
tabs with the floating `AppBottomNav`: 0 Home (`_HomeTab`), 1 Scan
(`FoodScannerPage`), 2 Vita (`VitaHomePage`), 3 Arena (`CommunityHubPage`),
4 Profile (`ProfilePage(onOpenArena:)`). It owns the per-session cubits
(water, sleep, trends, activity goals, gamification, notifications, stress,
diet plan, profile) and shows award snackbars outside Arena.

## UI system (follow it; Figma is the source of truth)

- Tokens: `core/theme/app_colors.dart` (`AppColors`, tracker accents
  `track*`, `stressLevels`, `scoreBonus`...), `app_dimens.dart` (`AppDimens`
  spacing/radii/sizes, `AppShadows`, `AppDurations`), `app_text_styles.dart`,
  `app_theme.dart` (`VitalUpColors` extension). `design/figma_tokens.md` maps
  them to Figma. Font: SF Pro Rounded.
- Lookups: `context.colors`, `context.text`, `context.vColors` (glassFill,
  glassBorder, grayText, primaryFill, track, success, warning...),
  `context.gutter` (16dp), `context.w(x)`, `context.safePadding`
  (`theme_context.dart`, `core/utils/responsive.dart`).
- Rules: no hardcoded colours/sizes, 16dp gutter, no emojis (Material/SVG
  icons; icon assets are supplied by the user, never created), Home is
  health-first and calm, gamification lives in Arena.
- Core widgets (`lib/core/widgets`): `AppScaffold` (background, header,
  scroll, `onRefresh`, `bottomBar`), `AppPageHeader` + `AppHeaderAction`,
  `AppSectionHeader` (uppercase grey title + "See all"), `AppCard` (glass
  card; `AppIconBadge`, `AppProgressBar`, `AppCaption`, `AppInfoNote` live in
  `app_card.dart`), `AppListGroup` + `AppListTile` (grouped settings-style
  rows), `AppSegmentedControl` (Figma segmented tabs; `compact` for rows),
  `AppPrimaryButton`/`AppSecondaryButton`, `AppTextField` (+ `.integer`,
  `.decimal`, `AppDropdownField`), `UserAvatar`, `LoadErrorView`,
  `VitalUpLoader`, `AppScoreRing`. Tracker kit in `core/widgets/tracker/`:
  `TrackerMetric` enum (label, icon, colour, route per metric),
  `TrackerCard`, `TrackerFigureRow`, `TrackerStatusChip`, `TrackerQuickAction`,
  `TrackerRing`, quick-log hub. Sheets/dialogs/snackbars:
  `core/utils/smooth_ui_helper.dart` (`showAppBottomSheet` already pads for
  the keyboard; `showSmoothDialog`, `showSuccessSnackBar`, `showErrorSnackBar`).
- Dashboard cards: `features/dashboard/presentation/widgets/`
  (`today_summary_card.dart` is the Today hero; `dashboard_card_header.dart`
  has `DashboardCardHeader`, `formatDashboardDuration`; `trend_widgets.dart`
  has `CardLink`, `TrendRangeToggle`).

## Feature notes

- **profile:** `ProfilePage` (identity card → Account details, one-line Arena
  strip, `HealthSnapshotCard`, Health and Account `AppListGroup`s, Sign out),
  `AccountDetailsPage` (route `account-details`; name, `UsernameInput`
  availability check, DOB ddMMyyyy, gender male/female, read-only email,
  export/delete), `HealthDetailsPage` (route `health-details`; per-section
  edit sheets; weight is logged through `WeightService` / `showWeightEntrySheet`;
  units come from Settings; sleep goal lives in My goals via `SleepService`).
  Helpers: `presentation/utils/body_metrics.dart` (height/weight/BMI, onboarding
  activity values, `watchSettings`). Pass the Profile tab's `ProfileCubit` as
  `extra` when pushing these routes (`_withProfileCubit` in the router);
  `ProfileState.shownProfile` gives the profile any state carries; a failed
  save emits `ProfileError` then `ProfileLoaded(previous)`.
- **settings:** Appearance, Units, Notifications, Connected, Privacy &
  security (app lock, leaderboard sheet), About. `SettingsEntity` holds
  themeMode, units (`cm`/`in`, `kg`/`lbs`), notification and health-sync flags.
- **home_widget (Android):** five widgets (Today, My metrics, Water, Mood
  check-in, Shortcuts). Dart formats everything
  (`data/widget_data.dart`: `WidgetInputs` → `buildTiles` → `publishWidgets`),
  Kotlin only lays it out (`android/app/src/main/kotlin/.../VitalWidget.kt`,
  `MetricsWidget.kt`, `HydrationWidgetProvider.kt`, `MoodWidgetProvider.kt`,
  `QuickShortcutsWidgetProvider.kt`; layouts `res/layout/wg_*.xml`), and
  `presentation/widget_previews.dart` mirrors the layouts in Flutter. Keep
  size thresholds and dimensions identical on both sides. Full refresh in
  `HomeWidgetService.refresh`; widget buttons run `homeWidgetCallback`
  (`data/widget_background.dart`, on-device data only). Widget taps go
  through GoRouter `/open?route=` → `HomeWidgetService.handleLink`
  (Home underneath, Back returns Home; held until Home shows on cold start).
  Android pins at a provider's default size, so each offered size is its own
  provider (`WidgetSizes.kt`, `res/xml/*_info.xml`, manifest receivers;
  `WidgetSizeProviders` maps preview size tabs to them). While refreshing,
  headers swap the refresh icon for a spinner (`refreshing_since_ms`).
  Details and storage keys: `docs/ios-home-widget.md`.
- **gamification / community / challenges:** Arena tab. `ScoreStreakCard`,
  `GamificationCubit` (stats, awards), badges, points history, leaderboards
  (`CommunitySettingsSheet.show(context, cubit:)`), friend challenges.
- **vita:** AI coach (chat, health analysis, diet plan, stress guide);
  stress check-ins (`StressCheckIn`, levels 1 very calm to 5 very stressed)
  stored per user in SharedPreferences `vita_checkins_<userId>`.
- **reminders:** local notifications; `reminder_actions.dart` also has the
  background-isolate helpers (add water, save/reset mood, read today's water
  and mood) used by notifications and widgets.

## Gotchas

- The shell is Git Bash on Windows: for `adb shell` paths use
  `MSYS_NO_PATHCONV=1`; long inline heredocs with quotes can fail to parse,
  so write scripts to the scratchpad and run them instead.
- Android widgets (RemoteViews): no plain `<View>` (use `FrameLayout`), tint
  dynamically with `setColorFilter`, progress bars are `ImageView` +
  `wg_bar_fill` clip drawable + `setImageLevel`, text sizes are dp.
- `SleepService.getSleepDataForLastNight()` asks for Health Connect access
  unless `requestPermission: false`; never prompt from background work.
- `setState(() => future = load())` returns a Future and throws; use a block body.
- `UserAvatar` moved to `core/widgets/user_avatar.dart`
  (re-exported by `community_widgets.dart`).
