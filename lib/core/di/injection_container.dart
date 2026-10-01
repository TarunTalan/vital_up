import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/network/dio_client.dart';
import 'package:vital_up/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:vital_up/features/auth/data/datasources/auth_local_data_source_impl.dart';
import 'package:vital_up/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:vital_up/features/auth/data/datasources/auth_remote_data_source_impl.dart';
import 'package:vital_up/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_data_store.dart';
import 'package:vital_up/features/onboarding/data/datasources/shared_preferences_onboarding_data_store.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_remote_data_source.dart';
import 'package:vital_up/features/onboarding/data/datasources/onboarding_remote_data_source_impl.dart';
import 'package:vital_up/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:vital_up/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:vital_up/features/diet_plan/data/datasources/diet_plan_remote_datasource.dart';
import 'package:vital_up/features/diet_plan/data/repositories/diet_plan_repository_impl.dart';
import 'package:vital_up/features/diet_plan/domain/repositories/diet_plan_repository.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/generate_meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/get_active_meal_plan.dart';
import 'package:vital_up/features/diet_plan/domain/usecases/set_active_meal_plan.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/vita/data/datasources/vita_local_datasource.dart';
import 'package:vital_up/features/vita/data/datasources/vita_remote_datasource.dart';
import 'package:vital_up/features/vita/data/repositories/vita_repository_impl.dart';
import 'package:vital_up/features/vita/data/services/health_snapshot_builder.dart';
import 'package:vital_up/features/vita/data/services/health_vitals_service.dart';
import 'package:vital_up/features/vita/domain/repositories/vita_repository.dart';
import 'package:vital_up/features/vita/presentation/cubit/vita_chat_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vital_up/features/dashboard/data/services/screen_time_service.dart' as vital_up_dashboard;
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_cubit.dart' as vital_up_dashboard;
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_cubit.dart';
import 'package:vital_up/features/activity_goals/data/datasources/activity_goals_local_datasource.dart';
import 'package:vital_up/features/community/data/datasources/community_remote_datasource.dart';
import 'package:vital_up/features/community/data/repositories/community_repository_impl.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/community/presentation/cubit/community_cubit.dart';
import 'package:vital_up/features/community/presentation/cubit/friends_cubit.dart';
import 'package:vital_up/features/gamification/data/datasources/gamification_remote_datasource.dart';
import 'package:vital_up/features/gamification/data/repositories/gamification_repository_impl.dart';
import 'package:vital_up/features/gamification/data/services/daily_metrics_collector.dart';
import 'package:vital_up/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:vital_up/features/gamification/presentation/cubit/gamification_cubit.dart';
import 'package:vital_up/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:vital_up/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:vital_up/features/notifications/data/services/push_service.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';
import 'package:vital_up/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:vital_up/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:vital_up/features/activity_goals/data/repositories/activity_goals_repository_impl.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/stress_checkin_cubit.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_cubit.dart';
import 'package:vital_up/features/food_scanner/data/datasources/meal_log_local_data_source.dart';
import 'package:vital_up/features/food_scanner/data/datasources/meal_log_local_data_source_impl.dart';
import 'package:vital_up/features/food_scanner/data/repositories/food_recognition_repository_impl.dart';
import 'package:vital_up/features/food_scanner/data/repositories/meal_log_repository_impl.dart';
import 'package:vital_up/features/food_scanner/data/repositories/meal_recommendation_repository_impl.dart';
import 'package:vital_up/features/food_scanner/data/repositories/nutrition_repository_impl.dart';
import 'package:vital_up/features/food_scanner/data/repositories/subscription_repository_impl.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/food_recognition_repository.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/meal_log_repository.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/meal_recommendation_repository.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/nutrition_repository.dart';
import 'package:vital_up/features/food_scanner/domain/repositories/subscription_repository.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/delete_meal_log.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/get_meal_recommendation.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/scan_barcode.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/scan_food_image.dart';
import 'package:vital_up/features/food_scanner/domain/usecases/save_meal_log.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/food_scan_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';

import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource_impl.dart';
import 'package:vital_up/features/profile/domain/repositories/profile_repository.dart';
import 'package:vital_up/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';

