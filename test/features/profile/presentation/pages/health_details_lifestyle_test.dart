import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/profile/presentation/pages/health_details_page.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_state.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';
import '../../../../helpers/pump_app.dart';

class _FakeSleepService implements SleepService {
  int goalMinutes = 480;

  @override
  int getGoalMinutes() => goalMinutes;

  @override
  Future<void> setGoalMinutes(int minutes) async {
    goalMinutes = minutes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWeightService implements WeightService {
  @override
  Future<WeightUnit> unit() async => WeightUnit.kg;

  @override
  Future<WeightLogCache?> latest() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestProfileCubit extends Cubit<ProfileState> implements ProfileCubit {
  ProfileEntity _profile;

  _TestProfileCubit(this._profile) : super(ProfileLoaded(_profile));

  @override
  ProfileEntity? get currentProfile => _profile;

  @override
  Future<void> loadProfile({bool forceRefresh = false}) async {
    emit(ProfileLoaded(_profile));
  }

  @override
  Future<void> updateProfile(ProfileEntity profile) async {
    _profile = profile;
    emit(ProfileSaveSuccess(_profile));
    emit(ProfileLoaded(_profile));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsCubit extends Cubit<SettingsState>
    implements SettingsCubit {
  _FakeSettingsCubit() : super(const SettingsLoaded(SettingsEntity()));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSleepService fakeSleepService;
  late _FakeWeightService fakeWeightService;
  late _TestProfileCubit profileCubit;
  late _FakeSettingsCubit settingsCubit;

  setUp(() async {
    fakeSleepService = _FakeSleepService();
    if (sl.isRegistered<SleepService>()) {
      sl.unregister<SleepService>();
    }
    sl.registerSingleton<SleepService>(fakeSleepService);

    fakeWeightService = _FakeWeightService();
    if (sl.isRegistered<WeightService>()) {
      sl.unregister<WeightService>();
    }
    sl.registerSingleton<WeightService>(fakeWeightService);

    profileCubit = _TestProfileCubit(
      const ProfileEntity(
        id: 'user_1',
        username: 'testuser',
        email: 'test@example.com',
        smokes: 'Never',
        sleep: '8h 0m',
      ),
    );

    settingsCubit = _FakeSettingsCubit();
  });

  tearDown(() {
    if (sl.isRegistered<SleepService>()) {
      sl.unregister<SleepService>();
    }
    if (sl.isRegistered<WeightService>()) {
      sl.unregister<WeightService>();
    }
  });

  Widget createWidgetUnderTest() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileCubit>.value(value: profileCubit),
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
      ],
      child: const HealthDetailsPage(),
    );
  }

  testWidgets(
    'Sleep goal tile in Lifestyle group is non-clickable static card',
    (tester) async {
      await pumpPage(
        tester,
        createWidgetUnderTest(),
        size: const Size(400, 1600),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.ancestor(
        of: find.text('Sleep goal'),
        matching: find.byType(AppListTile),
      );
      expect(tileFinder, findsOneWidget);

      final tile = tester.widget<AppListTile>(tileFinder);
      expect(tile.title, 'Sleep goal');
      expect(tile.value, '8h 0m');
      expect(tile.subtitle, isNull);
      expect(tile.onTap, isNull, reason: 'Tile must be non-clickable');
    },
  );

  testWidgets(
    'Lifestyle bottom sheet edits and saves sleep goal with stepper and slider',
    (tester) async {
      await pumpPage(
        tester,
        createWidgetUnderTest(),
        size: const Size(400, 1600),
      );
      await tester.pumpAndSettle();

      final lifestyleGroupFinder = find.byWidgetPredicate(
        (widget) => widget is AppListGroup && widget.title == 'Lifestyle',
      );
      expect(lifestyleGroupFinder, findsOneWidget);

      final editInLifestyle = find.descendant(
        of: lifestyleGroupFinder,
        matching: find.text('Edit'),
      );
      expect(editInLifestyle, findsOneWidget);
      await tester.tap(editInLifestyle);
      await tester.pumpAndSettle();

      // Lifestyle bottom sheet is now open
      expect(find.text('Do you smoke?'), findsOneWidget);
      expect(find.text('Nightly sleep goal'), findsOneWidget);
      expect(find.text('Recommended: 7–9 hrs'), findsOneWidget);

      // Current sleep goal displayed in sheet
      expect(find.text('8h 0m'), findsWidgets);

      // Tap decrease button
      final decreaseBtn = find.byTooltip('Decrease sleep goal');
      expect(decreaseBtn, findsOneWidget);
      await tester.tap(decreaseBtn);
      await tester.pumpAndSettle();

      // Value updates to 7h 30m
      expect(find.text('7h 30m'), findsOneWidget);

      // Tap Save
      final saveBtn = find.text('Save');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Sheet is closed, SleepService was updated
      expect(fakeSleepService.goalMinutes, 450);

      // HealthDetailsPage now shows updated goal
      expect(find.text('7h 30m'), findsOneWidget);
    },
  );
}
