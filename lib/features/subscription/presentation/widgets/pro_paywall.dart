import 'dart:math' as math;

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
import 'package:vital_up/core/widgets/fit_text.dart';
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
            _ProHero(
              // The page's header already names Pro; the sheet has none.
              title:
                  widget.reason?.title ??
                  (widget.popOnSuccess ? 'VitalUp Pro' : 'Get more every day'),
              message: widget.reason == null
                  ? 'More from Vita and the food scanner, every day.'
                  : 'They reset at ${quotaResetTime()}. Pro gives you up to '
                        '${widget.reason!.limit.pro} a day.',
            ),
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
              _PlanPicker(
                plans: state.plans,
                selected: plan!,
                onSelect: state.busy
                    ? null
                    : (p) => setState(() => _selectedId = p.id),
              ),
              const SizedBox(height: AppDimens.sectionGap),
              AppPrimaryButton(
                label: plan.hasTrial ? 'Start free trial' : 'Subscribe',
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

/// The top of the Pro page and sheet: a badge in a soft glow, a title and
/// one grey line. Pro users see the same hero with their plan.
class _ProHero extends StatelessWidget {
  final String title;
  final String message;

  const _ProHero({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Column(
      children: [
        Container(
          width: AppDimens.proGlow,
          height: AppDimens.proGlow,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                primary.withValues(alpha: 0.22),
                primary.withValues(alpha: 0),
              ],
            ),
          ),
          child: Container(
            width: AppDimens.proBadge,
            height: AppDimens.proBadge,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.vColors.surfaceElevated,
              border: Border.all(
                color: primary.withValues(alpha: AppDimens.tintBorderAlpha),
                width: AppDimens.borderThick,
              ),
              boxShadow: AppShadows.soft,
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: AppDimens.iconXl,
              color: context.iconTint(primary),
            ),
          ),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.text.headlineSmall,
        ),
        const SizedBox(height: AppDimens.space4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: context.vColors.grayText,
          ),
        ),
      ],
    );
  }
}

/// Daily limits, free next to Pro (or Pro only, for users who have it).
/// At large text, when the columns would squeeze the names, each row puts
/// its figures under its name instead.
class ProLimitsList extends StatelessWidget {
  /// Shows the Pro numbers only (for users who have Pro).
  final bool proOnly;

  const ProLimitsList({super.key, this.proOnly = false});

  static IconData _icon(ProLimit limit) => switch (limit) {
    ProLimits.photoScans => Icons.photo_camera_outlined,
    ProLimits.vitaChats => Icons.chat_bubble_outline_rounded,
    ProLimits.dietPlans => Icons.restaurant_menu_rounded,
    _ => Icons.insights_rounded,
  };

  static double _width(BuildContext context, String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final freeStyle = context.text.bodyMedium?.copyWith(color: v.grayText);
    final proStyle = context.text.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final headStyle = context.text.labelMedium?.copyWith(color: v.grayText);
    final tagStyle = _Tag.style(context);
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Each figure column fits its widest entry, header included.
          final column =
              [
                _width(context, 'Free', headStyle),
                _width(context, 'Pro', tagStyle) + 2 * AppDimens.space8,
                for (final l in ProLimits.all) ...[
                  _width(context, '${l.free}', freeStyle),
                  _width(context, '${l.pro}', proStyle),
                ],
              ].reduce(math.max) +
              AppDimens.space16;
          final columns = proOnly ? 1 : 2;
          final nameRoom =
              constraints.maxWidth -
              AppDimens.iconSm -
              AppDimens.space12 -
              columns * column;
          final stacked = nameRoom < context.textScaled(96);

          Widget figure(String text, TextStyle? style) => SizedBox(
            width: column,
            child: Text(text, textAlign: TextAlign.center, style: style),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      proOnly ? 'Your daily limits' : 'Daily limits',
                      style: context.text.titleSmall,
                    ),
                  ),
                  if (!stacked) ...[
                    if (!proOnly) figure('Free', headStyle),
                    SizedBox(
                      width: column,
                      child: const Center(child: _Tag('Pro')),
                    ),
                  ],
                ],
              ),
              for (final limit in ProLimits.all) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.space12,
                  ),
                  child: Divider(
                    height: AppDimens.hairline,
                    thickness: AppDimens.hairline,
                    color: v.divider,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      _icon(limit),
                      size: AppDimens.iconSm,
                      color: context.iconTint(context.colors.primary),
                    ),
                    const SizedBox(width: AppDimens.space12),
                    Expanded(
                      child: stacked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  limit.label,
                                  style: context.text.bodyMedium,
                                ),
                                Text(
                                  proOnly
                                      ? 'Up to ${limit.pro} a day'
                                      : 'Free ${limit.free} · Pro up to '
                                            '${limit.pro}',
                                  style: context.text.bodySmall?.copyWith(
                                    color: v.grayText,
                                  ),
                                ),
                              ],
                            )
                          : Text(limit.label, style: context.text.bodyMedium),
                    ),
                    if (!stacked) ...[
                      if (!proOnly) figure('${limit.free}', freeStyle),
                      figure('${limit.pro}', proStyle),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The plans as selectable tiles: side by side when two fit, else stacked.
class _PlanPicker extends StatelessWidget {
  final List<ProPlan> plans;
  final ProPlan selected;
  final ValueChanged<ProPlan>? onSelect;

  const _PlanPicker({
    required this.plans,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final onSelect = this.onSelect;
    Widget tile(ProPlan p) => _PlanTile(
      plan: p,
      selected: p == selected,
      onTap: onSelect == null ? null : () => onSelect(p),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - AppDimens.cardGap) / 2;
        final sideBySide =
            plans.length == 2 &&
            half >= context.textScaled(AppDimens.proPlanTileMinWidth);
        if (sideBySide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tile(plans[0])),
                const SizedBox(width: AppDimens.cardGap),
                Expanded(child: tile(plans[1])),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < plans.length; i++) ...[
              if (i > 0) const SizedBox(height: AppDimens.cardGap),
              tile(plans[i]),
            ],
          ],
        );
      },
    );
  }
}

