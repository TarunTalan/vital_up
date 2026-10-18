import 'package:flutter/widgets.dart';
import 'package:vital_up/core/theme/app_dimens.dart';
import 'package:vital_up/core/utils/responsive.dart';

/// Equal-width columns (stats, figures) in one row. With large text, or
/// when a column would get narrower than [minItemWidth], they wrap into
/// rows of [compactPerRow] so their text stays whole instead of shrinking
/// or ending in "...". Use it for any row of three or more figures.
class AdaptiveRow extends StatelessWidget {
  final List<Widget> children;
  final int compactPerRow;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  const AdaptiveRow({
    super.key,
    required this.children,
    this.compactPerRow = 2,
    this.minItemWidth = 72,
    this.spacing = AppDimens.space8,
    this.runSpacing = AppDimens.space12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = children.length;
        var perRow = n;
        final itemWidth = (constraints.maxWidth - spacing * (n - 1)) / n;
        if (n > compactPerRow &&
            (context.isLargeText ||
                itemWidth < context.textScaled(minItemWidth))) {
          perRow = compactPerRow;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row < n; row += perRow) ...[
              if (row > 0) SizedBox(height: runSpacing),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = row; i < row + perRow; i++) ...[
                    if (i > row) SizedBox(width: spacing),
                    Expanded(
                      child: i < n ? children[i] : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
