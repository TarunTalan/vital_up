import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:vital_up/core/error/exceptions.dart';
import 'package:vital_up/features/profile/data/datasources/profile_remote_datasource_impl.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';

// Custom Fake classes for Supabase mocking without external packages

class FakeLogger extends Fake implements Logger {
  final List<String> errors = [];
  final List<String> infos = [];

  @override
  void e(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    errors.add(message.toString());
  }

  @override
  void i(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    infos.add(message.toString());
  }
}

class FakeUser extends Fake implements User {
  final String _id;
  final String _email;
  final Map<String, dynamic> _userMetadata;

  FakeUser(this._id, this._email, this._userMetadata);

  @override
  String get id => _id;

  @override
  String? get email => _email;

  @override
  Map<String, dynamic> get userMetadata => _userMetadata;
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  User? currentUserValue;
  UserAttributes? lastUpdatedAttributes;

  @override
  User? get currentUser => currentUserValue;

  @override
  Future<UserResponse> updateUser(UserAttributes attributes, {String? redirectTo}) async {
    lastUpdatedAttributes = attributes;
    return FakeUserResponse();
  }
}

class FakeUserResponse extends Fake implements UserResponse {}

class FakePostgrestBuilder extends Fake implements PostgrestQueryBuilder, PostgrestFilterBuilder {
  final Map<String, dynamic>? singleResult;
  final Map<String, dynamic>? maybeSingleResult;
  final Function(Map<String, dynamic>)? onUpdate;
  final Function(Map<String, dynamic>)? onUpsert;
  final bool shouldThrow;

  FakePostgrestBuilder({
    this.singleResult,
    this.maybeSingleResult,
    this.onUpdate,
    this.onUpsert,
    this.shouldThrow = false,
  });

  @override
  PostgrestFilterBuilder select([String columns = '*']) => this;

  @override
  PostgrestFilterBuilder update(Map<String, dynamic> values) {
    if (shouldThrow) throw Exception('Update failed');
    if (onUpdate != null) onUpdate!(values);
    return this;
  }

  @override
  PostgrestFilterBuilder upsert(Object values, {UpsertOptions? options}) {
    if (shouldThrow) throw Exception('Upsert failed');
    if (onUpsert != null && values is Map<String, dynamic>) {
      onUpsert!(values);
    }
    return this;
  }

  @override
  PostgrestFilterBuilder eq(String column, Object value) => this;

  @override
  Future<Map<String, dynamic>> single() async {
    if (shouldThrow) throw Exception('Query failed');
    if (singleResult == null) {
      throw Exception('No result found');
    }
    return singleResult!;
  }

  @override
  Future<Map<String, dynamic>?> maybeSingle() async {
    if (shouldThrow) throw Exception('Query failed');
    return maybeSingleResult;
  }

  @override
  Future<T> then<T>(FutureOr<T> Function(dynamic) onValue, {Function? onError}) {
    return Future<dynamic>.value(null).then(onValue, onError: onError);
  }
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeGoTrueClient fakeAuth = FakeGoTrueClient();
  final Map<String, FakePostgrestBuilder> builders = {};

  @override
  GoTrueClient get auth => fakeAuth;

  @override
  PostgrestQueryBuilder from(String table) {
    final builder = builders[table];
    if (builder == null) {
      throw Exception('No fake builder registered for table $table');
    }
    return builder;
  }
}

