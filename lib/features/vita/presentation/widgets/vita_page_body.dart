import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';

import 'package:vital_up/core/widgets/load_error_view.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';

/// Body padding for Vita sub-pages: 16dp below the [AppTitleBar] (its own
/// bottom spacing), gutter sides, section gap at the bottom.
EdgeInsets vitaBodyPadding(BuildContext context) => EdgeInsets.fromLTRB(
  context.gutter,
  0,
  context.gutter,
  context.safePadding.bottom + AppDimens.sectionGap,
);

/// Loading / error / data switch for a one-shot Vita insight fetch.
class VitaFutureBody<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;

  /// Starts the fetch again (the page swaps in a new [future]).
  final VoidCallback onRetry;

  const VitaFutureBody({
    super.key,
    required this.future,
    required this.builder,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return builder(context, snapshot.data as T);
        if (snapshot.hasError) {
          return LoadErrorView(
            onRetry: onRetry,
            message: "Vita couldn't load this. Try again.",
          );
        }
        return const Center(child: VitalUpLoader());
      },
    );
  }
}
