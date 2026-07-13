import 'package:flutter_tts/flutter_tts.dart';
import 'package:vital_up/core/preferences/distance_unit_notifier.dart';
import 'package:vital_up/core/preferences/workout_prefs_notifier.dart';

/// Handles all text-to-speech announcements during a workout session.
///
/// Fires cues at each completed km/mi, on session start, and on session stop.
class VoiceCoachService {
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  double _lastAnnouncedDistanceKm = 0.0;
  bool _targetAchievedAnnounced = false;
  bool _announced50 = false;
  bool _announced75 = false;
  bool _announced90 = false;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> announceStart() async {
    await _tts.stop();
    _lastAnnouncedDistanceKm = 0.0;
    _targetAchievedAnnounced = false;
    _announced50 = false;
    _announced75 = false;
    _announced90 = false;
    await _speak("Activity started. Let's go!");
  }

  Future<void> announcePause() async {
    await _speak('Activity paused.');
  }

  Future<void> announceResume() async {
    await _speak('Activity resumed.');
  }

  Future<void> announceStop(
      {required double distanceMeters, required int elapsedSeconds}) async {
    await _tts.stop();
    final km = distanceMeters / 1000.0;
    final mins = elapsedSeconds ~/ 60;
    final secs = elapsedSeconds % 60;
    await _speak(
        'Activity complete. '
        'Distance: ${km.toStringAsFixed(2)} kilometres. '
        'Duration: $mins minutes and $secs seconds.');
  }

  /// Should be called on every new track point. Fires a milestone cue when
  /// the user crosses the next full km or mile boundary.
  Future<void> checkMilestone({
    required double distanceMeters,
    required int avgPaceSecondsPerKm,
    required DistanceUnit unit,
    required int calories,
    required WorkoutPrefs prefs,
  }) async {
    final intervalKm = unit == DistanceUnit.km ? 1.0 : 1.60934; // 1 mi in km
    final threshold =
        (_lastAnnouncedDistanceKm ~/ intervalKm + 1) * intervalKm;
    final distanceKm = distanceMeters / 1000.0;

    if (distanceKm >= threshold) {
      _lastAnnouncedDistanceKm = distanceKm;

      final count = (distanceKm / intervalKm).floor();
      final unitLabel = unit == DistanceUnit.km ? 'kilometre' : 'mile';
      final pluralLabel = count == 1 ? unitLabel : '${unitLabel}s';

      String paceStr = '';
      if (avgPaceSecondsPerKm > 0) {
        final pace = unit == DistanceUnit.miles
            ? (avgPaceSecondsPerKm * 1.60934).round()
            : avgPaceSecondsPerKm;
        final pm = pace ~/ 60;
        final ps = pace % 60;
        final unitPaceLabel = unit == DistanceUnit.km ? 'kilometre' : 'mile';
        paceStr =
            '. Average pace: $pm minutes and $ps seconds per $unitPaceLabel';
      }

      String targetStr = '';
      if (prefs.targetType == WorkoutTargetType.distance) {
        final targetKm = prefs.targetValue;
        final remainingKm = targetKm - distanceKm;
        if (remainingKm > 0) {
          if (unit == DistanceUnit.miles) {
            final remainingMi = remainingKm / 1.60934;
            targetStr = '. ${remainingMi.toStringAsFixed(1)} miles remaining to target';
          } else {
            targetStr = '. ${remainingKm.toStringAsFixed(1)} kilometres remaining to target';
          }
        }
      } else if (prefs.targetType == WorkoutTargetType.calories) {
        final remainingCals = prefs.targetValue - calories;
        if (remainingCals > 0) {
          targetStr = '. ${remainingCals.toStringAsFixed(0)} calories remaining to target';
        }
      }

      await _speak('$count $pluralLabel completed$paceStr$targetStr.');
    }
  }

