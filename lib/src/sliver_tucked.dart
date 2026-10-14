import 'dart:async';

import 'package:flutter/widgets.dart';

import 'render_sliver_tucked.dart';
import 'tuck_extent.dart';

const double _epsilon = 0.5;

/// A sliver that starts tucked away above the top of its scroll view, the way
/// a search field sits hidden above a list until you pull it down.
///
/// Wrap the sliver to hide in a [SliverTucked], and put it first in a
/// [CustomScrollView] (or right after a pinned sliver that is itself tucked
/// with [TuckExtent.toPinned]):
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverTucked.box(
///       child: const Padding(
///         padding: EdgeInsets.all(8),
///         child: SearchBar(hintText: 'Search'),
///       ),
///     ),
///     SliverList.builder(itemBuilder: buildRow, itemCount: 100),
///   ],
/// )
/// ```
///
/// The size of the sliver is measured during layout, so nothing needs to be
/// known up front: it works for a header whose height depends on the text
/// scale, the width or an image that loads later. On the first layout the
/// scroll view is moved forward by exactly the measured [extent], before the
/// first frame is painted. If the header then changes size while it is
/// tucked, the scroll offset is corrected by the difference, so the list
/// below doesn't jump and the header stays hidden.
///
/// Set [snap] to settle a half-revealed header fully open or fully tucked
/// when scrolling stops, and pass a [TuckController] to reveal or tuck it
/// from code.
///
/// To start a pinned `SliverAppBar` collapsed, wrap it with
/// `extent: TuckExtent.toPinned`.
class SliverTucked extends StatefulWidget {
  /// Wraps [sliver] so that it starts tucked.
  const SliverTucked({
    super.key,
    required this.sliver,
    this.extent = TuckExtent.full,
    this.startTucked = true,
    this.snap = false,
    this.snapDuration = const Duration(milliseconds: 250),
    this.snapCurve = Curves.easeOutCubic,
    this.controller,
  });

  /// Wraps a box [child] in a [SliverToBoxAdapter] that starts tucked.
  SliverTucked.box({
    Key? key,
    required Widget child,
    TuckExtent extent = TuckExtent.full,
    bool startTucked = true,
    bool snap = false,
    Duration snapDuration = const Duration(milliseconds: 250),
    Curve snapCurve = Curves.easeOutCubic,
    TuckController? controller,
  }) : this(
         key: key,
         sliver: SliverToBoxAdapter(child: child),
         extent: extent,
         startTucked: startTucked,
         snap: snap,
         snapDuration: snapDuration,
         snapCurve: snapCurve,
         controller: controller,
       );

  /// The sliver to tuck away.
  final Widget sliver;

  /// How much of [sliver] to hide when it's tucked. Defaults to
  /// [TuckExtent.full].
  final TuckExtent extent;

  /// Whether the scroll view starts with the sliver tucked.
  ///
  /// This is read on the first layout only. When it's false, the sliver
  /// starts revealed, but it still keeps the content steady when it resizes
  /// while tucked, and [snap] and [controller] still work.
  final bool startTucked;

  /// Whether to finish a partial reveal when scrolling stops.
  ///
  /// When the user lets go with the tucked part only partly hidden, the
  /// scroll view animates to fully revealed if less than half of it is
  /// hidden, and to fully tucked otherwise.
  final bool snap;

  /// How long the [snap] animation takes.
  final Duration snapDuration;

  /// The curve of the [snap] animation.
  final Curve snapCurve;

  /// Reveals or tucks the sliver from code and reports its state.
  final TuckController? controller;

  @override
  State<SliverTucked> createState() => _SliverTuckedState();
}

class _SliverTuckedState extends State<SliverTucked> {
  ScrollPosition? _position;
  double _hidden = 0;
  double _tuckExtent = 0;
  bool _hasLayout = false;
  bool _notifyScheduled = false;
  (bool, bool)? _lastReported;

  bool get _isTucked => _tuckExtent > 0 && _hidden >= _tuckExtent - _epsilon;
  bool get _isRevealed => _hidden <= _epsilon;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(SliverTucked oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.isScrollingNotifier.removeListener(_handleScrolling);
      _position = position;
      _position?.isScrollingNotifier.addListener(_handleScrolling);
    }
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_handleScrolling);
    widget.controller?._detach(this);
    super.dispose();
  }

  void _handleLayout(double hidden, double tuckExtent) {
    _hidden = hidden;
    _tuckExtent = tuckExtent;
    _hasLayout = true;
    final state = (_isTucked, _isRevealed);
    if (state == _lastReported || widget.controller == null) return;
    _lastReported = state;
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (mounted) widget.controller?._notify();
    });
  }

  void _handleScrolling() {
    if (!widget.snap) return;
    final position = _position;
    if (position == null || position.isScrollingNotifier.value) return;
    // Start the animation outside of the scroll activity change that
    // triggered this listener.
    scheduleMicrotask(() {
      if (!mounted || _position != position || !widget.snap) return;
      if (!position.hasPixels || position.isScrollingNotifier.value) return;
      if (_isTucked || _isRevealed || _hidden > _tuckExtent) return;
      final target = _hidden < _tuckExtent / 2
          ? position.pixels - _hidden
          : position.pixels + _tuckExtent - _hidden;
      position.animateTo(
        target,
        duration: widget.snapDuration,
        curve: widget.snapCurve,
      );
    });
  }

  Future<void> _scrollBy(double delta, Duration duration, Curve curve) {
    final position = _position;
    if (position == null || !position.hasPixels || delta.abs() < _epsilon) {
      return Future<void>.value();
    }
    final target = position.pixels + delta;
    if (duration == Duration.zero) {
      position.jumpTo(target);
      return Future<void>.value();
    }
    return position.animateTo(target, duration: duration, curve: curve);
  }

  Future<void> _reveal(Duration duration, Curve curve) =>
      _scrollBy(-_hidden, duration, curve);

  Future<void> _tuck(Duration duration, Curve curve) {
    if (_hidden >= _tuckExtent) return Future<void>.value();
    return _scrollBy(_tuckExtent - _hidden, duration, curve);
  }

  @override
  Widget build(BuildContext context) {
    return _SliverTuckedRender(
      extent: widget.extent,
      startTucked: widget.startTucked,
      onLayout: _handleLayout,
      sliver: widget.sliver,
    );
  }
}

