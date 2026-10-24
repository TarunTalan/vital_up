import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:vital_up/core/database/collections/downloaded_track.dart';
import 'package:vital_up/core/database/collections/favorite_audio.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/workout_audio_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/workout_music_player.dart';
import 'package:vital_up/features/activity_tracking/services/local_audio_query_service.dart';
import 'package:vital_up/features/activity_tracking/services/workout_audio_service.dart';

/// Workout music shared by the GPS and timer screens: the track picked in
/// [prefs], played by the built-in player or the user's own music app.
class WorkoutMusic {
  static const _audioChannel = MethodChannel(
    'com.example.vital_up/audio_intent',
  );

  /// Stories cycled through when no other queue has tracks.
  static const _stories = [
    'Story: It\'s Possible',
    'Story: Goals',
    'Story: Light Up the Darkness',
    'Story: Without Limits',
    'Story: Best Speeches',
  ];

  final WorkoutPrefsNotifier prefs;

  /// Shown when the user's music app can't be opened.
  final void Function(String message) onError;

  /// Whether the current track is a favourite.
  final ValueNotifier<bool> favorite = ValueNotifier(false);

  WorkoutMusic(this.prefs, {required this.onError});

  bool get usesExternalPlayer =>
      prefs.value.preferredPlayerPackage != 'builtIn';

  /// Opens the user's chosen music app. The app may have been uninstalled
  /// since it was picked, so failures are reported rather than thrown.
  void _launchExternalPlayer(String packageName) {
    _audioChannel
        .invokeMethod('launchAudioApp', {'packageName': packageName})
        .catchError((Object e) {
          debugPrint('Launching music app failed: $e');
          onError("Couldn't open your music app.");
          return null;
        });
  }

  void play({bool play = true}) {
    final p = prefs.value;
    if (usesExternalPlayer) {
      _launchExternalPlayer(p.preferredPlayerPackage);
      return;
    }
    Future(
          () => sl<IsarService>().isar.downloadedTracks
              .filter()
              .trackIdEqualTo(p.backgroundAudioTrack)
              .findFirst(),
        )
        .then((downloaded) {
          final source = downloaded != null
              ? 'download'
              : (p.backgroundAudioTrack.startsWith('Local:')
                    ? 'local'
                    : 'preset');
          sl<WorkoutAudioService>().playTrack(
            p.backgroundAudioTrack,
            source: source,
            localPath: downloaded?.localFilePath,
            play: play,
          );
        })
        .catchError((Object e) {
          debugPrint('Starting workout audio failed: $e');
        });
  }

  void pause() {
    if (!usesExternalPlayer) sl<WorkoutAudioService>().pause();
  }

  void resume() {
    if (usesExternalPlayer) {
      _launchExternalPlayer(prefs.value.preferredPlayerPackage);
    } else {
      sl<WorkoutAudioService>().resume();
    }
  }

  void stop() {
    if (!usesExternalPlayer) sl<WorkoutAudioService>().stop();
  }

  /// Play / pause button on the player.
  void togglePlaying() {
    if (usesExternalPlayer || !sl<WorkoutAudioService>().isPlaying) {
      play();
    } else {
      pause();
    }
  }

  /// No more music this workout.
  void discard() {
    prefs.setBackgroundAudioTrack('None');
    stop();
  }

  Future<void> cycleTrack({required bool next}) async {
    final p = prefs.value;
    final queueType = p.backgroundAudioQueueType;
    var queue = <String>[];
    try {
      if (queueType == 'stories' || queueType == 'curated') {
        queue = _stories;
      } else if (queueType == 'favorite') {
        final favs = await sl<IsarService>().isar.favoriteAudios
            .where()
            .findAll();
        queue = favs.map((f) => f.trackId).toList();
      } else if (queueType == 'local') {
        final songs = await sl<LocalAudioQueryService>().getLocalSongs();
        queue = songs.map((s) => 'Local:${s.id}').toList();
      }
    } catch (e) {
      debugPrint('Reading the music queue failed: $e');
    }
    if (queue.isEmpty) queue = _stories;

    final current = queue.indexOf(p.backgroundAudioTrack);
    final target = current == -1
        ? (next ? 0 : queue.length - 1)
        : (current + (next ? 1 : -1) + queue.length) % queue.length;
    await prefs.setBackgroundAudioTrack(queue[target], queueType: queueType);
    play();
  }

