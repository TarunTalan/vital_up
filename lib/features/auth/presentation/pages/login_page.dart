import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_header.dart';
import 'package:vital_up/features/auth/presentation/widgets/login_tab.dart';
import 'package:vital_up/features/auth/presentation/widgets/signup_screen.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedTab = _tabController.index;
      });
      context.read<AuthCubit>().reset();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final headerTitle = _selectedTab == 0 ? 'Welcome Back' : 'Create an account';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Go back to onboarding
        context.goNamed('onboarding');
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AuthBackground(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  AuthHeader(
                    headerText: headerTitle,
                    onBackClick: () => context.goNamed('onboarding'),
                  ),
                  // Custom Rounded Tab Switcher matches Compose design
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 25.0),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: colors.tertiary,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.outline, width: 2),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicatorPadding: const EdgeInsets.all(4.0),
                        indicator: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: colors.onSurface,
                        unselectedLabelColor: colors.onTertiary,
                        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        unselectedLabelStyle: Theme.of(context).textTheme.labelLarge,
                        tabs: const [
                          Tab(text: 'Login'),
                          Tab(text: 'Sign up'),
                        ],
                      ),
                    ),
                  ),
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
    );
  }
}
