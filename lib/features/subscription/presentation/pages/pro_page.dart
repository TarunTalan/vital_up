import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/core/widgets/app_card.dart';
import 'package:vital_up/core/widgets/app_list_group.dart';
import 'package:vital_up/core/widgets/app_page_header.dart';
import 'package:vital_up/core/widgets/app_scaffold.dart';
import 'package:vital_up/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/features/subscription/presentation/widgets/pro_paywall.dart';

/// Profile > VitalUp Pro: the plan for Pro users (renewal, manage,
/// restore), the paywall for everyone else.
class ProPage extends StatefulWidget {
  const ProPage({super.key});

  @override
  State<ProPage> createState() => _ProPageState();
}

class _ProPageState extends State<ProPage> {
  @override
  void initState() {
    super.initState();
    context.read<SubscriptionCubit>().refresh(force: true);
  }

  Future<void> _restore() async {
    final outcome = await context.read<SubscriptionCubit>().restore();
    if (!mounted) return;
    switch (outcome) {
      case PurchaseCompleted():
        showSuccessSnackBar(context, 'Your Pro plan is up to date.');
      case PurchaseFailed(:final message):
        showErrorSnackBar(context, message);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, state) {
        return AppScaffold(
          header: const AppPageHeader(title: 'VitalUp Pro'),
          onRefresh: () =>
              context.read<SubscriptionCubit>().refresh(force: true),
          body: state.isPro
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProStatusCard(status: state.status),
                    const SizedBox(height: AppDimens.sectionGap),
                    const ProLimitsList(proOnly: true),
                    const SizedBox(height: AppDimens.sectionGap),
                    AppListGroup(
                      children: [
                        AppListTile(
                          icon: Icons.open_in_new_rounded,
                          title: 'Manage subscription',
                          subtitle: 'Change or cancel in Google Play',
                          onTap: () => openProManagement(context, state.status),
                        ),
                        AppListTile(
                          icon: Icons.restore_rounded,
                          title: 'Restore purchases',
                          subtitle: 'After a reinstall or a new phone',
                          trailing: state.restoring
                              ? const SizedBox.square(
                                  dimension: AppDimens.iconMd,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          onTap: state.busy || !state.canPurchase
                              ? null
                              : _restore,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.cardGap),
                    const AppInfoNote(
                      message:
                          'Cancelling keeps Pro until the end of the period '
                          'you paid for.',
                    ),
                  ],
                )
              : const ProPaywall(popOnSuccess: false),
        );
      },
    );
  }
}
