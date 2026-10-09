import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/domain/reminder_rules.dart';

class RemindersState extends Equatable {
  final bool loading;
  final List<Reminder> reminders;

  /// The global Notifications switch in Settings.
  final bool notificationsEnabled;

  /// The system refused notification permission.
  final bool permissionDenied;

  /// Skip the rest of today's reminders once a habit is logged.
  final bool smartSkip;

  /// One-off snackbar text; [messageId] changes each time.
  final String? message;
  final int messageId;

  const RemindersState({
    this.loading = true,
    this.reminders = const [],
    this.notificationsEnabled = true,
    this.permissionDenied = false,
    this.smartSkip = true,
    this.message,
    this.messageId = 0,
  });

  List<Reminder> get presets => [
    for (final r in reminders)
      if (r.isPreset) r,
  ];

  List<Reminder> get custom => [
    for (final r in reminders)
      if (!r.isPreset) r,
  ];

  RemindersState copyWith({
    bool? loading,
    List<Reminder>? reminders,
    bool? notificationsEnabled,
    bool? permissionDenied,
    bool? smartSkip,
    String? message,
  }) => RemindersState(
    loading: loading ?? this.loading,
    reminders: reminders ?? this.reminders,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    smartSkip: smartSkip ?? this.smartSkip,
    message: message ?? this.message,
    messageId: message != null ? messageId + 1 : messageId,
  );

  @override
  List<Object?> get props => [
    loading,
    reminders,
    notificationsEnabled,
    permissionDenied,
    smartSkip,
    message,
    messageId,
  ];
}

class RemindersCubit extends Cubit<RemindersState> {
  final RemindersService _service;
  final String Function() _newId;

  RemindersCubit(this._service, {String Function()? newId})
    : _newId = newId ?? (() => const Uuid().v4()),
      super(const RemindersState());

  Future<void> load() async {
    final enabled = await _service.notificationsEnabled();
    final reminders = _service.load();
    // Show the "blocked" banner when permission was revoked in system
    // settings while reminders are on (unknown counts as allowed).
    var denied = false;
    if (enabled && reminders.any((r) => r.enabled)) {
      denied = await _service.permissionGranted() == false;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        loading: false,
        reminders: reminders,
        notificationsEnabled: enabled,
        permissionDenied: denied,
        smartSkip: _service.smartSkip(),
      ),
    );
  }

  Future<void> setSmartSkip(bool value) async {
    final previous = state.smartSkip;
    emit(state.copyWith(smartSkip: value));
    try {
      await _service.setSmartSkip(value);
    } catch (e) {
      debugPrint('Smart skip not saved: $e');
      if (isClosed) return;
      emit(state.copyWith(smartSkip: previous, message: _saveFailed));
    }
  }

  static const _saveFailed = "Couldn't update reminders. Try again.";

  Future<void> toggle(Reminder reminder, bool enabled) =>
      _replace(reminder.copyWith(enabled: enabled));

  /// Saves an edited reminder (or adds it, if new); text is cleaned first.
  Future<void> saveReminder(Reminder reminder) =>
      _replace(ReminderRules.sanitize(reminder));

  /// A new, unsaved custom reminder for the editor.
  Reminder draftCustom() => Reminder(
    id: 'custom_${_newId()}',
    kind: ReminderKind.custom,
    title: '',
    times: const [ReminderTime(9, 0)],
    enabled: true,
  );

  Future<void> delete(Reminder reminder) => _apply([
    for (final r in state.reminders)
      if (r.id != reminder.id) r,
  ]);

  Future<void> _replace(Reminder reminder) {
    final exists = state.reminders.any((r) => r.id == reminder.id);
    return _apply(
      exists
          ? [
              for (final r in state.reminders)
                r.id == reminder.id ? reminder : r,
            ]
          : [...state.reminders, reminder],
      turningOn: reminder.enabled,
    );
  }

  Future<void> _apply(
    List<Reminder> reminders, {
    bool turningOn = false,
  }) async {
    emit(state.copyWith(reminders: reminders));
    var denied = state.permissionDenied;
    final int dropped;
    try {
      if (turningOn && state.notificationsEnabled) {
        denied = !await _service.requestPermission();
      }
      dropped = await _service.save(reminders);
    } catch (e) {
      debugPrint('Saving reminders failed: $e');
      if (isClosed) return;
      // Show what is actually stored rather than the unsaved change.
      emit(state.copyWith(reminders: _service.load(), message: _saveFailed));
      return;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        permissionDenied: denied,
        message: dropped > 0
            ? "Too many reminders: $dropped won't ring. Turn some off."
            : null,
      ),
    );
  }
}
