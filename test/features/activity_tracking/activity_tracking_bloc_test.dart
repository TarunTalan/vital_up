import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/features/activity_tracking/data/services/workout_recovery_service.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_type.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/track_point.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/activity_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/location_tracking_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/step_counter_repository.dart';
import 'package:vital_up/features/activity_tracking/domain/services/workout_checkpoint.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_location_stream.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/get_live_steps_stream.dart';
import 'package:vital_up/features/activity_tracking/domain/usecases/stop_and_save_session.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_bloc.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_event.dart';
import 'package:vital_up/features/activity_tracking/presentation/bloc/activity_tracking_state.dart';
import 'package:vital_up/features/auth/domain/entities/user_entity.dart';
import 'package:vital_up/features/auth/domain/repositories/auth_repository.dart';

class _FakeLocation implements LocationTrackingRepository {
  bool granted = true;
  StreamController<TrackPoint> controller = StreamController<TrackPoint>();
  int subscriptions = 0;

  @override
  Future<bool> ensurePermission() async => granted;

  @override
  Stream<TrackPoint> watchTrackPoints(ActivityType activityType) {
    subscriptions++;
    return controller.stream;
  }
}

class _FakeSteps implements StepCounterRepository {
  final controller = StreamController<int>.broadcast();

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Stream<int> watchSteps() => controller.stream;
}

class _FakeActivityRepo implements ActivityRepository {
  final saved = <ActivitySession>[];

  @override
  Future<void> saveSession(ActivitySession session) async => saved.add(session);
  @override
  Future<List<ActivitySession>> getSessions() async => saved;
  @override
  Future<ActivitySession?> getSessionById(String id) async => null;
  final deleted = <String>[];
  @override
  Future<void> deleteSession(String id) async => deleted.add(id);
  @override
  Future<void> finalizeInterruptedSessions({String? keepOpenId}) async {}
}

class _FakeAuth implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async => const Right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _t0 = DateTime.utc(2026, 10, 1, 7);

TrackPoint _p(int second, double northMeters, {double altitude = 900}) => TrackPoint(
      latitude: 12.9716 + northMeters / 111195.0,
      longitude: 77.5946,
      timestamp: _t0.add(Duration(seconds: second)),
      accuracy: 5,
      speed: 1.4,
      altitude: altitude,
    );

