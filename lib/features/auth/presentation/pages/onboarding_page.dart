import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';

enum OnboardingItem {
  page1(
    icon: 'assets/images/onboarding1.png',
    description: 'Track your nutrition effortlessly with our smart scanner.',
  ),
  page2(
    icon: 'assets/images/onboarding2.png',
    description: 'Your AI health coach, guiding every step of your journey.',
  ),
  page3(
    icon: 'assets/images/onboarding3.png',
    description: 'Understand your body with clearer health insights.',
  ),
  page4(
    icon: 'assets/images/onboarding4.png',
    description: 'Join live sessions and learn directly from certified coaches.',
  );

  final String icon;
  final String description;

  const OnboardingItem({
    required this.icon,
    required this.description,
  });
}

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinish;
  final VoidCallback onGoogleSignInSuccess;

  const OnboardingPage({
    super.key,
    required this.onFinish,
    required this.onGoogleSignInSuccess,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final v = context.vColors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (!context.mounted) return;
          if (state is AuthError) {
            showSmoothSnackBar(
              context,
              message: state.message,
              iconColor: colors.error,
              icon: Icons.error_outline_rounded,
            );
            context.read<AuthCubit>().reset();
          } else if (state is AuthAuthenticated) {
            widget.onGoogleSignInSuccess();
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: OnboardingItem.values.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = OnboardingItem.values[index];
                        return Image.asset(
                          item.icon,
                          fit: BoxFit.cover,
                          alignment: Alignment.bottomCenter,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback in case the images are missing.
                            return ColoredBox(
                              color: colors.secondary.withValues(alpha: 0.2),
                              child: Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: AppDimens.iconXxl,
                                  color: colors.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  SizedBox(height: context.h(AppDimens.space24)),

                  // Page indicators — Figma: 16dp active, 12dp inactive.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      OnboardingItem.values.length,
                      (index) {
                        final isActive = _currentPage == index;
                        final size = isActive
                            ? AppDimens.pageIndicatorActive
                            : AppDimens.pageIndicatorInactive;

                        return AnimatedContainer(
                          duration: AppDurations.medium,
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppDimens.space16,
                          ),
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? colors.primary : v.indicatorInactive,
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: context.h(AppDimens.space24)),

                  // Description — Figma heading 2, centred.
                  SizedBox(
                    height: context.h(120),
                    child: Padding(
                      padding: context.pagePadding,
                      child: Text(
                        OnboardingItem.values[_currentPage].description,
                        style: context.text.headlineMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  SizedBox(height: context.h(AppDimens.space24)),

                  // Figma "two cta": primary + Google secondary + footnote.
                  Padding(
                    padding: context.pagePadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PrimaryAuthButton(
                          label: 'Get Started',
                          isLoading: false,
                          enabled: !isLoading,
                          onTap: widget.onFinish,
                        ),
                        const SizedBox(height: AppDimens.buttonGap),
                        AppSecondaryButton(
                          label: 'Continue with Google',
                          isLoading: isLoading,
                          containerColor: colors.surface,
                          borderColor: v.hairline,
                          contentColor: v.preText,
                          leadingIcon: SvgPicture.asset(
                            'assets/icons/google.svg',
                            width: AppDimens.iconXs,
                            height: AppDimens.iconXs,
                            placeholderBuilder: (context) => Icon(
                              Icons.g_mobiledata,
                              size: AppDimens.iconXs,
                              color: v.preText,
                            ),
                          ),
                          onTap: () => context.read<AuthCubit>().signInWithGoogle(
                                // The AuthAuthenticated listener above
                                // navigates; calling it here too would run
                                // the post-sign-in navigation twice.
                                onSuccess: () {},
                              ),
                        ),
                        const SizedBox(height: AppDimens.buttonGap),
                        Text(
                          'Your health data is encrypted and never sold.',
                          style: context.text.bodySmall?.copyWith(
                            color: v.grayText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimens.space16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
