import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tucked_header/tucked_header.dart';

const double _itemExtent = 50;

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _list({int count = 100}) => SliverFixedExtentList.builder(
  itemExtent: _itemExtent,
  itemCount: count,
  itemBuilder: (context, i) => Text('item $i'),
);

Widget _header(double height, {String label = 'header'}) =>
    SizedBox(height: height, child: Text(label));

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text, skipOffstage: false)).dy;

Future<void> _drag(WidgetTester tester, double dy) async {
  final gesture = await tester.startGesture(const Offset(400, 300));
  // Move in small steps so no fling velocity is left at the end.
  final steps = (dy.abs() / 10).ceil();
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 500));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('initial tuck', () {
    testWidgets('hides a box header before the first frame', (tester) async {
      final log = <double>[];
      final controller = ScrollController();
      controller.addListener(() => log.add(controller.offset));
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            controller: controller,
            slivers: [
              SliverTucked.box(child: _header(80)),
              _list(),
            ],
          ),
        ),
      );
      expect(_position(tester).pixels, 80);
      expect(_top(tester, 'item 0'), 0);
      expect(_top(tester, 'header'), -80);
      // Corrections don't notify scroll listeners.
      expect(log, isEmpty);
    });

    testWidgets('measures a header whose height depends on its content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              SliverTucked.box(
                child: const Column(
                  children: [
                    SizedBox(height: 33),
                    SizedBox(height: 44),
                    Text('header'),
                  ],
                ),
              ),
              _list(),
            ],
          ),
        ),
      );
      final headerHeight = tester
          .getSize(find.byType(Column, skipOffstage: false))
          .height;
      expect(headerHeight, greaterThan(77));
      expect(_position(tester).pixels, headerHeight);
      expect(_top(tester, 'item 0'), 0);
    });

    testWidgets('startTucked: false starts revealed', (tester) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              SliverTucked.box(startTucked: false, child: _header(80)),
              _list(),
            ],
          ),
        ),
      );
      expect(_position(tester).pixels, 0);
      expect(_top(tester, 'header'), 0);
    });

    testWidgets('TuckExtent.pixels hides part of the header', (tester) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              SliverTucked.box(
                extent: const TuckExtent.pixels(30),
                child: _header(80),
              ),
              _list(),
            ],
          ),
        ),
      );
      expect(_position(tester).pixels, 30);
    });

    testWidgets('TuckExtent.pixels is clamped to the sliver', (tester) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              SliverTucked.box(
                extent: const TuckExtent.pixels(500),
                child: _header(80),
              ),
              _list(),
            ],
          ),
        ),
      );
      expect(_position(tester).pixels, 80);
    });

    testWidgets('TuckExtent.toPinned starts a pinned app bar collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              const SliverTucked(
                extent: TuckExtent.toPinned,
                sliver: SliverAppBar(
                  pinned: true,
                  expandedHeight: 200,
                  title: Text('title'),
                ),
              ),
              _list(),
            ],
          ),
        ),
      );
      expect(_position(tester).pixels, 200 - kToolbarHeight);
      expect(_top(tester, 'item 0'), kToolbarHeight);
      expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
    });

    testWidgets('a header after a tucked pinned app bar hides under it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              const SliverTucked(
                extent: TuckExtent.toPinned,
                sliver: SliverAppBar(pinned: true, expandedHeight: 200),
              ),
              SliverTucked.box(child: _header(60)),
              _list(),
            ],
          ),
        ),
      );
      expect(_position(tester).pixels, 200 - kToolbarHeight + 60);
      expect(_top(tester, 'item 0'), kToolbarHeight);
    });

    testWidgets('does not tuck a sliver that starts off screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
                slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
              SliverTucked.box(child: _header(80)),
              _list(),
            ],
          ),
        ),
      );
      expect(_position(tester).pixels, 0);
      _position(tester).jumpTo(1900);
      await tester.pump();
      expect(_position(tester).pixels, 1900);
      expect(_top(tester, 'header'), 100);
    });

    testWidgets('springs back when the content is too short to scroll', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              SliverTucked.box(child: _header(80)),
              _list(count: 2),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, 0);
      expect(_top(tester, 'header'), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('works on a horizontal axis', (tester) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            scrollDirection: Axis.horizontal,
            slivers: [
              SliverTucked.box(
                child: const SizedBox(width: 120, child: Text('header')),
              ),
              SliverFixedExtentList.builder(
                itemExtent: 100,
                itemCount: 50,
                itemBuilder: (context, i) => Text('item $i'),
              ),
            ],
          ),
        ),
      );
      expect(_position(tester).pixels, 120);
      expect(tester.getTopLeft(find.text('item 0')).dx, 0);
    });

    testWidgets('works in a shrink-wrapped scroll view', (tester) async {
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            shrinkWrap: true,
            slivers: [
              SliverTucked.box(child: _header(80)),
              _list(),
            ],
          ),
        ),
      );
      expect(_position(tester).pixels, 80);
      expect(_top(tester, 'item 0'), 0);
    });
  });

  group('resizing', () {
    Future<ValueNotifier<double>> pumpResizable(
      WidgetTester tester, {
      bool startTucked = true,
    }) async {
      final height = ValueNotifier<double>(80);
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              SliverTucked.box(
                startTucked: startTucked,
                child: ValueListenableBuilder<double>(
                  valueListenable: height,
                  builder: (context, h, _) => _header(h),
                ),
              ),
              _list(),
            ],
          ),
        ),
      );
      return height;
    }

    testWidgets('keeps the header hidden when it grows while tucked', (
      tester,
    ) async {
      final height = await pumpResizable(tester);
      height.value = 130;
      await tester.pump();
      expect(_position(tester).pixels, 130);
      expect(_top(tester, 'item 0'), 0);
    });

    testWidgets('keeps the content steady when it shrinks while tucked', (
      tester,
    ) async {
      final height = await pumpResizable(tester);
      height.value = 20;
      await tester.pump();
      expect(_position(tester).pixels, 20);
      expect(_top(tester, 'item 0'), 0);
    });

    testWidgets('keeps the content steady while scrolled far past', (
      tester,
    ) async {
      final height = await pumpResizable(tester);
      _position(tester).jumpTo(80 + 10 * _itemExtent);
      await tester.pump();
      expect(_top(tester, 'item 10'), 0);
      height.value = 200;
      await tester.pump();
      expect(_top(tester, 'item 10'), 0);
    });

    testWidgets('lets the content move when the header is revealed', (
      tester,
    ) async {
      final height = await pumpResizable(tester, startTucked: false);
      height.value = 130;
      await tester.pump();
      expect(_position(tester).pixels, 0);
      expect(_top(tester, 'item 0'), 130);
    });

    testWidgets('lets the content move when the header is partly visible', (
      tester,
    ) async {
      final height = await pumpResizable(tester);
      _position(tester).jumpTo(40);
      await tester.pump();
      height.value = 130;
      await tester.pump();
      expect(_position(tester).pixels, 40);
      expect(_top(tester, 'item 0'), 90);
    });

    testWidgets('follows a new extent while tucked', (tester) async {
      Widget build(TuckExtent extent) => _app(
        CustomScrollView(
          slivers: [
            SliverTucked.box(extent: extent, child: _header(80)),
            _list(),
          ],
        ),
      );
      await tester.pumpWidget(build(TuckExtent.full));
      expect(_position(tester).pixels, 80);
      await tester.pumpWidget(build(const TuckExtent.pixels(30)));
      expect(_position(tester).pixels, 30);
      expect(_top(tester, 'header'), -30);
    });
  });

  group('snap', () {
    Future<void> pumpSnap(WidgetTester tester, {required bool snap}) =>
        tester.pumpWidget(
          _app(
            CustomScrollView(
              slivers: [
                SliverTucked.box(snap: snap, child: _header(80)),
                _list(),
              ],
            ),
          ),
        );

    testWidgets('tucks back when less than half is revealed', (tester) async {
      await pumpSnap(tester, snap: true);
      await _drag(tester, 30);
      expect(_position(tester).pixels, 80);
    });

    testWidgets('reveals fully when more than half is revealed', (
      tester,
    ) async {
      await pumpSnap(tester, snap: true);
      await _drag(tester, 60);
      expect(_position(tester).pixels, 0);
    });

    testWidgets('leaves a scrolled-past header alone', (tester) async {
      await pumpSnap(tester, snap: true);
      await _drag(tester, -200);
      expect(_position(tester).pixels, 280);
    });

    testWidgets('stays where it was dropped without snap', (tester) async {
      await pumpSnap(tester, snap: false);
      await _drag(tester, 30);
      expect(_position(tester).pixels, 50);
    });
  });

  group('TuckController', () {
    testWidgets('is empty when not attached', (tester) async {
      final controller = TuckController();
      expect(controller.isAttached, isFalse);
      expect(controller.isTucked, isFalse);
      expect(controller.isRevealed, isTrue);
      expect(controller.tuckExtent, 0);
      expect(controller.hiddenExtent, 0);
      await controller.reveal();
      await controller.tuck();
    });

    testWidgets('reports the state and reveals and tucks', (tester) async {
      final controller = TuckController();
      var notifications = 0;
      controller.addListener(() => notifications++);
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              SliverTucked.box(controller: controller, child: _header(80)),
              _list(),
            ],
          ),
        ),
      );
      expect(controller.isAttached, isTrue);
      expect(controller.isTucked, isTrue);
      expect(controller.isRevealed, isFalse);
      expect(controller.tuckExtent, 80);
      expect(controller.hiddenExtent, 80);
      expect(notifications, 1);

      final reveal = controller.reveal();
      await tester.pumpAndSettle();
      await reveal;
      expect(_position(tester).pixels, 0);
      expect(controller.isRevealed, isTrue);
      expect(controller.isTucked, isFalse);
      expect(notifications, 3); // left tucked, then reached revealed

      controller.tuck();
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, 80);
      expect(controller.isTucked, isTrue);

      controller.toggle(duration: Duration.zero);
      await tester.pump();
      expect(_position(tester).pixels, 0);
      controller.toggle(duration: Duration.zero);
      await tester.pump();
      expect(_position(tester).pixels, 80);
    });

    testWidgets('caps hiddenExtent and leaves a scrolled-past sliver alone', (
      tester,
    ) async {
      final controller = TuckController();
      await tester.pumpWidget(
        _app(
          CustomScrollView(
            slivers: [
              SliverTucked.box(controller: controller, child: _header(80)),
              _list(),
            ],
          ),
        ),
      );
      _position(tester).jumpTo(500);
      await tester.pump();
      expect(controller.hiddenExtent, 80);
      expect(controller.isTucked, isTrue);
      await controller.tuck();
      expect(_position(tester).pixels, 500);
      controller.reveal(duration: Duration.zero);
      await tester.pump();
      expect(_position(tester).pixels, 0);
    });

    testWidgets('moves to a new SliverTucked and detaches on dispose', (
      tester,
    ) async {
      final a = TuckController();
      final b = TuckController();
      Widget build(TuckController? c) => _app(
        CustomScrollView(
          slivers: [
            SliverTucked.box(controller: c, child: _header(80)),
            _list(),
          ],
        ),
      );
      await tester.pumpWidget(build(a));
      expect(a.isAttached, isTrue);
      await tester.pumpWidget(build(b));
      expect(a.isAttached, isFalse);
      expect(b.isAttached, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(b.isAttached, isFalse);
    });
  });

  testWidgets('RenderSliverTucked describes itself', (tester) async {
    await tester.pumpWidget(
      _app(
        CustomScrollView(
          slivers: [
            SliverTucked.box(child: _header(80)),
            _list(),
          ],
        ),
      ),
    );
    final render = tester.renderObject<RenderSliverTucked>(
      find.byType(SliverTucked, skipOffstage: false),
    );
    expect(render.tuckExtent, 80);
    expect(render.hiddenExtent, 80);
    expect(render.toStringDeep(), contains('TuckExtent.full'));
  });

  test('TuckExtent values', () {
    const geometry = SliverGeometry(
      scrollExtent: 200,
      paintExtent: 200,
      maxPaintExtent: 200,
      maxScrollObstructionExtent: 56,
    );
    expect(TuckExtent.full.resolve(geometry), 200);
    expect(TuckExtent.toPinned.resolve(geometry), 144);
    expect(const TuckExtent.pixels(30).resolve(geometry), 30);
    expect(const TuckExtent.pixels(30), const TuckExtent.pixels(30));
    expect(
      const TuckExtent.pixels(30).hashCode,
      const TuckExtent.pixels(30).hashCode,
    );
    expect(TuckExtent.full.toString(), 'TuckExtent.full');
    expect(TuckExtent.toPinned.toString(), 'TuckExtent.toPinned');
    expect(const TuckExtent.pixels(30).toString(), 'TuckExtent.pixels(30.0)');
  });
}
