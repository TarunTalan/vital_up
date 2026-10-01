import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/load_timeout.dart';

void main() {
  const short = Duration(milliseconds: 20);

  test('orFallback returns the fallback when a source hangs', () async {
    final never = Completer<int?>().future;
    expect(await never.orFallback(null, short), isNull);
  });

  test('orFallback returns the fallback when a source throws', () async {
    final failing = Future<List<int>>.error(StateError('no permission'));
    expect(await failing.orFallback(const [], short), isEmpty);
  });

  test('orFallback passes through a value that arrives in time', () async {
    expect(await Future.value(7).orFallback(0, short), 7);
  });

  test('withLoadTimeout throws instead of waiting forever', () {
    final never = Completer<int>().future;
    expect(never.withLoadTimeout(short), throwsA(isA<TimeoutException>()));
  });
}