void main() {
  late ProfileRemoteDataSourceImpl dataSource;
  late FakeSupabaseClient fakeSupabase;
  late FakeLogger fakeLogger;

  setUp(() {
    fakeSupabase = FakeSupabaseClient();
    fakeLogger = FakeLogger();
    dataSource = ProfileRemoteDataSourceImpl(
      supabaseClient: fakeSupabase,
      logger: fakeLogger,
    );
  });

  group('getProfile', () {
    test('should throw ServerException when user is not authenticated', () async {
      fakeSupabase.fakeAuth.currentUserValue = null;

      expect(
        () => dataSource.getProfile(),
        throwsA(isA<ServerException>()),
      );
    });

    test('should successfully fetch profile entity when authenticated and tables exist', () async {
      final user = FakeUser('user123', 'test@example.com', {
        'full_name': 'Metadata Full Name',
        'avatar_url': 'https://example.com/avatar.png',
      });
      fakeSupabase.fakeAuth.currentUserValue = user;

      fakeSupabase.builders['profiles'] = FakePostgrestBuilder(
        singleResult: {
          'id': 'user123',
          'username': 'testuser',
          'email': 'test@example.com',
        },
      );

      fakeSupabase.builders['user_health_data'] = FakePostgrestBuilder(
        maybeSingleResult: {
          'id': 'user123',
          'full_name': 'Test User',
          'dob': '15081995',
          'gender': 'Male',
          'weight': '80',
          'weight_unit': 'kg',
          'height': '180',
          'height_unit': 'cm',
          'oxygen_level': '99',
          'health_conditions': 'None',
          'allergies': 'None',
          'medicines': 'None',
          'smokes': 'No',
          'blood_pressure_top': '120',
          'blood_pressure_bottom': '80',
          'bpm': '70',
          'activity': 'Sedentary',
          'sleep': '7',
        },
      );

      final result = await dataSource.getProfile();

      expect(result.id, equals('user123'));
      expect(result.username, equals('testuser'));
      expect(result.email, equals('test@example.com'));
      expect(result.fullName, equals('Test User'));
      expect(result.dob, equals('15081995'));
      expect(result.gender, equals('Male'));
      expect(result.weight, equals('80'));
      expect(result.weightUnit, equals('kg'));
      expect(result.height, equals('180'));
      expect(result.heightUnit, equals('cm'));
      expect(result.oxygenLevel, equals('99'));
      expect(result.healthConditions, equals('None'));
      expect(result.allergies, equals('None'));
      expect(result.medicines, equals('None'));
      expect(result.smokes, equals('No'));
      expect(result.bloodPressureTop, equals('120'));
      expect(result.bloodPressureBottom, equals('80'));
      expect(result.bpm, equals('70'));
      expect(result.activity, equals('Sedentary'));
      expect(result.sleep, equals('7'));
      expect(result.photoUrl, equals('https://example.com/avatar.png'));
    });

    test('should throw ServerException when query fails', () async {
      fakeSupabase.fakeAuth.currentUserValue = FakeUser('user123', 'test@example.com', {});
      fakeSupabase.builders['profiles'] = FakePostgrestBuilder(shouldThrow: true);

      expect(
        () => dataSource.getProfile(),
        throwsA(isA<ServerException>()),
      );
      expect(fakeLogger.errors, isNotEmpty);
    });
  });

  group('updateProfile', () {
    const tProfile = ProfileEntity(
      id: 'user123',
      username: 'testuser',
      email: 'test@example.com',
      fullName: 'Updated Full Name',
      dob: '15081995',
      gender: 'Male',
      weight: '82',
      weightUnit: 'kg',
      height: '182',
      heightUnit: 'cm',
      oxygenLevel: '98',
      healthConditions: 'None',
      allergies: 'None',
      medicines: 'None',
      smokes: 'No',
      bloodPressureTop: '120',
      bloodPressureBottom: '82',
      bpm: '72',
      activity: 'Active',
      sleep: '8',
      photoUrl: 'https://example.com/new_avatar.png',
    );

    test('should throw ServerException when user is not authenticated', () async {
      fakeSupabase.fakeAuth.currentUserValue = null;

      expect(
        () => dataSource.updateProfile(tProfile),
        throwsA(isA<ServerException>()),
      );
    });

    test('should successfully update profiles, user_health_data, and user attributes', () async {
      fakeSupabase.fakeAuth.currentUserValue = FakeUser('user123', 'test@example.com', {});

      Map<String, dynamic>? updatedProfileData;
      Map<String, dynamic>? upsertedHealthData;

      fakeSupabase.builders['profiles'] = FakePostgrestBuilder(
        onUpdate: (data) => updatedProfileData = data,
      );

      fakeSupabase.builders['user_health_data'] = FakePostgrestBuilder(
        onUpsert: (data) => upsertedHealthData = data,
      );

      await dataSource.updateProfile(tProfile);

      // Verify profiles update
      expect(updatedProfileData, isNotNull);
      expect(updatedProfileData!['username'], equals('testuser'));

      // Verify health data upsert
      expect(upsertedHealthData, isNotNull);
      expect(upsertedHealthData!['full_name'], equals('Updated Full Name'));
      expect(upsertedHealthData!['weight'], equals('82'));
      expect(upsertedHealthData!['height'], equals('182'));
      expect(upsertedHealthData!['onboarding_completed'], isTrue);

      // Verify auth metadata updates
      expect(fakeSupabase.fakeAuth.lastUpdatedAttributes, isNotNull);
      expect(
        fakeSupabase.fakeAuth.lastUpdatedAttributes!.data!['full_name'],
        equals('Updated Full Name'),
      );
      expect(
        fakeSupabase.fakeAuth.lastUpdatedAttributes!.data!['avatar_url'],
        equals('https://example.com/new_avatar.png'),
      );
    });

    test('should throw ServerException when update fails', () async {
      fakeSupabase.fakeAuth.currentUserValue = FakeUser('user123', 'test@example.com', {});
      fakeSupabase.builders['profiles'] = FakePostgrestBuilder(shouldThrow: true);

      expect(
        () => dataSource.updateProfile(tProfile),
        throwsA(isA<ServerException>()),
      );
      expect(fakeLogger.errors, isNotEmpty);
    });
  });
}
