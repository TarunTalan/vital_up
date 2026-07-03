import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';

/// Login tab — NO scrolling, content fits in the available tab area.
/// Uses Spacer to push the button to a comfortable position at bottom.
class LoginTab extends StatelessWidget {
  final VoidCallback onSignedIn;

  const LoginTab({super.key, required this.onSignedIn});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final state = context.watch<AuthCubit>().state;
    final isLoading = state is AuthLoading;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.hPadding,
                ),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20.0),
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
                                final filtered = val.replaceAll(
                                  RegExp(r'[^A-Za-z0-9._@]'),
                                  '',
                                );
                                cubit.onUsernameLoginChange(filtered);
                              },
                              error: errorSnapshot.data,
                              enabled: !isLoading,
                              maxLength: 254,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16.0),
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
                    const Spacer(),
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
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}
