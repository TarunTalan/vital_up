import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_card.dart';

/// Figma `card/big` header: success-tint icon badge + "body 16 med" title,
/// with an optional trailing widget.
class DashboardCardHeader extends StatelessWidget {
  final String title;
  final String iconAsset;
  final Widget? trailing;

  const DashboardCardHeader({
    super.key,
    required this.title,
    required this.iconAsset,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;
    return Row(
      children: [
        AppIconBadge(
          color: context.vColors.success,
          icon: SvgPicture.asset(
            iconAsset,
            width: AppDimens.iconLg,
            height: AppDimens.iconLg,
            colorFilter: ColorFilter.mode(onSurface, BlendMode.srcIn),
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(color: onSurface),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppDimens.space8),
          trailing!,
        ],
      ],
    );
  }
}

/// Big numeric readout on dashboard cards (Figma "metric", 36/300).
class DashboardMetric extends StatelessWidget {
  final String value;

  const DashboardMetric(this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        maxLines: 1,
        style: AppTextStyles.metric.copyWith(color: context.colors.onSurface),
      ),
    );
  }
}

/// Centred spinner used while a dashboard card is loading.
class DashboardCardLoading extends StatelessWidget {
  const DashboardCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.space48),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: AppDimens.borderThick,
          color: context.colors.primary,
        ),
      ),
    );
  }
}

String formatDashboardDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
}
