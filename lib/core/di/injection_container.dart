import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/network/dio_client.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';

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
        secureStorage: sl<FlutterSecureStorage>(),
        logger: sl<Logger>(),
      ));

  // 6. Blocs / Cubits
  sl.registerFactory(() => AuthCubit());
}
