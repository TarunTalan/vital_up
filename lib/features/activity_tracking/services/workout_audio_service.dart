import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:isar_community/isar.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/database/collections/downloaded_track.dart';
import 'package:vital_up/features/activity_tracking/services/voice_coach_service.dart';

class WorkoutAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentTrack;

  WorkoutAudioService() {
    _audioPlayer.setLoopMode(LoopMode.one);
    _configureAudioSession();
  }

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers | AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
    } catch (e) {
      // Fail-safe
    }
  }

  Future<void> playTrack(String trackName, {String? source, String? localPath, bool play = true}) async {
    if (trackName == 'None') {
      await stop();
      try {
        sl<VoiceCoachService>().stop();
      } catch (_) {}
      return;
    }

    try {
      if (_currentTrack == trackName) {
        if (play) {
          if (!_audioPlayer.playing) {
            await _audioPlayer.play();
          }
        } else {
          if (_audioPlayer.playing) {
            await _audioPlayer.pause();
          }
        }
        return;
      }

      _currentTrack = trackName;

      try {
        sl<VoiceCoachService>().stop();
      } catch (_) {}

      String? resolvedSource = source;
      String? resolvedLocalPath = localPath;

      if (resolvedSource == null && !trackName.startsWith('Local:')) {
        final downloaded = await sl<IsarService>().isar.downloadedTracks
            .filter()
            .trackIdEqualTo(trackName)
            .findFirst();
        if (downloaded != null) {
          resolvedSource = 'download';
          resolvedLocalPath = downloaded.localFilePath;
        }
      }

      if (resolvedSource == 'local') {
        try {
          if (resolvedLocalPath != null) {
            if (resolvedLocalPath.startsWith('content://')) {
              await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(resolvedLocalPath)));
            } else {
              await _audioPlayer.setAudioSource(AudioSource.file(resolvedLocalPath));
            }
          } else if (trackName.startsWith('Local:')) {
            final songId = trackName.split(':').last;
            final contentUri = 'content://media/external/audio/media/$songId';
            await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(contentUri)));
          } else {
            throw Exception('Local path was null and track name does not start with Local:');
          }
        } catch (e) {
          if (trackName.startsWith('Local:')) {
            final songId = trackName.split(':').last;
            final contentUri = 'content://media/external/audio/media/$songId';
            await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(contentUri)));
          } else {
            rethrow;
          }
        }
      } else if (resolvedSource == 'download' && resolvedLocalPath != null) {
        // Play downloaded in-app audio file
        await _audioPlayer.setAudioSource(AudioSource.file(resolvedLocalPath));
      } else {
        // Play preset soundtrack or story. If the local asset file is not present,
        // we stream it from a public fallback URL so that it plays successfully.
        String? assetPath;
        String? fallbackUrl;

        if (trackName.contains("It's Possible")) {
          fallbackUrl = 'https://archive.org/download/DontMakeExcuses/3%20Its%20Possible.mp3';
        } else if (trackName.contains('Goals')) {
          fallbackUrl = 'https://archive.org/download/DontMakeExcuses/8%20Goals%20%28Its%20Possible%29.mp3';
        } else if (trackName.contains('Light Up the Darkness')) {
          fallbackUrl = 'https://archive.org/download/DontMakeExcuses/LIGHT%20UP%20THE%20DARKNESS.mp3';
        } else if (trackName.contains('Without Limits')) {
          fallbackUrl = 'https://archive.org/download/DontMakeExcuses/Living%20A%20Life%20Without%20Limits.mp3';
        } else if (trackName.contains('Best Speeches')) {
          fallbackUrl = 'https://archive.org/download/DontMakeExcuses/One%20of%20The%20Best%20Motivational%20Speeches%20Ever.mp3';
        } else if (trackName.contains('Synthwave Cardio Energy')) {
          assetPath = 'assets/audio/synthwave_cardio.mp3';
          fallbackUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3';
        } else if (trackName.contains('Lo-Fi Jogging Beats')) {
          assetPath = 'assets/audio/lofi_jogging.mp3';
          fallbackUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3';
        }

        if (assetPath != null) {
          try {
            // Attempt to load from local assets
            await _audioPlayer.setAudioSource(AudioSource.asset(assetPath));
          } catch (_) {
            if (fallbackUrl != null) {
              await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(fallbackUrl)));
            } else {
              await stop();
              return;
            }
          }
        } else if (fallbackUrl != null) {
          await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(fallbackUrl)));
        } else {
          await stop();
          return;
        }
      }

      if (play) {
        await _audioPlayer.play();
      } else {
        await _audioPlayer.pause();
      }
    } catch (e, stack) {
      print("VITAL_UP AUDIO PLAYBACK ERROR: $e");
      print(stack);
      _currentTrack = null;
    }
  }

  Future<void> pause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    }
    try {
      sl<VoiceCoachService>().stop();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_currentTrack != null && _currentTrack != 'None') {
      await _audioPlayer.play();
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentTrack = null;
  }

  /// Duck volume when voice coach TTS is talking
  Future<void> setDucked(bool ducked) async {
    await _audioPlayer.setVolume(ducked ? 0.2 : 1.0);
  }

  bool get isPlaying => _audioPlayer.playing;
  String? get currentTrack => _currentTrack;

  Stream<bool> get playingStream => _audioPlayer.playingStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<ProcessingState> get processingStateStream => _audioPlayer.processingStateStream;
  ProcessingState get processingState => _audioPlayer.processingState;

  Duration? get duration => _audioPlayer.duration;
  Duration get position => _audioPlayer.position;

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
