import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/database/collections/user_profile_cache.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/offline_errors.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource_impl.dart';
import 'package:vital_up/features/profile/data/profile_cache.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/repositories/profile_repository.dart';

/// Cache-first profile: reads come from [CacheStore] while fresh (and stay
/// available offline); edits land in the cache immediately and the server
/// writes are queued when there's no network.
class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;
  final IsarService isarService;
  final CacheStore cacheStore;
  final Logger logger;

  /// The signed-in user's id, or null (scopes the cache per account).
  final String? Function() currentUserId;

  ProfileRepositoryImpl({
    required this.remoteDataSource,
    required this.isarService,
    required this.cacheStore,
    required this.currentUserId,
    required this.logger,
  });

  static const _offlineMessage = "You're offline. Try again when connected.";

  @override
  Future<Either<Failure, ProfileEntity>> getProfile({
    bool forceRefresh = false,
  }) async {
    final userId = currentUserId();
    if (userId == null) {
      return const Left(ServerFailure('Please sign in again.'));
    }
    try {
      final profile = await cacheStore.fetch<ProfileEntity>(
        ProfileCache.key(userId),
        remote: () async {
          final remote = await remoteDataSource.getProfile();
          await _mirrorToIsar(remote);
          return remote;
        },
        maxAge: ProfileCache.maxAge,
        encode: ProfileCache.encode,
        decode: ProfileCache.decode,
        forceRefresh: forceRefresh,
      );
      return Right(profile);
    } catch (e) {
      if (isOfflineError(e)) {
        // Nothing in the cache yet (e.g. first launch after an update):
        // the older Isar mirror at least has the basics.
        final legacy = await _legacyProfile(userId);
        if (legacy != null) {
          logger.i('Loading profile from local Isar cache while offline.');
          return Right(legacy);
        }
      }
      logger.e('Profile load failed: $e');
      return Left(ServerFailure(
        _messageFor(e, fallback: "Couldn't load your profile. Try again."),
      ));
    }
  }

  @override
  Future<Either<Failure, void>> updateProfile(ProfileEntity profile) async {
    final key = ProfileCache.key(profile.id);
    final previous = await _cached(profile.id);

    // Optimistic: the edit shows everywhere at once, online or not.
    await cacheStore.write(key, ProfileCache.encode(profile));
    try {
      final sent = await remoteDataSource.updateProfile(
        profile,
        previous: previous,
      );
      if (!sent) logger.i('Profile edit queued until the device is online.');
      await _mirrorToIsar(profile);
      return const Right(null);
    } catch (e) {
      // The server rejected it (e.g. username taken): undo the local edit.
      if (previous != null) {
        await cacheStore.write(key, ProfileCache.encode(previous));
      } else {
        await cacheStore.remove(key);
      }
      logger.e('Profile save failed: $e');
      return Left(ServerFailure(_messageFor(e)));
    }
  }

  @override
  Future<Either<Failure, String>> uploadProfilePhoto(
    String userId,
    File imageFile,
  ) async {
    try {
      final url = await remoteDataSource.uploadProfilePhoto(userId, imageFile);
      await _cachePhotoUrl(userId, url);
      return Right(url);
    } catch (e) {
      return Left(ServerFailure(_photoMessageFor(e)));
    }
  }

  @override
  Future<Either<Failure, void>> removeProfilePhoto(String userId) async {
    try {
      await remoteDataSource.removeProfilePhoto(userId);
      await _cachePhotoUrl(userId, null);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(_photoMessageFor(e)));
    }
  }

  Future<ProfileEntity?> _cached(String userId) async =>
      (await cacheStore.read<ProfileEntity>(
        ProfileCache.key(userId),
        decode: ProfileCache.decode,
      ))
          ?.value;

  /// Other features (meal log, Vita, gamification) still read the calorie
  /// goal and name from the Isar profile mirror, so keep it current.
  Future<void> _mirrorToIsar(ProfileEntity profile) async {
    try {
      final isar = isarService.isar;
      await isar.writeTxn(() async {
        final cache = UserProfileCache()
          ..supabaseId = profile.id
          ..username = profile.username
          ..email = profile.email
          ..displayName = profile.fullName
          ..photoUrl = profile.photoUrl
          ..dailyCalorieGoal = profile.dailyCalorieGoal
          ..lastSyncedAt = DateTime.now();
        await isar.userProfileCaches.putBySupabaseId(cache);
      });
    } catch (cacheError) {
      logger.e('Failed to update local user profile cache: $cacheError');
    }
  }

  Future<ProfileEntity?> _legacyProfile(String userId) async {
    try {
      final user = await isarService.isar.userProfileCaches
          .getBySupabaseId(userId);
      if (user == null) return null;
      return ProfileEntity(
        id: user.supabaseId,
        username: user.username,
        email: user.email,
        fullName: user.displayName ?? '',
        photoUrl: user.photoUrl,
        dailyCalorieGoal: user.dailyCalorieGoal,
      );
    } catch (localError) {
      logger.e('Failed to load local profile cache: $localError');
      return null;
    }
  }

  /// Keeps the cached profile's photo in sync.
  Future<void> _cachePhotoUrl(String userId, String? url) async {
    await cacheStore.update(
      ProfileCache.key(userId),
      (data) => data is Map ? {...data, 'photo_url': url} : data,
    );
    try {
      final isar = isarService.isar;
      await isar.writeTxn(() async {
        final cache = await isar.userProfileCaches.getBySupabaseId(userId);
        if (cache == null) return;
        cache
          ..photoUrl = url
          ..lastSyncedAt = DateTime.now();
        await isar.userProfileCaches.putBySupabaseId(cache);
      });
    } catch (e) {
      logger.e('Failed to update cached profile photo: $e');
    }
  }

  /// Photo changes go straight to storage, so they need the network.
  String _photoMessageFor(Object error) {
    logger.e('Profile photo change failed: $error');
    return isOfflineError(error)
        ? "You're offline. Connect to change your photo."
        : _messageFor(error, fallback: "Couldn't update your photo. Try again.");
  }

  /// Short message for the user. [ProfileUserError]s are already written
  /// for the user; anything else is replaced by [fallback].
  String _messageFor(
    Object error, {
    String fallback = "Couldn't save your profile. Try again.",
  }) {
    if (isOfflineError(error)) return _offlineMessage;
    if (error is ProfileUserError) return error.message;
    return userMessage(error, fallback: fallback);
  }
}
