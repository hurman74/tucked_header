import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'tuck_extent.dart';

/// Called by [RenderSliverTucked] after each layout that wasn't corrected.
///
/// [hidden] is how many pixels of the sliver are scrolled out of view or
/// covered by a pinned sliver in front of it; [tuckExtent] is the resolved
/// [TuckExtent].
typedef TuckLayoutCallback = void Function(double hidden, double tuckExtent);

/// The render object behind `SliverTucked`.
///
/// It lays its sliver child out unchanged and passes the child's geometry
/// through, with two exceptions:
///
///  * On its first layout, if [startTucked] is true and the sliver is visible,
///    it asks the viewport to scroll forward until [extent] pixels of the
///    sliver are hidden. It does this with
///    [SliverGeometry.scrollOffsetCorrection], so the scroll position is right
///    before anything is painted, even if the child's size was only known
///    during this layout.
///  * Later, if the tuck extent changes while the tucked part is fully
///    hidden, it corrects the scroll offset by the difference, so the content
///    after it doesn't jump.
class RenderSliverTucked extends RenderProxySliver {
  /// Creates the render object.
  RenderSliverTucked({
    required TuckExtent extent,
    required this.startTucked,
    this.onLayout,
    RenderSliver? child,
  }) : _extent = extent {
    this.child = child;
  }

  static const double _epsilon = 1e-6;

  /// How much of the sliver to hide.
  TuckExtent get extent => _extent;
  TuckExtent _extent;
  set extent(TuckExtent value) {
    if (value == _extent) return;
    _extent = value;
    markNeedsLayout();
  }

  /// Whether to tuck the sliver on its first layout.
  ///
  /// Changing this after the first layout has no effect.
  bool startTucked;

  /// Called after each layout that didn't need a scroll offset correction.
  TuckLayoutCallback? onLayout;

  bool _hasLaidOut = false;
  double? _lastTuckExtent;

  /// How many pixels of the sliver were hidden at the last layout.
  ///
  /// This is the sliver's scroll offset plus the overlap from pinned slivers
  /// in front of it. It is zero while the sliver's leading edge is in view.
  double get hiddenExtent => _hiddenExtent;
  double _hiddenExtent = 0;

  /// The tuck extent resolved at the last layout.
  double get tuckExtent => _lastTuckExtent ?? 0;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    final childGeometry = child.geometry!;
    if (childGeometry.scrollOffsetCorrection != null) {
      geometry = childGeometry;
      return;
    }

    final tuck = clampDouble(
      extent.resolve(childGeometry),
      0,
      childGeometry.scrollExtent,
    );
    final hidden = constraints.scrollOffset + constraints.overlap;
    final previousTuck = _lastTuckExtent;
    _lastTuckExtent = tuck;

    var correction = 0.0;
    if (!_hasLaidOut) {
      _hasLaidOut = true;
      if (startTucked &&
          constraints.remainingPaintExtent > 0 &&
          hidden < tuck) {
        correction = tuck - hidden;
      }
    } else if (previousTuck != null &&
        (tuck - previousTuck).abs() > _epsilon &&
        hidden >= previousTuck - _epsilon) {
      correction = tuck - previousTuck;
    }

    if (correction.abs() > _epsilon) {
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return;
    }
    geometry = childGeometry;
    _hiddenExtent = hidden;
    onLayout?.call(hidden, tuck);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<TuckExtent>('extent', extent))
      ..add(
        FlagProperty(
          'startTucked',
          value: startTucked,
          ifTrue: 'starts tucked',
        ),
      )
      ..add(DoubleProperty('hiddenExtent', hiddenExtent))
      ..add(DoubleProperty('tuckExtent', tuckExtent));
  }
}
