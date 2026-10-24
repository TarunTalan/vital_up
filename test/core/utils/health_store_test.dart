import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/health_store.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('names the health store users know on each platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(healthStoreName, 'Health Connect');
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(healthStoreName, 'Apple Health');
  });
}
