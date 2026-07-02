import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/auth/presentation/pages/login_page.dart';
import 'package:vital_up/features/auth/presentation/pages/onboarding_page.dart';
import 'package:vital_up/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:vital_up/features/auth/presentation/pages/otp_screen.dart';
import 'package:vital_up/features/auth/presentation/pages/reset_password_page.dart';
import 'package:vital_up/features/auth/presentation/pages/reset_completed_page.dart';
import 'package:vital_up/features/dashboard/presentation/pages/dashboard_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => OnboardingPage(
          onFinish: () => context.goNamed('login'),
          onGoogleSignInSuccess: () => context.goNamed('dashboard'),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/verify-otp',
        name: 'verify-otp',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final token = state.uri.queryParameters['token'] ?? '';
          final flow = state.uri.queryParameters['flow'] ?? 'signup'; // 'signup' or 'forgot'
          return OtpScreen(
            email: email,
            token: token,
            flow: flow,
          );
        },
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return ResetPasswordPage(resetToken: token);
        },
      ),
      GoRoute(
        path: '/reset-completed',
        name: 'reset-completed',
        builder: (context, state) => const ResetCompletedPage(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('No route defined for ${state.uri.toString()}'),
      ),
    ),
  );
}
