import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/router/app_page_transitions.dart';
import 'package:vital_up/features/auth/presentation/pages/login_page.dart';
import 'package:vital_up/features/auth/presentation/utils/post_sign_in_navigation.dart';
import 'package:vital_up/features/auth/presentation/pages/onboarding_page.dart';
import 'package:vital_up/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:vital_up/features/auth/presentation/pages/otp_screen.dart';
import 'package:vital_up/features/auth/presentation/pages/reset_password_page.dart';
import 'package:vital_up/features/auth/presentation/pages/reset_completed_page.dart';
import 'package:vital_up/features/auth/presentation/pages/splash_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/activity_tracking_page.dart';
import 'package:vital_up/features/activity_tracking/presentation/pages/activity_history_page.dart';
import 'package:vital_up/features/activity_goals/presentation/pages/activity_goals_page.dart';
import 'package:vital_up/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:vital_up/features/dashboard/presentation/pages/diet_progress_page.dart';
import 'package:vital_up/features/dashboard/presentation/pages/sleep_trends_page.dart';
import 'package:vital_up/features/dashboard/presentation/pages/stress_trends_page.dart';
import 'package:vital_up/features/dashboard/presentation/pages/water_trends_page.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_scanner_page.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/meal_log_history_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/activity_page.dart';

