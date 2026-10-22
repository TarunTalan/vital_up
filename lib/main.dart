import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_preview/device_preview.dart';
import 'package:vital_up/features/feature_tips/data/feature_tips_service.dart';
import 'package:vital_up/features/gamification/presentation/widgets/game_icon.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/core/di/injection_container.dart' as di;
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/monitoring/crash_reporter.dart';
import 'package:vital_up/core/monitoring/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/sync/sync_service.dart';
import 'package:vital_up/core/router/app_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/app_error_fallback.dart';
import 'package:vital_up/core/widgets/biometric_lock_guard.dart';
import 'package:vital_up/core/widgets/app_loading_barrier.dart';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:vital_up/core/config/supabase_config.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/foreground_service_manager.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/services/launcher_shortcuts.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/foreground_service_manager.dart' show clearStaleWorkoutNotifications;
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_cubit.dart' as vital_up_dashboard;
import 'package:vital_up/features/notifications/data/services/push_service.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';

import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';
import 'package:vital_up/core/config/secure_session_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Which icons are bundled: missing ones show their fallback quietly.
  BundledAssets.preload();
  GoogleFonts.config.allowRuntimeFetching = false; // bundled in assets/google_fonts
  // OFL fonts ship with their licences; list them on the licences page.
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in [
      ('Nunito', 'Nunito-OFL.txt'),
      ('JetBrains Mono', 'JetBrainsMono-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/fonts/licenses/$file'));
    }
  });
  // debugPrint still writes to logcat in release builds, and error text can
  // carry server or health details. Real problems go to Crashlytics.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};

  // Uncaught errors go to Crashlytics (release builds, once configured).
  // Firebase and Supabase don't depend on each other: start both now and
  // only wait for Firebase where it's needed.
  final firebaseReady = CrashReporter.init().then(
    (_) => AnalyticsService.init(),
  );

  // A widget that fails to build shows a calm placeholder in release
  // builds instead of the grey/red error box with raw exception text.
  if (!kDebugMode) ErrorWidget.builder = AppErrorFallback.errorWidgetBuilder;
  
  // Initialize communication port for foreground task manager
  ForegroundServiceManager.init();

  // Set Mapbox access token globally (required by mapbox_maps_flutter v2.x)
  MapboxOptions.setAccessToken(SupabaseConfig.mapboxAccessToken);

  // Lock the app to Portrait mode
  final orientationSet = SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  var started = false;
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(supabaseUrl: SupabaseConfig.url),
      ),
    );

    // Initialize dependency injection (database, network, storage, etc.)
    await di.initDependencies();
    // Push and the user watchers below need Firebase.
    await firebaseReady;

    // Push notifications (no-op until Firebase is configured).
    sl<PushService>().init().catchError((e) => debugPrint('Push init error: $e'));

    // Re-apply reminders (app update, time-zone change). Loading the time
    // zone database is heavy synchronous work: keep it off the first frames.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        sl<RemindersService>().resync().catchError(
          (e) => debugPrint('Reminders resync error: $e'),
        );
        sl<RemindersService>().resyncOnNewDay();
      });
    });

    CrashReporter.watchUser(sl<SupabaseClient>());
    AnalyticsService.watchUser(sl<SupabaseClient>());

    // Back up logs to the cloud and bring back ones from other devices.
    sl<SyncService>().start();

    // Only at launch (not in the widget's background engine, which also
    // runs initDependencies): nothing is recording yet, so workout
    // notifications left by a closed app are stale. A GPS workout's comes
    // back on Resume; the timer's stays while a timer is saved.
    clearStaleWorkoutNotifications();

    // Trigger background sync of popular products to offline DB
    final isarService = sl<IsarService>();
    final supabase = sl<SupabaseClient>();
    isarService.syncOfflineFoodsBackground(supabase, sl<SharedPreferences>());
    started = true;
  } catch (e, stackTrace) {
    CrashReporter.report(e, stackTrace, reason: 'Initialization failed');
  }
  // Both are quick and never throw; make sure they're done before the UI.
  await firebaseReady.catchError((_) {});
  await orientationSet;

  // Core services are missing (e.g. the database couldn't open): the app
  // can't work, so say so plainly instead of crashing on the first lookup.
  if (!started && !sl.isRegistered<AuthCubit>()) {
    runApp(const _StartupFailedApp());
    return;
  }

  // Constant conditions: release builds drop device_preview entirely, and
  // profile builds skip it so performance traces are honest.
  runApp(
    !kDebugMode
        ? const MyApp()
        : DevicePreview(builder: (context) => const MyApp()),
  );
  // Long-press shortcuts on the app icon; one that launched the app opens
  // once Home shows.
  LauncherShortcuts.init();
  // Pages opened count as features found (no tip about them).
  sl<FeatureTipsService>().attach(AppRouter.router);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<AuthCubit>()..checkSession()),
        BlocProvider(create: (context) => sl<OnboardingCubit>()),
        // One app-wide copy: the Home card and the routed trends page share
        // it. (SleepCubit lives on the dashboard: it reads the signed-in
        // user's nights.)
        BlocProvider(create: (context) => sl<vital_up_dashboard.ScreenTimeCubit>()..loadStats()),
        BlocProvider(create: (context) => sl<SettingsCubit>()..loadSettings()),
        // VitalUp Pro, read by gates and the paywall anywhere in the app.
        BlocProvider.value(value: sl<SubscriptionCubit>()..start()),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settingsState) {
          ThemeMode themeMode = ThemeMode.system;
          if (settingsState is SettingsLoaded) {
            switch (settingsState.settings.themeMode.toLowerCase()) {
              case 'light':
                themeMode = ThemeMode.light;
                break;
              case 'dark':
                themeMode = ThemeMode.dark;
                break;
              case 'system':
              default:
                themeMode = ThemeMode.system;
                break;
            }
          }

          return MaterialApp.router(
            title: 'VitalUp',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            locale: kDebugMode ? DevicePreview.locale(context) : null,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: AppRouter.router,
            builder: (context, child) {
              final previewChild = kDebugMode
                  ? DevicePreview.appBuilder(context, child)
                  : child!;
              return AppLoadingBarrier(
                child: MultiBlocListener(
                  listeners: [
                    BlocListener<AuthCubit, AuthState>(
                      listener: (context, state) {
                        if (state is AuthError) {
                          showErrorSnackBar(context, state.message);
                        }
                      },
                    ),
                  ],
                  child: BiometricLockGuard(
                    child: ResponsiveTextScale(child: previewChild),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Shown when start-up failed before the app's services were ready.
class _StartupFailedApp extends StatelessWidget {
  const _StartupFailedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VitalUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const Scaffold(
        body: SafeArea(
          child: AppErrorFallback(
            message: "VitalUp couldn't start. Close the app and open it again.",
          ),
        ),
      ),
    );
  }
}
