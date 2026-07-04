import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_session_stream.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_bloc.dart';

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
  sl.registerFactory(() => AuthCubit(authRepository: sl<AuthRepository>()));
  
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

  // 9. Activity tracking (Drift DB and Repositories)
  final driftDb = AppDatabase();
  sl.registerLazySingleton<AppDatabase>(() => driftDb);

  sl.registerLazySingleton<ActivityRepository>(
    () => ActivityRepositoryImpl(sl<AppDatabase>()),
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
    () => GetLiveSessionStream(sl<LocationTrackingRepository>()),
  );

  // Bloc
  sl.registerFactory(
    () => ActivityTrackingBloc(
      getLiveLocationStream: sl<GetLiveLocationStream>(),
      getLiveStepsStream: sl<GetLiveStepsStream>(),
      stopAndSaveSession: sl<StopAndSaveSession>(),
    ),
  );
}
