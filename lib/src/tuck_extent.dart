import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// How much of a [SliverGeometry] a tucked sliver hides when it is tucked.
///
/// The value is measured on every layout, so it follows the sliver when its
/// size changes (a header that waits for an image, text that wraps
/// differently after a rotation, and so on).
///
/// Use one of the built-in values, or subclass this to compute your own:
///
///  * [TuckExtent.full] hides the whole sliver.
///  * [TuckExtent.toPinned] collapses a pinned header, such as a pinned
///    `SliverAppBar`, down to the part that stays pinned.
///  * [TuckExtent.pixels] hides at most a fixed number of pixels.
@immutable
abstract class TuckExtent {
  /// Allows subclasses to have const constructors.
  const TuckExtent();

  /// Hides the whole sliver: its full [SliverGeometry.scrollExtent].
  static const TuckExtent full = _FullTuckExtent();

  /// Hides everything except the part that stays pinned, that is the
  /// [SliverGeometry.scrollExtent] minus the
  /// [SliverGeometry.maxScrollObstructionExtent].
  ///
  /// For a pinned `SliverAppBar` or pinned `SliverPersistentHeader` this is
  /// `maxExtent - minExtent`, so the header starts collapsed. Slivers that
  /// don't pin report no obstruction, so for them this is the same as
  /// [full].
  static const TuckExtent toPinned = _PinnedTuckExtent();

  /// Hides [pixels] logical pixels, or the whole sliver if it is shorter.
  const factory TuckExtent.pixels(double pixels) = _PixelsTuckExtent;

  /// Returns how many pixels of the sliver to hide, given the geometry its
  /// child reported in this layout.
  ///
  /// The result is clamped to the range from zero to
  /// [SliverGeometry.scrollExtent].
  double resolve(SliverGeometry geometry);
}

class _FullTuckExtent extends TuckExtent {
  const _FullTuckExtent();

  @override
  double resolve(SliverGeometry geometry) => geometry.scrollExtent;

  @override
  String toString() => 'TuckExtent.full';
}

class _PinnedTuckExtent extends TuckExtent {
  const _PinnedTuckExtent();

  @override
  double resolve(SliverGeometry geometry) =>
      geometry.scrollExtent - geometry.maxScrollObstructionExtent;

  @override
  String toString() => 'TuckExtent.toPinned';
}

class _PixelsTuckExtent extends TuckExtent {
  const _PixelsTuckExtent(this.pixels) : assert(pixels >= 0);

  final double pixels;

  @override
  double resolve(SliverGeometry geometry) => pixels;

  @override
  bool operator ==(Object other) =>
      other is _PixelsTuckExtent && other.pixels == pixels;

  @override
  int get hashCode => pixels.hashCode;

  @override
  String toString() => 'TuckExtent.pixels($pixels)';
}
