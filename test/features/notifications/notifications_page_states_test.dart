import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/notifications/domain/entities/app_notification.dart';
import 'package:vital_up/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:vital_up/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:vital_up/features/notifications/presentation/pages/notifications_page.dart';

import '../../helpers/pump_app.dart';

class _FakeRepo implements NotificationsRepository {
  final results = <Future<List<AppNotification>> Function()>[];
  int calls = 0;

  @override
  Future<List<AppNotification>> getNotifications({
    int limit = 50,
    bool refresh = false,
  }) {
    calls++;
    return results.removeAt(0)();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _now = DateTime.now();

final _items = [
  AppNotification(
    id: 1,
    type: NotificationType.badge,
    title: 'You earned the Week Warrior badge for a seven day streak',
    body: 'Keep going. Each badge adds bonus points to your total.',
    createdAt: _now.subtract(const Duration(hours: 2)),
  ),
  AppNotification(
    id: 2,
    type: NotificationType.announcement,
    title: 'New in VitalUp',
    body: 'Weekly summaries now arrive on Sunday evening.',
    createdAt: _now.subtract(const Duration(days: 3)),
    readAt: _now.subtract(const Duration(days: 2)),
  ),
];

void main() {
  late _FakeRepo repo;

  setUp(() => repo = _FakeRepo());

  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    final cubit = NotificationsCubit(repo);
    addTearDown(cubit.close);
    await pumpPage(
      tester,
      BlocProvider.value(
        value: cubit..load(),
        child: const NotificationsPage(),
      ),
      textScale: textScale,
    );
  }

  testWidgets('shows the loader until the inbox arrives', (tester) async {
    final pending = Completer<List<AppNotification>>();
    repo.results.add(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(VitalUpLoader), findsOneWidget);

    pending.complete(_items);
    await settle(tester);
    expect(find.byType(VitalUpLoader), findsNothing);
    expect(find.text('New in VitalUp'), findsOneWidget);
  });

  testWidgets('a failed load shows the error, and retry loads', (tester) async {
    repo.results
      ..add(() async => throw Exception('offline'))
      ..add(() async => _items);
    await pump(tester);
    await settle(tester);

    expect(find.text(kLoadErrorMessage), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await settle(tester);

    expect(repo.calls, 2);
    expect(find.byType(LoadErrorView), findsNothing);
    expect(find.text('New in VitalUp'), findsOneWidget);
    expect(find.text('1 unread'), findsOneWidget);
  });

  testWidgets('an empty inbox says all caught up', (tester) async {
    repo.results.add(() async => const []);
    await pump(tester);
    await settle(tester);

    expect(find.textContaining("You're all caught up"), findsOneWidget);
    expect(find.byType(LoadErrorView), findsNothing);
  });

  testWidgets('fits a small phone at the largest text size', (tester) async {
    repo.results.add(() async => _items);
    await pump(tester, textScale: kMaxTextScale);
    await settle(tester);

    expect(
      shownTextScale(tester, find.byType(NotificationsPage)),
      kMaxTextScale,
    );
    expect(takeAllExceptions(tester), isEmpty);
    // Every label, figure and button shows whole.
    expect(
      truncatedTexts(
        tester,
        previews: {'You earned the Week Warrior badge for a seven day streak'},
      ),
      isEmpty,
    );
    expect(find.text('1 unread'), findsOneWidget);
  });
}
