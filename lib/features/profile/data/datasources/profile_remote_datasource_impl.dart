import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:vital_up/features/profile/data/profile_cache.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/domain/profile_rules.dart';

/// A failure whose [message] is written for the user (shown as is).
class ProfileUserError extends ServerException {
  const ProfileUserError(String message) : super(message: message);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient supabaseClient;
  final PendingWrites pendingWrites;
  final Logger logger;

  /// Public Supabase Storage bucket for profile photos; each user may only
  /// write inside their own `<userId>/` folder (see the avatars migration).
  static const _avatarBucket = 'avatars';

  static const _imageTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
  };

  ProfileRemoteDataSourceImpl({
    required this.supabaseClient,
    required this.pendingWrites,
    required this.logger,
  });

  @override
  Future<ProfileEntity> getProfile() async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        throw const ProfileUserError('Please sign in again.');
      }
      final userId = user.id;

      // Only the columns the profile uses; both tables in parallel.
      final results = await Future.wait([
        supabaseClient
            .from('profiles')
            .select('username, email')
            .eq('id', userId)
            .single(),
        supabaseClient
            .from('user_health_data')
            .select(_healthColumns)
            .eq('id', userId)
            .maybeSingle(),
      ]);
      final profileRes = results[0]!;
      final healthRes = results[1];

      final username = profileRes['username'] as String? ?? '';
      final email = profileRes['email'] as String? ?? user.email ?? '';

      final String fullName = healthRes?['full_name'] as String? ??
          user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          '';

      final String photoUrl = user.userMetadata?['avatar_url'] ??
          user.userMetadata?['picture'] ??
          '';

      return ProfileEntity(
        id: userId,
        username: username,
        email: email,
        fullName: fullName,
        dob: healthRes?['dob'] as String? ?? '',
        gender: healthRes?['gender'] as String? ?? '',
        weight: healthRes?['weight'] as String? ?? '',
        weightUnit: healthRes?['weight_unit'] as String? ?? 'kg',
        height: healthRes?['height'] as String? ?? '',
        heightUnit: healthRes?['height_unit'] as String? ?? 'cm',
        oxygenLevel: healthRes?['oxygen_level'] as String? ?? '',
        healthConditions: healthRes?['health_conditions'] as String? ?? '',
        allergies: healthRes?['allergies'] as String? ?? '',
        medicines: healthRes?['medicines'] as String? ?? '',
        smokes: healthRes?['smokes'] as String? ?? '',
        bloodPressureTop: healthRes?['blood_pressure_top'] as String? ?? '',
        bloodPressureBottom: healthRes?['blood_pressure_bottom'] as String? ?? '',
        bpm: healthRes?['bpm'] as String? ?? '',
        activity: healthRes?['activity'] as String? ?? '',
        sleep: healthRes?['sleep'] as String? ?? '',
        photoUrl: photoUrl.isEmpty ? null : photoUrl,
        dailyCalorieGoal: (healthRes?['calorie_goal'] as num?)?.toInt(),
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      logger.e('Error fetching profile from Supabase: $e');
      // Kept as-is so the cache can tell "offline" from a real failure.
      // Kept as-is: the repository logs it and shows a short message.
      rethrow;
    }
  }

  static const _healthColumns = 'full_name, dob, gender, weight, weight_unit, '
      'height, height_unit, oxygen_level, health_conditions, allergies, '
      'medicines, smokes, blood_pressure_top, blood_pressure_bottom, bpm, '
      'activity, sleep, calorie_goal';

  @override
  Future<bool> updateProfile(
    ProfileEntity profile, {
    ProfileEntity? previous,
  }) async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        throw const ProfileUserError('Please sign in again.');
      }
      var sent = true;

      // 1. Update profiles table (skipped when the username is unchanged).
      if (previous == null || previous.username != profile.username) {
        sent &= await pendingWrites.sendOrQueue(
          supabaseClient,
          PendingWrite.update(
            'profiles',
            values: {'username': profile.username},
            match: {'id': user.id},
            userId: user.id,
            key: ProfileCache.profilesWriteKey(user.id),
          ),
        );
      }

      // 2. Update user_health_data table
      final payload = {
        'id': user.id,
        'full_name': ProfileRules.cleanName(profile.fullName),
        'dob': profile.dob,
        'gender': profile.gender,
        'weight': profile.weight,
        'weight_unit': profile.weightUnit,
        'height': profile.height,
        'height_unit': profile.heightUnit,
        'oxygen_level': profile.oxygenLevel,
        'health_conditions': ProfileRules.cleanNote(profile.healthConditions),
        'medicines': ProfileRules.cleanNote(profile.medicines),
        'allergies': ProfileRules.cleanNote(profile.allergies),
        'smokes': profile.smokes,
        'blood_pressure_top': profile.bloodPressureTop,
        'blood_pressure_bottom': profile.bloodPressureBottom,
        'bpm': profile.bpm,
        'activity': profile.activity,
        'sleep': profile.sleep,
        'onboarding_completed': true,
      };

      sent &= await pendingWrites.sendOrQueue(
        supabaseClient,
        PendingWrite.upsert(
          'user_health_data',
          values: payload,
          userId: user.id,
          key: ProfileCache.healthWriteKey(user.id),
        ),
      );

      // 3. Auth metadata mirrors the name (the profile reads
      // user_health_data first). It can't be queued, so it's best effort.
      final nameChanged =
          previous == null || previous.fullName != profile.fullName;
      if (nameChanged && sent) {
        try {
          await supabaseClient.auth.updateUser(
            UserAttributes(data: {'full_name': profile.fullName}),
          );
        } catch (e) {
          logger.w('Could not sync name to auth metadata: $e');
        }
      }

      logger.i(sent
          ? 'Successfully updated profile for user: ${user.id}'
          : 'Profile saved offline for user: ${user.id}; queued for sync');
      return sent;
    } on ServerException {
      rethrow;
    } catch (e) {
      logger.e('Error updating profile in Supabase: $e');
      final usernameMessage = UsernameService.messageForServerError(e);
      if (usernameMessage != null) throw ProfileUserError(usernameMessage);
      rethrow;
    }
  }

  @override
  Future<String> uploadProfilePhoto(String userId, File imageFile) async {
    try {
      _requireCurrentUser(userId);

      final dot = imageFile.path.lastIndexOf('.');
      final ext = dot == -1 ? '' : imageFile.path.substring(dot + 1).toLowerCase();
      final contentType = _imageTypes[ext];
      if (contentType == null) {
        throw const ProfileUserError('Choose a JPG, PNG, WEBP or HEIC image.');
      }

      // A new file name per upload busts image caches holding the old URL.
      final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bucket = supabaseClient.storage.from(_avatarBucket);
      await bucket.upload(
        path,
        imageFile,
        fileOptions: FileOptions(contentType: contentType, cacheControl: '3600'),
      );
      final url = bucket.getPublicUrl(path);

      await supabaseClient.auth.updateUser(
        UserAttributes(data: {'avatar_url': url}),
      );
      await _syncLeaderboardAvatar(userId, url);
      await _deleteAvatarFiles(userId, keep: path);

      logger.i('Uploaded profile photo for user: $userId');
      return url;
    } on ServerException {
      rethrow;
    } catch (e) {
      logger.e('Error uploading profile photo: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeProfilePhoto(String userId) async {
    try {
      _requireCurrentUser(userId);
      await _deleteAvatarFiles(userId);

      // getProfile falls back to the OAuth `picture`, so clear both or a
      // Google user's original photo would reappear.
      await supabaseClient.auth.updateUser(
        UserAttributes(data: {'avatar_url': null, 'picture': null}),
      );
      await _syncLeaderboardAvatar(userId, null);
      logger.i('Removed profile photo for user: $userId');
    } on ServerException {
      rethrow;
    } catch (e) {
      logger.e('Error removing profile photo: $e');
      rethrow;
    }
  }

  /// Leaderboards read avatars from the public `profiles` row, not auth
  /// metadata. Best effort: a failure here shouldn't fail the upload.
  Future<void> _syncLeaderboardAvatar(String userId, String? url) async {
    try {
      await supabaseClient
          .from('profiles')
          .update({'avatar_url': url}).eq('id', userId);
    } catch (e) {
      logger.w('Could not sync avatar to profiles: $e');
    }
  }

  void _requireCurrentUser(String userId) {
    final user = supabaseClient.auth.currentUser;
    if (user == null) {
      throw const ProfileUserError('Please sign in again.');
    }
    if (user.id != userId) {
      throw const ProfileUserError("Can't change another user's photo.");
    }
  }

  /// Deletes the user's stored avatars except [keep]. Best effort: a failed
  /// cleanup only leaves an orphaned file, so it never fails the request.
  Future<void> _deleteAvatarFiles(String userId, {String? keep}) async {
    try {
      final bucket = supabaseClient.storage.from(_avatarBucket);
      final files = await bucket.list(path: userId);
      final stale = files
          .map((f) => '$userId/${f.name}')
          .where((path) => path != keep)
          .toList();
      if (stale.isNotEmpty) await bucket.remove(stale);
    } catch (e) {
      logger.w('Could not clean up old profile photos: $e');
    }
  }
}