  Future<void> refreshFavorite() async {
    final track = prefs.value.backgroundAudioTrack;
    try {
      final existing = await sl<IsarService>().isar.favoriteAudios
          .filter()
          .trackIdEqualTo(track)
          .findFirst();
      favorite.value = existing != null;
    } catch (e) {
      debugPrint('Reading favourite tracks failed: $e');
    }
  }

  Future<void> toggleFavorite() async {
    final track = prefs.value.backgroundAudioTrack;
    try {
      final isar = sl<IsarService>().isar;
      final existing = await isar.favoriteAudios
          .filter()
          .trackIdEqualTo(track)
          .findFirst();
      await isar.writeTxn(() async {
        if (existing != null) {
          await isar.favoriteAudios.delete(existing.id);
          return;
        }
        final local = track.startsWith('Local:');
        await isar.favoriteAudios.put(
          FavoriteAudio()
            ..trackId = track
            ..title = track
                .replaceFirst('Story: ', '')
                .replaceFirst('Music: ', '')
            ..subtitle = local ? 'Local Track' : 'Curated Audio'
            ..audioSource = local ? 'local' : 'preset'
            ..favoritedAt = DateTime.now(),
        );
      });
    } catch (e) {
      debugPrint('Updating favourites failed: $e');
      onError("Couldn't update favourites. Try again.");
    }
    await refreshFavorite();
  }

  /// The music picker; favourites may change there.
  Future<void> openPicker(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutAudioPage(current: prefs.value, notifier: prefs),
      ),
    );
    await refreshFavorite();
  }

  void dispose() => favorite.dispose();
}

/// The mini player above the workout controls; hidden with no track.
class WorkoutMusicBar extends StatefulWidget {
  final WorkoutMusic music;

  const WorkoutMusicBar({super.key, required this.music});

  @override
  State<WorkoutMusicBar> createState() => _WorkoutMusicBarState();
}

class _WorkoutMusicBarState extends State<WorkoutMusicBar> {
  bool _minimized = false;

  @override
  Widget build(BuildContext context) {
    final music = widget.music;
    return ValueListenableBuilder<WorkoutPrefs>(
      valueListenable: music.prefs,
      builder: (context, prefs, _) {
        final external = prefs.preferredPlayerPackage != 'builtIn';
        final track = external
            ? 'Player: ${prefs.preferredPlayerPackage.split('.').last.toUpperCase()}'
            : prefs.backgroundAudioTrack;
        final audio = sl<WorkoutAudioService>();
        return StreamBuilder<bool>(
          stream: audio.playingStream,
          initialData: audio.isPlaying,
          builder: (context, playing) => ValueListenableBuilder<bool>(
            valueListenable: music.favorite,
            builder: (context, favorite, _) => WorkoutMusicPlayer(
              trackName: track,
              isPlaying: !external && (playing.data ?? false),
              isFavorited: !external && favorite,
              isMinimized: _minimized,
              onMinimizeToggle: () => setState(() => _minimized = !_minimized),
              onTap: () => music.openPicker(context),
              onDiscard: music.discard,
              onPlayPause: music.togglePlaying,
              onNext: external ? () {} : () => music.cycleTrack(next: true),
              onPrevious: external
                  ? () {}
                  : () => music.cycleTrack(next: false),
              onFavoriteToggle: external ? () {} : music.toggleFavorite,
            ),
          ),
        );
      },
    );
  }
}