class _SliverTuckedRender extends SingleChildRenderObjectWidget {
  const _SliverTuckedRender({
    required this.extent,
    required this.startTucked,
    required this.onLayout,
    required Widget sliver,
  }) : super(child: sliver);

  final TuckExtent extent;
  final bool startTucked;
  final TuckLayoutCallback onLayout;

  @override
  RenderSliverTucked createRenderObject(BuildContext context) =>
      RenderSliverTucked(
        extent: extent,
        startTucked: startTucked,
        onLayout: onLayout,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverTucked renderObject,
  ) {
    renderObject
      ..extent = extent
      ..startTucked = startTucked
      ..onLayout = onLayout;
  }
}

/// Reveals or tucks a [SliverTucked] from code, and tells listeners when it
/// becomes fully tucked or fully revealed.
///
/// Pass it to one [SliverTucked] at a time. The values reflect the latest
/// layout, and listeners are notified after the frame in which [isTucked] or
/// [isRevealed] changed, so it's safe to call `setState` from a listener.
///
/// ```dart
/// final tuck = TuckController();
///
/// IconButton(
///   icon: const Icon(Icons.search),
///   onPressed: tuck.reveal,
/// )
/// ```
class TuckController extends ChangeNotifier {
  _SliverTuckedState? _state;

  /// Whether a [SliverTucked] that has been laid out is using this
  /// controller.
  bool get isAttached => _state?._hasLayout ?? false;

  /// How many pixels the sliver hides when it's tucked, as measured in the
  /// latest layout. Zero when not attached.
  double get tuckExtent => isAttached ? _state!._tuckExtent : 0;

  /// How many pixels of the sliver are currently out of view, from zero
  /// (fully revealed) up to [tuckExtent] (fully tucked).
  ///
  /// Scrolling further past a tucked sliver doesn't increase this beyond
  /// [tuckExtent].
  double get hiddenExtent {
    if (!isAttached) return 0;
    final state = _state!;
    return state._hidden.clamp(0, state._tuckExtent).toDouble();
  }

  /// Whether the tucked part of the sliver is fully out of view.
  bool get isTucked => isAttached && _state!._isTucked;

  /// Whether the sliver's leading edge is in view.
  bool get isRevealed => !isAttached || _state!._isRevealed;

  /// Scrolls back until the sliver's leading edge is in view.
  ///
  /// Pass [Duration.zero] to jump. The future completes when the animation
  /// ends. Does nothing when not attached.
  Future<void> reveal({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!isAttached) return Future<void>.value();
    return _state!._reveal(duration, curve);
  }

  /// Scrolls forward until the tucked part of the sliver is out of view.
  ///
  /// Does nothing if it's already tucked or the controller isn't attached.
  /// Meant for a sliver at the top of the scroll view, where [isRevealed] is
  /// true.
  Future<void> tuck({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!isAttached) return Future<void>.value();
    return _state!._tuck(duration, curve);
  }

  /// Reveals the sliver if it's tucked, and tucks it otherwise.
  Future<void> toggle({
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) => isTucked
      ? reveal(duration: duration, curve: curve)
      : tuck(duration: duration, curve: curve);

  void _attach(_SliverTuckedState state) {
    assert(
      _state == null || _state == state,
      'A TuckController can only be used by one SliverTucked at a time.',
    );
    _state = state;
  }

  void _detach(_SliverTuckedState state) {
    if (_state == state) _state = null;
  }

  void _notify() => notifyListeners();
}
