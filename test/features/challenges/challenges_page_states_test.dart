import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/challenges/data/challenges_repository.dart';
import 'package:vital_up/features/challenges/presentation/challenges_cubit.dart';
import 'package:vital_up/features/challenges/presentation/challenges_page.dart';

import '../../helpers/pump_app.dart';

/// Answers each `getChallenges` with the next queued result.
class _FakeRepo implements ChallengesRepository {
  final results = <Future<List<Challenge>> Function()>[];
  int calls = 0;

  @override
  Future<List<Challenge>> getChallenges() {
    calls++;
    return results.removeAt(0)();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Challenge _challenge(
  String id, {
  ParticipantStatus status = ParticipantStatus.joined,
  int endsInDays = 5,
}) {
  final now = DateTime.now();
  return Challenge(
    id: id,
    metric: ChallengeMetric.workouts,
    startsAt: now.subtract(const Duration(days: 2)),
    endsAt: now.add(Duration(days: endsInDays)),
    creatorUsername: 'a_very_long_username_$id',
    myStatus: status,
    participants: 12,
    myScore: 1234,
    myRank: 11,
  );
}

void main() {
  late _FakeRepo repo;

  setUp(() => repo = _FakeRepo());

  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    final cubit = ChallengesCubit(repo);
    addTearDown(cubit.close);
    await pumpPage(
      tester,
      BlocProvider.value(value: cubit..load(), child: const ChallengesPage()),
      textScale: textScale,
    );
  }

  testWidgets('shows the loader until challenges arrive', (tester) async {
    final pending = Completer<List<Challenge>>();
    repo.results.add(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(VitalUpLoader), findsOneWidget);
    expect(find.byType(LoadErrorView), findsNothing);

    pending.complete([_challenge('a')]);
    await settle(tester);
    expect(find.byType(VitalUpLoader), findsNothing);
    expect(find.text('ACTIVE (1)'), findsOneWidget);
  });

  testWidgets('a failed load shows the error, and retry loads', (tester) async {
    repo.results
      ..add(() async => throw Exception('offline'))
      ..add(() async => [_challenge('a')]);
    await pump(tester);
    await settle(tester);

    expect(find.text(kLoadErrorMessage), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await settle(tester);

    expect(repo.calls, 2);
    expect(find.byType(LoadErrorView), findsNothing);
    expect(find.text('ACTIVE (1)'), findsOneWidget);
  });

  testWidgets('no challenges shows the calm explainer', (tester) async {
    repo.results.add(() async => const []);
    await pump(tester);
    await settle(tester);

    expect(
      find.textContaining('Challenge friends to the most'),
      findsOneWidget,
    );
    expect(find.text('New challenge'), findsOneWidget);
  });

  testWidgets('groups invites, running and finished challenges', (
    tester,
  ) async {
    repo.results.add(
      () async => [
        _challenge('invite', status: ParticipantStatus.invited),
        _challenge('running'),
        _challenge('done', endsInDays: -1),
      ],
    );
    await pump(tester);
    await settle(tester);

    expect(find.text('INVITES (1)'), findsOneWidget);
    expect(find.text('ACTIVE (1)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('HISTORY (1)'), 200);
    expect(find.text('HISTORY (1)'), findsOneWidget);
  });

  testWidgets('fits a small phone at the largest text size', (tester) async {
    repo.results.add(
      () async => [
        _challenge('invite', status: ParticipantStatus.invited),
        _challenge('running'),
      ],
    );
    await pump(tester, textScale: kMaxTextScale);
    await settle(tester);

    expect(shownTextScale(tester, find.byType(ChallengesPage)), kMaxTextScale);
    expect(takeAllExceptions(tester), isEmpty);
    // Every label, figure and button shows whole.
    expect(truncatedTexts(tester), isEmpty);
    expect(find.text('INVITES (1)'), findsOneWidget);
  });
}
