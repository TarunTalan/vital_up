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
  void initState() {
    super.initState();
    // Clean fields and errors on entry
    context.read<AuthCubit>().clearResetFields();
  }

  @override
  void dispose() {
    // Clean fields and errors on exit
    context.read<AuthCubit>().clearAllFields();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final state = context.watch<AuthCubit>().state;
    final isLoading = state is AuthLoading;
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (MediaQuery.of(context).viewInsets.bottom > 0.0) {
          FocusScope.of(context).unfocus();
        } else {
          context.goNamed('login');
        }
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppTheme.hPadding),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 20.0),
                                    Text(
                                      'Enter your new password below.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: colors.onSurface,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20.0),
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
                                              textInputAction: TextInputAction.done,
                                              onSubmitted: (_) {
                                                FocusScope.of(context).unfocus();
                                                cubit.resetPassword(
                                                  resetToken: widget.resetToken,
                                                  onSuccess: () {},
                                                );
                                              },
                                              onChange: cubit.onPasswordChange,
                                              error: errorSnapshot.data,
                                              showForgot: false,
                                              validate: cubit.validatePassword,
                                              showValidation: true,
                                              enabled: !isLoading,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    const Spacer(),
                                    // Reset Button
                                    BlocListener<AuthCubit, AuthState>(
                                      listener: (context, state) {
                                        if (state is AuthPasswordResetSuccess) {
                                          context.goNamed('reset-completed');
                                        }
                                      },
                                      child: BlocBuilder<AuthCubit, AuthState>(
                                        builder: (context, state) {
                                          final isLoading = state is AuthLoading;
                  
                                          return PrimaryAuthButton(
                                            label: 'Reset Password',
                                            isLoading: isLoading,
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              cubit.resetPassword(
                                                resetToken: widget.resetToken,
                                                onSuccess: () {},
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 20.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