/// One plan: name and check, the price large, per-month and tags in grey
/// and tint. Selected, it takes the brand border and a light brand fill.
class _PlanTile extends StatelessWidget {
  final ProPlan plan;
  final bool selected;
  final VoidCallback? onTap;

  const _PlanTile({required this.plan, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = context.vColors;
    final primary = context.colors.primary;
    final title = switch (plan.period) {
      ProPlanPeriod.annual => 'Yearly',
      ProPlanPeriod.monthly => 'Monthly',
      ProPlanPeriod.other => 'Pro',
    };
    final per = switch (plan.period) {
      ProPlanPeriod.annual => 'a year',
      ProPlanPeriod.monthly => 'a month',
      ProPlanPeriod.other => null,
    };
    final tags = [
      if (plan.hasTrial) '${plan.trialDays} days free',
      if (plan.savingsPercent != null) 'Save ${plan.savingsPercent}%',
    ];
    final grey = context.text.bodySmall?.copyWith(color: v.grayText);
    final radius = BorderRadius.circular(AppDimens.radiusCard);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        decoration: BoxDecoration(
          color: selected ? v.primaryFill : v.glassFill,
          borderRadius: radius,
          border: Border.all(
            color: selected ? primary : v.glassBorder!,
            width: selected ? AppDimens.borderThick : AppDimens.borderThin,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: AppDimens.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: context.text.titleSmall),
                      ),
                      const SizedBox(width: AppDimens.space8),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: AppDimens.iconMd,
                        color: selected
                            ? context.iconTint(primary)
                            : v.grayText,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.space8),
                  FitText(
                    plan.price,
                    maxLines: 1,
                    style: context.text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (per != null) Text(per, style: grey),
                  if (plan.pricePerMonth != null)
                    Text('${plan.pricePerMonth} a month', style: grey),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: AppDimens.space12),
                    Wrap(
                      spacing: AppDimens.space8,
                      runSpacing: AppDimens.space4,
                      children: [for (final t in tags) _Tag(t)],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag(this.label);

  static TextStyle? style(BuildContext context) =>
      context.text.labelMedium?.copyWith(
        color: context.vColors.accentText,
        fontWeight: FontWeight.w600,
      );

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
          vertical: AppDimens.space2,
        ),
        child: Text(label, style: style(context)),
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
    // Small, tight links with dots between them, so all three sit on one
    // line on a small phone even at the largest text.
    final style = context.text.bodySmall?.copyWith(
      color: context.vColors.accentText,
      fontWeight: FontWeight.w600,
    );
    final buttonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.space4),
      minimumSize: const Size(0, kMinInteractiveDimension),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    Widget link(String label, VoidCallback? onTap) => TextButton(
      style: buttonStyle,
      onPressed: onTap,
      child: Text(label, style: style),
    );
    final dot = Text(
      '·',
      style: style?.copyWith(color: context.vColors.grayText),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        link(restoring ? 'Restoring...' : 'Restore purchases', onRestore),
        dot,
        link('Terms', () => _open(context, LegalLinks.terms)),
        dot,
        link('Privacy', () => _open(context, LegalLinks.privacyPolicy)),
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
  Widget build(BuildContext context) =>
      _ProHero(title: "You're on VitalUp Pro", message: describe(status));
}
