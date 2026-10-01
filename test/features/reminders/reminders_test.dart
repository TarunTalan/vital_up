import 'package:dartz/dartz.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/reminders/data/reminder_scheduler.dart';
import 'package:vital_up/features/reminders/data/reminders_local_datasource.dart';
import 'package:vital_up/features/reminders/data/reminders_service.dart';
import 'package:vital_up/features/reminders/domain/entities/reminder.dart';
import 'package:vital_up/features/reminders/domain/reminder_presets.dart';
import 'package:vital_up/features/reminders/domain/reminder_schedule.dart';
import 'package:vital_up/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:vital_up/features/reminders/presentation/widgets/reminder_style.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';

class _FakeScheduler extends ReminderScheduler {
  _FakeScheduler() : super(FlutterLocalNotificationsPlugin());

  final cancelled = <int>[];
  ReminderSchedulePlan? lastPlan;
  bool grant = true;
  int permissionRequests = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return grant;
  }

  @override
  Future<List<int>> schedule(ReminderSchedulePlan plan) async {
    lastPlan = plan;
    return [for (final e in plan.entries) e.id];
  }

  @override
  Future<void> cancel(Iterable<int> ids) async => cancelled.addAll(ids);
}

class _FakeSettings implements SettingsRepository {
  bool notifications = true;

  @override
  Future<Either<Failure, SettingsEntity>> getSettings() async => Right(
    SettingsEntity(
      themeMode: 'system',
      notificationsEnabled: notifications,
      healthSyncEnabled: false,
      weightUnit: 'kg',
      heightUnit: 'cm',
    ),
  );

  @override
  Future<Either<Failure, void>> saveSettings(SettingsEntity settings) async =>
      const Right(null);
}

Reminder _custom({
  String id = 'c1',
  List<ReminderTime> times = const [ReminderTime(9, 0)],
  Set<int> weekdays = Reminder.allWeekdays,
  bool enabled = true,
}) => Reminder(
  id: id,
  kind: ReminderKind.custom,
  title: 'Vitamins',
  times: times,
  weekdays: weekdays,
  enabled: enabled,
);

