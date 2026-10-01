import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_dimens.dart';

/// App-wide page transition (Material 3 shared-axis style).
///
/// Push: the new page glides in from the right on an emphasized-decelerate
/// curve and fades in over the first half, so it fully covers the old page
/// by mid-flight (no lingering double exposure over the glass backgrounds).
/// The covered page drifts slightly left and settles back a touch,
/// giving depth without competing with the incoming page.
/// Pop runs the same motion in reverse on the accelerate counterparts.
///
/// Respects the OS "reduce motion" setting by falling back to a plain fade.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const double _enterOffset = 0.08;
  static const double _coveredOffset = -0.05;
  static const double _coveredScale = 0.97;

  @override
  Duration get transitionDuration => AppDurations.page;

  @override
  Duration get reverseTransitionDuration => AppDurations.pageReverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    final enter = CurvedAnimation(
      parent: animation,
      curve: Easing.emphasizedDecelerate,
      reverseCurve: Easing.emphasizedAccelerate.flipped,
    );
    final enterFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
      reverseCurve: const Interval(0, 0.5, curve: Curves.easeIn),
    );
    final covered = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Easing.emphasizedDecelerate,
      reverseCurve: Easing.emphasizedAccelerate.flipped,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(_enterOffset, 0),
        end: Offset.zero,
      ).animate(enter),
      child: FadeTransition(
        opacity: enterFade,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(_coveredOffset, 0),
          ).animate(covered),
          child: ScaleTransition(
            scale: Tween<double>(begin: 1, end: _coveredScale).animate(covered),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Global [PageTransitionsTheme]: the app transition everywhere except iOS,
/// which keeps the native Cupertino slide so edge-swipe-back works.
const PageTransitionsTheme appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: AppPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: AppPageTransitionsBuilder(),
    TargetPlatform.windows: AppPageTransitionsBuilder(),
    TargetPlatform.linux: AppPageTransitionsBuilder(),
  },
);

/// go_router page that defers to the theme's [PageTransitionsTheme], so
/// router pages and imperative `MaterialPageRoute` pushes animate the same.
class AppPage<T> extends MaterialPage<T> {
  const AppPage({
    required super.child,
    required super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });
}
