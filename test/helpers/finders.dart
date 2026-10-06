import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page's main vertical scroll view (carousels inside scroll too).
final pageScroll = find.byType(Scrollable).first;

/// Scrolls the page (down, or [up]) until [target] is built, then brings it
/// fully on screen. Jumps the scroll position instead of dragging, so a map
/// or carousel under the finger can't swallow the gesture.
Future<void> scrollTo(WidgetTester tester, Finder target, {bool up = false}) async {
  final pos = tester.state<ScrollableState>(pageScroll).position;
  for (var i = 0; i < 100 && target.evaluate().isEmpty; i++) {
    final next = (pos.pixels + (up ? -300 : 300))
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (next == pos.pixels) break;
    pos.jumpTo(next);
    await tester.pump();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