import 'package:vital_up/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:vital_up/features/settings/data/datasources/settings_local_datasource_impl.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';
import 'package:vital_up/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/location_tracking_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/step_counter_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/location_tracking_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/step_counter_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_location_stream.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_steps_stream.dart';
import 'package:vital_up/core/database/drift_database.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/map_tile_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/start_tracking_session.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/pause_tracking_session.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/resume_tracking_session.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/stop_and_save_session.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_session_history.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/save_session_annotation.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/delete_activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_session_stream.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_bloc.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_bloc.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';
import 'package:vital_up/features/activity_tracking/data/repositories/activity_history_repository_impl.dart';
import 'package:vital_up/features/activity_tracking/services/workout_audio_service.dart';
import 'package:vital_up/features/activity_tracking/services/local_audio_query_service.dart';
import 'package:vital_up/features/activity_tracking/services/in_app_audio_downloader.dart';
import 'package:vital_up/features/activity_tracking/services/voice_coach_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vital_up/features/reminders/data/reminder_scheduler.dart';
import 'package:vital_up/features/account/data/account_service.dart';
import 'package:vital_up/core/sync/sync_adapters.dart';
import 'package:vital_up/core/sync/sync_service.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
import 'package:vital_up/features/reminders/data/reminders_local_datasource.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';
import 'package:vital_up/features/reminders/presentation/cubit/reminders_cubit.dart';


