import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/domain/entities/social.dart';
import 'package:street_coffee/domain/repositories/social_repository.dart';
import 'package:street_coffee/presentation/pages/social/feed_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/finders.dart';
import '../../helpers/pump_app.dart';

void main() {
  late TestEnv env;

  setUp(() async {
    env = TestEnv();
    await env.register();
  });
  tearDown(() => env.dispose());

  testWidgets('shows nearby drops as tickets', (tester) async {
    env.social.feed = (_) => Stream.value([drop('d1'), drop('d2', shopId: 's2')]);
    await env.pump(tester, const FeedPage());
    await tester.pumpAndSettle();

    expect(env.social.feedTabs.first, FeedTab.nearby);
    expect(find.text('Es kopi susu-nya juara d1'), findsOneWidget);
    expect(find.text('Kedai s1'), findsOneWidget);
  });

  testWidgets('a feed error (e.g. missing index) offers a working retry',
      (tester) async {
    var attempt = 0;
    env.social.feed = (_) => attempt++ == 0
        ? Stream.error(Exception('failed-precondition'))
        : Stream.value([drop('d1')]);
    await env.pump(tester, const FeedPage());
    await tester.pumpAndSettle();

    expect(find.text('Feed gagal dimuat'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Feed gagal dimuat'), findsNothing);
    expect(find.text('Es kopi susu-nya juara d1'), findsOneWidget);
  });

  testWidgets('an empty feed invites the first Drop', (tester) async {
    await env.pump(tester, const FeedPage());
    await tester.pumpAndSettle();

    expect(find.text('Belum ada Drop di sekitar'), findsOneWidget);
    await tester.tap(find.text('Buat Drop'));
    await tester.pumpAndSettle();
    // Guests have to log in first.
    expect(find.text('ROUTE /login'), findsOneWidget);
  });

  testWidgets('a slow feed shows skeletons, not an error', (tester) async {
    final pending = StreamController<List<Drop>>();
    addTearDown(pending.close);
    env.social.feed = (_) => pending.stream;
    await env.pump(tester, const FeedPage());
    await tester.pump();
    expect(find.text('Feed gagal dimuat'), findsNothing);
    expect(find.text('Belum ada Drop di sekitar'), findsNothing);
  });

  testWidgets('"Teman" asks guests to log in', (tester) async {
    await env.pump(tester, const FeedPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Teman'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk untuk lihat teman'), findsOneWidget);
  });

  testWidgets('switching to Trending re-queries the feed', (tester) async {
    await env.pump(tester, const FeedPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trending'));
    await tester.pumpAndSettle();
    expect(env.social.feedTabs.last, FeedTab.trending);
  });

  testWidgets('guests cheering a Drop are sent to login', (tester) async {
    env.social.feed = (_) => Stream.value([drop('d1', cheers: 12)]);
    await env.pump(tester, const FeedPage());
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('12 Cheers'));
    await tester.tap(find.text('12 Cheers'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /login'), findsOneWidget);
  });

  testWidgets('friends checked in right now appear in the live row',
      (tester) async {
    env.social.live = Stream.value(const [
      LiveCheckin(
          shopId: 's1',
          shopName: 'Kopi Lorong',
          shopImageUrl: '',
          userPhotos: [null],
          handles: ['@nadia']),
    ]);
    await env.pump(tester, const FeedPage());
    await tester.pumpAndSettle();
    expect(find.text('LAGI DI KEDAI SEKARANG'), findsOneWidget);
    expect(find.text('Kopi Lorong'), findsOneWidget);
  });
}
