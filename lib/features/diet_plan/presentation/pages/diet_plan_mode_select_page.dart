import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';

class DietPlanModeSelectPage extends StatelessWidget {
  final Map<String, dynamic> preferences;

  const DietPlanModeSelectPage({super.key, required this.preferences});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: const Text('Choose Mode'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.hPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('How would you like to set your targets?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              _ModeCard(
                title: 'Smart Mode',
                subtitle: 'Uses your health profile to calculate the perfect maintenance plan.',
                icon: Icons.auto_awesome,
                onTap: () {
                  context.pushNamed(
                    'diet-plan-result',
                    extra: {
                      'mode': 'smart',
                      'preferences': preferences,
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              _ModeCard(
                title: 'Goal Mode',
                subtitle: 'Set a weight goal and timeframe. We calculate the optimal deficit/surplus.',
                icon: Icons.track_changes,
                onTap: () {
                  context.pushNamed(
                    'diet-plan-goal',
                    extra: preferences,
                  );
                },
              ),
              const SizedBox(height: 16),
              _ModeCard(
                title: 'Manual Mode',
                subtitle: 'I know exactly what I want. Let me enter my macros directly.',
                icon: Icons.edit_note,
                onTap: () {
                  context.pushNamed(
                    'diet-plan-manual',
                    extra: preferences,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cardColor = theme.cardTheme.color ?? Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF777777))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