final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  // 1. Logger
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
  );
  sl.registerLazySingleton<Logger>(() => logger);

  // 2. SharedPreferences (Local key-value config cache)
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // 3. Secure Storage (For OAuth tokens)
  const secureStorage = FlutterSecureStorage();
  sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

  // 4. Local Database (Isar)
  final isarService = IsarService();
  try {
    await isarService.init();
  } catch (e) {
    logger.e('Failed to initialize Isar database: $e');
  }
  sl.registerLazySingleton<IsarService>(() => isarService);

  // 5. Network (Dio client)
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerLazySingleton<DioClient>(() => DioClient(
        dio: sl<Dio>(),
        logger: sl<Logger>(),
      ));

  // 6. Auth Clean Architecture Layers
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(secureStorage: sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(supabaseClient: sl<SupabaseClient>(), logger: sl<Logger>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl<AuthRemoteDataSource>(), localDataSource: sl<AuthLocalDataSource>()),
  );

  // 7. Blocs / Cubits
  sl.registerFactory(
    () => AuthCubit(
      authRepository: sl<AuthRepository>(),
      beforeSignOut: () async {
        await sl<PushService>().unregister();
        // Back up what's left, then remove this account's data from the
        // device; it comes back from the cloud on the next sign-in.
        await sl<SyncService>().sync();
        await sl<AccountService>().clearLocalUserData();
      },
    ),
  );
  
  // 8. Onboarding
  sl.registerLazySingleton<OnboardingDataStore>(
    () => SharedPreferencesOnboardingDataStore(sl<SharedPreferences>()),
  );
  sl.registerLazySingleton<OnboardingRemoteDataSource>(
    () => OnboardingRemoteDataSourceImpl(supabaseClient: sl<SupabaseClient>(), logger: sl<Logger>()),
  );
  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepositoryImpl(remoteDataSource: sl<OnboardingRemoteDataSource>()),
  );
  sl.registerFactory(() => OnboardingCubit(sl<OnboardingDataStore>(), sl<OnboardingRepository>()));

  // 9. Food Scan Clean Architecture Layers
  sl.registerLazySingleton<Uuid>(() => const Uuid());

  sl.registerLazySingleton<MealLogLocalDataSource>(
    () => MealLogLocalDataSourceImpl(
      isarService: sl<IsarService>(),
      uuid: sl<Uuid>(),
      sync: sl<SyncService>(),
    ),
  );

  sl.registerLazySingleton<FoodRecognitionRepository>(
    () => FoodRecognitionRepositoryImpl(
      logger: sl<Logger>(),
      supabaseClient: sl<SupabaseClient>(),
    ),
  );

  sl.registerLazySingleton<NutritionRepository>(
    () => NutritionRepositoryImpl(
      dio: sl<Dio>(),
      logger: sl<Logger>(),
      supabaseClient: sl<SupabaseClient>(),
      isarService: sl<IsarService>(),
    ),
  );

  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(
      supabaseClient: sl<SupabaseClient>(),
      logger: sl<Logger>(),
    ),
  );

  sl.registerLazySingleton<MealLogRepository>(
    () => MealLogRepositoryImpl(
      localDataSource: sl<MealLogLocalDataSource>(),
      logger: sl<Logger>(),
    ),
  );

  sl.registerLazySingleton<MealRecommendationRepository>(
    () => MealRecommendationRepositoryImpl(),
  );

  sl.registerLazySingleton<ScanFoodImage>(
    () => ScanFoodImage(
      foodRecognitionRepository: sl<FoodRecognitionRepository>(),
      nutritionRepository: sl<NutritionRepository>(),
    ),
  );

  sl.registerLazySingleton<ScanBarcode>(
    () => ScanBarcode(nutritionRepository: sl<NutritionRepository>()),
  );

  sl.registerLazySingleton<SaveMealLog>(
    () => SaveMealLog(mealLogRepository: sl<MealLogRepository>()),
  );

  sl.registerLazySingleton<GetMealLogHistory>(
    () => GetMealLogHistory(mealLogRepository: sl<MealLogRepository>()),
  );

  sl.registerLazySingleton<DeleteMealLog>(
    () => DeleteMealLog(mealLogRepository: sl<MealLogRepository>()),
  );

  sl.registerLazySingleton<GetMealRecommendation>(
    () => GetMealRecommendation(mealRecommendationRepository: sl<MealRecommendationRepository>()),
  );

  sl.registerFactory(() => FoodScanBloc(
    scanFoodImage: sl<ScanFoodImage>(),
    scanBarcode: sl<ScanBarcode>(),
    saveMealLog: sl<SaveMealLog>(),
    getMealRecommendation: sl<GetMealRecommendation>(),
    nutritionRepository: sl<NutritionRepository>(),
    uuid: sl<Uuid>(),
    logger: sl<Logger>(),
  ));

  sl.registerFactory(() => MealLogBloc(
    getMealLogHistory: sl<GetMealLogHistory>(),
    deleteMealLog: sl<DeleteMealLog>(),
    isarService: sl<IsarService>(),
  ));
  // 9. Diet Plan
  sl.registerLazySingleton<DietPlanRemoteDataSource>(
        () => DietPlanRemoteDataSourceImpl(sl<DioClient>()),
  );
  sl.registerLazySingleton<DietPlanRepository>(
        () => DietPlanRepositoryImpl(
      remoteDataSource: sl<DietPlanRemoteDataSource>(),
      isarService: sl<IsarService>(),
      prefs: sl<SharedPreferences>(),
    ),
  );
  sl.registerLazySingleton(() => GenerateMealPlan(sl<DietPlanRepository>()));
  sl.registerLazySingleton(() => GetActiveMealPlan(sl<DietPlanRepository>()));
  sl.registerLazySingleton(() => SetActiveMealPlan(sl<DietPlanRepository>()));
  sl.registerFactory(
        () => DietPlanCubit(
      generateMealPlan: sl<GenerateMealPlan>(),
      getActiveMealPlan: sl<GetActiveMealPlan>(),
      setActiveMealPlan: sl<SetActiveMealPlan>(),
    ),
  );

  // 10. Profile Screen Dependencies
  sl.registerLazySingleton<ProfileRemoteDataSource>(
        () => ProfileRemoteDataSourceImpl(supabaseClient: sl<SupabaseClient>(), logger: sl<Logger>()),
  );
  sl.registerLazySingleton<ProfileRepository>(
        () => ProfileRepositoryImpl(
      remoteDataSource: sl<ProfileRemoteDataSource>(),
      isarService: sl<IsarService>(),
      logger: sl<Logger>(),
    ),
  );
  sl.registerFactory(() => ProfileCubit(profileRepository: sl<ProfileRepository>()));

  // 11. Settings Dependencies
  sl.registerLazySingleton<SettingsLocalDataSource>(
        () => SettingsLocalDataSourceImpl(sharedPreferences: sl<SharedPreferences>()),
  );
  sl.registerLazySingleton<SettingsRepository>(
        () => SettingsRepositoryImpl(localDataSource: sl<SettingsLocalDataSource>()),
  );
  sl.registerFactory(
    () => SettingsCubit(
      settingsRepository: sl<SettingsRepository>(),
      onNotificationsChanged: (enabled) async {
        await sl<PushService>().setEnabled(enabled);
        await sl<RemindersService>().resync();
      },
    ),
  );

  // 9. Activity tracking (Drift DB and Repositories)
  final driftDb = AppDatabase();
  sl.registerLazySingleton<AppDatabase>(() => driftDb);

  sl.registerLazySingleton<ActivityRepository>(
        () => ActivityRepositoryImpl(sl<AppDatabase>(), sl<SyncService>()),
  );
  // A workout still open from a previous run means the app was killed
  // mid-recording; close it so its checkpointed progress shows in history.
  try {
    await sl<ActivityRepository>().finalizeInterruptedSessions();
  } catch (e) {
    debugPrint('Could not finalize interrupted activity sessions: $e');
  }
  sl.registerLazySingleton<ActivityHistoryRepository>(
        () => ActivityHistoryRepositoryImpl(
      activityRepository: sl<ActivityRepository>(),
      sharedPreferences: sl<SharedPreferences>(),
    ),
  );
  sl.registerLazySingleton<MapTileRepository>(
        () => MapTileRepositoryImpl(),
  );

  sl.registerLazySingleton<LocationTrackingRepository>(
        () => LocationTrackingRepositoryImpl(),
  );
  sl.registerLazySingleton<StepCounterRepository>(
        () => StepCounterRepositoryImpl(),
  );

  // Use cases
  sl.registerLazySingleton(
        () => GetLiveLocationStream(sl<LocationTrackingRepository>()),
  );
  sl.registerLazySingleton(
        () => GetLiveStepsStream(sl<StepCounterRepository>()),
  );
  sl.registerLazySingleton(
        () => StartTrackingSession(sl<LocationTrackingRepository>()),
  );
  sl.registerLazySingleton(
        () => PauseTrackingSession(),
  );
  sl.registerLazySingleton(
        () => ResumeTrackingSession(),
  );
  sl.registerLazySingleton(
        () => StopAndSaveSession(sl<ActivityRepository>()),
  );
  sl.registerLazySingleton(
        () => GetSessionHistory(sl<ActivityRepository>()),
  );
  sl.registerLazySingleton(
        () => GetActivityHistory(sl<ActivityHistoryRepository>()),
  );
  sl.registerLazySingleton(
        () => SaveSessionAnnotation(sl<ActivityHistoryRepository>()),
  );
  sl.registerLazySingleton(
        () => DeleteActivitySession(sl<ActivityHistoryRepository>()),
  );
  sl.registerLazySingleton(
        () => GetLiveSessionStream(sl<LocationTrackingRepository>()),
  );

  // Bloc
  sl.registerFactory(
        () => ActivityTrackingBloc(
      getLiveLocationStream: sl<GetLiveLocationStream>(),
      getLiveStepsStream: sl<GetLiveStepsStream>(),
      stopAndSaveSession: sl<StopAndSaveSession>(),
      authRepository: sl<AuthRepository>(),
    ),
  );
  sl.registerFactory(
        () => ActivityHistoryBloc(
      getActivityHistory: sl<GetActivityHistory>(),
      saveSessionAnnotation: sl<SaveSessionAnnotation>(),
      deleteActivitySession: sl<DeleteActivitySession>(),
    ),
  );

  // Audio Services
  sl.registerLazySingleton<WorkoutAudioService>(() => WorkoutAudioService());
  sl.registerLazySingleton<LocalAudioQueryService>(() => LocalAudioQueryService());
  sl.registerLazySingleton<InAppAudioDownloader>(() => InAppAudioDownloader(sl<IsarService>()));
  sl.registerLazySingleton<VoiceCoachService>(() => VoiceCoachService());
  // 10. Dashboard / Screen Time / Sleep
  sl.registerLazySingleton<vital_up_dashboard.ScreenTimeService>(() => vital_up_dashboard.ScreenTimeService());
  sl.registerFactory(() => vital_up_dashboard.ScreenTimeCubit(sl<vital_up_dashboard.ScreenTimeService>()));

  sl.registerLazySingleton<SleepService>(() => SleepService(sl<IsarService>(), sl<SharedPreferences>(), sl<SyncService>()));
  sl.registerFactory(() => SleepCubit(sl<SleepService>()));

  sl.registerLazySingleton<WaterIntakeService>(() => WaterIntakeService(sl<IsarService>(), sl<SharedPreferences>(), sl<SyncService>()));
  sl.registerFactory(() => WaterIntakeCubit(sl<WaterIntakeService>()));
  sl.registerLazySingleton<TrendsService>(
    () => TrendsService(
      sl<WaterIntakeService>(),
      sl<SleepService>(),
      sl<VitaRepository>(),
      sl<GetMealLogHistory>(),
      sl<GetActiveMealPlan>(),
    ),
  );

  // 12. Vita health coach
  sl.registerLazySingleton<HealthVitalsService>(
    () => HealthVitalsService(sl<SharedPreferences>()),
  );
  sl.registerLazySingleton<HealthSnapshotBuilder>(
    () => HealthSnapshotBuilder(
      mealHistory: sl<GetMealLogHistory>(),
      isar: sl<IsarService>(),
      water: sl<WaterIntakeService>(),
      screenTime: sl<vital_up_dashboard.ScreenTimeService>(),
      activity: sl<GetActivityHistory>(),
      onboarding: sl<OnboardingDataStore>(),
      activePlan: sl<GetActiveMealPlan>(),
      vitals: sl<HealthVitalsService>(),
      supabase: sl<SupabaseClient>(),
    ),
  );
  sl.registerLazySingleton<VitaRepository>(
    () => VitaRepositoryImpl(
      remote: VitaRemoteDataSource(sl<SupabaseClient>()),
      local: VitaLocalDataSource(sl<SharedPreferences>()),
      snapshots: sl<HealthSnapshotBuilder>(),
      vitals: sl<HealthVitalsService>(),
      supabase: sl<SupabaseClient>(),
    ),
  );
  sl.registerFactory(() => VitaChatCubit(sl<VitaRepository>()));
  sl.registerFactory(() => StressCheckInCubit(sl<VitaRepository>()));

  // 13. Activity goals
  sl.registerLazySingleton<ActivityGoalsRepository>(
    () => ActivityGoalsRepositoryImpl(
      local: ActivityGoalsLocalDataSource(sl<SharedPreferences>()),
      history: sl<GetActivityHistory>(),
      health: sl<HealthVitalsService>(),
    ),
  );
  sl.registerFactory(() => ActivityGoalsCubit(sl<ActivityGoalsRepository>()));

  // 14. Gamification: points, levels, badges, streaks
  sl.registerLazySingleton<GamificationRepository>(
    () => GamificationRepositoryImpl(
      remote: GamificationRemoteDataSource(sl<SupabaseClient>()),
      collector: DailyMetricsCollector(
        goals: sl<ActivityGoalsRepository>(),
        history: sl<GetActivityHistory>(),
        health: sl<HealthVitalsService>(),
        meals: sl<GetMealLogHistory>(),
        activePlan: sl<GetActiveMealPlan>(),
        water: sl<WaterIntakeService>(),
        sleep: sl<SleepService>(),
        vita: VitaLocalDataSource(sl<SharedPreferences>()),
        isar: sl<IsarService>(),
      ),
      prefs: sl<SharedPreferences>(),
    ),
  );
  sl.registerFactory(() => GamificationCubit(sl<GamificationRepository>()));

  // 15. Community, friends & leaderboards
  sl.registerLazySingleton<CommunityRepository>(
    () => CommunityRepositoryImpl(CommunityRemoteDataSource(sl<SupabaseClient>())),
  );
  sl.registerFactory(() => CommunityCubit(sl<CommunityRepository>()));
  sl.registerFactory(() => FriendsCubit(sl<CommunityRepository>()));

  // 16. Usernames (Google sign-ups choose theirs after sign-in)
  sl.registerLazySingleton(() => UsernameService(sl<SupabaseClient>()));

  // 17. Notifications: friend requests, achievements, announcements
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(
      NotificationsRemoteDataSource(sl<SupabaseClient>()),
      sl<CommunityRepository>(),
    ),
  );
  sl.registerFactory(() => NotificationsCubit(sl<NotificationsRepository>()));
  sl.registerLazySingleton(FlutterLocalNotificationsPlugin.new);
  sl.registerLazySingleton(
    () => PushService(
      sl<SupabaseClient>(),
      sl<SettingsRepository>(),
      sl<NotificationsRepository>(),
      sl<FlutterLocalNotificationsPlugin>(),
    ),
  );

  // 18. Reminders (local, on-device schedule)
  sl.registerLazySingleton(() => ReminderScheduler(sl<FlutterLocalNotificationsPlugin>()));
  sl.registerLazySingleton(
    () => RemindersService(
      RemindersLocalDataSource(sl<SharedPreferences>()),
      sl<ReminderScheduler>(),
      sl<SettingsRepository>(),
    ),
  );
  sl.registerFactory(() => RemindersCubit(sl<RemindersService>()));

  // 19. Cloud backup of logs (water, sleep, meals, workouts, weight)
  sl.registerLazySingleton(
    () => SyncService(sl<SupabaseClient>(), sl<SharedPreferences>(), [
      WaterSyncAdapter(sl<IsarService>()),
      SleepSyncAdapter(sl<IsarService>()),
      MealSyncAdapter(sl<IsarService>()),
      WeightSyncAdapter(sl<IsarService>()),
      ActivitySyncAdapter(sl<AppDatabase>()),
    ]),
  );

  // 21. Weight log
  sl.registerLazySingleton(
    () => WeightService(
      sl<IsarService>(),
      sl<SupabaseClient>(),
      sl<SettingsRepository>(),
      sl<SharedPreferences>(),
      sl<SyncService>(),
    ),
  );

  // 20. Account deletion
  sl.registerLazySingleton(
    () => AccountService(
      sl<SupabaseClient>(),
      sl<AuthRepository>(),
      sl<RemindersService>(),
      sl<IsarService>(),
      sl<AppDatabase>(),
      sl<SharedPreferences>(),
      sl<SyncService>(),
    ),
  );
}
