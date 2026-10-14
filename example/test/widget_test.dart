import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tucked_header_example/main.dart';

void main() {
  testWidgets('search starts tucked under the app bar', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(
      tester.getBottomLeft(find.byType(SearchField, skipOffstage: false)).dy,
      lessThanOrEqualTo(appBarBottom),
    );
    expect(tester.getTopLeft(find.byType(MailTile).first).dy, appBarBottom);
    expect(find.byTooltip('Show search'), findsOneWidget);
  });

  testWidgets('the search button reveals and hides it', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;

    await tester.tap(find.byTooltip('Show search'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(SearchField)).dy, appBarBottom);
    expect(find.byTooltip('Hide search'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide search'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(MailTile).first).dy, appBarBottom);
    expect(find.byTooltip('Show search'), findsOneWidget);
  });
}
