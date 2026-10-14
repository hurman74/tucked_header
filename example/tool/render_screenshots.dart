// Renders the README images into ../doc/. Run from the example directory:
//
//   flutter test tool/render_screenshots.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tucked_header/tucked_header.dart';
import 'package:tucked_header_example/main.dart';

import 'readme_shots.dart';

const Size _gifCanvas = Size(400, 680);

Offset _phoneCenter(WidgetTester tester) =>
    tester.getCenter(find.byType(InboxPage));

Future<void> _drag(
  WidgetTester tester,
  GifRecorder gif,
  double dy, {
  int steps = 12,
}) async {
  final gesture = await tester.startGesture(_phoneCenter(tester));
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 40));
    await gif.frame(5);
  }
  await tester.pump(const Duration(milliseconds: 300));
  await gesture.up();
  await _settle(tester, gif);
}

Future<void> _settle(WidgetTester tester, GifRecorder gif) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 60));
    await gif.frame(6);
  }
  await tester.pumpAndSettle();
}

/// An inbox scrolled the usual way: a guessed `initialScrollOffset`.
Widget _guessedInbox(double guess) {
  return Scaffold(
    body: CustomScrollView(
      controller: ScrollController(initialScrollOffset: guess),
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Inbox')),
        const SliverToBoxAdapter(child: SearchField()),
        SliverList.builder(
          itemCount: mails.length,
          itemBuilder: (context, i) => MailTile(mail: mails[i]),
        ),
      ],
    ),
  );
}

Widget _tuckedInbox() {
  return Scaffold(
    body: CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Inbox')),
        SliverTucked.box(child: const SearchField()),
        SliverList.builder(
          itemCount: mails.length,
          itemBuilder: (context, i) => MailTile(mail: mails[i]),
        ),
      ],
    ),
  );
}

Widget _largeText(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.3)),
    child: child,
  ),
);

void main() {
  setUpAll(loadShotFonts);

  testWidgets('demo.gif', (tester) async {
    final boundary = await pumpShot(
      tester,
      _gifCanvas,
      phone(const InboxPage()),
    );
    final gif = GifRecorder(tester, boundary, width: 340);
    await gif.frame(120);

    // Pull down a little: snap tucks it back.
    await _drag(tester, gif, 40, steps: 6);
    await gif.frame(60);
    // Pull down further: snap opens it.
    await _drag(tester, gif, 90, steps: 8);
    await gif.frame(100);
    // Scroll the list away, then bring search back with the button.
    await _drag(tester, gif, -260);
    await gif.frame(60);
    await tester.tap(find.byTooltip('Show search'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await gif.frame(5);
    }
    await tester.pumpAndSettle();
    await gif.frame(150);
    gif.save('demo.gif');
  });

  testWidgets('comparison.png', (tester) async {
    // The guess fits the field at the default text size (64 px), but the
    // real header is taller: it has chips, and the text is scaled up.
    await writePng(
      tester,
      'comparison.png',
      const Size(800, 760),
      _largeText(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                caption(
                  'initialScrollOffset: 64',
                  detail:
                      'A guessed height leaves the\n'
                      'chips showing at 130% text',
                  detailColor: const Color(0xFFC5221F),
                ),
                phone(_guessedInbox(64)),
              ],
            ),
            const SizedBox(width: 32),
            Column(
              children: [
                caption(
                  'SliverTucked',
                  detail:
                      'Measured during layout:\n'
                      'hidden at any text size',
                  detailColor: const Color(0xFF188038),
                ),
                phone(_tuckedInbox()),
              ],
            ),
          ],
        ),
      ),
    );
  });
}