import 'package:vital_up/features/onboarding/presentation/pages/dietary_preference_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/height_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/info_and_permission_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/onboarding_entry_point.dart';
import 'package:vital_up/features/onboarding/presentation/pages/goals.dart';
import 'package:vital_up/features/onboarding/presentation/pages/personal_details_page.dart';
import 'package:vital_up/features/onboarding/presentation/pages/weight_page.dart';
import 'package:vital_up/features/diet_plan/presentation/pages/diet_plan_mode_select_page.dart';
import 'package:vital_up/features/diet_plan/presentation/pages/diet_plan_preferences_page.dart';
import 'package:vital_up/features/diet_plan/presentation/pages/diet_plan_edit_page.dart';
import 'package:vital_up/features/diet_plan/presentation/pages/diet_plan_result_page.dart';
import 'package:vital_up/features/diet_plan/presentation/pages/goal_setup_page.dart';
import 'package:vital_up/features/diet_plan/presentation/pages/manual_target_page.dart';
import 'package:vital_up/features/settings/presentation/pages/settings_page.dart';
import 'package:vital_up/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:vital_up/features/reminders/presentation/pages/reminders_page.dart';
import 'package:vital_up/features/weight/presentation/weight_trends_page.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_chat_page.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_diet_plan_page.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_health_analysis_page.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_stress_guide_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/community/domain/entities/community.dart';
import 'package:vital_up/features/community/presentation/pages/friends_page.dart';
import 'package:vital_up/features/community/presentation/pages/leaderboard_page.dart';
import 'package:vital_up/features/gamification/presentation/pages/badges_page.dart';
import 'package:vital_up/features/gamification/presentation/pages/points_history_page.dart';
import 'package:vital_up/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:vital_up/features/notifications/presentation/pages/notifications_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const SplashPage(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) {
          return AppPage(
            key: state.pageKey,
            child: OnboardingPage(
              onFinish: () => context.goNamed('login'),
              onGoogleSignInSuccess: () => goAfterSignIn(context),
            ),
          );
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) {
          return AppPage(
            key: state.pageKey,
            child: const LoginPage(),
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) {
          return AppPage(
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
          return AppPage(
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
          return AppPage(
            key: state.pageKey,
            child: ResetPasswordPage(resetToken: token),
          );
        },
      ),
      GoRoute(
        path: '/reset-completed',
        name: 'reset-completed',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const ResetCompletedPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const DashboardPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard/water',
        name: 'water-trends',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const WaterTrendsPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard/weight',
        name: 'weight-trends',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const WeightTrendsPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard/sleep',
        name: 'sleep-trends',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const SleepTrendsPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard/stress',
        name: 'stress-trends',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const StressTrendsPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard/activity-goals',
        name: 'activity-goals',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const ActivityGoalsPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard/diet',
        name: 'diet-progress',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const DietProgressPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard/badges',
        name: 'badges',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const BadgesPage(),
        ),
      ),
      GoRoute(
        path: '/dashboard/points',
        name: 'points-history',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const PointsHistoryPage(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        // Opened from the home bell, which passes its cubit so the unread
        // count stays in sync; without it fall back to the dashboard.
        redirect: (context, state) =>
            state.extra is NotificationsCubit ? null : '/dashboard',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: BlocProvider.value(
            value: state.extra! as NotificationsCubit,
            child: const NotificationsPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/friends',
        name: 'friends',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: FriendsPage(myUsername: state.extra as String?),
        ),
      ),
      GoRoute(
        path: '/community/:id',
        name: 'leaderboard',
        // Opened from the community tab, which passes the Community; without
        // it (a stale deep link) fall back to the dashboard.
        redirect: (context, state) =>
            state.extra is Community ? null : '/dashboard',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: LeaderboardPage(community: state.extra! as Community),
        ),
      ),

      GoRoute(
        path: '/activity-tracking',
        name: 'activity-tracking',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const ActivityTrackingPage(),
        ),
      ),
      GoRoute(
        path: '/activity-history',
        name: 'activity-history',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const ActivityHistoryPage(),
        ),
      ),
      GoRoute(
        path: '/food-scan',
        name: 'food-scan',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const FoodScannerPage(),
        ),
      ),
      GoRoute(
        path: '/meal-log-history',
        name: 'meal-log-history',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const MealLogHistoryPage(),
        ),
      ),
      GoRoute(
        path: '/health-onboarding',
        name: 'health-onboarding',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const OnboardingEntryPoint(),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/personal-details',
        name: 'health-personal-details',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const PersonalDetailsPage(),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/height',
        name: 'health-height',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const HeightPage(),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/weight',
        name: 'health-weight',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const WeightPage(),
        ),
      ),


      GoRoute(
        path: '/health-onboarding/dietary-preference',
        name: 'health-dietary-preference',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: DietaryPreferencePage(
            onNext: () => context.goNamed('health-goals'),
            onBack: () => context.goNamed('health-weight'),
            onSkip: () => context.goNamed('health-goals'),
          ),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/goals',
        name: 'health-goals',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: GoalsPage(
            onNext: () => context.goNamed('health-activity'),
            onBack: () => context.goNamed('health-dietary-preference'),
            onSkip: () => context.goNamed('health-activity'),
          ),
        ),
      ),
      GoRoute(
        path: '/health-onboarding/activity',
        name: 'health-activity',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: ActivityPage(
            onNext: () => context.goNamed('health-info-permission'),
            onBack: () => context.goNamed('health-goals'),
            onSkip: () => context.goNamed('health-info-permission'),
          ),
        ),
      ),

      GoRoute(
        path: '/health-onboarding/info-permission',
        name: 'health-info-permission',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: InfoAndPermissionPage(
            onNext: () => context.goNamed('dashboard'), // Complete flow
            onBack: () => context.goNamed('health-activity'),
            onSkip: () => context.goNamed('dashboard'),
          ),
        ),
      ),
      GoRoute(
        path: '/diet-plan-prefs',
        name: 'diet-plan-prefs',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const DietPlanPreferencesPage(),
        ),
      ),
      GoRoute(
        path: '/diet-plan-mode',
        name: 'diet-plan-mode',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AppPage(
            key: state.pageKey,
            child: DietPlanModeSelectPage(preferences: extra),
          );
        },
      ),
      GoRoute(
        path: '/diet-plan-goal',
        name: 'diet-plan-goal',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AppPage(
            key: state.pageKey,
            child: GoalSetupPage(preferences: extra),
          );
        },
      ),
      GoRoute(
        path: '/diet-plan-manual',
        name: 'diet-plan-manual',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AppPage(
            key: state.pageKey,
            child: ManualTargetPage(preferences: extra),
          );
        },
      ),
      GoRoute(
        path: '/diet-plan-edit',
        name: 'diet-plan-edit',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const DietPlanEditPage(),
        ),
      ),
      GoRoute(
        path: '/diet-plan-result',
        name: 'diet-plan-result',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AppPage(
            key: state.pageKey,
            child: DietPlanResultPage(params: extra),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: BlocProvider<SettingsCubit>(
            create: (context) => sl<SettingsCubit>()..loadSettings(),
            child: const SettingsPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/reminders',
        name: 'reminders',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: BlocProvider<RemindersCubit>(
            create: (context) => sl<RemindersCubit>()..load(),
            child: const RemindersPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/vita/chat',
        name: 'vita-chat',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final args = extra is VitaChatArgs
              ? extra
              : VitaChatArgs(initialPrompt: extra as String?);
          return AppPage(
            key: state.pageKey,
            child: VitaChatPage(
              initialPrompt: args.initialPrompt,
              draftPlan: args.draftPlan,
            ),
          );
        },
      ),
      GoRoute(
        path: '/vita/analysis',
        name: 'vita-analysis',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const VitaHealthAnalysisPage(),
        ),
      ),
      GoRoute(
        path: '/vita/diet-plan',
        name: 'vita-diet-plan',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: VitaDietPlanPage(fromChat: state.extra == true),
        ),
      ),
      GoRoute(
        path: '/vita/stress',
        name: 'vita-stress',
        pageBuilder: (context, state) => AppPage(
          key: state.pageKey,
          child: const VitaStressGuidePage(),
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
