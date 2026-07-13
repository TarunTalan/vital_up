import 'package:flutter/material.dart';

class WorkoutMusicPlayer extends StatelessWidget {
  final String trackName;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  const WorkoutMusicPlayer({
    super.key,
    required this.trackName,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (trackName == 'None') return const SizedBox.shrink();

    final isStory = trackName.startsWith('Story:');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
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
          // Animated music note / mic icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isStory ? Icons.mic_rounded : Icons.music_note_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Track Details
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStory ? 'NARRATIVE STORY' : 'WORKOUT SOUNDTRACK',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white.withOpacity(0.5),
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
            ),
          ),
          const SizedBox(width: 8),

          // Play / Pause
          IconButton(
            onPressed: onPlayPause,
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),

          // Skip / Next
          IconButton(
            onPressed: onNext,
            icon: const Icon(
              Icons.skip_next_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
