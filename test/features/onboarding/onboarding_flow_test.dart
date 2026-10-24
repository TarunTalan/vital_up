import 'dart:io';
import 'dart:ui' as ui;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vital_up/core/database/isar_service.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/error/failures.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/activity_goals/domain/repositories/activity_goals_repository.dart';
import 'package:vital_up/features/dashboard/data/services/sleep_service.dart';
import 'package:vital_up/features/dashboard/data/services/water_intake_service.dart';
import 'package:vital_up/features/onboarding/data/datasources/shared_preferences_onboarding_data_store.dart';
import 'package:vital_up/features/onboarding/data/starting_goals_writer.dart';
import 'package:vital_up/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:vital_up/features/onboarding/domain/onboarding_step.dart';
import 'package:vital_up/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:vital_up/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:vital_up/features/onboarding/presentation/pages/onboarding_flow_page.dart';
import 'package:vital_up/features/profile/data/services/username_service.dart';
import 'package:vital_up/features/settings/domain/entities/settings_entity.dart';
import 'package:vital_up/features/settings/domain/repositories/settings_repository.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/readme_shots.dart';
import 'starting_goals_test.dart' show goalsWriter, FakeActivityGoals;

class _FakeRepository implements OnboardingRepository {
  final sent = <OnboardingData>[];
  Failure? failure;

  @override
  Future<Either<Failure, void>> submitOnboardingData(
    OnboardingData data,
  ) async {
    sent.add(data);
    final failure = this.failure;
    return failure == null ? const Right(null) : Left(failure);
  }
}

class _FakeSettings implements SettingsRepository {
  SettingsEntity settings = const SettingsEntity();

  @override
  Future<Either<Failure, SettingsEntity>> getSettings() async =>
      Right(settings);

  @override
  Future<Either<Failure, void>> saveSettings(SettingsEntity s) async {
    settings = s;
    return const Right(null);
  }
}

/// Signed in with a username already confirmed: no username field.
class _FakeUsernames extends Fake implements UsernameService {
  @override
  Future<UsernameStatus?> fetchStatus() async => null;
}

/// A finished "About you" step, so later steps have what they rely on.
const _about = {
  'onboarding_full_name': 'Asha Rao',
  'onboarding_dob': '24061996',
  'onboarding_gender': 'female',
};

late SharedPreferences _prefs;
late _FakeRepository _repo;
late _FakeSettings _settings;

Future<OnboardingCubit> _pump(
  WidgetTester tester, {
  OnboardingStep step = OnboardingStep.about,
  Map<String, Object> prefs = _about,
  double textScale = 1.0,
  Size size = kSmallPhone,
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  _prefs = await SharedPreferences.getInstance();
  _repo = _FakeRepository();
  _settings = _FakeSettings();
  await sl.reset();
  sl.registerSingleton<UsernameService>(_FakeUsernames());
  sl.registerSingleton<StartingGoalsWriter>(goalsWriter(_prefs));
  sl.registerSingleton<WaterIntakeService>(
    WaterIntakeService(IsarService(), _prefs),
  );
  sl.registerSingleton<SleepService>(SleepService(IsarService(), _prefs));
  sl.registerSingleton<ActivityGoalsRepository>(FakeActivityGoals(_prefs));
  addTearDown(sl.reset);

  final cubit = OnboardingCubit(
    SharedPreferencesOnboardingDataStore(_prefs),
    _repo,
  );
  await cubit.reload();
  final settings = SettingsCubit(settingsRepository: _settings);
  await settings.loadSettings();
  addTearDown(cubit.close);
  addTearDown(settings.close);

  await pumpPage(
    tester,
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cubit),
        BlocProvider.value(value: settings),
      ],
      child: OnboardingFlowPage(initialStep: step),
    ),
    textScale: textScale,
    size: size,
    theme: theme,
  );
  await tester.pumpAndSettle();
  return cubit;
}

