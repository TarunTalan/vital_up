import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_up/core/database/collections/weight_log_cache.dart';
import 'package:vital_up/core/di/injection_container.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/tracker/tracker_status.dart';
import 'package:vital_up/core/widgets/tracker/tracker_widgets.dart';
import 'package:vital_up/features/profile/domain/entities/profile_entity.dart';
import 'package:vital_up/features/profile/presentation/utils/body_metrics.dart';
import 'package:vital_up/features/weight/data/weight_service.dart';

/// Weight, height and BMI. Weight is the latest weight log (what Home and
/// the weight trend show), falling back to the profile before any log.
///
/// With [onLogWeight] it shows a "Log weight" action and reloads after it.
class HealthSnapshotCard extends StatefulWidget {
  final ProfileEntity profile;
  final VoidCallback? onTap;
  final Future<void> Function()? onLogWeight;

  /// Shown under the figures (e.g. the activity-level row).
  final Widget? footer;

  const HealthSnapshotCard({
    super.key,
    required this.profile,
    this.onTap,
    this.onLogWeight,
    this.footer,
  });

  @override
  State<HealthSnapshotCard> createState() => _HealthSnapshotCardState();
}

class _HealthSnapshotCardState extends State<HealthSnapshotCard> {
  late Future<WeightLogCache?> _latest = sl<WeightService>().latest();

  @override
  void didUpdateWidget(HealthSnapshotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) _reload();
  }

  void _reload() => setState(() => _latest = sl<WeightService>().latest());

  Future<void> _logWeight() async {
    await widget.onLogWeight!();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final settings = watchSettings(context);
    final unit = WeightUnit.fromCode(settings.weightUnit);
    final heightCm = profileHeightCm(widget.profile);

    return FutureBuilder<WeightLogCache?>(
      future: _latest,
      builder: (context, snapshot) {
        final log = snapshot.data;
        final weightKg = log?.weightKg ?? profileWeightKg(widget.profile);
        final bmi = bmiOf(kg: weightKg, cm: heightCm);
        final band = bmi == null ? null : BmiBand.of(bmi);
        final grey = context.vColors.grayText;

        return AppCard(
          width: double.infinity,
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrackerFigureRow(
                figures: [
                  TrackerFigure(
                    label: 'Weight',
                    value: weightKg == null ? '—' : unit.format(weightKg),
                  ),
                  TrackerFigure(
                    label: 'Height',
                    value: heightCm == null
                        ? '—'
                        : formatHeight(heightCm, settings),
                  ),
                  TrackerFigure(
                    label: 'BMI',
                    value: bmi == null ? '—' : bmi.toStringAsFixed(1),
                  ),
                ],
              ),
              if (band != null ||
                  log != null ||
                  widget.onLogWeight != null) ...[
                const SizedBox(height: AppDimens.cardInnerGap),
                Wrap(
                  spacing: AppDimens.space8,
                  runSpacing: AppDimens.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.onLogWeight != null)
                      IntrinsicWidth(
                        child: TrackerQuickAction(
                          label: 'Log weight',
                          icon: Icons.add_rounded,
                          color: AppColors.trackWeight,
                          onTap: _logWeight,
                        ),
                      ),
                    if (band != null)
                      TrackerStatusChip(
                        band == BmiBand.healthy
                            ? TrackerStatus.done
                            : TrackerStatus.over,
                        label: band.label,
                        color: band.color(context),
                      ),
                    if (log != null)
                      Text(
                        'Weight logged ${DateFormat('d MMM').format(log.timestamp)}',
                        style: context.text.bodySmall?.copyWith(color: grey),
                      ),
                  ],
                ),
              ],
              if (widget.footer != null) ...[
                const SizedBox(height: AppDimens.space8),
                Divider(color: context.vColors.divider),
                widget.footer!,
              ],
            ],
          ),
        );
      },
    );
  }
}
