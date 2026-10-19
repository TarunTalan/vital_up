import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/widgets/app_buttons.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/activity_tracking/domain/entities/activity_session.dart';
import 'package:vital_up/features/activity_tracking/presentation/widgets/activity_summary.dart';

/// Shown after any activity is saved (GPS or timed): its [ActivitySummary],
/// the same one history shows, with View history and New activity.
class ActivityCompletionPage extends StatelessWidget {
  final ActivitySession session;
  final VoidCallback onBack;
  final VoidCallback onNewActivity;
  final VoidCallback onViewHistory;

  const ActivityCompletionPage({
    super.key,
    required this.session,
    required this.onBack,
    required this.onNewActivity,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onBack();
      },
      child: AppScaffold(
        header: AppPageHeader(title: 'Activity result', onBack: onBack),
        bottomBar: Row(
          children: [
            Expanded(
              child: AppSecondaryButton(
                label: 'View history',
                onTap: onViewHistory,
              ),
            ),
            const SizedBox(width: AppDimens.space12),
            Expanded(
              child: AppPrimaryButton(
                label: 'New activity',
                onTap: onNewActivity,
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: AppDimens.space16),
          child: ActivitySummary(session: session),
        ),
      ),
    );
  }
}