/// `HOME_SHOTS=1` writes the screen to build/onboarding_shots/[id].png.
Future<void> _shot(WidgetTester tester, String id) async {
  if (Platform.environment['HOME_SHOTS'] != '1') return;
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('build/onboarding_shots/$id.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  group('OnboardingStep', () {
    test('unknown or old saved steps start at the beginning', () {
      expect(OnboardingStep.fromId('blood_pressure'), OnboardingStep.about);
      expect(OnboardingStep.fromId(''), OnboardingStep.about);
      expect(OnboardingStep.fromId('goals'), OnboardingStep.goal);
    });

    test('only the middle steps can be skipped', () {
      expect(OnboardingStep.about.skippable, isFalse);
      expect(OnboardingStep.privacy.skippable, isFalse);
      expect(OnboardingStep.weight.skippable, isTrue);
    });
  });

  group('OnboardingCubit', () {
    test('reload drops answers wiped by a sign-out', () async {
      SharedPreferences.setMockInitialValues(_about);
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesOnboardingDataStore(prefs);
      final cubit = OnboardingCubit(store, _FakeRepository());
      await cubit.reload();
      expect(cubit.state.fullName, 'Asha Rao');

      await store.clearOnboardingData();
      await cubit.reload();
      expect(cubit.state.fullName, isEmpty);
      expect(cubit.state.currentStep, 'personal_details');
      await cubit.close();
    });

    test('no weight is made up when none was given', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = OnboardingCubit(
        SharedPreferencesOnboardingDataStore(prefs),
        _FakeRepository(),
      );
      await cubit.reload();
      expect(cubit.state.weight, isEmpty);
      await cubit.close();
    });
  });

  group('flow', () {
    testWidgets('About you asks for what is missing', (tester) async {
      await _pump(tester, prefs: const {});
      await _continue(tester);
      expect(find.text('About you'), findsOneWidget);
      expect(find.text('Choose one to continue.'), findsOneWidget);
    });

    testWidgets('Continue saves the shown height, then slides on', (
      tester,
    ) async {
      final cubit = await _pump(tester, step: OnboardingStep.height);
      expect(find.text('How tall are you?'), findsOneWidget);
      await _continue(tester);
      // The shown default (female: 163 cm) is saved, not left empty, in
      // feet and inches (the default height unit).
      expect(_prefs.getString('onboarding_height'), '5-4');
      expect(_prefs.getString('onboarding_height_unit'), 'ft');
      expect(find.text('What do you weigh?'), findsOneWidget);
      expect(cubit.state.currentStep, 'weight');
    });

    testWidgets('Skip leaves the weight empty', (tester) async {
      await _pump(tester, step: OnboardingStep.weight);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('How do you eat?'), findsOneWidget);
      expect(_prefs.getString('onboarding_weight') ?? '', isEmpty);
    });

    testWidgets('back returns to the previous step', (tester) async {
      final cubit = await _pump(tester, step: OnboardingStep.diet);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.text('What do you weigh?'), findsOneWidget);
      expect(cubit.state.currentStep, 'weight');
    });

    testWidgets('a picked diet is saved on Continue', (tester) async {
      await _pump(tester, step: OnboardingStep.diet);
      await tester.tap(find.text('Vegan'));
      await tester.pumpAndSettle();
      await _continue(tester);
      expect(_prefs.getString('onboarding_dietary_preference'), 'Vegan');
    });

    testWidgets('analytics switch shows and changes the real setting', (
      tester,
    ) async {
      await _pump(tester, step: OnboardingStep.privacy);
      await tester.scrollUntilVisible(find.text('Share usage analytics'), 200);
      final analytics = find.descendant(
        of: find.ancestor(
          of: find.text('Share usage analytics'),
          matching: find.byType(Row),
        ),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(analytics.first).value, isTrue);
      await tester.tap(analytics.first);
      await tester.pumpAndSettle();
      expect(_settings.settings.analyticsEnabled, isFalse);
    });

    testWidgets('Finish saves everything and welcomes the user', (
      tester,
    ) async {
      await _pump(
        tester,
        step: OnboardingStep.privacy,
        prefs: {
          ..._about,
          'onboarding_weight': '62',
          'onboarding_weight_unit': 'kg',
          'onboarding_height': '163',
          'onboarding_height_unit': 'cm',
        },
      );
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(_repo.sent, hasLength(1));
      expect(find.text("You're all set, Asha"), findsOneWidget);
      expect(find.text('Your goals'), findsOneWidget);
      // 62 kg: 2,170 ml -> 2.25 L; no activity answer: 8,000 steps.
      expect(find.text('2.25 L a day'), findsOneWidget);
      expect(find.text('8,000 a day'), findsOneWidget);
      expect(find.text('3 a week'), findsOneWidget);
      expect(find.text('8h a night'), findsOneWidget);
      expect(_prefs.getInt('daily_screen_time_limit_min'), 0);
      expect(find.text('Go to Home'), findsOneWidget);
    });

    testWidgets('a failed save stays on the step', (tester) async {
      await _pump(tester, step: OnboardingStep.privacy);
      _repo.failure = const ServerFailure("You're offline. Try again.");
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('Your data, your call'), findsOneWidget);
      expect(find.text("You're offline. Try again."), findsOneWidget);
    });
  });

  group('readme', () {
    const tarun = {
      'onboarding_full_name': kDemoName,
      'onboarding_dob': '14031998',
      'onboarding_gender': 'male',
      'onboarding_weight': '72',
      'onboarding_weight_unit': 'kg',
      'onboarding_height': '176',
      'onboarding_height_unit': 'cm',
      'onboarding_activity': 'Moderately active',
    };

    testWidgets('onboarding', (tester) async {
      await tester.runAsync(loadAllFonts);
      await _pump(
        tester,
        step: OnboardingStep.weight,
        prefs: tarun,
        size: kReadmePhone,
      );
      await settleReadmeAssets(tester);
      await captureReadmeShot(tester, 'onboarding');
    }, skip: !readmeShots);

    testWidgets('onboarding_done', (tester) async {
      await tester.runAsync(loadAllFonts);
      await _pump(
        tester,
        step: OnboardingStep.privacy,
        prefs: tarun,
        size: kReadmePhone,
      );
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await settleReadmeAssets(tester);
      await captureReadmeShot(tester, 'onboarding_done');
    }, skip: !readmeShots);
  });

  // The finish screen with the longest figures (lb, 4 L of water).
  for (final c in const [
    (width: 360.0, scale: kMaxTextScale, dark: false),
    (width: 412.0, scale: 1.0, dark: true),
  ]) {
    final id =
        '8_done_${c.width.round()}_${c.scale}_${c.dark ? 'dark' : 'light'}';
    testWidgets('finish screen fits: $id', (tester) async {
      await tester.runAsync(loadAllFonts);
      await _pump(
        tester,
        step: OnboardingStep.privacy,
        prefs: {
          ..._about,
          'onboarding_weight': '229.9',
          'onboarding_weight_unit': 'lb',
          'onboarding_activity': 'Very active',
        },
        textScale: c.scale,
        size: Size(c.width, 800),
        theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      );
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      expect(find.text('Go to Home'), findsOneWidget);
      expect(find.text('11,000 a day'), findsOneWidget);
      await _shot(tester, id);
      expect(takeAllExceptions(tester), isEmpty);
      expect(truncatedTexts(tester), isEmpty);
    });
  }

  // Every step on the smallest phone at normal and largest text, light
  // and dark: nothing cut or overflowing. `HOME_SHOTS=1` writes PNGs to
  // build/onboarding_shots/.
  group('layout', () {
    for (final step in OnboardingStep.values) {
      for (final c in const [
        (width: 360.0, scale: 1.0, dark: false),
        (width: 360.0, scale: kMaxTextScale, dark: false),
        (width: 412.0, scale: 1.0, dark: true),
      ]) {
        final id =
            '${step.number}_${step.name}_${c.width.round()}_${c.scale}_'
            '${c.dark ? 'dark' : 'light'}';
        testWidgets(id, (tester) async {
          await tester.runAsync(loadAllFonts);
          await _pump(
            tester,
            step: step,
            textScale: c.scale,
            size: Size(c.width, 800),
            theme: c.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          );
          final errors = takeAllExceptions(tester);
          final cut = truncatedTexts(tester);
          await _shot(tester, id);
          expect(errors, isEmpty);
          expect(cut, isEmpty);
        });
      }
    }
  });
}
