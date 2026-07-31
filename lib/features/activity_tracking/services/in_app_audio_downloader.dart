import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar_community/isar.dart';
import 'package:vital_up/core/database/collections/downloaded_track.dart';
import 'package:vital_up/core/database/isar_service.dart';

import 'package:vital_up/features/activity_tracking/presentation/bloc/foreground_service_manager.dart';

class InAppAudioDownloader {
  final Dio _dio = Dio();
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
    try {
      await ForegroundServiceManager.startDownloadService(trackTitle: title);

      final docDir = await getApplicationDocumentsDirectory();
      // Ensure the audio subdirectory exists
      final audioDir = Directory('${docDir.path}/downloaded_audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final localFilePath = '${audioDir.path}/$trackId.mp3';

      // Start download
      await _dio.download(
        remoteUrl,
        localFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            ForegroundServiceManager.updateDownloadProgress(trackTitle: title, progress: progress);
          }
        },
      );

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
    } catch (e) {
      rethrow;
    } finally {
      await ForegroundServiceManager.stopDownloadService();
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
