import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';

class LoginTab extends StatelessWidget {
  final VoidCallback onSignedIn;

  const LoginTab({super.key, required this.onSignedIn});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
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
                    label: 'Username',
                    onChange: (val) {
                      // Filter username input: allow only letters, numbers, dot, underscore up to 20 chars
                      final filtered = val.replaceAll(RegExp(r'[^A-Za-z0-9._]'), '');
                      cubit.onUsernameLoginChange(filtered);
                    },
                    error: errorSnapshot.data,
                    validate: cubit.validateUsernameLogin,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
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
                    onChange: cubit.onPasswordChange,
                    error: errorSnapshot.data,
                    onForgotPassword: () => context.push('/forgot-password'),
                    validate: cubit.validatePassword,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          // Sign In Action Button
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final isLoading = state is AuthLoading;

              return PrimaryAuthButton(
                label: 'Sign in',
                isLoading: isLoading,
                onTap: () {
                  cubit.signIn(onSuccess: onSignedIn);
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
