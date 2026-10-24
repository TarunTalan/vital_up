import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:vital_up/core/database/collections/downloaded_track.dart';
import 'package:vital_up/core/database/isar_service.dart';

/// File name for a track id such as "Story: It's Possible": only letters,
/// digits, dash and underscore, so ids can never escape the audio folder.
String safeAudioFileName(String trackId) {
  final cleaned = trackId.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  final trimmed = cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  return trimmed.isEmpty ? 'track' : trimmed;
}

/// A track download that didn't finish (network, server, cancelled from the
/// notification).
class AudioDownloadFailed implements Exception {
  final TaskStatus status;

  const AudioDownloadFailed(this.status);

  @override
  String toString() => 'AudioDownloadFailed(${status.name})';
}

/// Downloads workout tracks with the system's background job scheduler
/// (WorkManager on Android, a background URL session on iOS), so a download
/// carries on with the app in the background or closed, and shows its
/// progress in the notification tray. No foreground service: the one the
/// app has is declared for location and only runs during GPS workouts.
///
/// A download that finishes while the app isn't running is added to the
/// library by [settleBackgroundDownloads] on the next start.
class InAppAudioDownloader {
  static const group = 'workout_audio';
  static const _folder = 'downloaded_audio';

  final IsarService _isarService;
  bool _started = false;

  InAppAudioDownloader(this._isarService);

  /// Call once at startup: picks up downloads that ran while the app was
  /// closed and sets up their notifications.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      FileDownloader().configureNotificationForGroup(
        group,
        running: const TaskNotification(
          'Downloading {displayName}',
          '{progress}',
        ),
        complete: const TaskNotification(
          '{displayName}',
          'Ready to play offline',
        ),
        error: const TaskNotification(
          "Couldn't download {displayName}",
          'Open the app to try again',
        ),
        paused: const TaskNotification('{displayName}', 'Download paused'),
        progressBar: true,
      );
      await FileDownloader().start();
      await settleBackgroundDownloads();
    } catch (e) {
      // Downloads still work in the foreground without the tracking db.
      debugPrint('Background downloads unavailable: $e');
    }
  }

  static String taskIdFor(String trackId) =>
      'audio_${safeAudioFileName(trackId)}';

  /// Downloads a track from [remoteUrl] and adds it to the library. Keeps
  /// going in the background; [onProgress] reports 0-1 while this screen
  /// is listening. Throws [AudioDownloadFailed] when it doesn't finish.
  Future<void> downloadTrack({
    required String trackId,
    required String remoteUrl,
    required String title,
    required String subtitle,
    required void Function(double progress) onProgress,
  }) async {
    final task = DownloadTask(
      taskId: taskIdFor(trackId),
      url: remoteUrl,
      filename: '${safeAudioFileName(trackId)}.mp3',
      directory: _folder,
      baseDirectory: BaseDirectory.applicationDocuments,
      group: group,
      displayName: title,
      updates: Updates.statusAndProgress,
      retries: 2,
      allowPause: true,
      metaData: jsonEncode({
        'trackId': trackId,
        'title': title,
        'subtitle': subtitle,
      }),
    );
    // The downloader writes to a temp file and only moves it into place
    // when complete, so a dropped connection never leaves a truncated file.
    final result = await FileDownloader().download(
      task,
      onProgress: (progress) {
        // Negative values are status markers (failed, paused...).
        if (progress >= 0) onProgress(progress.clamp(0.0, 1.0));
      },
    );
    if (result.status != TaskStatus.complete) {
      throw AudioDownloadFailed(result.status);
    }
    await _addToLibrary(task);
    await _forget(task.taskId);
  }

  /// Track ids being downloaded right now (possibly started before the app
  /// was last closed), with their progress.
  Future<Map<String, double>> activeDownloads() async {
    final active = <String, double>{};
    try {
      for (final record in await FileDownloader().database.allRecords(
        group: group,
      )) {
        if (record.status.isNotFinalState) {
          final trackId = _trackIdOf(record.task);
          if (trackId != null) {
            active[trackId] = record.progress.clamp(0.0, 1.0);
          }
        }
      }
    } catch (e) {
      debugPrint('Reading active downloads failed: $e');
    }
    return active;
  }

  /// Progress (0-1) of downloads, and null when one ends; for a screen
  /// showing a download it didn't start (e.g. reopened mid-download).
  Stream<({String trackId, double? progress})> get changes => FileDownloader()
      .database
      .updates
      .where((r) => r.group == group)
      .asyncMap((record) async {
        final trackId = _trackIdOf(record.task);
        if (trackId == null) return null;
        if (record.status == TaskStatus.complete) {
          await _addToLibrary(record.task);
          return (trackId: trackId, progress: null);
        }
        if (record.status.isFinalState) {
          return (trackId: trackId, progress: null);
        }
        return (trackId: trackId, progress: record.progress.clamp(0.0, 1.0));
      })
      .where((change) => change != null)
      .cast<({String trackId, double? progress})>();

  /// Adds downloads that completed while the app was closed to the library
  /// and clears finished records.
  Future<void> settleBackgroundDownloads() async {
    final records = await FileDownloader().database.allRecords(group: group);
    for (final record in records) {
      if (record.status == TaskStatus.complete) {
        try {
          await _addToLibrary(record.task);
        } catch (e) {
          debugPrint('Adding a background download failed: $e');
          continue;
        }
      }
      if (record.status.isFinalState) await _forget(record.taskId);
    }
  }

  static String? _trackIdOf(Task task) {
    try {
      final meta = jsonDecode(task.metaData);
      final id = meta is Map ? meta['trackId'] : null;
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _addToLibrary(Task task) async {
    final meta = Map<String, dynamic>.from(jsonDecode(task.metaData) as Map);
    final trackId = meta['trackId'] as String;
    final path = await task.filePath();
    if (!await File(path).exists()) return;
    final isar = _isarService.isar;
    // Looked up inside the write: the screen and the download can both
    // finish adding the same track.
    await isar.writeTxn(() async {
      final existing = await isar.downloadedTracks
          .filter()
          .trackIdEqualTo(trackId)
          .findFirst();
      final track = (existing ?? DownloadedTrack())
        ..trackId = trackId
        ..localFilePath = path
        ..title = meta['title'] as String? ?? trackId
        ..subtitle = meta['subtitle'] as String? ?? ''
        ..downloadedAt = DateTime.now();
      await isar.downloadedTracks.put(track);
    });
  }

  Future<void> _forget(String taskId) async {
    try {
      await FileDownloader().database.deleteRecordWithId(taskId);
    } catch (e) {
      debugPrint('Clearing a download record failed: $e');
    }
  }

  /// Checks if a track is downloaded offline
  Future<DownloadedTrack?> getDownloadedTrack(String trackId) async {
    final isar = _isarService.isar;
    return await isar.downloadedTracks
        .filter()
        .trackIdEqualTo(trackId)
        .findFirst();
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
