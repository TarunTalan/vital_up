import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
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
      context.read<AuthCubit>().reset();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    context.read<AuthCubit>().clearAllFields();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vColors = Theme.of(context).extension<VitalUpColors>();
    final colors = Theme.of(context).colorScheme;

    // Figma: title changes per tab
    final headerTitle =
        _selectedTab == 0 ? 'Welcome Back' : 'Create an account';

    // Figma tab bar colours from VitalUpColors
    final tabTextActive =
        vColors?.tabTextActive ?? AppTheme.lightCustomColors.tabTextActive!;
    final tabTextInactive =
        vColors?.tabTextInactive ?? AppTheme.lightCustomColors.tabTextInactive!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.goNamed('onboarding');
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
        body: AuthBackground(
          // Figma login screen: floating cyan + mint ellipses
          style: AuthBackgroundStyle.ellipses,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Header with back arrow + left-aligned title
                    AuthHeader(
                      headerText: headerTitle,
                      onBackClick: () => context.goNamed('onboarding'),
                    ),

                    // Tab switcher — Figma: shape 18dp, padding (16, 12, 16, 12)
                    Padding(
                      padding: EdgeInsets.only(
                        left: 16.0,
                        top: AppTheme.responsiveHeight(context, 8.0),
                        right: 16.0,
                        bottom: AppTheme.responsiveHeight(context, 8.0),
                      ),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBABABA).withValues(alpha: 0.13), // rgba(186, 186, 186, 0.13)
                          borderRadius: BorderRadius.circular(18), // RoundedCornerShape(size = 18.dp)
                          border: Border.all(
                            color: const Color(0xFFBABABA).withValues(alpha: 0.27), // rgba(186, 186, 186, 0.27)
                            width: 1.0, // 1dp
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          indicatorPadding: const EdgeInsets.all(4.0),
                          indicator: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(18), // RoundedCornerShape(size = 18.dp)
                          ),
                          labelColor: tabTextActive,
                          unselectedLabelColor: tabTextInactive,
                          labelStyle:
                              Theme.of(context).textTheme.labelLarge,
                          unselectedLabelStyle:
                              Theme.of(context).textTheme.labelLarge,
                          tabs: const [
                            Tab(text: 'Login'),
                            Tab(text: 'Sign up'),
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
                            onSignedIn: () => context.goNamed('dashboard'),
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
      ),
    );
  }
}
