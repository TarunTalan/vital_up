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

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  @override
  void dispose() {
    // Clear fields and errors when leaving this page
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
                    headerText: 'Forgot Password',
                    onBackClick: () => context.goNamed('login'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: AppTheme.hPadding),
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          Text(
                            'Please enter your registered email to receive a verification code.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          // Email Input Block
                          StreamBuilder<String>(
                            stream: cubit.emailStream,
                            initialData: cubit.emailVal,
                            builder: (context, emailSnapshot) {
                              return StreamBuilder<String?>(
                                stream: cubit.emailErrorStream,
                                builder: (context, errorSnapshot) {
                                  return AuthEmailField(
                                    value: emailSnapshot.data ?? '',
                                    label: 'Email ID',
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) {
                                      cubit.requestForgotPassword(onSuccess: () {});
                                    },
                                    onChange: cubit.onEmailChange,
                                    error: errorSnapshot.data,
                                    validate: cubit.validateEmail,
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          // Action Button
                          BlocConsumer<AuthCubit, AuthState>(
                            listener: (context, state) {
                              if (state is AuthForgotPasswordOtpSent) {
                                context.push(
                                  '/verify-otp?email=${state.email}&token=${state.token}&flow=forgot',
                                );
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
                                label: 'Send',
                                isLoading: isLoading,
                                onTap: () {
                                  cubit.requestForgotPassword(onSuccess: () {});
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
