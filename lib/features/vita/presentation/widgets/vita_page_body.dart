import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/responsive.dart';

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

  const VitaFutureBody({
    super.key,
    required this.future,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return builder(context, snapshot.data as T);
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Vita couldn't load this. Try again later.",
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(
                color: context.vColors.grayText,
              ),
            ),
          );
        }
        return const Center(child: VitalUpLoader());
      },
    );
  }
}
