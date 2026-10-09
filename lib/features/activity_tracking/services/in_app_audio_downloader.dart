import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar_community/isar.dart';
import 'package:vital_up/core/database/collections/downloaded_track.dart';
import 'package:vital_up/core/database/isar_service.dart';

import 'package:vital_up/features/activity_tracking/presentation/bloc/foreground_service_manager.dart';

/// File name for a track id such as "Story: It's Possible": only letters,
/// digits, dash and underscore, so ids can never escape the audio folder.
String safeAudioFileName(String trackId) {
  final cleaned = trackId.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  final trimmed = cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  return trimmed.isEmpty ? 'track' : trimmed;
}

class InAppAudioDownloader {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  final IsarService _isarService;

  InAppAudioDownloader(this._isarService);

  /// Downloads a track from [remoteUrl] and saves it locally.
  /// Updates [DownloadedTrack] schema in Isar database.
  Future<void> downloadTrack({
    required String trackId,
    required String remoteUrl,
    required String title,
    required String subtitle,
    required Function(double progress) onProgress,
  }) async {
    File? partial;
    try {
      try {
        await ForegroundServiceManager.startDownloadService(trackTitle: title);
      } catch (e) {
        // The download still works in the foreground without the service.
        debugPrint('Download service failed to start: $e');
      }

      final docDir = await getApplicationDocumentsDirectory();
      // Ensure the audio subdirectory exists
      final audioDir = Directory('${docDir.path}/downloaded_audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final localFilePath = '${audioDir.path}/${safeAudioFileName(trackId)}.mp3';

      // Download to a temp file so a dropped connection never leaves a
      // truncated file behind that looks like a finished download.
      partial = File('$localFilePath.part');
      await _dio.download(
        remoteUrl,
        partial.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            onProgress(progress);
            ForegroundServiceManager.updateDownloadProgress(
              trackTitle: title,
              progress: progress,
            ).catchError((Object e) {
              debugPrint('Download progress update failed: $e');
            });
          }
        },
      );
      await partial.rename(localFilePath);
      partial = null;

      // Save to Isar
      final isar = _isarService.isar;
      final track = DownloadedTrack()
        ..trackId = trackId
        ..localFilePath = localFilePath
        ..title = title
        ..subtitle = subtitle
        ..downloadedAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.downloadedTracks.put(track);
      });
    } finally {
      final leftover = partial;
      if (leftover != null) {
        try {
          if (await leftover.exists()) await leftover.delete();
        } catch (e) {
          debugPrint('Removing partial download failed: $e');
        }
      }
      try {
        await ForegroundServiceManager.stopDownloadService();
      } catch (e) {
        debugPrint('Download service failed to stop: $e');
      }
    }
  }

  /// Checks if a track is downloaded offline
  Future<DownloadedTrack?> getDownloadedTrack(String trackId) async {
    final isar = _isarService.isar;
    return await isar.downloadedTracks.filter().trackIdEqualTo(trackId).findFirst();
  }

  /// Deletes a downloaded track from local disk and Isar database
  Future<void> deleteDownloadedTrack(String trackId) async {
    final isar = _isarService.isar;
    final track = await getDownloadedTrack(trackId);
    if (track != null) {
      final file = File(track.localFilePath);
      if (await file.exists()) {
        await file.delete();
      }
      await isar.writeTxn(() async {
        await isar.downloadedTracks.delete(track.id);
      });
    }
  }
}
