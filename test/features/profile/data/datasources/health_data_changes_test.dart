import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource_impl.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

void main() {
  const base = ProfileEntity(
    id: 'u1',
    username: 'tarun',
    email: 'e',
    fullName: 'Tarun',
    weight: '78',
    height: '180',
    allergies: 'Peanuts',
  );

  test('only the fields this edit changed are sent', () {
    final changes = healthDataChanges(base.copyWith(height: '181'), base);
    expect(changes, {'height': '181', 'height_unit': 'cm'});
  });

  test('an untouched weight is never sent back', () {
    // Weight logged meanwhile on the server; this edit is about allergies.
    final changes = healthDataChanges(base.copyWith(allergies: 'None'), base);
    expect(changes.containsKey('weight'), isFalse);
    expect(changes['allergies'], 'None');
  });

  test('nothing changed: nothing to send', () {
    expect(healthDataChanges(base, base), isEmpty);
  });

  test('without a previous copy every column is sent', () {
    final changes = healthDataChanges(base, null);
    expect(changes['weight'], '78');
    expect(changes['onboarding_completed'], isTrue);
  });
}
