import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
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
    final colors = Theme.of(context).colorScheme;
    final customColors = Theme.of(context).extension<VitalUpColors>();

    // Dimensions mimicking Compose rDp and rSp definitions
    const double horizontalPadding = 20.0;
    const double smallSpacing = 12.0;

    final double descriptionFontSize = (MediaQuery.of(context).size.width * 0.055).clamp(18.0, 26.0);
    const double buttonTextSize = 15.0;
    const double buttonHeight = 52.0;

    const double indicatorSizeActive = 14.0;
    const double indicatorSizeInactive = 10.0;
    const double indicatorSpacing = 10.0;
    const double bottomPadding = 20.0;

    return Scaffold(
      backgroundColor: colors.surface,
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (!context.mounted) return;
          if (state is AuthError) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1C1C1C), // Modern elegant dark slate
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0), // RoundedCornerShape matching textfields
                ),
                margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                content: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.message,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            context.read<AuthCubit>().reset();
          } else if (state is AuthAuthenticated) {
            widget.onGoogleSignInSuccess();
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
  
          return SafeArea(
            bottom: true,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    // Horizontal Image PageView (Fixed proportion of screen)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.52,
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
                              // Fallback container in case the user has not yet dropped the images
                              return Container(
                                color: colors.secondary.withValues(alpha: 0.2),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 64,
                                        color: colors.onSurface.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Onboarding Image ${index + 1}\n(Place in assets/images/${item.icon.split('/').last})',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: colors.onSurface.withValues(alpha: 0.6),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    
                    const Spacer(flex: 1),
    
                    // Page Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        OnboardingItem.values.length,
                        (index) {
                          final isActive = _currentPage == index;
                          final indicatorColor = isActive ? colors.primary : colors.outline;
                          final size = isActive ? indicatorSizeActive : indicatorSizeInactive;
    
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: indicatorSpacing / 2),
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: indicatorColor,
                            ),
                          );
                        },
                      ),
                    ),
    
                    const Spacer(flex: 1),
    
                    // Description Text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Text(
                        OnboardingItem.values[_currentPage].description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: descriptionFontSize,
                              fontWeight: FontWeight.w500, // Medium
                              color: colors.onSurface,
                              height: 1.2,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
    
                    const Spacer(flex: 2),
    
                    // Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PrimaryAuthButton(
                            label: 'Get Started',
                            isLoading: false,
                            enabled: !isLoading,
                            onTap: widget.onFinish,
                          ),
                          const SizedBox(height: smallSpacing),
                          SizedBox(
                            width: double.infinity,
                            height: buttonHeight,
                            child: OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.read<AuthCubit>().signInWithGoogle(
                                        onSuccess: widget.onGoogleSignInSuccess,
                                      ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: colors.outline, width: 1.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? SizedBox(
                                      width: buttonHeight * 0.5,
                                      height: buttonHeight * 0.5,
                                      child: CircularProgressIndicator(
                                        color: colors.primary,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          'assets/icons/google.svg',
                                          width: buttonHeight * 0.4,
                                          height: buttonHeight * 0.4,
                                          placeholderBuilder: (context) => Icon(
                                            Icons.g_mobiledata,
                                            size: buttonHeight * 0.5,
                                            color: customColors?.preText,
                                          ),
                                        ),
                                        const SizedBox(width: smallSpacing),
                                        Text(
                                          'Continue with Google',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                color: customColors?.preText ?? const Color(0xFF0F7586),
                                                fontSize: buttonTextSize,
                                                fontWeight: FontWeight.normal,
                                              ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
    
                    const Spacer(flex: 1),
    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Text(
                        'Your health data is encrypted and never sold.',
                        style: TextStyle(
                          fontFamily: 'SFProRounded',
                          fontWeight: FontWeight.w400,
                          fontSize: 12.0,
                          height: 1.0,
                          color: customColors?.grayText ?? const Color(0xFF757575),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
    
                    const SizedBox(height: bottomPadding),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
