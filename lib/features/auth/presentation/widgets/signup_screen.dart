import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';
import 'package:vital_up/features/auth/presentation/widgets/terms_dialog.dart';

class SignupScreen extends StatefulWidget {
  final Function(String token, String email) onOTPSent;

  const SignupScreen({super.key, required this.onOTPSent});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _termsAccepted = false;
  String? _termsError;
  bool _showTermsDialog = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Username Input Block
          StreamBuilder<String>(
            stream: cubit.usernameSignupStream,
            initialData: cubit.usernameSignupVal,
            builder: (context, usernameSnapshot) {
              return StreamBuilder<String?>(
                stream: cubit.usernameErrorSignupStream,
                builder: (context, errorSnapshot) {
                  return AuthTextField(
                    value: usernameSnapshot.data ?? '',
                    label: 'Username',
                    onChange: (val) {
                      final filtered = val.replaceAll(RegExp(r'[^A-Za-z0-9._]'), '');
                      cubit.onUsernameSignupChange(filtered);
                    },
                    error: errorSnapshot.data,
                    validate: cubit.validateUsernameSignup,
                    maxLength: 20,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
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
                    onChange: cubit.onEmailChange,
                    error: errorSnapshot.data,
                    validate: cubit.validateEmail,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
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
                    showForgot: false,
                    validate: cubit.validatePassword,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
          // Confirm Password Input Block
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
          const SizedBox(height: 16),
          // Terms and Conditions checkbox row
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _termsAccepted,
                  onChanged: (val) {
                    setState(() {
                      _termsAccepted = val ?? false;
                      if (_termsAccepted) _termsError = null;
                    });
                  },
                  activeColor: colors.primary,
                  checkColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showTermsDialog = true;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onTertiary,
                            fontSize: 14.0,
                          ),
                      children: [
                        const TextSpan(text: 'I have read and agree with the '),
                        TextSpan(
                          text: 'terms and conditions',
                          style: TextStyle(
                            color: colors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_termsError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Text(
                  _termsError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.error,
                        fontSize: 11.0,
                      ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          // Sign Up Action Button
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              final isLoading = state is AuthLoading;

              return PrimaryAuthButton(
                label: 'Sign up',
                isLoading: isLoading,
                onTap: () {
                  final isUsernameValid = cubit.validateUsernameSignup();
                  final isEmailValid = cubit.validateEmail();
                  final isPasswordValid = cubit.validatePassword();
                  final isConfirmValid = cubit.validateConfirmPassword();
                  final isTermsValid = _termsAccepted;

                  if (!isTermsValid) {
                    setState(() {
                      _termsError = 'Please accept the terms & conditions';
                    });
                  }

                  if (!isUsernameValid || !isEmailValid || !isPasswordValid || !isConfirmValid || !isTermsValid) {
                    return;
                  }

                  cubit.signUpWithOTP(
                    onOTPSent: (token) {
                      widget.onOTPSent(token, cubit.emailVal);
                    },
                    onError: (_) {},
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          if (_showTermsDialog)
            TermsAndConditionsDialog(
              onDismiss: () {
                setState(() {
                  _showTermsDialog = false;
                });
              },
              onAccept: () {
                setState(() {
                  _termsAccepted = true;
                  _termsError = null;
                  _showTermsDialog = false;
                });
              },
            ),
        ],
      ),
    );
  }
}
