import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/router/fade_slide_page_route.dart';
import 'package:vital_up/features/auth/presentation/pages/login_page.dart';
import 'package:vital_up/features/auth/presentation/pages/onboarding_page.dart';
import 'package:vital_up/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:vital_up/features/auth/presentation/pages/otp_screen.dart';
import 'package:vital_up/features/auth/presentation/pages/reset_password_page.dart';
import 'package:vital_up/features/auth/presentation/pages/reset_completed_page.dart';
import 'package:vital_up/features/auth/presentation/pages/splash_page.dart';
import 'package:vital_up/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_detail_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/activity_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/blood_pressure_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/bpm_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/extra_details_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/height_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/info_and_permission_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/onboarding_entry_point.dart';
import 'package:vital_up/features/onboarding/presentation/pages/ox_level_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/personal_details_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/sleep_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/weight_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: const SplashPage(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) {
          return FadeSlidePageRoute(
            key: state.pageKey,
            child: OnboardingPage(
              onFinish: () => context.goNamed('login'),
              onGoogleSignInSuccess: () => context.goNamed('health-onboarding'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) {
          return FadeSlidePageRoute(
            key: state.pageKey,
            child: const LoginPage(),
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) {
          return FadeSlidePageRoute(
            key: state.pageKey,
            child: const ForgotPasswordPage(),
          );
        },
      ),
      GoRoute(
        path: '/verify-otp',
        name: 'verify-otp',
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final token = state.uri.queryParameters['token'] ?? '';
          final flow = state.uri.queryParameters['flow'] ?? 'signup'; // 'signup' or 'forgot'
          return FadeSlidePageRoute(
            key: state.pageKey,
            child: OtpScreen(
              email: email,
              token: token,
              flow: flow,
            ),
          );
        },
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return FadeSlidePageRoute(
            key: state.pageKey,
            child: ResetPasswordPage(resetToken: token),
          );
        },
      ),
      GoRoute(
        path: '/reset-completed',
        name: 'reset-completed',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: const ResetCompletedPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: const DashboardPage(),
        ),
      ),
      GoRoute(
        path: '/food-detail',
        name: 'food-detail',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final imagePath = extra is String ? extra : null;
          return FadeSlidePageRoute(
            key: state.pageKey,
            child: FoodDetailPage(imagePath: imagePath),
          );
        },
      ),
      GoRoute(
        path: '/health-onboarding',
        name: 'health-onboarding',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: const OnboardingEntryPoint(),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/personal-details',
        name: 'health-personal-details',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: const PersonalDetailsPage(),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/height',
        name: 'health-height',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: const HeightPage(),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/weight',
        name: 'health-weight',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: const WeightPage(),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/extra-details',
        name: 'health-extra-details',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: ExtraDetailsPage(
            onNext: () => context.goNamed('health-info-permission'),
            onBack: () => context.goNamed('health-sleep'),
            onSkip: () => context.goNamed('health-info-permission'),
          ),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/blood-pressure',
        name: 'health-blood-pressure',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: BloodPressurePage(
            onNext: () => context.goNamed('health-ox-level'),
            onBack: () => context.goNamed('health-bpm'),
            onSkip: () => context.goNamed('health-ox-level'),
          ),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/bpm',
        name: 'health-bpm',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: BpmPage(
            onNext: () => context.goNamed('health-blood-pressure'),
            onBack: () => context.goNamed('health-weight'),
            onSkip: () => context.goNamed('health-blood-pressure'),
          ),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/ox-level',
        name: 'health-ox-level',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: OxLevelPage(
            onNext: () => context.goNamed('health-activity'),
            onBack: () => context.goNamed('health-blood-pressure'),
            onSkip: () => context.goNamed('health-activity'),
          ),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/activity',
        name: 'health-activity',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: ActivityPage(
            onNext: () => context.goNamed('health-sleep'),
            onBack: () => context.goNamed('health-ox-level'),
            onSkip: () => context.goNamed('health-sleep'),
          ),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/sleep',
        name: 'health-sleep',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: SleepPage(
            onNext: () => context.goNamed('health-extra-details'),
            onBack: () => context.goNamed('health-activity'),
            onSkip: () => context.goNamed('health-extra-details'),
          ),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/info-permission',
        name: 'health-info-permission',
        pageBuilder: (context, state) => FadeSlidePageRoute(
          key: state.pageKey,
          child: InfoAndPermissionPage(
            onNext: () => context.goNamed('dashboard'), // Complete flow
            onBack: () => context.goNamed('health-activity'),
            onSkip: () => context.goNamed('dashboard'),
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('No route defined for ${state.uri.toString()}'),
      ),
    ),
  );
}
