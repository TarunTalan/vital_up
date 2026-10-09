import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/input_rules.dart';
import 'package:vital_up/core/utils/responsive.dart';
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
        _termsError = 'Accept the terms and conditions to continue';
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
    final colors = context.colors;
    final v = context.vColors;

    return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(horizontal: context.gutter),
                child: Column(
                  children: [
                    SizedBox(height: context.h(AppDimens.space20)),
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
                                      maxLength: InputLimits.usernameMax,
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
                    const SizedBox(height: AppDimens.space12),
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
                    const SizedBox(height: AppDimens.space12),
                    // Terms and Conditions checkbox row
                    Row(
                      children: [
                        SizedBox.square(
                          dimension: AppDimens.iconLg,
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
                            checkColor: v.buttonText,
                            side: BorderSide(
                              color: _termsError != null ? colors.error : v.grayText!,
                              width: AppDimens.borderThin,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimens.space8),
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
                                style: context.text.bodyMedium?.copyWith(
                                  color: v.grayText,
                                ),
                                children: [
                                  const TextSpan(text: 'I have read and agree with the '),
                                  TextSpan(
                                    text: 'terms and conditions',
                                    style: context.text.bodyMedium?.copyWith(
                                      color: v.termsLink,
                                      decoration: TextDecoration.underline,
                                      decorationColor: v.termsLink,
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
                          padding: const EdgeInsets.only(top: AppDimens.inputLabelGap),
                          child: Text(
                            _termsError!,
                            style: context.text.bodyLarge?.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppDimens.space20),
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
                    const SizedBox(height: AppDimens.space20),
                  ],
                ),
        );
  }
}
