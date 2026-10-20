import 'package:flutter/material.dart';
import 'package:vital_up/core/services/app_loading_controller.dart';

/// Top-level or page-level barrier that renders the whole screen un-interactive
/// whenever an API call is in-flight or any page/component is in a loading state.
///
/// Disables pointer touches, tap gestures, scrolling, and system back actions.
class AppLoadingBarrier extends StatelessWidget {
  final Widget child;

  const AppLoadingBarrier({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLoadingController.instance,
      builder: (context, _) {
        final isBusy = AppLoadingController.instance.isLoading;

        return PopScope(
          canPop: !isBusy,
          child: MouseRegion(
            cursor: isBusy ? SystemMouseCursors.wait : MouseCursor.defer,
            child: AbsorbPointer(absorbing: isBusy, child: child),
          ),
        );
      },
    );
  }
}
