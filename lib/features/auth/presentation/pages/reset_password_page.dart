import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_header.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';

class ResetPasswordPage extends StatefulWidget {
  final String resetToken;

  const ResetPasswordPage({super.key, required this.resetToken});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  @override
  void dispose() {
    // Clean fields and errors on exit
    context.read<AuthCubit>().clearAllFields();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.goNamed('login');
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
        body: AuthBackground(
          style: AuthBackgroundStyle.ellipses,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  AuthHeader(
                    headerText: 'Reset Password',
                    onBackClick: () => context.goNamed('login'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: AppTheme.hPadding),
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          Text(
                            'Enter your new password below.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          // New Password Block
                          StreamBuilder<String>(
                            stream: cubit.passwordStream,
                            initialData: cubit.passwordVal,
                            builder: (context, passwordSnapshot) {
                              return StreamBuilder<String?>(
                                stream: cubit.passwordErrorStream,
                                builder: (context, errorSnapshot) {
                                  return AuthPasswordField(
                                    value: passwordSnapshot.data ?? '',
                                    label: 'New Password',
                                    textInputAction: TextInputAction.next,
                                    onChange: cubit.onPasswordChange,
                                    error: errorSnapshot.data,
                                    showForgot: false,
                                    validate: cubit.validatePassword,
                                    showValidation: true,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          // Confirm Password Block
                          StreamBuilder<String>(
                            stream: cubit.confirmPasswordStream,
                            initialData: cubit.confirmPasswordVal,
                            builder: (context, confirmPasswordSnapshot) {
                              return StreamBuilder<String?>(
                                stream: cubit.confirmPasswordErrorStream,
                                builder: (context, errorSnapshot) {
                                  return AuthTextField(
                                    value: confirmPasswordSnapshot.data ?? '',
                                    label: 'Confirm Password',
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) {
                                      cubit.resetPassword(
                                        resetToken: widget.resetToken,
                                        onSuccess: () {},
                                      );
                                    },
                                    autofillHints: const [AutofillHints.newPassword],
                                    onChange: cubit.onConfirmPasswordChange,
                                    placeholder: 'Re-enter password',
                                    isPassword: true,
                                    error: errorSnapshot.data,
                                    showForgot: false,
                                    validate: cubit.validateConfirmPassword,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 26),
                          // Reset Button
                          BlocConsumer<AuthCubit, AuthState>(
                            listener: (context, state) {
                              if (state is AuthPasswordResetSuccess) {
                                context.goNamed('reset-completed');
                              } else if (state is AuthError) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(state.message),
                                    backgroundColor: colors.error,
                                  ),
                                );
                                cubit.reset();
                              }
                            },
                            builder: (context, state) {
                              final isLoading = state is AuthLoading;
      
                              return PrimaryAuthButton(
                                label: 'Reset Password',
                                isLoading: isLoading,
                                onTap: () {
                                  cubit.resetPassword(
                                    resetToken: widget.resetToken,
                                    onSuccess: () {},
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
