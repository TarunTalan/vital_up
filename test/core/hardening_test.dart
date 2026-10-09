import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/cache/cache_store.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/network/connectivity_service.dart';
import 'package:vital_up/core/sync/pending_writes.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_error_fallback.dart';
import 'package:vital_up/core/widgets/app_text_field.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
);

void main() {
  group('AppTextField input filtering', () {
    testWidgets('drops invisible characters and line breaks', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_host(AppTextField(controller: controller)));
      await tester.enterText(find.byType(TextField), 'Ra\u200Bvi\nKumar');
      expect(controller.text, 'RaviKumar');
    });

    testWidgets('multiline fields keep line breaks', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_host(AppTextField(
        controller: controller,
        multiline: true,
        maxLines: 4,
      )));
      await tester.enterText(find.byType(TextField), 'a\nb');
      expect(controller.text, 'a\nb');
    });

    testWidgets('integer rejects letters and absurd lengths', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_host(AppTextField.integer(controller: controller)));
      await tester.enterText(find.byType(TextField), '1234567');
      expect(controller.text, '1234567');
      await tester.enterText(find.byType(TextField), '12345678');
      expect(controller.text, '1234567');
      await tester.enterText(find.byType(TextField), '12a');
      expect(controller.text, '1234567');
    });

    testWidgets('decimal allows one separator and turns a comma into a dot',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_host(AppTextField.decimal(controller: controller)));
      await tester.enterText(find.byType(TextField), '72,5');
      expect(controller.text, '72.5');
      await tester.enterText(find.byType(TextField), '72.5.1');
      expect(controller.text, '72.5');
    });
  });

  testWidgets('AppErrorFallback shows a calm message, not the error', (tester) async {
    await tester.pumpWidget(_host(
      AppErrorFallback.errorWidgetBuilder(
        FlutterErrorDetails(exception: Exception('Null check operator')),
      ),
    ));
    expect(find.text('Something went wrong here.'), findsOneWidget);
    expect(find.textContaining('Null check'), findsNothing);
  });

  test('failure messages stay short and calm', () {
    const failures = <Failure>[
      ServerFailure(),
      CacheFailure(),
      NetworkFailure(),
      DatabaseFailure(),
      ValidationFailure(),
      NoFoodDetectedFailure(),
      LowConfidenceFailure(),
      BarcodeNotFoundFailure(),
      RecognitionUnavailableFailure(),
      ScanQuotaExceededFailure(),
    ];
    for (final f in failures) {
      expect(f.message.length, lessThanOrEqualTo(60), reason: f.message);
      expect(f.message, isNot(contains('!')));
    }
  });

  group('CacheStore', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('cache_hardening'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('a corrupt cache file is dropped, not thrown', () async {
      final cache = CacheStore(ConnectivityService(), directory: dir);
      await cache.write('k', {'a': 1});
      final file = dir.listSync().whereType<File>().single;
      file.writeAsStringSync('{"t": 1, "v": ');

      final fresh = CacheStore(ConnectivityService(), directory: dir);
      expect(await fresh.read<Object?>('k'), isNull);
      expect(file.existsSync(), isFalse);
    });

    test('a fetch finishing after clear() does not refill the cache', () async {
      final cache = CacheStore(ConnectivityService(), directory: dir);
      final started = Completer<void>();
      final release = Completer<int>();
      final pending = cache.fetch<int>(
        'user:a',
        remote: () {
          started.complete();
          return release.future;
        },
        maxAge: Duration.zero,
      );
      await started.future; // Request in flight, then the user signs out.
      await cache.clear();
      release.complete(1);
      expect(await pending, 1);
      expect(await cache.read<int>('user:a'), isNull);
    });
  });

  group('PendingWrites', () {
    test('a corrupt queued entry does not break the queue', () async {
      SharedPreferences.setMockInitialValues({
        'pending_server_writes_v1': <String>['not json', '{"kind": 1}'],
      });
      final writes = PendingWrites(
        await SharedPreferences.getInstance(),
        ConnectivityService(),
      );
      expect(writes.countFor('u1'), 0);
      await writes.enqueue(PendingWrite.rpc('set_my_timezone', params: {'tz': 'UTC'}, userId: 'u1'));
      expect(writes.countFor('u1'), 1);
    });

    test('the queue is capped', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final writes = PendingWrites(prefs, ConnectivityService());
      for (var i = 0; i < PendingWrites.maxQueued + 3; i++) {
        await writes.enqueue(PendingWrite.rpc('f', params: {'i': i}, userId: 'u1'));
      }
      expect(writes.countFor('u1'), PendingWrites.maxQueued);
    });
  });
}
