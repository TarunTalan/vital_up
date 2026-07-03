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
              onGoogleSignInSuccess: () => context.goNamed('dashboard'),
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
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('No route defined for ${state.uri.toString()}'),
      ),
    ),
  );
}
