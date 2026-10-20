import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/features/subscription/domain/pro_limits.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/features/subscription/presentation/utils/pro_gate.dart';

/// "3 photo scans left today" over the camera, for free users only.
///
/// Re-reads after every scan (the repository's cached count changes), on
/// resume (the day may have turned) and when the plan changes. Hidden
/// with Pro and while the count is unknown (offline with no copy). At
/// zero, a tap offers Pro.
class ScansLeftHint extends StatefulWidget {
  final SubscriptionRepository? repository;

  const ScansLeftHint({super.key, this.repository});

  @override
  State<ScansLeftHint> createState() => _ScansLeftHintState();
}

class _ScansLeftHintState extends State<ScansLeftHint>
    with WidgetsBindingObserver {
  late final SubscriptionRepository _repository =
      widget.repository ?? GetIt.instance<SubscriptionRepository>();
  StreamSubscription<void>? _changesSub;
  int? _left;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changesSub = _repository.remainingScansChanges.listen((_) => _load());
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    int? left;
    try {
      left = await _repository.remainingFreeScans();
    } catch (e) {
      debugPrint('Scans left unavailable: ${e.runtimeType}');
    }
    if (!mounted || generation != _generation) return;
    if (left != _left) setState(() => _left = left);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<SubscriptionCubit>().state;
    final left = _left;
    if (plan.isPro || left == null || left < 0) return const SizedBox.shrink();

    final text = switch (left) {
      0 => 'No photo scans left today. Barcodes still work.',
      1 => '1 photo scan left today',
      _ => '$left photo scans left today',
    };
    final offerPro = left == 0 && plan.canUpgrade;
    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space12,
        vertical: AppDimens.space8,
      ),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.12),
          width: AppDimens.borderThin,
        ),
      ),
      child: Text(
        offerPro ? '$text Get more with Pro' : text,
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (!offerPro) return Semantics(liveRegion: true, child: pill);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => offerProForLimit(
          context,
          reason: ProReason.photoScans,
          message: text,
        ),
        child: pill,
      ),
    );
  }
}
