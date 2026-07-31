import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/repositories/profile_repository.dart';
import 'package:isar_community/isar.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final IsarService isarService;
  final Logger logger;

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.isarService,
    required this.logger,
  });

  @override
  Future<Either<Failure, ProfileEntity>> getProfile() async {
    try {
      final remoteProfile = await remoteDataSource.getProfile();

      // Update the local cache in Isar
      try {
        final isar = isarService.isar;
        await isar.writeTxn(() async {
          final cache = UserProfileCache()
            ..supabaseId = remoteProfile.id
            ..username = remoteProfile.username
            ..email = remoteProfile.email
            ..displayName = remoteProfile.fullName
            ..photoUrl = remoteProfile.photoUrl
            ..lastSyncedAt = DateTime.now();
          await isar.userProfileCaches.putBySupabaseId(cache);
        });
      } catch (cacheError) {
        logger.e('Failed to update local user profile cache: $cacheError');
      }

      return Right(remoteProfile);
    } on ServerException catch (e) {
      // Offline / server error fallback: check local Isar cache
      try {
        final isar = isarService.isar;
        final user = isar.userProfileCaches.where().findAllSync().firstOrNull; // Get any cached user profile
        if (user != null) {
          logger.i('Loading profile from local Isar cache after remote fetch failure.');
          return Right(ProfileEntity(
            id: user.supabaseId,
            username: user.username,
            email: user.email,
            fullName: user.displayName ?? '',
            photoUrl: user.photoUrl,
            // Rest of details are empty on fallback cache
          ));
        }
      } catch (localError) {
        logger.e('Failed to load local profile cache: $localError');
      }

      return Left(ServerFailure(_mapExceptionMessage(e.message)));
    } catch (e) {
      return Left(ServerFailure(_mapExceptionMessage(e.toString())));
    }
  }

  @override
  Future<Either<Failure, void>> updateProfile(ProfileEntity profile) async {
    try {
      await remoteDataSource.updateProfile(profile);

      // Update local Isar cache on successful remote update
      try {
        final isar = isarService.isar;
        await isar.writeTxn(() async {
          final cache = UserProfileCache()
            ..supabaseId = profile.id
            ..username = profile.username
            ..email = profile.email
            ..displayName = profile.fullName
            ..photoUrl = profile.photoUrl
            ..lastSyncedAt = DateTime.now();
          await isar.userProfileCaches.putBySupabaseId(cache);
        });
      } catch (cacheError) {
        logger.e('Failed to update local profile cache after update: $cacheError');
      }

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(_mapExceptionMessage(e.message)));
    } catch (e) {
      return Left(ServerFailure(_mapExceptionMessage(e.toString())));
    }
  }

  String _mapExceptionMessage(String originalMessage) {
    final msg = originalMessage.toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('handshake') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception')) {
      return 'No internet connection. Please check your network settings.';
    }
    if (msg.contains('postgrestexception') ||
        msg.contains('database') ||
        msg.contains('postgres') ||
        msg.contains('upsert')) {
      return 'Database operation failed. Please try again.';
    }
    final cleanMsg = originalMessage.replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (cleanMsg.length < 60 && !cleanMsg.contains('{') && !cleanMsg.contains('[')) {
      return cleanMsg;
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
