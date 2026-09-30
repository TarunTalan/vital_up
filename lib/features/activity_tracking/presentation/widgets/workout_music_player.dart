import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/music_visualizer.dart';
import 'package:vital_up/features/activity_tracking/services/workout_audio_service.dart';

class WorkoutMusicPlayer extends StatelessWidget {
  final String trackName;
  final bool isPlaying;
  final bool isFavorited;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;
  final VoidCallback onDiscard;
  final bool isMinimized;
  final VoidCallback onMinimizeToggle;

  const WorkoutMusicPlayer({
    super.key,
    required this.trackName,
    required this.isPlaying,
    required this.isFavorited,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onFavoriteToggle,
    required this.onTap,
    required this.onDiscard,
    required this.isMinimized,
    required this.onMinimizeToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (trackName == 'None') return const SizedBox.shrink();

    final colors = context.colors;
    final v = context.vColors;
    final isStory = trackName.startsWith('Story:');
    final isExternal = trackName.startsWith('Player:');
    final displayName = trackName
        .replaceFirst('Story: ', '')
        .replaceFirst('Music: ', '');
    final muted = colors.onSurface.withValues(alpha: 0.6);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < AppDimens.smallPhoneBreakpoint;

        final iconWidget = StreamBuilder<ProcessingState>(
          stream: sl<WorkoutAudioService>().processingStateStream,
          initialData: sl<WorkoutAudioService>().processingState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? ProcessingState.idle;
            final isLoading =
                state == ProcessingState.loading ||
                state == ProcessingState.buffering;

            return AppIconBadge(
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: AppDimens.iconXs,
                      child: CircularProgressIndicator(
                        strokeWidth: AppDimens.borderThick,
                      ),
                    )
                  : (isPlaying
                        ? MusicVisualizer(color: colors.primary)
                        : Icon(
                            isStory
                                ? Icons.mic_rounded
                                : Icons.music_note_rounded,
                          )),
            );
          },
        );

        final detailsWidget = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCaption(isStory ? 'Narrative story' : 'Activity soundtrack'),
            const SizedBox(height: AppDimens.space2),
            Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );

        final favButton = _PlayerIconButton(
          onPressed: onFavoriteToggle,
          icon: isFavorited
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: isFavorited ? colors.error : colors.onSurface,
        );
        final prevButton = _PlayerIconButton(
          onPressed: onPrevious,
          icon: Icons.skip_previous_rounded,
          color: colors.onSurface,
        );
        final playPauseButton = _PlayerIconButton(
          onPressed: onPlayPause,
          icon: isPlaying
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_filled_rounded,
          color: colors.primary,
          size: AppDimens.iconXl,
        );
        final nextButton = _PlayerIconButton(
          onPressed: onNext,
          icon: Icons.skip_next_rounded,
          color: colors.onSurface,
        );
        final discardButton = _PlayerIconButton(
          onPressed: onDiscard,
          icon: Icons.close_rounded,
          color: muted,
          size: AppDimens.iconSm,
          tooltip: 'Dismiss Player',
        );
        final minimizeButton = _PlayerIconButton(
          onPressed: onMinimizeToggle,
          icon: Icons.close_fullscreen_rounded,
          color: muted,
          size: AppDimens.iconSm,
          tooltip: 'Minimize Player',
        );

        final cardTint = v.surfaceElevated!.withValues(alpha: 0.9);

        if (isMinimized) {
          return AppCard(
            onTap: onMinimizeToggle,
            margin: const EdgeInsets.symmetric(vertical: AppDimens.space8),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.space12,
              vertical: AppDimens.space8,
            ),
            tint: cardTint,
            blur: true,
            shadow: AppShadows.soft,
            child: Row(
              children: [
                iconWidget,
                const SizedBox(width: AppDimens.space8),
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                prevButton,
                playPauseButton,
                nextButton,
                _PlayerIconButton(
                  onPressed: onMinimizeToggle,
                  icon: Icons.open_in_full_rounded,
                  color: muted,
                  size: AppDimens.iconXs,
                  tooltip: 'Maximize Player',
                ),
              ],
            ),
          );
        }

        return AppCard(
          onTap: onTap,
          margin: const EdgeInsets.symmetric(vertical: AppDimens.space8),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.space12,
            vertical: AppDimens.space12,
          ),
          tint: cardTint,
          blur: true,
          shadow: AppShadows.soft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isNarrow
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            iconWidget,
                            const SizedBox(width: AppDimens.space12),
                            Expanded(child: detailsWidget),
                            minimizeButton,
                            discardButton,
                          ],
                        ),
                        const SizedBox(height: AppDimens.space8),
                        const Divider(),
                        const SizedBox(height: AppDimens.space4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            favButton,
                            prevButton,
                            playPauseButton,
                            nextButton,
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        iconWidget,
                        const SizedBox(width: AppDimens.space12),
                        Expanded(child: detailsWidget),
                        favButton,
                        prevButton,
                        playPauseButton,
                        nextButton,
                        minimizeButton,
                        discardButton,
                      ],
                    ),
              if (!isExternal) ...[
                const SizedBox(height: AppDimens.space8),
                const _AudioProgressBar(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PlayerIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;
  final double size;
  final String? tooltip;

  const _PlayerIconButton({
    required this.onPressed,
    required this.icon,
    required this.color,
    this.size = AppDimens.iconLg,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: size),
      padding: const EdgeInsets.all(AppDimens.space4),
      constraints: const BoxConstraints(),
      tooltip: tooltip,
    );
  }
}

class _AudioProgressBar extends StatelessWidget {
  const _AudioProgressBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final audioService = sl<WorkoutAudioService>();
    final timeStyle = context.text.labelSmall?.copyWith(
      color: colors.onSurface.withValues(alpha: 0.6),
      fontWeight: FontWeight.w500,
    );

    return StreamBuilder<Duration>(
      stream: audioService.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: audioService.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;

            // Format duration to MM:SS
            String formatDuration(Duration d) {
              final minutes = d.inMinutes;
              final seconds = d.inSeconds % 60;
              return '$minutes:${seconds.toString().padLeft(2, '0')}';
            }

            final totalMs = duration.inMilliseconds;
            final currentMs = position.inMilliseconds;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: AppDimens.space20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: AppDimens.space4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: AppDimens.space6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: AppDimens.space12,
                      ),
                      overlayColor: colors.primary.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: totalMs > 0 ? totalMs.toDouble() : 1.0,
                      value: currentMs.toDouble().clamp(
                        0.0,
                        totalMs > 0 ? totalMs.toDouble() : 1.0,
                      ),
                      onChanged: (value) {
                        audioService.seek(
                          Duration(milliseconds: value.toInt()),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(position), style: timeStyle),
                      Text(formatDuration(duration), style: timeStyle),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
