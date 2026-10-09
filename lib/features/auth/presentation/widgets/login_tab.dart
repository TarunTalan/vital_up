import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';

/// Login tab (Figma login frame): inputs followed directly by the CTA.
/// Scrolls when the keyboard or large text scale needs it.
class LoginTab extends StatelessWidget {
  final VoidCallback onSignedIn;

  const LoginTab({super.key, required this.onSignedIn});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final state = context.watch<AuthCubit>().state;
    final isLoading = state is AuthLoading;

    return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(horizontal: context.gutter),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: context.h(AppDimens.space32)),
                    // Username Input Block
                    StreamBuilder<String>(
                      stream: cubit.usernameLoginStream,
                      initialData: cubit.usernameLoginVal,
                      builder: (context, usernameSnapshot) {
                        return StreamBuilder<String?>(
                          stream: cubit.usernameErrorLoginStream,
                          builder: (context, errorSnapshot) {
                            return AuthUsernameField(
                              value: usernameSnapshot.data ?? '',
                              label: 'Username or Email Id',
                              textInputAction: TextInputAction.next,
                              onChange: (val) {
                                // Emails may contain + % and - too.
                                final filtered = val.replaceAll(
                                  RegExp(r'[^A-Za-z0-9._@+%\-]'),
                                  '',
                                );
                                cubit.onUsernameLoginChange(filtered);
                              },
                              error: errorSnapshot.data,
                              enabled: !isLoading,
                              maxLength: InputLimits.email,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: AppDimens.space12),
                    // Password Input Block
                    StreamBuilder<String>(
                      stream: cubit.passwordStream,
                      initialData: cubit.passwordVal,
                      builder: (context, passwordSnapshot) {
                        return StreamBuilder<String?>(
                          stream: cubit.passwordErrorStream,
                          builder: (context, errorSnapshot) {
                            return AuthPasswordField(
                              value: passwordSnapshot.data ?? '',
                              label: 'Password',
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                                cubit.signIn(onSuccess: onSignedIn);
                              },
                              onChange: cubit.onPasswordChange,
                              error: errorSnapshot.data,
                              onForgotPassword: () =>
                                  context.push('/forgot-password'),
                              enabled: !isLoading,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: AppDimens.space20),
                    // Sign In Action Button
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;

                        return PrimaryAuthButton(
                          label: 'Login',
                          isLoading: isLoading,
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            cubit.signIn(onSuccess: onSignedIn);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: AppDimens.space20),
                  ],
                ),
              ),
        );
  }
}
