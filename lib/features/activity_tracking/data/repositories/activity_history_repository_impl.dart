import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/session_annotation.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';

class ActivityHistoryRepositoryImpl implements ActivityHistoryRepository {
  final ActivityRepository activityRepository;
  final SharedPreferences sharedPreferences;

  static const String _kAnnotationsKey = 'activity_annotations';

  ActivityHistoryRepositoryImpl({
    required this.activityRepository,
    required this.sharedPreferences,
  });

  @override
  Future<List<ActivitySession>> getSessions() {
    return activityRepository.getSessions();
  }

  @override
  Future<SessionAnnotation?> getAnnotation(String sessionId) async {
    final annotations = _getStoredAnnotations();
    return annotations[sessionId];
  }

  @override
  Future<Map<String, SessionAnnotation>> getAllAnnotations() async {
    return _getStoredAnnotations();
  }

  @override
  Future<void> saveAnnotation(SessionAnnotation annotation) async {
    final annotations = _getStoredAnnotations();
    annotations[annotation.sessionId] = annotation;
    await _saveStoredAnnotations(annotations);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await activityRepository.deleteSession(sessionId);
    final annotations = _getStoredAnnotations();
    if (annotations.containsKey(sessionId)) {
      annotations.remove(sessionId);
      await _saveStoredAnnotations(annotations);
    }
  }

  Map<String, SessionAnnotation> _getStoredAnnotations() {
    final jsonString = sharedPreferences.getString(_kAnnotationsKey);
    if (jsonString == null) return {};

    try {
      final Map<String, dynamic> decoded = json.decode(jsonString);
      return decoded.map((key, value) {
        final map = value as Map<String, dynamic>;
        return MapEntry(
          key,
          SessionAnnotation(
            sessionId: map['sessionId'] as String,
            tag: map['tag'] as String?,
            note: map['note'] as String?,
            updatedAt: DateTime.parse(map['updatedAt'] as String),
          ),
        );
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveStoredAnnotations(Map<String, SessionAnnotation> annotations) async {
    final encoded = json.encode(annotations.map((key, value) => MapEntry(
      key,
      {
        'sessionId': value.sessionId,
        'tag': value.tag,
        'note': value.note,
        'updatedAt': value.updatedAt.toIso8601String(),
      },
    )));
    await sharedPreferences.setString(_kAnnotationsKey, encoded);
  }
}
