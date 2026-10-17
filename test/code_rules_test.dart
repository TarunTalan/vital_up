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
    expect(offenders, isEmpty, reason: 'Use a block body: setState(() { ... });');
  });
}
