import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/session_annotation.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_history_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/delete_activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_activity_history.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/save_session_annotation.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_history_bloc.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/activity_history_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_history_card.dart';

import '../../helpers/pump_app.dart';

const _loadError = "Couldn't load your workouts. Try again.";

class _FakeRepo implements ActivityHistoryRepository {
  final results = <Future<List<ActivitySession>> Function()>[];
  int calls = 0;

  @override
  Future<List<ActivitySession>> getSessions({
    DateTime? since,
    bool withRoutes = false,
  }) {
    calls++;
    return results.removeAt(0)();
  }

  @override
  Future<Map<String, SessionAnnotation>> getAllAnnotations() async => {
    'a': SessionAnnotation(
      sessionId: 'a',
      tag: 'Morning run by the lake with friends',
      note: 'Felt strong',
      updatedAt: DateTime(2026, 10, 1),
    ),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ActivitySession _session(
  String id,
  ActivityType type,
  int daysAgo, {
  double meters = 21097.5,
}) {
  final start = DateTime.now().subtract(Duration(days: daysAgo, hours: 1));
  return ActivitySession(
    id: id,
    activityType: type,
    startTime: start,
    endTime: start.add(const Duration(hours: 2, minutes: 14)),
    totalDistanceMeters: meters,
    totalDurationSeconds: 8040,
    avgPaceSecondsPerKm: 381,
    calories: 1480,
    steps: 23950,
    stepCountReliable: true,
    points: const [],
  );
}

final _sessions = [
  _session('a', ActivityType.run, 0),
  _session('b', ActivityType.cycle, 2),
  _session('c', ActivityType.trekking, 9),
];

void main() {
  late _FakeRepo repo;

  setUp(() {
    repo = _FakeRepo();
    sl.registerFactory<ActivityHistoryBloc>(
      () => ActivityHistoryBloc(
        getActivityHistory: GetActivityHistory(repo),
        saveSessionAnnotation: SaveSessionAnnotation(repo),
        deleteActivitySession: DeleteActivitySession(repo),
      ),
    );
  });

  tearDown(() => sl.unregister<ActivityHistoryBloc>());

  testWidgets('shows the loader until workouts arrive', (tester) async {
    final pending = Completer<List<ActivitySession>>();
    repo.results.add(() => pending.future);
    await pumpPage(tester, const ActivityHistoryPage());
    await tester.pump();

    expect(find.byType(VitalUpLoader), findsOneWidget);
    pending.complete(_sessions);
    await settle(tester);
    expect(find.byType(VitalUpLoader), findsNothing);
    expect(find.byType(ActivityHistoryCard), findsNWidgets(3));
  });

  testWidgets('a failed load shows the error, and retry loads', (tester) async {
    repo.results
      ..add(() async => throw Exception('disk'))
      ..add(() async => _sessions);
    await pumpPage(tester, const ActivityHistoryPage());
    await settle(tester);

    expect(find.text(_loadError), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await settle(tester);

    expect(repo.calls, 2);
    expect(find.text(_loadError), findsNothing);
    expect(find.byType(ActivityHistoryCard), findsWidgets);
  });

  testWidgets(
    'no workouts yet invites a first one instead of blaming a filter',
    (tester) async {
      repo.results.add(() async => const []);
      await pumpPage(tester, const ActivityHistoryPage());
      await settle(tester);

      expect(find.text('No activities match'), findsNothing);
      expect(find.text('No activities yet'), findsOneWidget);
    },
  );

  testWidgets('a filter with no matches says so', (tester) async {
    repo.results.add(() async => [_sessions.first]);
    await pumpPage(tester, const ActivityHistoryPage());
    await settle(tester);

    await tester.tap(find.byTooltip('Search'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'zzz');
    await settle(tester);
    expect(find.text('No activities match'), findsOneWidget);
  });

  testWidgets('Outdoor and Workouts split GPS sessions from gym ones', (
    tester,
  ) async {
    repo.results.add(
      () async => [
        ..._sessions,
        _session('g', ActivityType.strength, 1, meters: 0),
      ],
    );
    await pumpPage(tester, const ActivityHistoryPage());
    await settle(tester);

    final cards = find.byType(ActivityHistoryCard);
    Finder card(String label) =>
        find.descendant(of: cards, matching: find.text(label));

    expect(cards, findsNWidgets(4));
    expect(card('Strength'), findsOneWidget);

    await tester.tap(find.text('Workouts'));
    await settle(tester);
    expect(cards, findsOneWidget);
    expect(card('Strength'), findsOneWidget);
    // No distance on a gym session.
    expect(
      find.descendant(of: cards, matching: find.textContaining(' km')),
      findsNothing,
    );

    await tester.tap(find.text('Outdoor'));
    await settle(tester);
    expect(cards, findsNWidgets(3));
    expect(card('Strength'), findsNothing);

    await tester.tap(find.text('All'));
    await settle(tester);
    expect(cards, findsNWidgets(4));
  });

  testWidgets('fits a small phone at the largest text size', (tester) async {
    repo.results.add(() async => _sessions);
    await pumpPage(
      tester,
      const ActivityHistoryPage(),
      textScale: kMaxTextScale,
    );
    await settle(tester);

    expect(
      shownTextScale(tester, find.byType(ActivityHistoryPage)),
      kMaxTextScale,
    );
    expect(takeAllExceptions(tester), isEmpty);
    // Every label, figure and button shows whole.
    expect(
      truncatedTexts(
        tester,
        previews: {'Morning run by the lake with friends'},
      ),
      isEmpty,
    );
    expect(find.byType(ActivityHistoryCard), findsWidgets);
  });
}
