import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/utils/responsive.dart';

void main() {
  test('body text gets the full factor', () {
    const scaler = AppTextScaler(2);
    expect(scaler.scale(12), 24);
    expect(scaler.scale(14), 28);
  });

  test('large text grows less, like Android 14', () {
    const scaler = AppTextScaler(2);
    expect(scaler.scale(24), closeTo(40, 0.5));
    expect(scaler.scale(36), lessThan(56));
    expect(scaler.scale(48), lessThan(70));
  });

  test('sizes keep their order and default size is unchanged', () {
    const scaler = AppTextScaler(1.5);
    var last = 0.0;
    for (var size = 8.0; size <= 60; size += 2) {
      final scaled = scaler.scale(size);
      expect(scaled, greaterThan(last));
      last = scaled;
    }
    expect(const AppTextScaler(1).scale(36), 36);
  });

  test('smaller system text shrinks every size evenly', () {
    expect(const AppTextScaler(0.85).scale(40), closeTo(34, 0.001));
  });

  testWidgets('boxes grow with body text, never shrink, and reflow late', (
    tester,
  ) async {
    late BuildContext captured;
    Future<void> pump(double factor) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: AppTextScaler(factor)),
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    await pump(0.85);
    expect(captured.textScaled(100), 100);
    expect(captured.isLargeText, isFalse);

    await pump(1.15);
    expect(captured.textScaled(100), closeTo(115, 0.001));
    expect(captured.isLargeText, isFalse);

    await pump(1.25);
    expect(captured.isLargeText, isTrue);
  });
}
