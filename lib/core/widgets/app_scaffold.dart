import 'package:flutter/material.dart';
import 'package:vital_up/core/services/app_loading_controller.dart';
import 'package:vital_up/core/theme/app_theme.dart';
import 'package:vital_up/core/utils/load_timeout.dart';
import 'package:vital_up/core/utils/responsive.dart';
import 'package:vital_up/core/widgets/vital_up_loader.dart';
import 'package:vital_up/features/auth/presentation/widgets/auth_background.dart';

/// Standard page shell: branded blob background, optional [header]
/// (usually an [AppPageHeader]), a scrollable body padded to the 16dp gutter
/// and capped at 600dp on tablets, and an optional pinned [bottomBar]
/// (e.g. a primary CTA) that lifts above the keyboard.
///
/// When [isLoading] or [isBusy] is true (or when [body] is a loader),
/// the whole screen is rendered completely un-interactive: touches,
/// taps, scrolling, and system back actions are disabled.
class AppScaffold extends StatefulWidget {
  final Widget? header;
  final Widget body;
  final Widget? bottomBar;
  final bool scrollable;
  final bool padBody;
  final bool showBackground;
  final EdgeInsetsGeometry? bodyPadding;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;
  final bool isLoading;
  final bool isBusy;

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
    this.isLoading = false,
    this.isBusy = false,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool get _isLoaderBody {
    final w = widget.body;
    if (w is VitalUpLoader) return true;
    if (w is Center && w.child is VitalUpLoader) return true;
    return false;
  }

  bool get _effectiveLoading =>
      widget.isLoading || widget.isBusy || _isLoaderBody;

  @override
  void initState() {
    super.initState();
    if (_effectiveLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _effectiveLoading) {
          AppLoadingController.instance.setTokenLoading(this, true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasLoading = oldWidget.isLoading ||
        oldWidget.isBusy ||
        (oldWidget.body is VitalUpLoader) ||
        (oldWidget.body is Center &&
            (oldWidget.body as Center).child is VitalUpLoader);
    final nowLoading = _effectiveLoading;

    if (wasLoading != nowLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppLoadingController.instance.setTokenLoading(this, nowLoading);
        }
      });
    }
  }

  @override
  void dispose() {
    if (_effectiveLoading) {
      AppLoadingController.instance.setTokenLoading(this, false);
    }
    super.dispose();
  }

  /// Pull-to-refresh never spins forever and never surfaces an error from
  /// here: the page shows its own state once the reload settles.
  Future<void> _refresh() async {
    try {
      await widget.onRefresh!().timeout(kLoadTimeout);
    } catch (e) {
      debugPrint('AppScaffold: refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.bodyPadding ??
        (widget.padBody
            ? EdgeInsets.fromLTRB(
                context.gutter,
                AppDimens.sectionGap,
                context.gutter,
                AppDimens.sectionGap,
              )
            : EdgeInsets.zero);

    Widget content = ResponsiveCenter(
      child: Padding(padding: padding, child: widget.body),
    );

    if (widget.scrollable) {
      content = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: widget.onRefresh != null
              ? const AlwaysScrollableScrollPhysics()
              : null,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: ResponsiveCenter(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(padding: padding, child: widget.body),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: _refresh,
        child: content,
      );
    }

    final isPageLoading = widget.isLoading || _isLoaderBody;

    final page = Column(
      children: [
        ?widget.header,
        if (widget.header == null) SizedBox(height: context.safePadding.top),
        Expanded(
          child: isPageLoading
              ? const Center(child: VitalUpLoader())
              : content,
        ),
        if (widget.bottomBar != null)
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
                child: widget.bottomBar,
              ),
            ),
          ),
      ],
    );

    final pageWithUnfocus = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: page,
    );

    final baseScaffold = Scaffold(
      backgroundColor: widget.showBackground
          ? Colors.transparent
          : context.colors.surface,
      floatingActionButton: widget.floatingActionButton,
      body: widget.showBackground
          ? AuthBackground(child: pageWithUnfocus)
          : pageWithUnfocus,
    );

    final isUninteractive = _effectiveLoading;

    final scaffoldWithOverlay = Stack(
      children: [
        baseScaffold,
        if (widget.isBusy && !isPageLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.15),
              alignment: Alignment.center,
              child: const VitalUpLoader(),
            ),
          ),
      ],
    );

    return PopScope(
      canPop: !isUninteractive,
      child: AbsorbPointer(
        absorbing: isUninteractive,
        child: scaffoldWithOverlay,
      ),
    );
  }
}
