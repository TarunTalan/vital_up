import 'package:flutter/material.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';

/// Standard page shell: branded blob background, optional [header]
/// (usually an [AppPageHeader]), a scrollable body padded to the 16dp gutter
/// and capped at 600dp on tablets, and an optional pinned [bottomBar]
/// (e.g. a primary CTA) that lifts above the keyboard.
///
/// Set [scrollable] to false for bodies that manage their own scrolling
/// (lists, maps); they still get the gutter + width cap unless
/// [padBody] is false.
class AppScaffold extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final Widget? bottomBar;
  final bool scrollable;
  final bool padBody;
  final bool showBackground;
  final EdgeInsetsGeometry? bodyPadding;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;

  const AppScaffold({
    super.key,
    required this.body,
    this.header,
    this.bottomBar,
    this.scrollable = true,
    this.padBody = true,
    this.showBackground = true,
    this.bodyPadding,
    this.floatingActionButton,
    this.onRefresh,
  });

  /// Pull-to-refresh never spins forever and never surfaces an error from
  /// here: the page shows its own state once the reload settles.
  Future<void> _refresh() async {
    try {
      await onRefresh!().timeout(kLoadTimeout);
    } catch (e) {
      debugPrint('AppScaffold: refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = bodyPadding ??
        (padBody
            ? EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.sectionGap,
                context.gutter,
                AppDimens.sectionGap,
              )
            : EdgeInsets.zero);

    Widget content = ResponsiveCenter(
      child: Padding(padding: padding, child: body),
    );

    if (scrollable) {
      content = SingleChildScrollView(
        physics: onRefresh != null ? const AlwaysScrollableScrollPhysics() : null,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: content,
      );
    }

    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: _refresh,
        child: content,
      );
    }

    final page = Column(
      children: [
        ?header,
        if (header == null) SizedBox(height: context.safePadding.top),
        Expanded(child: content),
        if (bottomBar != null)
          SafeArea(
            top: false,
            child: ResponsiveCenter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.gutter,
                  AppDimens.space12,
                  context.gutter,
                  AppDimens.space16,
                ),
                child: bottomBar,
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor:
          showBackground ? Colors.transparent : context.colors.surface,
      floatingActionButton: floatingActionButton,
      body: showBackground ? AuthBackground(child: page) : page,
    );
  }
}
