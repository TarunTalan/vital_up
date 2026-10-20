import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/config/legal_links.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/quota_reset.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/subscription/domain/entities/pro_status.dart';
import 'package:vital_up/features/subscription/domain/pro_limits.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';

/// Opens the Pro sheet over the current page. [reason] is the daily limit
/// the user just reached, if any. True when they bought or restored Pro.
Future<bool> showProPaywall(BuildContext context, {ProReason? reason}) async {
  final cubit = context.read<SubscriptionCubit>();
  final result = await showAppBottomSheet<bool>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.gutter,
            0,
            context.gutter,
            AppDimens.space16,
          ),
          child: ProPaywall(reason: reason),
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Store page where the user changes or cancels their plan.
Future<void> openProManagement(BuildContext context, ProStatus status) async {
  final url =
      status.managementUrl ??
      'https://play.google.com/store/account/subscriptions'
          '?package=com.vitalup.app';
  final opened = await LegalLinks.open(url);
  if (!opened && context.mounted) {
    showErrorSnackBar(context, "Couldn't open Google Play.");
  }
}

/// What Pro adds, the plans and the buy button: the body of the Pro sheet
/// and of the Pro page for free users. Pops `true` from a sheet when Pro
/// starts (pass [popOnSuccess] false on a page).
class ProPaywall extends StatefulWidget {
  final ProReason? reason;
  final bool popOnSuccess;

  const ProPaywall({super.key, this.reason, this.popOnSuccess = true});

  @override
  State<ProPaywall> createState() => _ProPaywallState();
}

class _ProPaywallState extends State<ProPaywall> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionCubit>().loadPlans();
  }

  ProPlan? _selected(List<ProPlan> plans) {
    if (plans.isEmpty) return null;
    return plans.firstWhere(
      (p) => p.id == _selectedId,
      orElse: () => plans.first,
    );
  }

  Future<void> _buy(ProPlan plan) async {
    final outcome = await context.read<SubscriptionCubit>().purchase(plan.id);
    if (!mounted || outcome == null) return;
    _report(outcome);
  }

  Future<void> _restore() async {
    final outcome = await context.read<SubscriptionCubit>().restore();
    if (!mounted || outcome == null) return;
    _report(outcome);
  }

  void _report(PurchaseOutcome outcome) {
    switch (outcome) {
      case PurchaseCompleted():
        showSuccessSnackBar(context, 'Welcome to VitalUp Pro.');
        if (widget.popOnSuccess) Navigator.of(context).pop(true);
      case PurchasePending():
        showSuccessSnackBar(
          context,
          'Pro starts once Google Play confirms your payment.',
        );
      case PurchaseFailed(:final message):
        showErrorSnackBar(context, message);
      case PurchaseCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, state) {
        final plan = _selected(state.plans);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProHeader(reason: widget.reason),
            const SizedBox(height: AppDimens.sectionGap),
            const ProLimitsList(),
            const SizedBox(height: AppDimens.cardGap),
            const AppInfoNote(
              icon: Icons.favorite_outline_rounded,
              message: 'Tracking, workouts, trends and Arena stay free.',
            ),
            const SizedBox(height: AppDimens.sectionGap),
            if (!state.canPurchase)
              const AppInfoNote(
                message: "Pro isn't available on this device yet.",
              )
            else if (state.plansLoading && state.plans.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppDimens.space24),
                child: Center(child: VitalUpLoader()),
              )
            else if (state.plans.isEmpty)
              _PlansError(
                message:
                    state.plansError ?? "Plans aren't available right now.",
                onRetry: () =>
                    context.read<SubscriptionCubit>().loadPlans(force: true),
              )
            else ...[
              for (final p in state.plans) ...[
                _PlanOption(
                  plan: p,
                  selected: p == plan,
                  onTap: state.busy
                      ? null
                      : () => setState(() => _selectedId = p.id),
                ),
                const SizedBox(height: AppDimens.cardGap),
              ],
              const SizedBox(height: AppDimens.space4),
              AppPrimaryButton(
                label: plan!.hasTrial ? 'Start free trial' : 'Subscribe',
                isLoading: state.buyingPlanId != null,
                enabled: !state.busy,
                onTap: () => _buy(plan),
              ),
              const SizedBox(height: AppDimens.space8),
              Text(
                _terms(plan),
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: context.vColors.grayText,
                ),
              ),
            ],
            if (state.canPurchase) ...[
              const SizedBox(height: AppDimens.space8),
              _FooterLinks(
                restoring: state.restoring,
                onRestore: state.busy ? null : _restore,
              ),
            ],
          ],
        );
      },
    );
  }

  /// What the user agrees to (Play policy: price, period, auto-renewal and
  /// how to cancel, before they buy).
  static String _terms(ProPlan plan) {
    final period = switch (plan.period) {
      ProPlanPeriod.annual => 'a year',
      ProPlanPeriod.monthly => 'a month',
      ProPlanPeriod.other => 'each period',
    };
    final price = '${plan.price} $period';
    final start = plan.hasTrial
        ? 'Free for ${plan.trialDays} days, then $price.'
        : '$price.';
    return '$start Renews automatically until you cancel in Google Play.';
  }
}

class _ProHeader extends StatelessWidget {
  final ProReason? reason;

  const _ProHeader({this.reason});

