import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/widgets/animated_tick.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_header.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';

class ResetCompletedPage extends StatefulWidget {
  const ResetCompletedPage({super.key});

  @override
  State<ResetCompletedPage> createState() => _ResetCompletedPageState();
}

class _ResetCompletedPageState extends State<ResetCompletedPage> {
  bool _playAnimation = false;

  @override
  void initState() {
    super.initState();
    // Delay slightly to allow screen transition to complete before playing animation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _playAnimation = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.goNamed('dashboard');
      },
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
                    headerText: 'Password Changed',
                    onBackClick: () => context.goNamed('dashboard'),
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
                                      'Your password has been changed successfully.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: colors.onSurface,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20.0),
                                    AnimatedTick(
                                      play: _playAnimation,
                                      totalSize: 115,
                                      tickSize: 55,
                                    ),
                                    const Spacer(),
                                    PrimaryAuthButton(
                                      label: 'Go to Dashboard',
                                      isLoading: false,
                                      onTap: () {
                                        context.goNamed('dashboard');
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
