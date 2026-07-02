import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/features/auth/presentation/widgets/animated_tick.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_header.dart';
import 'package:vital_up/features/auth/presentation/widgets/primary_auth_button.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';

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
        context.goNamed('login');
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
                    headerText: 'Reset Password',
                    onBackClick: () => context.goNamed('login'),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 28),
                          Text(
                            'Your password has been changed successfully.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                          AnimatedTick(
                            play: _playAnimation,
                            totalSize: 115,
                            tickSize: 55,
                          ),
                          const SizedBox(height: 40),
                          PrimaryAuthButton(
                            label: 'Back to Login',
                            isLoading: false,
                            onTap: () {
                              context.goNamed('login');
                            },
                          ),
                        ],
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