  @override
  Widget build(BuildContext context) {
    final reason = this.reason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconBadge(
          icon: const Icon(Icons.workspace_premium_rounded),
          color: context.colors.primary,
        ),
        const SizedBox(height: AppDimens.space12),
        Text(reason?.title ?? 'VitalUp Pro', style: context.text.headlineSmall),
        const SizedBox(height: AppDimens.space4),
        Text(
          reason == null
              ? 'More from Vita and the food scanner, every day.'
              : 'They reset at ${quotaResetTime()}. Pro gives you up to '
                    '${reason.limit.pro} a day.',
          style: context.text.bodyMedium?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
      ],
    );
  }
}

/// Free vs Pro daily allowances.
class ProLimitsList extends StatelessWidget {
  /// Shows the Pro numbers only (for users who have Pro).
  final bool proOnly;

  const ProLimitsList({super.key, this.proOnly = false});

  @override
  Widget build(BuildContext context) {
    return AppListGroup(
      title: proOnly ? 'Your daily allowance' : 'With Pro, every day',
      children: [
        for (final limit in ProLimits.all)
          AppListTile(
            icon: _icon(limit),
            iconColor: context.colors.primary,
            title: limit.label,
            subtitle: proOnly ? null : 'Free plan: ${limit.free}',
            value: 'Up to ${limit.pro}',
          ),
      ],
    );
  }

  static IconData _icon(ProLimit limit) => switch (limit) {
    ProLimits.photoScans => Icons.photo_camera_outlined,
    ProLimits.vitaChats => Icons.chat_bubble_outline_rounded,
    ProLimits.dietPlans => Icons.restaurant_menu_rounded,
    _ => Icons.insights_rounded,
  };
}

class _PlanOption extends StatelessWidget {
  final ProPlan plan;
  final bool selected;
  final VoidCallback? onTap;

  const _PlanOption({required this.plan, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = switch (plan.period) {
      ProPlanPeriod.annual => 'Yearly',
      ProPlanPeriod.monthly => 'Monthly',
      ProPlanPeriod.other => 'Pro',
    };
    final per = switch (plan.period) {
      ProPlanPeriod.annual => ' a year',
      ProPlanPeriod.monthly => ' a month',
      ProPlanPeriod.other => '',
    };
    final tags = [
      if (plan.hasTrial) '${plan.trialDays} days free',
      if (plan.savingsPercent != null) 'Save ${plan.savingsPercent}%',
    ];
    return Semantics(
      selected: selected,
      button: true,
      child: AppCard(
        onTap: onTap,
        highlighted: selected,
        borderColor: selected ? context.colors.primary : null,
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? context.colors.primary
                  : context.vColors.grayText,
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  const SizedBox(height: AppDimens.space4),
                  Text('${plan.price}$per', style: context.text.bodyLarge),
                  if (plan.pricePerMonth != null)
                    Text(
                      '${plan.pricePerMonth} a month',
                      style: context.text.bodySmall?.copyWith(
                        color: context.vColors.grayText,
                      ),
                    ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: AppDimens.space8),
                    Wrap(
                      spacing: AppDimens.space8,
                      runSpacing: AppDimens.space4,
                      children: [for (final t in tags) _Tag(t)],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vColors.primaryFill,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.space8,
          vertical: AppDimens.space4,
        ),
        child: Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: context.vColors.accentText,
          ),
        ),
      ),
    );
  }
}

class _PlansError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PlansError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: AppDimens.space12),
        AppSecondaryButton(label: 'Try again', onTap: onRetry),
      ],
    );
  }
}

class _FooterLinks extends StatelessWidget {
  final bool restoring;
  final VoidCallback? onRestore;

  const _FooterLinks({required this.restoring, this.onRestore});

  Future<void> _open(BuildContext context, String url) async {
    final opened = await LegalLinks.open(url);
    if (!opened && context.mounted) {
      showErrorSnackBar(context, "Couldn't open the page.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelLarge?.copyWith(
      color: context.vColors.accentText,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          onPressed: onRestore,
          child: Text(
            restoring ? 'Restoring...' : 'Restore purchases',
            style: style,
          ),
        ),
        TextButton(
          onPressed: () => _open(context, LegalLinks.terms),
          child: Text('Terms', style: style),
        ),
        TextButton(
          onPressed: () => _open(context, LegalLinks.privacyPolicy),
          child: Text('Privacy', style: style),
        ),
      ],
    );
  }
}

/// The current plan for Pro users: what it is, when it renews or ends,
/// and where to change it.
class ProStatusCard extends StatelessWidget {
  final ProStatus status;

  const ProStatusCard({super.key, required this.status});

  static String describe(ProStatus status) {
    final plan = status.isTrial
        ? 'Free trial'
        : status.isYearly
        ? 'Yearly plan'
        : status.productId == null
        ? 'Pro'
        : 'Monthly plan';
    final end = status.expiresAt;
    if (end == null) return plan;
    final date = DateFormat('d MMM y').format(end);
    if (status.isTrial) {
      return status.willRenew
          ? '$plan, paid plan starts $date'
          : '$plan, ends $date';
    }
    return status.willRenew ? '$plan, renews $date' : '$plan, ends $date';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      highlighted: true,
      child: Row(
        children: [
          AppIconBadge(
            icon: const Icon(Icons.workspace_premium_rounded),
            color: context.colors.primary,
          ),
          const SizedBox(width: AppDimens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You're on VitalUp Pro", style: context.text.titleMedium),
                const SizedBox(height: AppDimens.space4),
                Text(
                  describe(status),
                  style: context.text.bodyMedium?.copyWith(
                    color: context.vColors.grayText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
