import 'package:flutter/material.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_header.dart';
import 'package:vital_up/features/auth/presentation/widgets/login_tab.dart';
import 'package:vital_up/features/auth/presentation/widgets/signup_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _selectedTab = _tabController.index);
      context.read<AuthCubit>().clearAllFields();
    });
    // Clear all fields on entry
    context.read<AuthCubit>().clearAllFields();
  }

  @override
  void dispose() {
    _tabController.dispose();
    context.read<AuthCubit>().clearAllFields();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final colors = context.colors;

    // Figma: title changes per tab
    final headerTitle =
        _selectedTab == 0 ? 'Welcome Back' : 'Create an account';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (MediaQuery.of(context).viewInsets.bottom > 0.0) {
          FocusScope.of(context).unfocus();
        } else {
          context.goNamed('onboarding');
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
        body: AuthBackground(
          style: AuthBackgroundStyle.ellipses,
          child: ResponsiveCenter(
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    AuthHeader(
                      headerText: headerTitle,
                      onBackClick: () => context.goNamed('onboarding'),
                    ),

                    // Figma Tabs/Default: glass track, radius 20, 4dp inset,
                    // cyan 48dp selected pill (radius 18).
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.gutter,
                        context.h(AppDimens.space32),
                        context.gutter,
                        0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppDimens.space4),
                        decoration: BoxDecoration(
                          color: v.glassFill,
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusInput),
                          border: Border.all(
                            color: v.glassBorder!,
                            width: AppDimens.borderThin,
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          overlayColor:
                              const WidgetStatePropertyAll(Colors.transparent),
                          splashBorderRadius:
                              BorderRadius.circular(AppDimens.radiusTab),
                          indicator: BoxDecoration(
                            color: colors.primary,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusTab),
                          ),
                          labelColor: AppColors.lighter,
                          unselectedLabelColor: v.grayText,
                          labelStyle: context.text.titleSmall,
                          unselectedLabelStyle: context.text.bodyLarge,
                          tabs: const [
                            Tab(height: AppDimens.buttonHeight, text: 'Login'),
                            Tab(height: AppDimens.buttonHeight, text: 'Sign up'),
                          ],
                        ),
                      ),
                    ),

                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          LoginTab(
                            onSignedIn: () async {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(
                                  child: VitalUpLoader(),
                                ),
                              );
                              final completed = await context
                                  .read<AuthCubit>()
                                  .hasCompletedOnboarding();
                              if (context.mounted) {
                                Navigator.of(context).pop(); // Close loader
                                context.goNamed(
                                  completed ? 'dashboard' : 'health-onboarding',
                                );
                              }
                            },
                          ),
                          SignupScreen(
                            onOTPSent: (token, email) {
                              context.push(
                                '/verify-otp?email=$email&token=$token&flow=signup',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ),
        ),
        ),
      ),
    );
  }
}
