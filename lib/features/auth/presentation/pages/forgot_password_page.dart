import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
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
  /// Kept for dispose, where looking up the widget tree isn't allowed.
  late final AuthCubit _authCubit = context.read<AuthCubit>();

  @override
  void initState() {
    super.initState();
    // Clear fields and errors when entering this page
    _authCubit.clearAllFields();
  }

  @override
  void dispose() {
    // Clear fields and errors when leaving this page
    _authCubit.clearAllFields();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    _authCubit.requestForgotPassword(
      onSuccess: (token) {
        if (!mounted) return;
        // Encoded: a "+" in the email would decode to a space.
        context.push(
          Uri(
            path: '/verify-otp',
            queryParameters: {
              'email': _authCubit.emailVal,
              'token': token,
              'flow': 'forgot',
            },
          ).toString(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    final state = context.watch<AuthCubit>().state;
    final isLoading = state is AuthLoading;
    final colors = context.colors;

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
          child: ResponsiveCenter(
              child: Column(
                children: [
                  AuthHeader(
                    headerText: 'Forgot Password',
                    onBackClick: () => context.goNamed('login'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              child: Padding(
                                padding: context.pagePadding,
                                child: Column(
                                  children: [
                                    SizedBox(height: context.h(AppDimens.space32)),
                                    Text(
                                      'Please enter your registered email to receive a verification code.',
                                      style: context.text.bodyLarge?.copyWith(
                                            color: colors.onSurface,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: context.h(AppDimens.space32)),
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
                                              onSubmitted: (_) => _submit(),
                                              onChange: cubit.onEmailChange,
                                              error: errorSnapshot.data,
                                              validate: cubit.validateEmail,
                                              enabled: !isLoading,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    SizedBox(height: context.h(AppDimens.space32)),
                                    // Action Button
                                    BlocBuilder<AuthCubit, AuthState>(
                                      builder: (context, state) {
                                        final isLoading = state is AuthLoading;
                
                                        return PrimaryAuthButton(
                                          label: 'Send',
                                          isLoading: isLoading,
                                          onTap: _submit,
                                        );
                                      },
                                    ),
                                    SizedBox(height: context.h(AppDimens.space32)),
                                  ],
                                ),
                              ),
                    ),
                  ),
                ],
              ),
          ),
        ),
        ),
      ),
    );
  }
}
