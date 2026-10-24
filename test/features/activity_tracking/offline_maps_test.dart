import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/activity_tracking/data/services/offline_map_service.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/offline_map_area.dart';
import 'package:vital_up/features/activity_tracking/domain/repositories/map_tile_repository.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/offline_maps_page.dart';

import '../../helpers/pump_app.dart';

/// Tile store in memory. A download completes at once unless [failNext]
/// or [hold] says otherwise.
class _FakeTiles implements MapTileRepository {
  final Map<String, OfflineMapArea> stored = {};
  final List<String> downloads = [];
  final List<String> deleted = [];
  bool failNext = false;
  Completer<void>? hold;

  @override
  Future<List<OfflineMapArea>> areas() async => stored.values.toList();

  @override
  Future<int?> estimateBytes(OfflineMapArea area) async => 1000;

  @override
  Stream<double> download(OfflineMapArea area) async* {
    downloads.add(area.id);
    stored[area.id] = area.copyWith(complete: false, progress: 0.4);
    yield 0.4;
    if (hold case final hold?) await hold.future;
    if (failNext) {
      failNext = false;
      throw Exception('offline');
    }
    stored[area.id] = area.copyWith(
      complete: true,
      progress: 1,
      sizeBytes: 30 * 1024 * 1024,
    );
    yield 1;
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    stored.remove(id);
  }
}

OfflineMapArea _area(
  String id, {
  double lat = 12.97,
  double lng = 77.59,
  double radiusKm = 10,
  bool isAuto = false,
  bool complete = true,
  String name = 'Trail',
}) => OfflineMapArea(
  id: id,
  name: name,
  latitude: lat,
  longitude: lng,
  radiusKm: radiusKm,
  isAuto: isAuto,
  complete: complete,
  progress: complete ? 1 : 0.5,
  sizeBytes: complete ? 40 * 1024 * 1024 : 0,
  savedAt: DateTime(2026, 10, 20),
);

