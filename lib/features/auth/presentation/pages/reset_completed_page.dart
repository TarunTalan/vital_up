import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
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
  bool _showContent = false;

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
    final colors = context.colors;
    final animationDuration = const Duration(milliseconds: 600);

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
          child: ResponsiveCenter(
              child: Column(
                children: [
                  AnimatedOpacity(
                    opacity: _showContent ? 1.0 : 0.0,
                    duration: animationDuration,
                    child: AuthHeader(
                      headerText: 'Password Changed',
                      onBackClick: () => context.goNamed('dashboard'),
                    ),
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
                                    AnimatedOpacity(
                                      opacity: _showContent ? 1.0 : 0.0,
                                      duration: animationDuration,
                                      child: Text(
                                        'Your password has been changed successfully.',
                                        style: context.text.bodyLarge?.copyWith(
                                              color: colors.onSurface,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(height: context.h(AppDimens.space32)),
                                    // The tick is always rendered in its final spot
                                    AnimatedTick(
                                      play: _playAnimation,
                                      completed: _showContent,
                                      totalSize: AppDimens.successBadge,
                                      tickSize: AppDimens.successTick,
                                      onFinished: () {
                                        if (mounted) {
                                          setState(() {
                                            _showContent = true;
                                          });
                                        }
                                      },
                                    ),
                                    SizedBox(height: context.h(AppDimens.space32)),
                                    AnimatedOpacity(
                                      opacity: _showContent ? 1.0 : 0.0,
                                      duration: animationDuration,
                                      child: PrimaryAuthButton(
                                        label: 'Go to Dashboard',
                                        isLoading: false,
                                        onTap: () {
                                          context.goNamed('dashboard');
                                        },
                                      ),
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
    );
  }
}
