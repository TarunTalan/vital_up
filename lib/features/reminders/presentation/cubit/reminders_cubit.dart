import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';

class RemindersState extends Equatable {
  final bool loading;
  final List<Reminder> reminders;

  /// The global Notifications switch in Settings.
  final bool notificationsEnabled;

  /// The system refused notification permission.
  final bool permissionDenied;

  /// One-off snackbar text; [messageId] changes each time.
  final String? message;
  final int messageId;

  const RemindersState({
    this.loading = true,
    this.reminders = const [],
    this.notificationsEnabled = true,
    this.permissionDenied = false,
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
    String? message,
  }) => RemindersState(
    loading: loading ?? this.loading,
    reminders: reminders ?? this.reminders,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    permissionDenied: permissionDenied ?? this.permissionDenied,
    message: message ?? this.message,
    messageId: message != null ? messageId + 1 : messageId,
  );

  @override
  List<Object?> get props => [
    loading,
    reminders,
    notificationsEnabled,
    permissionDenied,
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
    emit(
      state.copyWith(
        loading: false,
        reminders: _service.load(),
        notificationsEnabled: enabled,
      ),
    );
  }

  Future<void> toggle(Reminder reminder, bool enabled) =>
      _replace(reminder.copyWith(enabled: enabled));

  /// Saves an edited reminder (or adds it, if new).
  Future<void> saveReminder(Reminder reminder) => _replace(reminder);

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
    if (turningOn && state.notificationsEnabled) {
      denied = !await _service.requestPermission();
    }
    final dropped = await _service.save(reminders);
    if (isClosed) return;
    emit(
      state.copyWith(
        permissionDenied: denied,
        message: dropped > 0
            ? 'Too many reminders — $dropped won\'t be delivered. '
                  'Turn some off or space them out.'
            : null,
      ),
    );
  }
}