void main() {
  group('OfflineMapArea.covers', () {
    test('inside the square with the margin to spare', () {
      final area = _area('a');
      expect(area.covers(12.97, 77.59), isTrue);
      // ~5.5 km north: 10 - 3 margin = 7 km of room.
      expect(area.covers(13.02, 77.59), isTrue);
      // ~8.9 km north: inside the square but within the margin.
      expect(area.covers(13.05, 77.59), isFalse);
    });

    test('an incomplete area covers nothing', () {
      expect(_area('a', complete: false).covers(12.97, 77.59), isFalse);
    });

    test('across the date line', () {
      final area = _area('a', lat: 0, lng: 179.99);
      expect(area.covers(0, -179.99), isTrue);
    });

    test('longitude shrinks towards the poles', () {
      // At 60° a degree of longitude is ~55 km: 0.1° is ~5.5 km.
      final area = _area('a', lat: 60, lng: 10);
      expect(area.covers(60, 10.1), isTrue);
      expect(area.covers(60, 10.2), isFalse);
    });
  });

  group('OfflineMapRules', () {
    test('frame size from zoom', () {
      // 300 px at zoom 12 on the equator: 300 * 19.1 m / 2.
      final r = OfflineMapRules.radiusForFrame(
        framePx: 300,
        latitude: 0,
        zoom: 12,
      );
      expect(r, closeTo(2.87, 0.01));
      // One zoom level out doubles it.
      expect(
        OfflineMapRules.radiusForFrame(framePx: 300, latitude: 0, zoom: 11),
        closeTo(r * 2, 0.001),
      );
    });

    test('labels', () {
      expect(OfflineMapRules.sideLabel(10), '20 × 20 km');
      expect(OfflineMapRules.sideLabel(1), '2 × 2 km');
      expect(OfflineMapRules.sideLabel(1.27), '2.5 × 2.5 km');
      expect(OfflineMapRules.sizeLabel(38 * 1024 * 1024), '38 MB');
      expect(OfflineMapRules.sizeLabel(850 * 1024), '850 KB');
      expect(OfflineMapRules.sizeLabel(1288490189), '1.2 GB');
    });
  });

  group('OfflineMapService', () {
    late _FakeTiles tiles;
    late StreamController<bool> online;
    late OfflineMapService service;
    ({double latitude, double longitude})? position;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tiles = _FakeTiles();
      online = StreamController<bool>.broadcast();
      position = (latitude: 12.97, longitude: 77.59);
      service = OfflineMapService(
        tiles,
        await SharedPreferences.getInstance(),
        onlineChanges: online.stream,
        locate: () async => position,
        hasMapToken: () => true,
        now: () => DateTime(2026, 10, 22),
      );
    });

    tearDown(() async {
      await service.dispose();
      await online.close();
    });

    test('downloads the area around the user at start', () async {
      await service.prefetchAtStartup();
      await service.idle();
      expect(tiles.downloads, [OfflineMapService.autoAreaId]);
      expect(service.state.value.auto?.complete, isTrue);
    });

    test('no position (location not allowed): nothing downloads', () async {
      position = null;
      await service.prefetchAtStartup();
      await service.idle();
      expect(tiles.downloads, isEmpty);
      expect(service.state.value.loaded, isTrue);
    });

    test('a saved area that covers the spot spares the download', () async {
      tiles.stored['area_1'] = _area('area_1');
      await service.ensureAround(12.97, 77.59);
      await service.idle();
      expect(tiles.downloads, isEmpty);
    });

    test('moved away: the automatic area downloads again', () async {
      tiles.stored[OfflineMapService.autoAreaId] = _area(
        OfflineMapService.autoAreaId,
        isAuto: true,
      );
      await service.ensureAround(28.61, 77.20);
      await service.idle();
      expect(tiles.downloads, [OfflineMapService.autoAreaId]);
      expect(tiles.stored[OfflineMapService.autoAreaId]?.latitude, 28.61);
    });

    test('picked areas download one at a time, in order', () async {
      tiles.hold = Completer<void>();
      await service.refresh();
      expect(
        service.download(
          service.draft(latitude: 1, longitude: 1, radiusKm: 5, name: 'A'),
        ),
        isNull,
      );
      await Future<void>.delayed(Duration.zero);
      final second = OfflineMapArea(
        id: 'area_b',
        name: 'B',
        latitude: 2,
        longitude: 2,
        radiusKm: 5,
      );
      expect(service.download(second), isNull);
      await Future<void>.delayed(Duration.zero);
      final state = service.state.value;
      expect(state.downloadingId, isNot('area_b'));
      expect(state.queuedIds, {'area_b'});
      expect(state.saved.map((a) => a.name), containsAll(['A', 'B']));
      tiles.hold!.complete();
      await service.idle();
      expect(tiles.downloads.length, 2);
      expect(tiles.downloads.last, 'area_b');
      expect(service.state.value.saved.every((a) => a.complete), isTrue);
    });

    test('a download cut off resumes once back online', () async {
      await service.refresh();
      tiles.failNext = true;
      service.download(
        service.draft(latitude: 1, longitude: 1, radiusKm: 5, name: 'Hike'),
      );
      await service.idle();
      final stopped = service.state.value.saved.single;
      expect(stopped.complete, isFalse);
      expect(offlineAreaStatus(stopped, service.state.value), contains('40%'));

      online.add(true);
      await Future<void>.delayed(Duration.zero);
      await service.idle();
      expect(service.state.value.saved.single.complete, isTrue);
    });

    test('a stopped download finishes at the next start', () async {
      tiles.stored['area_1'] = _area('area_1', complete: false);
      position = null;
      await service.prefetchAtStartup();
      await service.idle();
      expect(tiles.downloads, ['area_1']);
      expect(service.state.value.saved.single.complete, isTrue);
    });

    test('keeps at most the limit of picked areas', () async {
      for (var i = 0; i < OfflineMapRules.maxSavedAreas; i++) {
        tiles.stored['area_$i'] = _area('area_$i', name: 'Map area ${i + 1}');
      }
      await service.refresh();
      expect(service.canSaveMore, isFalse);
      expect(
        service.download(service.draft(latitude: 1, longitude: 1, radiusKm: 5)),
        contains('Delete one first'),
      );
      expect(tiles.downloads, isEmpty);
    });

    test('names are cleaned and a blank one gets the next number', () async {
      tiles.stored['area_1'] = _area('area_1', name: 'Map area 1');
      await service.refresh();
      expect(service.suggestedName(), 'Map area 2');
      service.download(
        service.draft(latitude: 1, longitude: 1, radiusKm: 5, name: '  '),
      );
      await service.idle();
      expect(
        service.state.value.saved.map((a) => a.name),
        contains('Map area 2'),
      );
    });

    test('a picked area is clamped to the allowed size', () {
      final big = service.draft(latitude: 1, longitude: 1, radiusKm: 400);
      expect(big.radiusKm, OfflineMapRules.maxRadiusKm);
      final small = service.draft(latitude: 1, longitude: 1, radiusKm: 0.1);
      expect(small.radiusKm, OfflineMapRules.minRadiusKm);
    });

    test('switching the automatic area off deletes it', () async {
      tiles.stored[OfflineMapService.autoAreaId] = _area(
        OfflineMapService.autoAreaId,
        isAuto: true,
      );
      await service.refresh();
      await service.setAutoEnabled(false);
      expect(tiles.deleted, [OfflineMapService.autoAreaId]);
      await service.ensureAround(28.61, 77.20);
      await service.idle();
      expect(tiles.downloads, isEmpty);
    });

    test('sign-out deletes every area, even one downloading', () async {
      tiles.stored['area_1'] = _area('area_1');
      tiles.hold = Completer<void>();
      await service.ensureAround(28.61, 77.20);
      await Future<void>.delayed(Duration.zero);
      await service.clearAll();
      expect(tiles.deleted, contains('area_1'));
      tiles.hold!.complete();
      await service.idle();
      expect(tiles.stored, isEmpty);
      expect(service.state.value.areas, isEmpty);
    });
  });

  group('OfflineMapsPage', () {
    Future<OfflineMapService> serviceWith(_FakeTiles tiles) async {
      SharedPreferences.setMockInitialValues({});
      final service = OfflineMapService(
        tiles,
        await SharedPreferences.getInstance(),
        locate: () async => null,
        hasMapToken: () => true,
      );
      addTearDown(service.dispose);
      return service;
    }

    for (final scale in [1.0, kMaxTextScale]) {
      for (final dark in [false, true]) {
        testWidgets('areas at text $scale${dark ? ' dark' : ''}', (
          tester,
        ) async {
          final tiles = _FakeTiles()
            ..stored[OfflineMapService.autoAreaId] = _area(
              OfflineMapService.autoAreaId,
              isAuto: true,
            )
            ..stored['area_1'] = _area('area_1', name: 'Coorg weekend trail')
            ..stored['area_2'] = _area('area_2', complete: false);
          final service = await serviceWith(tiles);
          await pumpPage(
            tester,
            OfflineMapsPage(service: service),
            textScale: scale,
            theme: dark ? AppTheme.darkTheme : null,
          );
          await tester.runAsync(service.refresh);
          await settle(tester);

          expect(find.text('Map around you'), findsOneWidget);
          expect(find.text('Coorg weekend trail'), findsOneWidget);
          expect(find.text('Resume download'), findsOneWidget);
          expect(find.text('Download a new area'), findsOneWidget);
          expect(takeAllExceptions(tester), isEmpty);
          expect(truncatedTexts(tester), isEmpty);
        });
      }
    }

    testWidgets('empty: explains what to do', (tester) async {
      final service = await serviceWith(_FakeTiles());
      await pumpPage(
        tester,
        OfflineMapsPage(service: service),
        textScale: kMaxTextScale,
      );
      await tester.runAsync(service.refresh);
      await settle(tester);
      expect(
        find.text('Saved when you next open the workout map'),
        findsOneWidget,
      );
      expect(
        find.text('Going somewhere new? Save its map before you go.'),
        findsOneWidget,
      );
      expect(truncatedTexts(tester), isEmpty);
    });

    testWidgets('delete asks first', (tester) async {
      final tiles = _FakeTiles()..stored['area_1'] = _area('area_1');
      final service = await serviceWith(tiles);
      await pumpPage(tester, OfflineMapsPage(service: service));
      await tester.runAsync(service.refresh);
      await settle(tester);
      await tester.tap(find.byTooltip('Delete'));
      await settle(tester);
      expect(find.text('Delete Trail?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(tester);
      expect(tiles.deleted, ['area_1']);
    });
  });
}
