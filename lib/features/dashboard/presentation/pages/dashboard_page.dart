import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/database/collections/water_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_bottom_nav.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/features/activity_goals/presentation/cubit/activity_goals_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:vital_up/features/auth/presentation/cubit/auth_state.dart';
import 'package:vital_up/features/dashboard/data/services/trends_service.dart';
import 'package:vital_up/features/dashboard/domain/entities/sleep_session_info.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/screen_time_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/stress_checkin_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/trend_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/sleep_cubit.dart';
import 'package:vital_up/features/dashboard/presentation/cubit/water_intake_cubit.dart';
import 'package:vital_up/features/activity_goals/presentation/widgets/activity_goals_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/nutrition_summary_card.dart';
import 'package:vital_up/features/dashboard/presentation/widgets/stress_checkin_card.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_cubit.dart';
import 'package:vital_up/features/diet_plan/presentation/cubit/diet_plan_state.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_bloc.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_event.dart';
import 'package:vital_up/features/food_scanner/presentation/bloc/meal_log_state.dart';
import 'package:vital_up/features/food_scanner/domain/entities/meal_log_entry.dart';
import 'package:vital_up/features/food_scanner/presentation/pages/food_scanner_page.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:vital_up/features/profile/presentation/cubit/profile_state.dart';
import 'package:vital_up/features/profile/presentation/pages/profile_page.dart';
import 'package:vital_up/features/vita/presentation/pages/vita_home_page.dart';
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
            create: (context) => sl<WaterIntakeCubit>()..loadData(_userId(context)),
          ),
          BlocProvider<TrendCubit<WaterLogCache>>(
            create: (context) {
              final userId = _userId(context);
              return TrendCubit<WaterLogCache>(
                (range) => sl<TrendsService>().water(userId, range),
              )..load();
            },
          ),
          BlocProvider<ActivityGoalsCubit>(
            create: (_) => sl<ActivityGoalsCubit>()..load(),
          ),
          BlocProvider<StressCheckInCubit>(
            create: (_) => sl<StressCheckInCubit>()..load(),
          ),
          BlocProvider<TrendCubit<MealLogEntry>>(
            create: (_) =>
                TrendCubit<MealLogEntry>(sl<TrendsService>().calories)..load(),
          ),
          BlocProvider<TrendCubit<SleepSessionInfo>>(
            create: (_) =>
                TrendCubit<SleepSessionInfo>(sl<TrendsService>().sleep)..load(),
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

  static String _userId(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    return authState is AuthAuthenticated ? authState.user.id : 'unknown';
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
      2 => VitaHomePage(
          onBack: () => setState(() => _selectedIndex = 0),
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

class _HomeTab extends StatefulWidget {
  final VoidCallback? onScanMeal;
  const _HomeTab({this.onScanMeal});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  // Health Connect data (steps, synced sleep) changes outside the app.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      if (!mounted) return;
      context.read<WaterIntakeCubit>().reload();
      context.read<TrendCubit<SleepSessionInfo>>().load();
      context.read<ActivityGoalsCubit>().load();
      context.read<StressCheckInCubit>().load();
      context.read<MealLogBloc>().add(const LoadTodaysMeals());
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _push(String route, {Object? extra}) async {
    final meals = context.read<MealLogBloc>();
    final calories = context.read<TrendCubit<MealLogEntry>>();
    final plan = context.read<DietPlanCubit>();
    await context.pushNamed(route, extra: extra);
    meals.add(const LoadTodaysMeals());
    calories.load();
    plan.loadActiveMealPlan();
  }

  @override
  Widget build(BuildContext context) {
    final onScanMeal = widget.onScanMeal;
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
                        BlocListener<MealLogBloc, MealLogState>(
                          // A newly logged meal moves today's calories bar.
                          listenWhen: (_, state) => state is MealLogLoaded,
                          listener: (context, _) =>
                              context.read<TrendCubit<MealLogEntry>>().load(),
                          child: BlocBuilder<DietPlanCubit, DietPlanState>(
                            builder: (context, state) {
                              final plan =
                                  state is DietPlanLoaded ? state.mealPlan : null;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  NutritionSummaryCard(
                                    plan: plan,
                                    onViewAll: () => _push('meal-log-history'),
                                    onOpenProgress: () => _push('diet-progress'),
                                    onScanMeal: onScanMeal,
                                  ),
                                  if (plan == null) ...[
                                    const SizedBox(height: AppDimens.cardGap),
                                    _DietPlanCard(
                                      onTap: () => _push('diet-plan-prefs'),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppDimens.cardGap),
                        const ActivityGoalsCard(),
                        const SizedBox(height: AppDimens.cardGap),
                        const StressCheckInCard(),
                        const SizedBox(height: AppDimens.cardGap),
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

String _greeting(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
