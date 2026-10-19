import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_up/core/utils/smooth_ui_helper.dart';
import 'package:vital_up/features/subscription/domain/pro_limits.dart';
import 'package:vital_up/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:vital_up/features/subscription/presentation/widgets/pro_paywall.dart';

/// A daily AI limit was reached. Free users who can buy Pro here get the
/// Pro sheet (with the reason); everyone else gets [message]. True when
/// the user started Pro, so the caller can try the action again.
Future<bool> offerProForLimit(
  BuildContext context, {
  required ProReason reason,
  required String message,
}) async {
  final state = context.read<SubscriptionCubit>().state;
  if (!state.canUpgrade) {
    showErrorSnackBar(context, message);
    return false;
  }
  return showProPaywall(context, reason: reason);
}