  /// Checks distance or calorie progress against target values and announces achievement.
  Future<void> checkTargetStatus({
    required double distanceMeters,
    required int calories,
    required WorkoutPrefs prefs,
    required DistanceUnit unit,
  }) async {
    if (prefs.targetType == WorkoutTargetType.none) return;

    double progressPct = 0.0;
    if (prefs.targetType == WorkoutTargetType.distance) {
      final distanceKm = distanceMeters / 1000.0;
      progressPct = prefs.targetValue > 0 ? distanceKm / prefs.targetValue : 0.0;
    } else if (prefs.targetType == WorkoutTargetType.calories) {
      progressPct = prefs.targetValue > 0 ? calories / prefs.targetValue : 0.0;
    }

    // If progress is below target, reset the flag so they can achieve it again if target is changed
    if (prefs.targetType == WorkoutTargetType.distance) {
      final distanceKm = distanceMeters / 1000.0;
      if (distanceKm < prefs.targetValue) {
        _targetAchievedAnnounced = false;
      }
    } else if (prefs.targetType == WorkoutTargetType.calories) {
      if (calories < prefs.targetValue) {
        _targetAchievedAnnounced = false;
      }
    }

    if (progressPct < 0.50) {
      _announced50 = false;
      _announced75 = false;
      _announced90 = false;
    } else if (progressPct < 0.75) {
      _announced75 = false;
      _announced90 = false;
    } else if (progressPct < 0.90) {
      _announced90 = false;
    }

    // Check and speak milestone achievements (50%, 75%, 90%)
    if (progressPct >= 0.50 && progressPct < 0.75 && !_announced50) {
      _announced50 = true;
      await _speak('Fifty percent of activity target completed.');
    } else if (progressPct >= 0.75 && progressPct < 0.90 && !_announced75) {
      _announced50 = true;
      _announced75 = true;
      await _speak('Seventy-five percent of activity target completed.');
    } else if (progressPct >= 0.90 && progressPct < 1.00 && !_announced90) {
      _announced50 = true;
      _announced75 = true;
      _announced90 = true;
      await _speak('Ninety percent of activity target completed.');
    }

    if (_targetAchievedAnnounced) return;

    if (prefs.targetType == WorkoutTargetType.distance) {
      final distanceKm = distanceMeters / 1000.0;
      final targetKm = prefs.targetValue;
      if (distanceKm >= targetKm) {
        _targetAchievedAnnounced = true;
        _announced50 = true;
        _announced75 = true;
        _announced90 = true;
        final displayVal = unit == DistanceUnit.miles
            ? targetKm / 1.60934
            : targetKm;
        final unitLabel = unit == DistanceUnit.km ? 'kilometre' : 'mile';
        final pluralLabel = displayVal == 1.0 ? unitLabel : '${unitLabel}s';
        await announceTargetReached('${displayVal.toStringAsFixed(1)} $pluralLabel');
      }
    } else if (prefs.targetType == WorkoutTargetType.calories) {
      final targetCals = prefs.targetValue;
      if (calories >= targetCals) {
        _targetAchievedAnnounced = true;
        _announced50 = true;
        _announced75 = true;
        _announced90 = true;
        await announceTargetReached('${targetCals.toStringAsFixed(0)} calories');
      }
    }
  }

  Future<void> announceTargetReached(String targetLabel) async {
    await _speak('Target reached! $targetLabel. Great job!');
  }

  int _lastStorySegmentIndex = 0;
  DateTime? _lastStoryTime;

  void resetStory() {
    _lastStorySegmentIndex = 0;
    _lastStoryTime = null;
  }

  /// Announce a motivational story segment every 90 seconds if active
  Future<void> checkStoryNarrative(String trackName) async {
    if (trackName == 'None' || trackName.startsWith('Music:')) return;
    
    final now = DateTime.now();
    if (_lastStoryTime != null && now.difference(_lastStoryTime!).inSeconds < 90) {
      return; 
    }
    
    _lastStoryTime = now;
    
    List<String> segments = [];
    if (trackName.contains('Rise & Grind')) {
      segments = [
        "Welcome to Rise and Grind. The morning air is crisp, but you are warmer. Your muscles are warming up. Every stride is a decision to be better.",
        "Remember why you started this. The cold road ahead represents opportunity. Let go of the fatigue. Focus on your breathing.",
        "Your pace is steady. Your posture is upright. You are matching the rhythm of your heart. Keep your eyes forward, victory is in your steps.",
        "Halfway through the morning breeze. The world is waking up, but you are already ahead. Do not stop now, push the tempo.",
        "You are in the final stretch. Dig deep. The ground under your feet is yours to conquer. Finish strong!"
      ];
    } else if (trackName.contains('The Ascent')) {
      segments = [
        "Starting the ascent. The mountain is tall, but your determination is taller. Take deep breaths. Keep a steady cadence.",
        "The slope is getting steeper. This is where champions are forged. Feel the burn in your calves, embrace it. You are climbing.",
        "Look how far you've come from the valley. Keep moving forward. Don't look back, focus on the next step.",
        "Near the peak. The wind is howling, but your spirit is solid. Push through this threshold. Just a little more.",
        "You've reached the summit! Feel the wind, look at the horizon. You conquered the ascent today. Amazing job."
      ];
    }
    
    if (segments.isNotEmpty) {
      final index = _lastStorySegmentIndex % segments.length;
      _lastStorySegmentIndex++;
      await _speak(segments[index]);
    }
  }

  Future<void> dispose() async {
    await _tts.stop();
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }
}
