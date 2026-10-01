import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/services/biometric_auth_service.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';

class BiometricLockGuard extends StatefulWidget {
  final Widget child;

  const BiometricLockGuard({super.key, required this.child});

  @override
  State<BiometricLockGuard> createState() => _BiometricLockGuardState();
}

class _BiometricLockGuardState extends State<BiometricLockGuard>
    with WidgetsBindingObserver {
  late final BiometricAuthService _bioService;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bioService = sl<BiometricAuthService>();

    if (_bioService.isBiometricEnabled()) {
      _isLocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerUnlock();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_bioService.isBiometricEnabled()) return;

    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final elapsed = DateTime.now().difference(_pausedTime!);
        // Lock if app was in background for more than 15 seconds
        if (elapsed.inSeconds >= 15 && !_isLocked) {
          setState(() => _isLocked = true);
          _triggerUnlock();
        }
      }
      _pausedTime = null;
    }
  }

  Future<void> _triggerUnlock() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    final authenticated = await _bioService.authenticate(
      reason: 'Unlock VitalUp to access your health and fitness records',
    );

    _isAuthenticating = false;
    if (mounted && authenticated) {
      HapticFeedback.mediumImpact();
      setState(() => _isLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: _BiometricLockScreen(
              onUnlockPressed: _triggerUnlock,
            ),
          ),
      ],
    );
  }
}

class _BiometricLockScreen extends StatelessWidget {
  final VoidCallback onUnlockPressed;

  const _BiometricLockScreen({required this.onUnlockPressed});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF101418) : const Color(0xFFF4F8FA),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.space32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Biometric Avatar
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withAlpha(80),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(60),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 52,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.space24),
                Text(
                  'VitalUp is Locked',
                  style: context.text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppDimens.space8),
                Text(
                  'Biometric authentication is required to access your health data.',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: v.grayText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppDimens.space32),
                AppPrimaryButton(
                  label: 'Unlock with Biometrics',
                  leadingIcon: const Icon(
                    Icons.lock_open_rounded,
                    size: AppDimens.iconSm,
                  ),
                  onTap: onUnlockPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