void main() {
  group('Reminder', () {
    test('interval reminders fire across the window, ends included', () {
      const r = Reminder(
        id: 'w',
        kind: ReminderKind.water,
        title: 'Water',
        intervalMinutes: 120,
        windowStart: ReminderTime(9, 0),
        windowEnd: ReminderTime(21, 0),
      );
      expect(r.firingTimes.map((t) => t.label), [
        '09:00',
        '11:00',
        '13:00',
        '15:00',
        '17:00',
        '19:00',
        '21:00',
      ]);
    });

    test('fixed times are sorted and de-duplicated', () {
      final r = _custom(
        times: const [
          ReminderTime(18, 0),
          ReminderTime(7, 5),
          ReminderTime(18, 0),
        ],
      );
      expect(r.firingTimes.map((t) => t.label), ['07:05', '18:00']);
    });

    test('JSON round-trip keeps every field', () {
      final r = _custom(weekdays: {1, 3, 5}).copyWith(route: () => 'food-scan');
      expect(Reminder.fromJson(r.toJson()), r);
      final water = reminderPresets.firstWhere((p) => p.id == 'preset_water');
      expect(Reminder.fromJson(water.toJson()), water);
    });

    test('summary text', () {
      expect(reminderSummary(_custom()), 'Daily · 09:00');
      expect(
        reminderSummary(_custom(weekdays: {1, 2, 3, 4, 5})),
        'Weekdays · 09:00',
      );
      expect(reminderSummary(_custom(weekdays: {1, 3})), 'Mon, Wed · 09:00');
      expect(
        reminderSummary(reminderPresets.firstWhere((p) => p.isInterval)),
        'Every 2 h · 09:00–21:00',
      );
    });
  });

  group('mergeWithPresets', () {
    test('keeps saved presets, adds missing ones, keeps custom last', () {
      final savedBreakfast = reminderPresets
          .firstWhere((p) => p.id == 'preset_breakfast')
          .copyWith(enabled: true, times: const [ReminderTime(7, 0)]);
      final merged = mergeWithPresets([_custom(), savedBreakfast]);
      expect(merged.length, reminderPresets.length + 1);
      expect(
        merged.firstWhere((r) => r.id == 'preset_breakfast'),
        savedBreakfast,
      );
      expect(merged.last.id, 'c1');
    });
  });

  group('planReminders', () {
    test('only enabled reminders; daily = one entry per time', () {
      final plan = planReminders([
        _custom(times: const [ReminderTime(8, 0), ReminderTime(20, 0)]),
        _custom(id: 'off', enabled: false),
      ]);
      expect(plan.entries.length, 2);
      expect(plan.entries.every((e) => e.weekday == null), isTrue);
    });

    test('some weekdays = one entry per day per time', () {
      final plan = planReminders([
        _custom(weekdays: {1, 3, 5}),
      ]);
      expect(plan.entries.map((e) => e.weekday), [1, 3, 5]);
    });

    test('ids are stable, unique and in the reminder range', () {
      final reminders = [
        for (var i = 0; i < 5; i++) _custom(id: 'c$i', weekdays: {1, 2, 6}),
      ];
      final a = planReminders(reminders).entries.map((e) => e.id).toList();
      final b = planReminders(reminders).entries.map((e) => e.id).toList();
      expect(a, b);
      expect(a.toSet().length, a.length);
      expect(a.every((id) => id >= 1000000000 && id <= 1999999999), isTrue);
    });

    test('caps the number of scheduled notifications', () {
      final plan = planReminders([
        for (var i = 0; i < 20; i++) _custom(id: 'c$i', weekdays: {1, 2, 3, 4}),
      ]);
      expect(plan.entries.length, maxScheduledReminders);
      expect(plan.dropped, 80 - maxScheduledReminders);
    });
  });

  group('RemindersService', () {
    late _FakeScheduler scheduler;
    late _FakeSettings settings;
    late RemindersLocalDataSource local;
    late RemindersService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      local = RemindersLocalDataSource(await SharedPreferences.getInstance());
      scheduler = _FakeScheduler();
      settings = _FakeSettings();
      service = RemindersService(local, scheduler, settings);
    });

    test(
      'save persists, cancels the old schedule and schedules anew',
      () async {
        await service.save([_custom()]);
        final firstIds = local.scheduledIds();
        expect(firstIds, hasLength(1));
        expect(service.load().where((r) => !r.isPreset), [_custom()]);

        await service.save([
          _custom(times: const [ReminderTime(10, 0)]),
        ]);
        expect(scheduler.cancelled, firstIds);
      },
    );

    test('nothing is scheduled while Notifications is off', () async {
      settings.notifications = false;
      await service.save([_custom()]);
      expect(scheduler.lastPlan, isNull);
      expect(local.scheduledIds(), isEmpty);
    });

    test('starter set turns on the starter presets only', () async {
      await service.enableStarterSet();
      final on = {
        for (final r in service.load())
          if (r.enabled) r.id,
      };
      expect(on, starterPresetIds);
    });

    test('clear cancels and forgets everything', () async {
      await service.save([_custom()]);
      final ids = local.scheduledIds();
      await service.clear();
      expect(scheduler.cancelled, containsAll(ids));
      expect(service.load().any((r) => !r.isPreset), isFalse);
    });
  });

  group('RemindersCubit', () {
    late _FakeScheduler scheduler;
    late RemindersCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      scheduler = _FakeScheduler();
      final service = RemindersService(
        RemindersLocalDataSource(await SharedPreferences.getInstance()),
        scheduler,
        _FakeSettings(),
      );
      cubit = RemindersCubit(service, newId: () => 'x');
      await cubit.load();
    });

    tearDown(() => cubit.close());

    test('loads the presets, all off', () {
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.presets, hasLength(reminderPresets.length));
      expect(cubit.state.presets.any((r) => r.enabled), isFalse);
    });

    test(
      'turning a reminder on asks for permission and schedules it',
      () async {
        await cubit.toggle(cubit.state.presets.first, true);
        expect(scheduler.permissionRequests, 1);
        expect(scheduler.lastPlan!.entries, hasLength(1));
        expect(cubit.state.permissionDenied, isFalse);
      },
    );

    test('denied permission is surfaced', () async {
      scheduler.grant = false;
      await cubit.toggle(cubit.state.presets.first, true);
      expect(cubit.state.permissionDenied, isTrue);
    });

    test('adds and deletes custom reminders', () async {
      final draft = cubit.draftCustom().copyWith(title: 'Stretch');
      await cubit.saveReminder(draft);
      expect(cubit.state.custom.single.id, 'custom_x');
      await cubit.delete(draft);
      expect(cubit.state.custom, isEmpty);
    });
  });
}