/// Lets queued bloc events run.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late _FakeLocation location;
  late _FakeSteps steps;
  late _FakeActivityRepo repo;
  late ActivityTrackingBloc bloc;

  setUp(() {
    location = _FakeLocation();
    steps = _FakeSteps();
    repo = _FakeActivityRepo();
    bloc = ActivityTrackingBloc(
      getLiveLocationStream: GetLiveLocationStream(location),
      getLiveStepsStream: GetLiveStepsStream(steps),
      stopAndSaveSession: StopAndSaveSession(repo),
      authRepository: _FakeAuth(),
    );
  });

  tearDown(() => bloc.close());

  test('a double tap on start opens one session and one GPS stream', () async {
    bloc
      ..add(StartTracking())
      ..add(StartTracking());
    await _settle();
    expect(bloc.state, isA<TrackingInProgress>());
    expect(location.subscriptions, 1);
  });

  test('denied location permission returns to idle so the user can leave', () async {
    location.granted = false;
    bloc.add(const SelectActivityType(ActivityType.run));
    await _settle();
    final states = <ActivityTrackingState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(StartTracking());
    await _settle();
    await sub.cancel();

    expect(states.first, isA<TrackingPermissionDenied>());
    expect(bloc.state, isA<TrackingIdle>());
    expect(bloc.state.activityType, ActivityType.run);
  });

  test('distance accrues per segment and excludes movement while paused', () async {
    bloc.add(StartTracking());
    await _settle();

    location.controller
      ..add(_p(0, 0))
      ..add(_p(10, 14));
    await _settle();
    expect((bloc.state as TrackingInProgress).distanceMeters, closeTo(14, 0.1));

    bloc.add(PauseTracking());
    await _settle();
    location.controller.add(_p(60, 200)); // walked away while paused
    await _settle();

    bloc.add(ResumeTracking());
    await _settle();
    location.controller
      ..add(_p(70, 214)) // first fix after resume only re-anchors
      ..add(_p(80, 228));
    await _settle();

    expect((bloc.state as TrackingInProgress).distanceMeters, closeTo(28, 0.1));
  });

  test('an implausible jump after a GPS gap is not added as distance', () async {
    bloc.add(StartTracking());
    await _settle();
    location.controller
      ..add(_p(0, 0))
      ..add(_p(1, 500)); // 500 m in 1 s while walking
    await _settle();
    expect((bloc.state as TrackingInProgress).distanceMeters, 0);
  });

  test('elevation gain ignores small altitude jitter', () async {
    bloc.add(StartTracking());
    await _settle();
    final altitudes = <double>[900, 902, 899, 901, 900, 905, 904, 910];
    for (var i = 0; i < altitudes.length; i++) {
      location.controller.add(_p(i * 5, i * 7.0, altitude: altitudes[i]));
    }
    await _settle();
    // Only the real climb from 900 → 910 counts.
    expect((bloc.state as TrackingInProgress).elevationGainMeters, closeTo(10, 0.01));
  });

  test('steps exclude those taken while paused', () async {
    bloc.add(StartTracking());
    await _settle();
    steps.controller.add(40);
    await _settle();
    bloc.add(PauseTracking());
    await _settle();
    steps.controller.add(70);
    await _settle();
    bloc.add(ResumeTracking());
    await _settle();
    steps.controller.add(80);
    await _settle();
    expect((bloc.state as TrackingInProgress).steps, 50);
  });

  test('stop saves exactly once with an end time, even when tapped twice', () async {
    bloc.add(StartTracking());
    await _settle();
    location.controller
      ..add(_p(0, 0))
      ..add(_p(10, 14));
    await _settle();

    bloc
      ..add(const StopAndSaveTracking())
      ..add(const StopAndSaveTracking());
    await _settle();

    final finals = repo.saved.where((s) => s.endTime != null).toList();
    expect(finals, hasLength(1));
    expect(repo.saved.last.endTime, isNotNull);
    expect(finals.single.points, hasLength(2));
    expect(bloc.state, isA<TrackingCompleted>());
    expect((bloc.state as TrackingCompleted).saved, isTrue);
  });

  test('backgrounding checkpoints the running session without an end time', () async {
    bloc.add(StartTracking());
    await _settle();
    bloc.add(PersistProgress());
    await _settle();
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.endTime, isNull);
  });

  test('re-subscribes when the GPS stream drops', () async {
    bloc.add(StartTracking());
    await _settle();
    final first = location.controller;
    location.controller = StreamController<TrackPoint>();
    await first.close();
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(location.subscriptions, 2);
  });

  test('an accidental start with nothing recorded is discarded, not saved', () async {
    bloc.add(StartTracking());
    await _settle();
    bloc.add(PersistProgress()); // a checkpoint already stored it
    await _settle();
    bloc.add(const StopAndSaveTracking());
    await _settle();

    final state = bloc.state as TrackingCompleted;
    expect(state.discarded, isTrue);
    expect(repo.saved.where((s) => s.endTime != null), isEmpty);
    expect(repo.deleted, [repo.saved.single.id]);
  });

  test('denied permission message is short and plain', () async {
    location.granted = false;
    final states = <ActivityTrackingState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(StartTracking());
    await _settle();
    await sub.cancel();
    final message = (states.first as TrackingPermissionDenied).message;
    expect(message.length, lessThan(60));
    expect(message.contains('!'), isFalse);
  });

  group('resume after the app was killed', () {
    late WorkoutCheckpointStore store;
    late ActivityTrackingBloc tracked;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = WorkoutCheckpointStore(await SharedPreferences.getInstance());
      tracked = ActivityTrackingBloc(
        getLiveLocationStream: GetLiveLocationStream(location),
        getLiveStepsStream: GetLiveStepsStream(steps),
        stopAndSaveSession: StopAndSaveSession(repo),
        authRepository: _FakeAuth(),
        checkpointStore: store,
      );
    });

    tearDown(() => tracked.close());

    ActivitySession interrupted() => ActivitySession(
          id: 'killed',
          activityType: ActivityType.run,
          startTime: _t0.subtract(const Duration(minutes: 30)),
          endTime: null,
          totalDistanceMeters: 2000,
          totalDurationSeconds: 600,
          avgPaceSecondsPerKm: 300,
          calories: 150,
          steps: 1000,
          stepCountReliable: true,
          points: [_p(0, 0), _p(10, 14)],
        );

    WorkoutCheckpoint marker({bool paused = false}) => WorkoutCheckpoint(
          sessionId: 'killed',
          savedAt: DateTime.now(),
          paused: paused,
          elevationGainMeters: 12,
          weightKg: 60,
        );

    test('a checkpoint marks the workout and a finish clears it', () async {
      tracked.add(StartTracking());
      await _settle();
      tracked.add(PersistProgress());
      await _settle();
      final cp = store.read()!;
      expect(cp.sessionId, repo.saved.single.id);
      expect(cp.paused, isFalse);

      tracked.add(const StopAndSaveTracking());
      await _settle();
      expect(store.read(), isNull);
    });

    test('resumes a running workout from its checkpoint', () async {
      tracked.add(RestoreTracking(checkpoint: marker(), session: interrupted()));
      await _settle();

      final s = tracked.state as TrackingInProgress;
      expect(s.elapsed, greaterThanOrEqualTo(const Duration(minutes: 10)));
      expect(s.elapsed, lessThan(const Duration(minutes: 10, seconds: 5)));
      expect(s.distanceMeters, 2000);
      expect(s.steps, 1000);
      expect(s.routePoints, hasLength(2));
      expect(s.elevationGainMeters, 12);
      expect(location.subscriptions, 1);

      // The first fix after the gap only re-anchors the route.
      location.controller
        ..add(_p(900, 400))
        ..add(_p(910, 414));
      await _settle();
      expect((tracked.state as TrackingInProgress).distanceMeters, closeTo(2014, 0.1));

      // A new step stream counts from zero.
      steps.controller.add(30);
      await _settle();
      expect((tracked.state as TrackingInProgress).steps, 1030);

      // It keeps the same session and saves it on finish.
      tracked.add(const StopAndSaveTracking());
      await _settle();
      final done = repo.saved.last;
      expect(done.id, 'killed');
      expect(done.endTime, isNotNull);
      expect(done.totalDurationSeconds, greaterThanOrEqualTo(600));
      expect(store.read(), isNull);
    });

    test('a workout paused when the app died comes back paused', () async {
      tracked.add(RestoreTracking(checkpoint: marker(paused: true), session: interrupted()));
      await _settle();
      expect(tracked.state, isA<TrackingPaused>());
      expect((tracked.state as TrackingPaused).elapsed, const Duration(minutes: 10));

      steps.controller.add(50); // walked while paused
      await _settle();
      tracked.add(ResumeTracking());
      await _settle();
      steps.controller.add(70);
      await _settle();
      expect((tracked.state as TrackingInProgress).steps, 1020);
    });

    test('denied location keeps the checkpoint for another try', () async {
      await store.write(marker());
      location.granted = false;
      tracked.add(RestoreTracking(checkpoint: marker(), session: interrupted()));
      await _settle();
      expect(tracked.state, isA<TrackingIdle>());
      expect(store.read(), isNotNull);
    });
  });
}
