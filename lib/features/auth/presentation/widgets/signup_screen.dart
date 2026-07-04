import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
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

  void _submit(AuthCubit cubit) {
    FocusScope.of(context).unfocus();
    final isUsernameValid = cubit.validateUsernameSignup();
    final isEmailValid = cubit.validateEmail();
    final isPasswordValid = cubit.validatePassword();
    final isTermsValid = _termsAccepted;

    if (!isTermsValid) {
      setState(() {
        _termsError = 'Please accept the terms & conditions';
      });
    }

    if (!isUsernameValid || !isEmailValid || !isPasswordValid || !isTermsValid) {
      return;
    }

    cubit.signUpWithOTP(
      onOTPSent: (token) {
        widget.onOTPSent(token, cubit.emailVal);
      },
      onError: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final state = context.watch<AuthCubit>().state;
    final isLoading = state is AuthLoading;
    final colors = Theme.of(context).colorScheme;
    final vColors = Theme.of(context).extension<VitalUpColors>();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.hPadding),
                child: Column(
                  children: [
                    const SizedBox(height: 20.0),
                    // Username Input Block
                    StreamBuilder<String>(
                      stream: cubit.usernameSignupStream,
                      initialData: cubit.usernameSignupVal,
                      builder: (context, usernameSnapshot) {
                        return StreamBuilder<String?>(
                          stream: cubit.usernameErrorSignupStream,
                          builder: (context, errorSnapshot) {
                            return StreamBuilder<bool?>(
                              stream: cubit.isUsernameAvailableStream,
                              initialData: null,
                              builder: (context, availableSnapshot) {
                                return StreamBuilder<bool>(
                                  stream: cubit.isCheckingUsernameStream,
                                  initialData: false,
                                  builder: (context, checkingSnapshot) {
                                    final isChecking = checkingSnapshot.data ?? false;
                                    final isAvailable = availableSnapshot.data;

                                    return AuthTextField(
                                      value: usernameSnapshot.data ?? '',
                                      label: 'Username',
                                      placeholder: 'Enter your name',
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.username],
                                      onChange: (val) {
                                        final filtered = val.replaceAll(RegExp(r'[^A-Za-z0-9._]'), '');
                                        cubit.onUsernameSignupChange(filtered);
                                      },
                                      error: errorSnapshot.data,
                                      isAvailable: isAvailable,
                                      isChecking: isChecking,
                                      validate: cubit.validateUsernameSignup,
                                      maxLength: 20,
                                      enabled: !isLoading,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16.0),
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
                              label: 'Email Id',
                              textInputAction: TextInputAction.next,
                              onChange: cubit.onEmailChange,
                              error: errorSnapshot.data,
                              validate: cubit.validateEmail,
                              placeholder: 'Enter your email id',
                              enabled: !isLoading,
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
                              onSubmitted: (_) => _submit(cubit),
                              onChange: cubit.onPasswordChange,
                              error: errorSnapshot.data,
                              showForgot: false,
                              validate: cubit.validatePassword,
                              placeholder: 'Enter password',
                              enabled: !isLoading,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20.0),
                    // Terms and Conditions checkbox row
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _termsAccepted,
                            onChanged: isLoading
                                ? null
                                : (val) {
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
                              showSmoothDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (context) => TermsAndConditionsDialog(
                                  onDismiss: () => Navigator.of(context).pop(),
                                  onAccept: () {
                                    setState(() {
                                      _termsAccepted = true;
                                      _termsError = null;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                ),
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: vColors?.grayText ?? AppTheme.lightCustomColors.grayText,
                                      fontSize: 14.0,
                                    ),
                                children: [
                                  const TextSpan(text: 'I have read and agree with the '),
                                  TextSpan(
                                    text: 'terms and conditions',
                                    style: TextStyle(
                                      color: vColors?.termsLink ?? AppTheme.lightCustomColors.termsLink,
                                      decoration: TextDecoration.underline,
                                      fontSize: 14.0,
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
                    const Spacer(),
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;

                        return PrimaryAuthButton(
                          label: 'Sign up',
                          isLoading: isLoading,
                          onTap: () => _submit(cubit),
                        );
                      },
                    ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
