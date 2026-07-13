import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:isar_community/isar.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/database/collections/favorite_audio.dart';
import 'package:vital_up/core/database/collections/downloaded_track.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';
import 'package:vital_up/features/activity_tracking/services/local_audio_query_service.dart';
import 'package:vital_up/features/activity_tracking/services/in_app_audio_downloader.dart';
import 'package:vital_up/features/activity_tracking/services/workout_audio_service.dart';

class WorkoutAudioPage extends StatefulWidget {
  final WorkoutPrefs current;
  final WorkoutPrefsNotifier notifier;

  const WorkoutAudioPage({
    super.key,
    required this.current,
    required this.notifier,
  });

  @override
  State<WorkoutAudioPage> createState() => _WorkoutAudioPageState();
}

class _AudioPageTheme {
  static const Color background = Color(0xFF0F0E13);
  static const Color cardColor = Color(0xFF1B1A22);
  static const Color accentColor = Color(0xFF2BC7D8);
  static const Color subtitleColor = Color(0xFFAAAAAA);
}

class _WorkoutAudioPageState extends State<WorkoutAudioPage> {
  final LocalAudioQueryService _localQuery = sl<LocalAudioQueryService>();
  final InAppAudioDownloader _downloader = sl<InAppAudioDownloader>();
  final IsarService _isarService = sl<IsarService>();

  List<SongModel> _localSongs = [];
  List<FavoriteAudio> _favorites = [];
  List<DownloadedTrack> _downloads = [];

  bool _isLoadingLocal = false;
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _loadLocalSongs();
    _loadFavoritesAndDownloads();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadLocalSongs() async {
    if (!mounted) return;
    setState(() => _isLoadingLocal = true);
    try {
      final songs = await _localQuery.getLocalSongs();
      if (mounted) {
        setState(() {
          _localSongs = songs;
          _isLoadingLocal = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocal = false);
    }
  }

  Future<void> _loadFavoritesAndDownloads() async {
    final isar = _isarService.isar;
    final favs = await isar.favoriteAudios.where().findAll();
    final dls = await isar.downloadedTracks.where().findAll();
    if (mounted) {
      setState(() {
        _favorites = favs;
        _downloads = dls;
      });
    }
  }

  // Removed external app methods



  Future<void> _toggleFavorite(String trackId, String title, String subtitle, String source) async {
    final isar = _isarService.isar;
    final existing = await isar.favoriteAudios.filter().trackIdEqualTo(trackId).findFirst();

    await isar.writeTxn(() async {
      if (existing != null) {
        await isar.favoriteAudios.delete(existing.id);
      } else {
        final fav = FavoriteAudio()
          ..trackId = trackId
          ..title = title
          ..subtitle = subtitle
          ..audioSource = source
          ..favoritedAt = DateTime.now();
        await isar.favoriteAudios.put(fav);
      }
    });

    _loadFavoritesAndDownloads();
  }

  bool _isFavorited(String trackId) {
    return _favorites.any((f) => f.trackId == trackId);
  }

  bool _isDownloaded(String trackId) {
    return _downloads.any((d) => d.trackId == trackId);
  }

  Future<void> _startDownload(String trackId, String remoteUrl, String title, String subtitle) async {
    setState(() => _downloadProgress[trackId] = 0.01);
    try {
      await _downloader.downloadTrack(
        trackId: trackId,
        remoteUrl: remoteUrl,
        title: title,
        subtitle: subtitle,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress[trackId] = progress);
          }
        },
      );
      if (mounted) {
        setState(() => _downloadProgress.remove(trackId));
      }
      _loadFavoritesAndDownloads();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded "$title" successfully!')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(trackId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AudioPageTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Workout Soundtrack',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ValueListenableBuilder<WorkoutPrefs>(
        valueListenable: widget.notifier,
        builder: (context, prefs, _) {
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                // TabBar control
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _AudioPageTheme.accentColor,
                  unselectedLabelColor: _AudioPageTheme.subtitleColor,
                  indicatorColor: _AudioPageTheme.accentColor,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(text: 'In-App Stories'),
                    Tab(text: 'Local Audio'),
                    Tab(text: 'Favorites'),
                  ],
                ),
                const SizedBox(height: 12),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildStoriesTab(prefs),
                      _buildLocalTab(prefs),
                      _buildFavoritesTab(prefs),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoriesTab(WorkoutPrefs prefs) {
    final storyTracks = [
      (
        'None',
        'No background stories',
        Icons.music_off_rounded,
        Colors.grey,
        ''
      ),
      (
        'Story: It\'s Possible',
        'Inspirational speech on overcoming odds and believing in yourself',
        Icons.star_rounded,
        Colors.amber,
        'https://archive.org/download/DontMakeExcuses/3%20Its%20Possible.mp3'
      ),
      (
        'Story: Goals',
        'Focus on setting, chasing, and achieving your life and fitness goals',
        Icons.flag_rounded,
        Colors.blue,
        'https://archive.org/download/DontMakeExcuses/8%20Goals%20%28Its%20Possible%29.mp3'
      ),
      (
        'Story: Light Up the Darkness',
        'Find your inner strength during tough challenges and pushes',
        Icons.wb_sunny_rounded,
        Colors.orange,
        'https://archive.org/download/DontMakeExcuses/LIGHT%20UP%20THE%20DARKNESS.mp3'
      ),
      (
        'Story: Without Limits',
        'Break your boundaries and run a workout with unlimited potential',
        Icons.directions_run_rounded,
        Colors.green,
        'https://archive.org/download/DontMakeExcuses/Living%20A%20Life%20Without%20Limits.mp3'
      ),
      (
        'Story: Best Speeches',
        'A power-packed motivation compilation for peak fitness pushes',
        Icons.bolt_rounded,
        Colors.purple,
        'https://archive.org/download/DontMakeExcuses/One%20of%20The%20Best%20Motivational%20Speeches%20Ever.mp3'
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: storyTracks.length,
      itemBuilder: (context, index) {
        final (title, subtitle, icon, color, downloadUrl) = storyTracks[index];
        final isSelected = prefs.backgroundAudioTrack == title;
        final isDownloadedOffline = _isDownloaded(title) || title == 'None';
        final downloadingProgress = _downloadProgress[title];

        return Card(
          color: _AudioPageTheme.cardColor,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? _AudioPageTheme.accentColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ListTile(
            onTap: () {
              final isCurrent = sl<WorkoutAudioService>().currentTrack == title;
              if (isCurrent) {
                if (sl<WorkoutAudioService>().isPlaying) {
                  sl<WorkoutAudioService>().pause();
                } else {
                  sl<WorkoutAudioService>().resume();
                }
              } else {
                widget.notifier.setBackgroundAudioTrack(title, queueType: 'stories');
                sl<WorkoutAudioService>().playTrack(title);
              }
            },
            leading: AudioTrackLeadingIcon(
              trackId: title,
              isSelected: isSelected,
              defaultIcon: icon,
              defaultColor: color,
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: _AudioPageTheme.subtitleColor),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != 'None') ...[
                  if (downloadingProgress != null)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: downloadingProgress,
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation(Colors.grey),
                      ),
                    )
                  else if (isDownloadedOffline)
                    const Icon(Icons.offline_pin_rounded, color: Colors.grey, size: 20)
                  else
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: _AudioPageTheme.subtitleColor, size: 20),
                      onPressed: () => _startDownload(title, downloadUrl, title, 'Curated Audio'),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _isFavorited(title) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFavorited(title) ? Colors.red : _AudioPageTheme.subtitleColor,
                      size: 20,
                    ),
                    onPressed: () => _toggleFavorite(title, title, 'Curated Audio', 'preset'),
                  ),
                ],
                if (isSelected) const Icon(Icons.check_circle_rounded, color: _AudioPageTheme.accentColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocalTab(WorkoutPrefs prefs) {
    if (_isLoadingLocal) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(_AudioPageTheme.accentColor)));
    }

