import 'package:dartz/dartz.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource localDataSource;

  SettingsRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, SettingsEntity>> getSettings() async {
    try {
      final settings = await localDataSource.getSettings();
      return Right(settings);
    } catch (e) {
      return const Left(CacheFailure('Failed to load settings preferences'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSettings(SettingsEntity settings) async {
    try {
      await localDataSource.saveSettings(settings);
      return const Right(null);
    } catch (e) {
      return const Left(CacheFailure('Failed to save settings preferences'));
    }
  }
}
