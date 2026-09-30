import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_bottom_nav.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/nutrition_summary_card.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_scanner_page.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/profile/presentation/pages/profile_page.dart';
import '../widgets/screen_time_card.dart';
import '../widgets/sleep_card.dart';
import '../widgets/water_intake_card.dart';

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
    // Syncs the profile (incl. calorie goal) into the local cache that the
    // nutrition card reads.
    _profileCubit = sl<ProfileCubit>()..loadProfile();
  }

  @override
  void dispose() {
    _dietPlanCubit.close();
    _profileCubit.close();
    super.dispose();
  }

  static const _items = [
    AppBottomNavItem('Home', 'assets/icons/home.svg'),
    AppBottomNavItem('Scan', 'assets/icons/scanner.svg'),
    AppBottomNavItem('Vita', 'assets/icons/vita.svg'),
    AppBottomNavItem('Profile', 'assets/icons/profile.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.goNamed('onboarding');
        }
      },
      child: MultiBlocProvider(
        providers: [
          BlocProvider<DietPlanCubit>.value(
            value: _dietPlanCubit,
          ),
          BlocProvider<WaterIntakeCubit>(
            create: (context) {
              final authState = context.read<AuthCubit>().state;
              final userId = authState is AuthAuthenticated ? authState.user.id : 'unknown';
              return sl<WaterIntakeCubit>()..loadData(userId);
            },
          ),
          BlocProvider<ScreenTimeCubit>(
            create: (context) => sl<ScreenTimeCubit>()..loadStats(),
          ),
          BlocProvider<SleepCubit>(
            create: (context) => sl<SleepCubit>()..loadSleepData(),
          ),
        ],
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
            backgroundColor: context.theme.scaffoldBackgroundColor,
            extendBody: true,
            body: _buildSelectedTab(context),
            bottomNavigationBar: _selectedIndex == 1
                ? null
                : AppBottomNav(
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
      ),
    );
  }

  Widget _buildSelectedTab(BuildContext context) {
    return switch (_selectedIndex) {
      0 => BlocProvider<MealLogBloc>(
          create: (_) => sl<MealLogBloc>()..add(const LoadTodaysMeals()),
          child: BlocListener<ProfileCubit, ProfileState>(
            bloc: _profileCubit,
            listenWhen: (_, state) => state is ProfileLoaded,
            // Re-read so the calorie goal appears once the profile syncs.
            listener: (context, _) =>
                context.read<MealLogBloc>().add(const LoadTodaysMeals()),
            child: _HomeTab(
              onScanMeal: () => setState(() => _selectedIndex = 1),
            ),
          ),
        ),
      1 => FoodScannerPage(
          onBack: () => setState(() => _selectedIndex = 0),
        ),
      2 => _SimpleTab(
          title: 'Vita',
          subtitle: 'Your personal health assistant.',
          icon: Icons.favorite_rounded,
          buttonLabel: 'Generate AI Diet Plan',
          onButtonTap: () => context.pushNamed('diet-plan-prefs'),
        ),
      _ => BlocProvider.value(
          value: _profileCubit,
          child: ProfilePage(onLogout: () => _showLogoutDialog(context)),
        ),
    };
  }

  void _showLogoutDialog(BuildContext context) {
    final errorColor = context.colors.error;
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
            style: TextButton.styleFrom(foregroundColor: errorColor),
            onPressed: () {
              Navigator.of(context).pop();
              cubit.logout();
            },
            child: const Text('Logout'),
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
    // With Scaffold.extendBody the floating nav bar height is reported as
    // bottom padding, so content always clears it.
    final bottomInset = context.safePadding.bottom + AppDimens.sectionGap;

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg.png',
            fit: BoxFit.cover,
          ),
        ),
        Column(
          children: [
            AppPageHeader(
              showBack: false,
              title: _greeting(DateTime.now()),
              subtitle: DateFormat('EEEE, MMMM d').format(DateTime.now()),
              action: const AppHeaderAction(
                tooltip: 'Calendar',
                icon: _SvgIcon('assets/icons/calendar.svg'),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: AppDimens.sectionGap,
                  bottom: bottomInset,
                ),
                child: ResponsiveCenter(
                  child: Padding(
                    padding: context.pagePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _InsightCard(),
                        const SizedBox(height: AppDimens.cardGap),
                        NutritionSummaryCard(
                          onViewAll: () {
                            context.pushNamed('meal-log-history');
                          },
                          onScanMeal: onScanMeal,
                        ),
                        const SizedBox(height: AppDimens.cardGap),
                        BlocBuilder<DietPlanCubit, DietPlanState>(
                          builder: (context, state) {
                            if (state is DietPlanLoaded) {
                              return _ActiveDietPlanCard(
                                plan: state.mealPlan,
                                onTap: () {
                                  context.pushNamed('diet-plan-result', extra: {
                                    'plan': state.mealPlan,
                                  });
                                },
                              );
                            }
                            return _DietPlanCard(
                              onTap: () {
                                context.pushNamed('diet-plan-prefs');
                              },
                            );
                          },
                        ),
                        const SizedBox(height: AppDimens.sectionGap),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _QuickActionTile(
                                label: 'Steps',
                                iconAsset: 'assets/icons/footprints.svg',
                              ),
                              const _QuickActionTile(
                                label: 'Water',
                                iconAsset: 'assets/icons/drop.svg',
                              ),
                              _QuickActionTile(
                                label: 'Workout',
                                iconAsset: 'assets/icons/barbell.svg',
                                onTap: () => context.pushNamed('activity-tracking'),
                              ),
                              const _QuickActionTile(
                                label: 'Mood',
                                iconAsset: 'assets/icons/smiley.svg',
                              ),
                              const _QuickActionTile(
                                label: 'Sleep',
                                iconAsset: 'assets/icons/moon_stars.svg',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimens.sectionGap),
                        Divider(
                          color: context.vColors.divider,
                          height: AppDimens.borderThin,
                          thickness: AppDimens.borderThin,
                        ),
                        const SizedBox(height: AppDimens.sectionGap),
                        const _DashboardSegmentedTabs(),
                        const SizedBox(height: AppDimens.sectionGap),
                        const WaterIntakeCard(),
                        const SizedBox(height: AppDimens.cardGap),
                        const SleepCard(),
                        const SizedBox(height: AppDimens.cardGap),
                        const ScreenTimeCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// SVG that picks up the surrounding [IconTheme] colour and size.
class _SvgIcon extends StatelessWidget {
  final String asset;
  const _SvgIcon(this.asset);

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = iconTheme.size ?? AppDimens.iconLg;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        iconTheme.color ?? context.colors.primary,
        BlendMode.srcIn,
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppCaption("Today's insights"),
          const SizedBox(height: AppDimens.cardInnerGap),
          Text(
            "You've been most active between 9-11am this week. "
            'Consider scheduling important tasks during this time '
            'when your energy is naturally higher.',
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurface),
          ),
        ],
      ),
    );
  }
}

