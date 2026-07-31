import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_scanner_page.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/nutrition_summary_card.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/pages/profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DietPlanCubit _dietPlanCubit;
  late final ProfileCubit _profileCubit;
  int _selectedIndex = 0;
  final List<int> _navigationQueue = [0];

  @override
  void initState() {
    super.initState();
    _dietPlanCubit = sl<DietPlanCubit>()..loadActiveMealPlan();
    _profileCubit = sl<ProfileCubit>();
  }

  @override
  void dispose() {
    _dietPlanCubit.close();
    _profileCubit.close();
    super.dispose();
  }

  static const _items = [
    _BottomNavItem('Home', 'assets/icons/home.svg'),
    _BottomNavItem('Scan', 'assets/icons/scanner.svg'),
    _BottomNavItem('Vita', 'assets/icons/vita.svg'),
    _BottomNavItem('Profile', 'assets/icons/profile.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.goNamed('onboarding');
        }
      },
      child: PopScope(
        canPop: _navigationQueue.length <= 1,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_navigationQueue.length > 1) {
            setState(() {
              _navigationQueue.removeLast();
              _selectedIndex = _navigationQueue.last;
            });
          }
        },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          extendBody: true,
          body: _buildSelectedTab(context),
          bottomNavigationBar: _selectedIndex == 1
              ? null
              : _BottomNavBar(
                  items: _items,
                  selectedIndex: _selectedIndex,
                  onItemSelected: (index) {
                    if (_selectedIndex == index) return;
                    setState(() {
                      _navigationQueue.remove(index);
                      _navigationQueue.add(index);
                      _selectedIndex = index;
                    });
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSelectedTab(BuildContext context) {
    return switch (_selectedIndex) {
      0 => BlocProvider<MealLogBloc>(
          create: (_) => sl<MealLogBloc>()..add(const LoadTodaysMeals()),
          child: _HomeTab(
            onScanMeal: () => setState(() => _selectedIndex = 1),
          ),
        ),
      1 => FoodScannerPage(
          onBack: () => setState(() => _selectedIndex = 0),
        ),
      2 => const _SimpleTab(
          title: 'Vita',
          subtitle: 'Your personal health assistant.',
          icon: Icons.favorite_rounded,
        ),
      _ => BlocProvider.value(
          value: _profileCubit,
          child: ProfilePage(onLogout: () => _showLogoutDialog(context)),
        ),
    };
  }

  void _showLogoutDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cubit = context.read<AuthCubit>();

    showSmoothDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              cubit.logout();
            },
            child: Text(
              'Logout',
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final VoidCallback? onScanMeal;
  const _HomeTab({this.onScanMeal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final customColors = theme.extension<VitalUpColors>();

    return Stack(
      children: [
        // Background - Full Screen
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg.png',
            fit: BoxFit.cover,
          ),
        ),
        // Scrollable Content
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 150, 20, 128), // 150pt top padding to start below fixed header
            children: [
              const _InsightCard(),
              const SizedBox(height: 16),
              NutritionSummaryCard(
                onViewAll: () {
                  context.pushNamed('meal-log-history');
                },
                onScanMeal: onScanMeal,
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    const _MetricChip(
                      label: 'Steps',
                      iconAsset: 'assets/icons/active.svg',
                    ),
                    const _MetricChip(
                      label: 'Water',
                      iconAsset: 'assets/icons/drop.svg',
                    ),
                    _MetricChip(
                      label: 'Workout',
                      iconAsset: 'assets/icons/moderate.svg',
                      onTap: () => context.pushNamed('activity-tracking'),
                    ),
                    const _MetricChip(
                      label: 'Mood',
                      iconAsset: 'assets/icons/smile.svg',
                    ),
                    const _MetricChip(
                      label: 'Sleep',
                      iconAsset: 'assets/icons/sleep.svg',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Divider(
                color: colors.outline.withValues(alpha: 0.45),
                height: 1,
              ),
              const SizedBox(height: 24),
              const _DashboardSegmentedTabs(),
              const SizedBox(height: 25),
              const _RestMetricCard(
                title: 'Sleep',
                value: '6h 43m',
                subtitle: 'Good night of rest',
                iconAsset: 'assets/icons/sleep.svg',
                progress: 0.72,
              ),
              const SizedBox(height: 12),
              const _RestMetricCard(
                title: 'Screen Time',
                value: '3h 54m',
                subtitle: 'About usual for you',
                iconAsset: 'assets/icons/Watch.svg',
                progress: 0.72,
              ),
            ],
          ),
        ),
        // Fixed Top Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.7),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Good morning',
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontSize: 28,
                                height: 1.08,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tuesday, January 13',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: customColors?.grayText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          color: colors.primary,
                          size: 25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 17, 12, 17),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFD8D8D8).withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S INSIGHTS",
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.7,
              color: const Color(0xFF777777),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "You've been most active between 9-11am this week.\n"
            'Consider scheduling important tasks during this time\n'
            'when your energy is naturally higher.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 1.25,
              color: const Color(0xFF101010),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String iconAsset;
  final VoidCallback? onTap;

  const _MetricChip({
    required this.label,
    required this.iconAsset,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 9),
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: const Color(0xFFD8D8D8).withValues(alpha: 0.78),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  iconAsset,
                  width: 22,
                  height: 22,
                  colorFilter:
                      ColorFilter.mode(colors.primary, BlendMode.srcIn),
                ),
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                fontSize: 12,
                color: const Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSegmentedTabs extends StatelessWidget {
  const _DashboardSegmentedTabs();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const tabs = ['Move', 'Rest', 'Fuel', 'Vitals'];

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD8D8D8).withValues(alpha: 0.76),
        ),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tab == 'Rest' ? colors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tab,
                  style: textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RestMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String iconAsset;
  final double progress;

  const _RestMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.iconAsset,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 196),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 20, 52, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFD8D8D8).withValues(alpha: 0.78),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8F2DC),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    iconAsset,
                    width: 23,
                    height: 23,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF111111),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF161616),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: const Color(0xFF47B85A),
              backgroundColor: colors.outline.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 14,
              color: const Color(0xFF777777),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleTab extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;

  const _SimpleTab({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.buttonLabel,
    this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<VitalUpColors>();

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.hPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: customColors?.grayText,
                ),
              ),
              if (buttonLabel != null && onButtonTap != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: AppTheme.buttonHeight,
                  child: FilledButton(
                    onPressed: onButtonTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: customColors?.buttonText,
                    ),
                    child: Text(buttonLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder _ProfileTab has been replaced by ProfilePage

class _BottomNavBar extends StatelessWidget {
  final List<_BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _BottomNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavItem(
                        item: items[i],
                        selected: selectedIndex == i,
                        onTap: () => onItemSelected(i),
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

class _NavItem extends StatelessWidget {
  final _BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor =
        selected ? theme.colorScheme.primary : const Color(0xFF111111);
    final textColor =
        selected ? const Color(0xFF111111) : const Color(0xFF4E4E4E);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedScale(
        scale: selected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: selected ? 26 : 22,
                  end: selected ? 26 : 22,
                ),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (context, iconSize, child) {
                  return SvgPicture.asset(
                    item.iconAsset,
                    width: iconSize,
                    height: iconSize,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  );
                },
              ),
              const SizedBox(height: 1),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                style: theme.textTheme.labelSmall!.copyWith(
                  fontSize: 12,
                  color: textColor,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final String label;
  final String iconAsset;

  const _BottomNavItem(this.label, this.iconAsset);
}

class _DietPlanCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DietPlanCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_menu, color: colors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Diet Plan', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Generate a personalized meal plan', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: colors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ActiveDietPlanCard extends StatelessWidget {
  final dynamic plan;
  final VoidCallback onTap;

  const _ActiveDietPlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFD8F2DC),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF47B85A).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF47B85A).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant, color: Color(0xFF111111)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Diet Plan', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF111111))),
                  const SizedBox(height: 4),
                  Text('${plan.totalCalories} kcal • ${plan.meals.length} meals', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF4E4E4E))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF111111), size: 16),
          ],
        ),
      ),
    );
  }
}
