import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:isar_community/isar.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/music_visualizer.dart';
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
    final List<FavoriteAudio> favs;
    final List<DownloadedTrack> dls;
    try {
      favs = await isar.favoriteAudios.where().findAll();
      dls = await isar.downloadedTracks.where().findAll();
    } catch (e) {
      debugPrint('Loading saved tracks failed: $e');
      return;
    }
    if (mounted) {
      setState(() {
        _favorites = favs;
        _downloads = dls;
      });
    }
  }

  Future<void> _toggleFavorite(
    String trackId,
    String title,
    String subtitle,
    String source,
  ) async {
    final isar = _isarService.isar;
    try {
      final existing = await isar.favoriteAudios
          .filter()
          .trackIdEqualTo(trackId)
          .findFirst();

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
    } catch (e) {
      debugPrint('Updating favourites failed: $e');
      if (mounted) {
        showErrorSnackBar(context, "Couldn't update favourites. Try again.");
      }
    }

    _loadFavoritesAndDownloads();
  }

  bool _isFavorited(String trackId) {
    return _favorites.any((f) => f.trackId == trackId);
  }

  bool _isDownloaded(String trackId) {
    return _downloads.any((d) => d.trackId == trackId);
  }

  Future<void> _startDownload(
    String trackId,
    String remoteUrl,
    String title,
    String subtitle,
  ) async {
    // One download per track: a second tap would write the same file.
    if (_downloadProgress.containsKey(trackId)) return;
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
      if (mounted) {
        showSuccessSnackBar(context, '"$title" is ready to play offline.');
      }
    } catch (e) {
      debugPrint('Audio download failed: $e');
      if (mounted) {
        setState(() => _downloadProgress.remove(trackId));
        showErrorSnackBar(
          context,
          userMessage(e, fallback: "Couldn't download this track. Try again."),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;

    return AppScaffold(
      header: const AppPageHeader(title: 'Workout Soundtrack'),
      scrollable: false,
      padBody: false,
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<WorkoutPrefs>(
          valueListenable: widget.notifier,
          builder: (context, prefs, _) {
            return DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const SizedBox(height: AppDimens.space16),
                  Padding(
                    padding: context.pagePadding,
                    child: Container(
                      padding: const EdgeInsets.all(AppDimens.space4),
                      decoration: BoxDecoration(
                        color: v.glassFill,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusCard,
                        ),
                        border: Border.all(color: v.glassBorder!),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusSm,
                          ),
                          boxShadow: AppShadows.segment,
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: v.buttonText,
                        unselectedLabelColor: v.grayText,
                        labelStyle: context.text.labelMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        dividerColor: Colors.transparent,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.space4,
                        ),
                        tabs: const [
                          _SegmentTab('In-App Stories'),
                          _SegmentTab('Local Audio'),
                          _SegmentTab('Favorites'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.space8),
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
      ),
    );
  }

  EdgeInsets get _listPadding => EdgeInsets.symmetric(
    horizontal: context.gutter,
    vertical: AppDimens.space8,
  );

  Widget _favoriteButton(bool favorited, VoidCallback onPressed) {
    return IconButton(
      tooltip: favorited ? 'Remove favorite' : 'Add favorite',
      icon: Icon(
        favorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: favorited ? context.colors.error : context.vColors.grayText,
        size: AppDimens.iconMd,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildStoriesTab(WorkoutPrefs prefs) {
    final colors = context.colors;
    final v = context.vColors;

    final storyTracks = [
      (
        'None',
        'No background stories',
        Icons.music_off_rounded,
        v.grayText!,
        '',
      ),
      (
        'Story: It\'s Possible',
        'Inspirational speech on overcoming odds and believing in yourself',
        Icons.star_rounded,
        ActivityColors.accentAmber,
        'https://archive.org/download/DontMakeExcuses/3%20Its%20Possible.mp3',
      ),
      (
        'Story: Goals',
        'Focus on setting, chasing, and achieving your life and fitness goals',
        Icons.flag_rounded,
        v.info!,
        'https://archive.org/download/DontMakeExcuses/8%20Goals%20%28Its%20Possible%29.mp3',
      ),
      (
        'Story: Light Up the Darkness',
        'Find your inner strength during tough challenges and pushes',
        Icons.wb_sunny_rounded,
        v.warning!,
        'https://archive.org/download/DontMakeExcuses/LIGHT%20UP%20THE%20DARKNESS.mp3',
      ),
      (
        'Story: Without Limits',
        'Break your boundaries and run a workout with unlimited potential',
        Icons.directions_run_rounded,
        v.success!,
        'https://archive.org/download/DontMakeExcuses/Living%20A%20Life%20Without%20Limits.mp3',
      ),
      (
        'Story: Best Speeches',
        'A power-packed motivation compilation for peak fitness pushes',
        Icons.bolt_rounded,
        ActivityColors.accentPurple,
        'https://archive.org/download/DontMakeExcuses/One%20of%20The%20Best%20Motivational%20Speeches%20Ever.mp3',
      ),
    ];

    return ListView.builder(
      padding: _listPadding,
      itemCount: storyTracks.length,
      itemBuilder: (context, index) {
        final (title, subtitle, icon, color, downloadUrl) = storyTracks[index];
        final isSelected = prefs.backgroundAudioTrack == title;
        final isDownloadedOffline = _isDownloaded(title) || title == 'None';
        final downloadingProgress = _downloadProgress[title];

        return _TrackCard(
          selected: isSelected,
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
                widget.notifier.setBackgroundAudioTrack(
                  title,
                  queueType: 'stories',
                );
                sl<WorkoutAudioService>().playTrack(title);
              }
            },
            leading: AudioTrackLeadingIcon(
              trackId: title,
              isSelected: isSelected,
              defaultIcon: icon,
              defaultColor: color,
            ),
            title: Text(title),
            subtitle: Text(
              subtitle,
              style: context.text.bodySmall?.copyWith(color: v.grayText),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != 'None') ...[
                  if (downloadingProgress != null)
                    SizedBox.square(
                      dimension: AppDimens.iconMd,
                      child: CircularProgressIndicator(
                        value: downloadingProgress,
                        strokeWidth: AppDimens.borderThick,
                      ),
                    )
                  else if (isDownloadedOffline)
                    Icon(
                      Icons.offline_pin_rounded,
                      color: v.grayText,
                      size: AppDimens.iconMd,
                    )
                  else
                    IconButton(
                      tooltip: 'Download',
                      icon: Icon(
                        Icons.download_rounded,
                        color: v.grayText,
                        size: AppDimens.iconMd,
                      ),
                      onPressed: () => _startDownload(
                        title,
                        downloadUrl,
                        title,
                        'Curated Audio',
                      ),
                    ),
                  _favoriteButton(
                    _isFavorited(title),
                    () => _toggleFavorite(
                      title,
                      title,
                      'Curated Audio',
                      'preset',
                    ),
                  ),
                ],
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: colors.primary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocalTab(WorkoutPrefs prefs) {
    final colors = context.colors;
    final v = context.vColors;

    if (_isLoadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_localSongs.isEmpty) {
      return _EmptyState(
        icon: Icons.music_note_rounded,
        title: 'No local audio files found',
        message:
            'Grant media storage permissions to scan local device MP3 files.',
        action: AppPrimaryButton(
          label: 'Grant Access',
          expand: false,
          onTap: () async {
            final granted = await _localQuery.requestPermissions();
            if (granted) _loadLocalSongs();
          },
        ),
      );
    }

    return ListView.builder(
      padding: _listPadding,
      itemCount: _localSongs.length,
      itemBuilder: (context, index) {
        final song = _localSongs[index];
        final trackName = 'Local:${song.id}';
        final isSelected = prefs.backgroundAudioTrack == trackName;

        return _TrackCard(
          selected: isSelected,
          child: ListTile(
            onTap: () {
              final isCurrent =
                  sl<WorkoutAudioService>().currentTrack == trackName;
              if (isCurrent) {
                if (sl<WorkoutAudioService>().isPlaying) {
                  sl<WorkoutAudioService>().pause();
                } else {
                  sl<WorkoutAudioService>().resume();
                }
              } else {
                widget.notifier.setBackgroundAudioTrack(
                  trackName,
                  queueType: 'local',
                );
                sl<WorkoutAudioService>().playTrack(
                  trackName,
                  source: 'local',
                  localPath: song.uri ?? song.data,
                );
              }
            },
            leading: AudioTrackLeadingIcon(
              trackId: trackName,
              isSelected: isSelected,
              defaultIcon: Icons.music_note_rounded,
              defaultColor: colors.primary,
              fallbackWidget: QueryArtworkWidget(
                id: song.id,
                type: ArtworkType.AUDIO,
                nullArtworkWidget: AppIconBadge(
                  icon: const Icon(Icons.music_note_rounded),
                  color: v.grayText,
                ),
              ),
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              song.artist ?? 'Unknown Artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: v.grayText),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _favoriteButton(
                  _isFavorited(trackName),
                  () => _toggleFavorite(
                    trackName,
                    song.title,
                    song.artist ?? 'Unknown Artist',
                    'local',
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: colors.primary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab(WorkoutPrefs prefs) {
    final colors = context.colors;
    final v = context.vColors;

    if (_favorites.isEmpty) {
      return const _EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No favorite soundtracks yet',
        message: 'Toggle the heart button on any track to add it here.',
      );
    }

    return ListView.builder(
      padding: _listPadding,
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final fav = _favorites[index];
        final isSelected = prefs.backgroundAudioTrack == fav.trackId;

        final isStory = fav.trackId.startsWith('Story: ');
        final isLocal = fav.trackId.startsWith('Local:');

        IconData leadIcon = Icons.audiotrack_rounded;
        if (isStory) leadIcon = Icons.mic_rounded;
        if (isLocal) leadIcon = Icons.music_note_rounded;

        return _TrackCard(
          selected: isSelected,
          child: ListTile(
            onTap: () {
              final isCurrent =
                  sl<WorkoutAudioService>().currentTrack == fav.trackId;
              if (isCurrent) {
                if (sl<WorkoutAudioService>().isPlaying) {
                  sl<WorkoutAudioService>().pause();
                } else {
                  sl<WorkoutAudioService>().resume();
                }
              } else {
                widget.notifier.setBackgroundAudioTrack(
                  fav.trackId,
                  queueType: 'favorite',
                );
                if (fav.audioSource == 'local') {
                  final songId = fav.trackId.split(':').last;
                  final contentUri =
                      'content://media/external/audio/media/$songId';
                  sl<WorkoutAudioService>().playTrack(
                    fav.trackId,
                    source: 'local',
                    localPath: contentUri,
                  );
                } else {
                  sl<WorkoutAudioService>().playTrack(fav.trackId);
                }
              }
            },
            leading: AudioTrackLeadingIcon(
              trackId: fav.trackId,
              isSelected: isSelected,
              defaultIcon: leadIcon,
              defaultColor: colors.primary,
            ),
            title: Text(fav.title),
            subtitle: Text(
              fav.subtitle,
              style: context.text.bodySmall?.copyWith(color: v.grayText),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _favoriteButton(
                  true,
                  () => _toggleFavorite(
                    fav.trackId,
                    fav.title,
                    fav.subtitle,
                    fav.audioSource,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: colors.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  const _SegmentTab(this.label);

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: AppDimens.segmentHeight,
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final bool selected;
  final Widget child;

  const _TrackCard({required this.selected, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: AppDimens.space4),
      padding: EdgeInsets.zero,
      borderColor: selected ? context.colors.primary : null,
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconBadge(icon: Icon(icon), size: AppDimens.iconBadgeLarge),
            const SizedBox(height: AppDimens.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppDimens.space16),
              action!,
            ],
          ],
        ),
      ),
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
    final idle =
        fallbackWidget ??
        AppIconBadge(icon: Icon(defaultIcon), color: defaultColor);

    if (!isSelected || trackId == 'None') return idle;

    final audioService = sl<WorkoutAudioService>();

    return StreamBuilder<bool>(
      stream: audioService.playingStream,
      initialData:
          audioService.isPlaying && audioService.currentTrack == trackId,
      builder: (context, playingSnapshot) {
        final isPlaying = playingSnapshot.data ?? false;
        final isCurrent = audioService.currentTrack == trackId;

        if (!isCurrent) return idle;

        return StreamBuilder<ProcessingState>(
          stream: audioService.processingStateStream,
          initialData: audioService.processingState,
          builder: (context, processingSnapshot) {
            final state = processingSnapshot.data ?? ProcessingState.idle;
            final isLoading =
                state == ProcessingState.loading ||
                state == ProcessingState.buffering;

            return AppIconBadge(
              color: defaultColor,
              icon: isLoading
                  ? SizedBox.square(
                      dimension: AppDimens.iconXs,
                      child: CircularProgressIndicator(
                        strokeWidth: AppDimens.borderThick,
                        valueColor: AlwaysStoppedAnimation(defaultColor),
                      ),
                    )
                  : MusicVisualizer(color: defaultColor, isPlaying: isPlaying),
            );
          },
        );
      },
    );
  }
}
