import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vital_up/core/di/injection_container.dart';
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

    final isStory = trackName.startsWith('Story:');
    const containerColor = Color(0xFF1B1A22);
    final isExternal = trackName.startsWith('Player:');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;

        final iconWidget = StreamBuilder<ProcessingState>(
          stream: sl<WorkoutAudioService>().processingStateStream,
          initialData: sl<WorkoutAudioService>().processingState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? ProcessingState.idle;
            final isLoading = state == ProcessingState.loading || state == ProcessingState.buffering;

            return Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF2BC7D8).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF2BC7D8)),
                      ),
                    )
                  : (isPlaying
                      ? const _MusicVisualizer(color: Color(0xFF2BC7D8))
                      : Icon(
                          isStory ? Icons.mic_rounded : Icons.music_note_rounded,
                          color: const Color(0xFF2BC7D8),
                          size: 20,
                        )),
            );
          },
        );

        final detailsWidget = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStory ? 'NARRATIVE STORY' : 'ACTIVITY SOUNDTRACK',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              trackName.replaceFirst('Story: ', '').replaceFirst('Music: ', ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        );

        final favButton = IconButton(
          onPressed: onFavoriteToggle,
          icon: Icon(
            isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorited ? Colors.red.shade400 : Colors.white,
            size: 20,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        );

        final prevButton = IconButton(
          onPressed: onPrevious,
          icon: const Icon(
            Icons.skip_previous_rounded,
            color: Colors.white,
            size: 22,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        );

        final playPauseButton = IconButton(
          onPressed: onPlayPause,
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
            color: const Color(0xFF2BC7D8),
            size: 30,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        );

        final nextButton = IconButton(
          onPressed: onNext,
          icon: const Icon(
            Icons.skip_next_rounded,
            color: Colors.white,
            size: 22,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        );

        final discardButton = IconButton(
          onPressed: onDiscard,
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white60,
            size: 18,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          tooltip: 'Dismiss Player',
        );

        final minimizeButton = IconButton(
          onPressed: onMinimizeToggle,
          icon: const Icon(
            Icons.close_fullscreen_rounded,
            color: Colors.white60,
            size: 18,
          ),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
          tooltip: 'Minimize Player',
        );

        if (isMinimized) {
          return GestureDetector(
            onTap: onMinimizeToggle,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2BC7D8).withOpacity(0.3), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      trackName.replaceFirst('Story: ', '').replaceFirst('Music: ', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  prevButton,
                  const SizedBox(width: 8),
                  playPauseButton,
                  const SizedBox(width: 8),
                  nextButton,
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onMinimizeToggle,
                    icon: const Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Maximize Player',
                  ),
                ],
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2BC7D8).withOpacity(0.3), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
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
                              const SizedBox(width: 12),
                              Expanded(child: detailsWidget),
                              const SizedBox(width: 8),
                              minimizeButton,
                              const SizedBox(width: 8),
                              discardButton,
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.white10, height: 1, thickness: 0.5),
                          const SizedBox(height: 8),
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
                          const SizedBox(width: 12),
                          Expanded(child: detailsWidget),
                          const SizedBox(width: 8),
                          favButton,
                          const SizedBox(width: 8),
                          prevButton,
                          const SizedBox(width: 8),
                          playPauseButton,
                          const SizedBox(width: 8),
                          nextButton,
                          const SizedBox(width: 8),
                          minimizeButton,
                          const SizedBox(width: 8),
                          discardButton,
                        ],
                      ),
                if (!isExternal) ...[
                  const SizedBox(height: 8),
                  const _AudioProgressBar(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AudioProgressBar extends StatelessWidget {
  const _AudioProgressBar();

  @override
  Widget build(BuildContext context) {
    final audioService = sl<WorkoutAudioService>();

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
                  height: 20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: const Color(0xFF2BC7D8),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFF2BC7D8),
                      overlayColor: const Color(0xFF2BC7D8).withOpacity(0.2),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: totalMs > 0 ? totalMs.toDouble() : 1.0,
                      value: currentMs.toDouble().clamp(0.0, totalMs > 0 ? totalMs.toDouble() : 1.0),
                      onChanged: (value) {
                        audioService.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(position),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        formatDuration(duration),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

class _MusicVisualizer extends StatefulWidget {
  final Color color;
  final bool isPlaying;

  const _MusicVisualizer({required this.color, this.isPlaying = true});

  @override
  State<_MusicVisualizer> createState() => _MusicVisualizerState();
}

class _MusicVisualizerState extends State<_MusicVisualizer> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(_MusicVisualizer oldWidget) {
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
