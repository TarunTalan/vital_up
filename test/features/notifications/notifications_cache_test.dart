import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/features/community/domain/repositories/community_repository.dart';
import 'package:vital_up/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:vital_up/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:vital_up/features/notifications/presentation/cubit/notifications_cubit.dart';

Map<String, dynamic> _row(int id, {String? readAt, String type = 'badge'}) => {
  'id': id,
  'type': type,
  'title': 'Notification $id',
  'body': null,
  'actor_id': type == 'friend_request' ? 'u-$id' : null,
  'data': type == 'friend_request'
      ? {'username': 'sam', 'status': 'pending'}
      : <String, dynamic>{},
  'created_at': '2026-10-0${id}T10:00:00+00:00',
  'read_at': readAt,
};

class _FakeRemote implements NotificationsRemoteDataSource {
  int fetches = 0;
  final readCalls = <List<int>?>[];
  final deleted = <int>[];
  final feed = StreamController<Map<String, dynamic>>.broadcast();

  @override
  String? get userId => 'me';

  @override
  Future<List<Map<String, dynamic>>> fetch({required int limit}) async {
    fetches++;
    return [_row(2), _row(1, type: 'friend_request')];
  }

  @override
  Future<bool> markRead(List<int>? ids) async {
    readCalls.add(ids);
    return false;
  }

  @override
  Future<bool> delete(int id) async {
    deleted.add(id);
    return false;
  }

  @override
  Stream<Map<String, dynamic>> changes() => feed.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCommunity implements CommunityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  late Directory dir;
  late _FakeRemote remote;
  late NotificationsRepositoryImpl repo;
  late NotificationsCubit cubit;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('notifications_cache');
    remote = _FakeRemote();
    repo = NotificationsRepositoryImpl(
      remote,
      _FakeCommunity(),
      CacheStore(ConnectivityService(), directory: dir),
    );
    cubit = NotificationsCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
    dir.deleteSync(recursive: true);
  });

  test('a realtime insert is prepended without refetching', () async {
    await cubit.load();
    cubit.watch();
    remote.feed.add(_row(3));
    await pumpEventQueue();
    // Let the cache write land on disk.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(cubit.state.items!.map((n) => n.id), [3, 2, 1]);
    expect(remote.fetches, 1);

    // The cached inbox has it too.
    final cached = await repo.getNotifications();
    expect(cached.first.id, 3);
    expect(remote.fetches, 1);
  });

  test('a realtime update replaces the row in place', () async {
    await cubit.load();
    cubit.watch();
    remote.feed.add(_row(2, readAt: '2026-10-02T11:00:00+00:00'));
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(cubit.state.items!.map((n) => n.id), [2, 1]);
    expect(cubit.state.items!.first.isRead, isTrue);
  });

  test('mark read and delete apply locally and to the cache', () async {
    await cubit.load();
    await cubit.markRead(cubit.state.items!.first);
    await cubit.remove(cubit.state.items!.last);
    expect(cubit.state.items!.map((n) => n.id), [2]);
    expect(cubit.state.unreadCount, 0);
    expect(remote.readCalls, [
      [2],
    ]);
    expect(remote.deleted, [1]);

    final cached = await repo.getNotifications();
    expect(cached.map((n) => n.id), [2]);
    expect(cached.single.isRead, isTrue);
    expect(remote.fetches, 1);
  });

  test('accepting a request updates it locally', () async {
    await cubit.load();
    final request = cubit.state.items!.last;
    expect(request.isPendingRequest, isTrue);
    await cubit.respond(request, accept: true);
    final updated = cubit.state.items!.last;
    expect(updated.isPendingRequest, isFalse);
    expect(updated.isRead, isTrue);
    expect(remote.fetches, 1);
  });

  test('declining a request removes it', () async {
    await cubit.load();
    await cubit.respond(cubit.state.items!.last, accept: false);
    expect(cubit.state.items!.map((n) => n.id), [2]);
    expect((await repo.getNotifications()).map((n) => n.id), [2]);
  });
}
