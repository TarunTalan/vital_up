import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/quota_reset.dart';
import 'package:vital_up/features/subscription/data/services/ai_quota_service.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/features/subscription/presentation/widgets/pro_paywall.dart';

/// "12 of 15 messages left today · Get more with Pro", for free users.
///
/// Follows every use (the service's count changes), re-reads on resume
/// (the server day may have turned) and hides with Pro, while the count
/// is unknown, or where there is no plan state (tests, signed out). At
/// zero it says when the allowance comes back. The Pro link shows only
/// where Pro can be bought.
class AiQuotaLine extends StatefulWidget {
  final AiQuota quota;
  final AiQuotaService? service;
  final TextAlign textAlign;

  /// The latest count (null when unknown or Pro), e.g. so the chat can
  /// turn its composer off at 0.
  final ValueChanged<int?>? onChanged;

  const AiQuotaLine({
    super.key,
    required this.quota,
    this.service,
    this.textAlign = TextAlign.center,
    this.onChanged,
  });

  /// "message" / "messages", "AI plan" / "AI plans".
  static String noun(AiQuota quota, int count) => switch (quota) {
    AiQuota.vitaChat => count == 1 ? 'message' : 'messages',
    AiQuota.dietPlan => count == 1 ? 'AI plan' : 'AI plans',
  };

  /// The line's text for [left] uses left.
  static String describe(AiQuota quota, int left, {DateTime? now}) {
    if (left <= 0) {
      return 'No ${noun(quota, 2)} left today. More at '
          '${quotaResetTime(now: now)}.';
    }
    final free = quota.limit.free;
    return '$left of $free ${noun(quota, free)} left today';
  }

  @override
  State<AiQuotaLine> createState() => _AiQuotaLineState();
}

class _AiQuotaLineState extends State<AiQuotaLine> with WidgetsBindingObserver {
  AiQuotaService? get _service =>
      widget.service ??
      (GetIt.instance.isRegistered<AiQuotaService>()
          ? GetIt.instance<AiQuotaService>()
          : null);

  StreamSubscription<void>? _changesSub;
  int? _left;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changesSub = _service?.changes(widget.quota).listen((_) => _load());
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) return;
    final generation = ++_generation;
    final left = await service.freeLeft(widget.quota);
    if (!mounted || generation != _generation) return;
    if (left != _left) {
      setState(() => _left = left);
      widget.onChanged?.call(left);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<SubscriptionCubit?>()?.state;
    final left = _left;
    if (plan == null || plan.isPro || left == null) {
      return const SizedBox.shrink();
    }
    final v = context.vColors;
    final out = left <= 0;
    final text = Text(
      AiQuotaLine.describe(widget.quota, left),
      textAlign: widget.textAlign,
      style: context.text.bodySmall?.copyWith(
        color: out ? context.colors.onSurface : v.grayText,
      ),
    );
    final alignment = switch (widget.textAlign) {
      TextAlign.start || TextAlign.left => WrapAlignment.start,
      TextAlign.end || TextAlign.right => WrapAlignment.end,
      _ => WrapAlignment.center,
    };
    return Semantics(
      liveRegion: true,
      child: Wrap(
        alignment: alignment,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppDimens.space4,
        children: [
          text,
          if (plan.canUpgrade)
            InkWell(
              onTap: () => showProPaywall(
                context,
                reason: out ? widget.quota.reason : null,
              ),
              borderRadius: BorderRadius.circular(AppDimens.radiusXs),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.space4,
                  vertical: AppDimens.space4,
                ),
                child: Text(
                  'Get more with Pro',
                  style: context.text.bodySmall?.copyWith(
                    color: v.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