    if (_localSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note_rounded, size: 64, color: _AudioPageTheme.subtitleColor),
              const SizedBox(height: 16),
              const Text(
                'No local audio files found',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Grant media storage permissions to scan local device MP3 files.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _AudioPageTheme.subtitleColor, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final granted = await _localQuery.requestPermissions();
                  if (granted) _loadLocalSongs();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AudioPageTheme.accentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Grant Access', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _localSongs.length,
      itemBuilder: (context, index) {
        final song = _localSongs[index];
        final trackName = 'Local:${song.id}';
        final isSelected = prefs.backgroundAudioTrack == trackName;

        return Card(
          color: _AudioPageTheme.cardColor,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? _AudioPageTheme.accentColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ListTile(
            onTap: () {
              final isCurrent = sl<WorkoutAudioService>().currentTrack == trackName;
              if (isCurrent) {
                if (sl<WorkoutAudioService>().isPlaying) {
                  sl<WorkoutAudioService>().pause();
                } else {
                  sl<WorkoutAudioService>().resume();
                }
              } else {
                widget.notifier.setBackgroundAudioTrack(trackName, queueType: 'local');
                sl<WorkoutAudioService>().playTrack(trackName, source: 'local', localPath: song.uri ?? song.data);
              }
            },
            leading: AudioTrackLeadingIcon(
              trackId: trackName,
              isSelected: isSelected,
              defaultIcon: Icons.music_note_rounded,
              defaultColor: _AudioPageTheme.accentColor,
              fallbackWidget: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                nullArtworkWidget: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22212A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.music_note_rounded, color: _AudioPageTheme.subtitleColor, size: 20),
                ),
              ),
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            subtitle: Text(
              song.artist ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _AudioPageTheme.subtitleColor),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isFavorited(trackName) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFavorited(trackName) ? Colors.red : _AudioPageTheme.subtitleColor,
                    size: 20,
                  ),
                  onPressed: () => _toggleFavorite(trackName, song.title, song.artist ?? 'Unknown Artist', 'local'),
                ),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: _AudioPageTheme.accentColor),
              ],
            ),
          ),
        );
      },
    );
  }

  // Removed _buildAppsTab

  Widget _buildFavoritesTab(WorkoutPrefs prefs) {
    if (_favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded, size: 64, color: _AudioPageTheme.subtitleColor),
            SizedBox(height: 16),
            Text(
              'No favorite soundtracks yet',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Toggle the heart button on any track to add it here.',
              style: TextStyle(color: _AudioPageTheme.subtitleColor, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final fav = _favorites[index];
        final isSelected = prefs.backgroundAudioTrack == fav.trackId;

        final isStory = fav.trackId.startsWith('Story: ');
        final isLocal = fav.trackId.startsWith('Local:');

        IconData leadIcon = Icons.audiotrack_rounded;
        if (isStory) leadIcon = Icons.mic_rounded;
        if (isLocal) leadIcon = Icons.music_note_rounded;

        return Card(
          color: _AudioPageTheme.cardColor,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? _AudioPageTheme.accentColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ListTile(
            onTap: () {
              final isCurrent = sl<WorkoutAudioService>().currentTrack == fav.trackId;
              if (isCurrent) {
                if (sl<WorkoutAudioService>().isPlaying) {
                  sl<WorkoutAudioService>().pause();
                } else {
                  sl<WorkoutAudioService>().resume();
                }
              } else {
                widget.notifier.setBackgroundAudioTrack(fav.trackId, queueType: 'favorite');
                if (fav.audioSource == 'local') {
                  final songId = fav.trackId.split(':').last;
                  final contentUri = 'content://media/external/audio/media/$songId';
                  sl<WorkoutAudioService>().playTrack(fav.trackId, source: 'local', localPath: contentUri);
                } else {
                  sl<WorkoutAudioService>().playTrack(fav.trackId);
                }
              }
            },
            leading: AudioTrackLeadingIcon(
              trackId: fav.trackId,
              isSelected: isSelected,
              defaultIcon: leadIcon,
              defaultColor: _AudioPageTheme.accentColor,
            ),
            title: Text(
              fav.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            subtitle: Text(
              fav.subtitle,
              style: const TextStyle(fontSize: 11, color: _AudioPageTheme.subtitleColor),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_rounded, color: Colors.red, size: 20),
                  onPressed: () => _toggleFavorite(fav.trackId, fav.title, fav.subtitle, fav.audioSource),
                ),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: _AudioPageTheme.accentColor),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AudioTrackLeadingIcon extends StatelessWidget {
  final String trackId;
  final bool isSelected;
  final IconData defaultIcon;
  final Color defaultColor;
  final Widget? fallbackWidget;

  const AudioTrackLeadingIcon({
    super.key,
    required this.trackId,
    required this.isSelected,
    required this.defaultIcon,
    required this.defaultColor,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSelected || trackId == 'None') {
      return fallbackWidget ?? Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: defaultColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(defaultIcon, color: defaultColor, size: 20),
      );
    }

    final audioService = sl<WorkoutAudioService>();

    return StreamBuilder<bool>(
      stream: audioService.playingStream,
      initialData: audioService.isPlaying && audioService.currentTrack == trackId,
      builder: (context, playingSnapshot) {
        final isPlaying = playingSnapshot.data ?? false;
        final isCurrent = audioService.currentTrack == trackId;

        if (!isCurrent) {
          return fallbackWidget ?? Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: defaultColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(defaultIcon, color: defaultColor, size: 20),
          );
        }

        return StreamBuilder<ProcessingState>(
          stream: audioService.processingStateStream,
          initialData: audioService.processingState,
          builder: (context, processingSnapshot) {
            final state = processingSnapshot.data ?? ProcessingState.idle;
            final isLoading = state == ProcessingState.loading || state == ProcessingState.buffering;

            return Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: defaultColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(defaultColor),
                      ),
                    )
                  : MusicVisualizer(
                      color: defaultColor,
                      isPlaying: isPlaying,
                    ),
            );
          },
        );
      },
    );
  }
}

class MusicVisualizer extends StatefulWidget {
  final Color color;
  final bool isPlaying;

  const MusicVisualizer({super.key, required this.color, this.isPlaying = true});

  @override
  State<MusicVisualizer> createState() => _MusicVisualizerState();
}

class _MusicVisualizerState extends State<MusicVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<int> _durations = [900, 800, 1000, 700];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(MusicVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(4, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double value = 0.3;
            if (widget.isPlaying) {
              final t = (_controller.value * 1000 / _durations[index]) % 1.0;
              value = 0.3 + 0.7 * (0.5 - (0.5 - t).abs()) * 2;
            }
            return Container(
              width: 2.2,
              height: 14 * value,
              margin: const EdgeInsets.symmetric(horizontal: 0.8),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          },
        );
      }),
    );
  }
}
