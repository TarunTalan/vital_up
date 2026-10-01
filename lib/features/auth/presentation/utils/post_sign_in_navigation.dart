import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';

/// After sign-in: returning users go to the dashboard, users who never
/// finished health onboarding go to it.
Future<void> goAfterSignIn(BuildContext context) async {
  final completed = await context.read<AuthCubit>().hasCompletedOnboarding();
  if (!context.mounted) return;
  context.goNamed(completed ? 'dashboard' : 'health-onboarding');
}
