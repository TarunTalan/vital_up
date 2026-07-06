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
import 'package:vital_up/features/food_scan/data/datasources/meal_log_local_data_source.dart';
import 'package:vital_up/features/food_scan/data/datasources/meal_log_local_data_source_impl.dart';
import 'package:vital_up/features/food_scan/data/repositories/food_recognition_repository_impl.dart';
import 'package:vital_up/features/food_scan/data/repositories/meal_log_repository_impl.dart';
import 'package:vital_up/features/food_scan/data/repositories/meal_recommendation_repository_impl.dart';
import 'package:vital_up/features/food_scan/data/repositories/nutrition_repository_impl.dart';
import 'package:vital_up/features/food_scan/data/repositories/subscription_repository_impl.dart';
import 'package:vital_up/features/food_scan/domain/repositories/food_recognition_repository.dart';
import 'package:vital_up/features/food_scan/domain/repositories/meal_log_repository.dart';
import 'package:vital_up/features/food_scan/domain/repositories/meal_recommendation_repository.dart';
import 'package:vital_up/features/food_scan/domain/repositories/nutrition_repository.dart';
import 'package:vital_up/features/food_scan/domain/repositories/subscription_repository.dart';
import 'package:vital_up/features/food_scan/domain/usecases/delete_meal_log.dart';
import 'package:vital_up/features/food_scan/domain/usecases/get_meal_log_history.dart';
import 'package:vital_up/features/food_scan/domain/usecases/get_meal_recommendation.dart';
import 'package:vital_up/features/food_scan/domain/usecases/scan_barcode.dart';
import 'package:vital_up/features/food_scan/domain/usecases/scan_food_image.dart';
import 'package:vital_up/features/food_scan/domain/usecases/save_meal_log.dart';
import 'package:vital_up/features/food_scan/presentation/bloc/food_scan_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // 9. Food Scan Clean Architecture Layers
  sl.registerLazySingleton<Uuid>(() => const Uuid());
  
  sl.registerLazySingleton<MealLogLocalDataSource>(
    () => MealLogLocalDataSourceImpl(
      isarService: sl<IsarService>(),
      uuid: sl<Uuid>(),
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
      subscriptionRepository: sl<SubscriptionRepository>(),
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
    uuid: sl<Uuid>(),
  ));
}
