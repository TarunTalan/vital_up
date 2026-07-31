import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

void main() {
  group('ProfileEntity', () {
    const tProfile = ProfileEntity(
      id: 'user123',
      username: 'johndoe',
      email: 'john@example.com',
      fullName: 'John Doe',
      dob: '01011990',
      gender: 'Male',
      weight: '75',
      weightUnit: 'kg',
      height: '180',
      heightUnit: 'cm',
      oxygenLevel: '98',
      healthConditions: 'None',
      allergies: 'Peanuts',
      medicines: 'None',
      smokes: 'No',
      bloodPressureTop: '120',
      bloodPressureBottom: '80',
      bpm: '72',
      activity: 'Moderate',
      sleep: '8',
      photoUrl: 'https://example.com/avatar.jpg',
    );

    test('should support value equality via Equatable', () {
      const profile1 = ProfileEntity(
        id: 'user123',
        username: 'johndoe',
        email: 'john@example.com',
      );
      const profile2 = ProfileEntity(
        id: 'user123',
        username: 'johndoe',
        email: 'john@example.com',
      );

      expect(profile1, equals(profile2));
    });

    test('copyWith should return a new object with updated values', () {
      final updatedProfile = tProfile.copyWith(
        fullName: 'Jane Doe',
        weight: '68',
        photoUrl: 'https://example.com/jane.jpg',
      );

      expect(updatedProfile.id, equals(tProfile.id));
      expect(updatedProfile.username, equals(tProfile.username));
      expect(updatedProfile.email, equals(tProfile.email));
      expect(updatedProfile.fullName, equals('Jane Doe'));
      expect(updatedProfile.weight, equals('68'));
      expect(updatedProfile.photoUrl, equals('https://example.com/jane.jpg'));
      // Unchanged fields should retain original values
      expect(updatedProfile.height, equals(tProfile.height));
      expect(updatedProfile.dob, equals(tProfile.dob));
    });

    test('copyWith should retain existing values if arguments are null', () {
      final updatedProfile = tProfile.copyWith();
      expect(updatedProfile, equals(tProfile));
    });
  });
}
