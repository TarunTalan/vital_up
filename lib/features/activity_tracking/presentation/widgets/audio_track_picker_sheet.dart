import 'package:flutter/material.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';

class AudioTrackPickerSheet extends StatelessWidget {
  final WorkoutPrefs current;
  final WorkoutPrefsNotifier notifier;

  const AudioTrackPickerSheet({
    super.key,
    required this.current,
    required this.notifier,
  });

  static Future<void> show(
    BuildContext context, {
    required WorkoutPrefs current,
    required WorkoutPrefsNotifier notifier,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AudioTrackPickerSheet(
        current: current,
        notifier: notifier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracks = [
      (
        'None',
        'No music or background stories',
        Icons.music_off_rounded,
        Colors.grey
      ),
      (
        'Story: Rise & Grind',
        'Narrated high-intensity morning motivation',
        Icons.mic_rounded,
        Colors.blue
      ),
      (
        'Story: The Ascent',
        'Conquer mountain heights with a guided narrative climb',
        Icons.landscape_rounded,
        Colors.green
      ),
      (
        'Music: Synthwave Cardio Energy',
        'Upbeat electronic rhythms for running tempo',
        Icons.audiotrack_rounded,
        Colors.purple
      ),
      (
        'Music: Lo-Fi Jogging Beats',
        'Relaxing chill beats for steady-state walking/jogging',
        Icons.piano_rounded,
        Colors.orange
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'WORKOUT SOUNDTRACK',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose background music or audio stories',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final (title, subtitle, icon, color) = tracks[index];
                  final isSelected = current.backgroundAudioTrack == title;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF9F9F9) : Colors.white,
                      border: Border.all(
                        color: isSelected ? Colors.black : const Color(0xFFEEEEEE),
                        width: isSelected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      onTap: () {
                        notifier.setBackgroundAudioTrack(title);
                        Navigator.of(context).pop();
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.black : const Color(0xFF555555),
                        ),
                      ),
                      subtitle: Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Colors.black)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