/// Figma quick-action tile: 80w glass tile, 40 icon badge + small 12 label.
class _QuickActionTile extends StatelessWidget {
  final String label;
  final String iconAsset;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.label,
    required this.iconAsset,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: context.w(AppDimens.quickActionWidth),
      margin: const EdgeInsets.only(right: AppDimens.space8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space4,
        vertical: AppDimens.space20,
      ),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: double.infinity),
          AppIconBadge(icon: _SvgIcon(iconAsset)),
          const SizedBox(height: AppDimens.space12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: context.text.labelSmall
                  ?.copyWith(color: context.colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSegmentedTabs extends StatelessWidget {
  const _DashboardSegmentedTabs();

  @override
  Widget build(BuildContext context) {
    const tabs = ['Move', 'Rest', 'Fuel', 'Vitals'];
    const selected = 'Rest';
    final v = context.vColors;

    return Container(
      padding: const EdgeInsets.all(AppDimens.space8),
      decoration: BoxDecoration(
        color: v.glassFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: v.glassBorder!),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: Container(
                constraints:
                    const BoxConstraints(minHeight: AppDimens.segmentHeight),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimens.space4),
                decoration: BoxDecoration(
                  color: tab == selected
                      ? context.colors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  boxShadow: tab == selected ? AppShadows.segment : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tab,
                    maxLines: 1,
                    style: context.text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: tab == selected
                          ? v.buttonText
                          : context.colors.onSurface,
                    ),
                  ),
                ),
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
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.gutter),
          child: ResponsiveCenter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconBadge(
                  size: AppDimens.iconBadgeLarge * 2,
                  icon: Icon(icon),
                ),
                const SizedBox(height: AppDimens.space16),
                Text(title, style: context.text.headlineSmall),
                const SizedBox(height: AppDimens.space8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.vColors.grayText),
                ),
                if (buttonLabel != null && onButtonTap != null) ...[
                  const SizedBox(height: AppDimens.sectionGap),
                  AppPrimaryButton(
                    label: buttonLabel!,
                    onTap: onButtonTap!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared row layout for the diet-plan cards.
class _DietPlanRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  const _DietPlanRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    return Row(
      children: [
        AppIconBadge(color: accent, icon: Icon(icon)),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.text.titleSmall?.copyWith(color: onSurface),
              ),
              const SizedBox(height: AppDimens.space4),
              Text(
                subtitle,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.vColors.grayText),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimens.space8),
        Icon(Icons.arrow_forward_ios, color: onSurface, size: AppDimens.iconXs),
      ],
    );
  }
}

class _DietPlanCard extends StatelessWidget {
  final VoidCallback onTap;

  const _DietPlanCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      onTap: onTap,
      child: _DietPlanRow(
        icon: Icons.restaurant_menu,
        accent: context.colors.primary,
        title: 'AI Diet Plan',
        subtitle: 'Generate your personalized meal plan',
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
    final v = context.vColors;
    return AppCard(
      width: double.infinity,
      padding: AppDimens.cardPaddingCompact,
      tint: v.successTint,
      borderColor: v.success!.withValues(alpha: 0.3),
      onTap: onTap,
      child: _DietPlanRow(
        icon: Icons.restaurant,
        accent: v.success!,
        title: 'Active Diet Plan',
        subtitle: '${plan.totalCalories} kcal • ${plan.meals.length} meals',
      ),
    );
  }
}

String _greeting(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
