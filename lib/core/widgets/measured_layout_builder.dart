import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Natural sizes of a [MeasuredLayoutBuilder]'s content, answered without
/// building it.
class LayoutMeasures {
  /// Widest the content wants to be (one line, full size).
  final double Function() maxWidth;

  /// Narrowest it can usefully get.
  final double Function() minWidth;

  /// Height it takes when laid out [width] wide.
  final double Function(double width) heightFor;

  const LayoutMeasures({
    required this.maxWidth,
    required this.minWidth,
    required this.heightFor,
  });
}

/// A [LayoutBuilder] that can also report its intrinsic size (from
/// [measures]), so it works inside [IntrinsicWidth], [IntrinsicHeight] and
/// other parents that ask for a natural size first. A plain LayoutBuilder
/// throws there ("LayoutBuilder does not support returning intrinsic
/// dimensions").
class MeasuredLayoutBuilder extends ConstrainedLayoutBuilder<BoxConstraints> {
  final LayoutMeasures measures;

  const MeasuredLayoutBuilder({
    super.key,
    required this.measures,
    required super.builder,
  });

  @override
  RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox>
  createRenderObject(BuildContext context) =>
      _RenderMeasuredLayoutBuilder(measures);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeasuredLayoutBuilder).measures = measures;
  }
}

class _RenderMeasuredLayoutBuilder extends RenderBox
    with
        RenderObjectWithChildMixin<RenderBox>,
        RenderObjectWithLayoutCallbackMixin,
        RenderAbstractLayoutBuilderMixin<BoxConstraints, RenderBox> {
  _RenderMeasuredLayoutBuilder(this._measures);

  LayoutMeasures _measures;
  set measures(LayoutMeasures value) {
    if (identical(value, _measures)) return;
    _measures = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _measures.minWidth();

  @override
  double computeMaxIntrinsicWidth(double height) => _measures.maxWidth();

  @override
  double computeMinIntrinsicHeight(double width) =>
      _measures.heightFor(width.isFinite ? width : _measures.maxWidth());

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.constrainWidth(_measures.maxWidth());
    return constraints.constrain(Size(width, _measures.heightFor(width)));
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    runLayoutCallback();
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child!.size);
    } else {
      size = constraints.biggest;
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      child?.getDistanceToActualBaseline(baseline) ??
      super.computeDistanceToActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      child?.hitTest(result, position: position) ?? false;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child!, offset);
  }
}
