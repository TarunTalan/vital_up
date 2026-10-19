import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source checks for mistakes the analyzer doesn't catch.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

  test('setState never gets a closure that returns a Future', () {
    // `setState(() => _future = load())` returns the Future from the
    // closure, which throws at runtime (and broke the Profile tab once).
    // Fields typed Future<...> (type arguments only: no `=>` or calls).
    final futureField = RegExp(r'Future<[\w<>?, ]*>\??\s+(_?\w+)\s*[=;]');
    final arrowAssign = RegExp(r'setState\(\s*\(\)\s*=>\s*(_?\w+)\s*=');
    final offenders = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      final futures = {
        for (final m in futureField.allMatches(source)) m.group(1)!,
      };
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        for (final m in arrowAssign.allMatches(lines[i])) {
          if (futures.contains(m.group(1))) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use a block body: setState(() { ... });',
    );
  });

  test('text never shrinks without a floor or below the minimum size', () {
    // A FittedBox around a Text can shrink it to any size; FitText stops
    // at a readable minimum and then ends in an ellipsis. Home widget
    // previews scale a whole mock widget on purpose.
    final fittedText = RegExp(
      r'FittedBox\(\s*fit: BoxFit\.scaleDown,\s*(alignment: [\w.]+,\s*)?'
      r'child: Text\b',
    );
    final tinyFont = RegExp(r'fontSize: ([0-9]+(\.[0-9]+)?)\b');
    final offenders = <String>[];
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.endsWith('home_widget/presentation/widget_previews.dart')) {
        continue;
      }
      final source = file.readAsStringSync();
      for (final m in fittedText.allMatches(source)) {
        offenders.add('$path:${_line(source, m.start)} FittedBox around Text');
      }
      for (final m in tinyFont.allMatches(source)) {
        if (double.parse(m.group(1)!) < 12) {
          offenders.add('$path:${_line(source, m.start)} font below 12');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use FitText and AppTextStyles (min AppTextStyles.minFontSize).',
    );
  });
}

int _line(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;
