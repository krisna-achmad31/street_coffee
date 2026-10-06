import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/domain/entities/social.dart';
import 'package:street_coffee/presentation/pages/profile/profile_page.dart';

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

  testWidgets('guests can sign in from the profile tab', (tester) async {
    await env.pump(tester, const ProfilePage());
    await tester.pumpAndSettle();

    expect(find.text('Belum masuk'), findsOneWidget);
    await tester.tap(find.text('Masuk dengan Google'));
    await tester.pumpAndSettle();
    expect(find.text('Belum masuk'), findsNothing);
  });

  testWidgets('members see their passport and stats', (tester) async {
    env.auth.initialUser = member;
    env.social.profile = Stream.value(const UserProfile(
        uid: 'u1', handle: '@raka', displayName: 'Raka', dropsCount: 7));
    await env.pump(tester, const ProfilePage());
    await tester.pumpAndSettle();

    expect(find.text('@raka'), findsWidgets);
  });

  testWidgets('"Mau ke sini" lists saved shops and opens them',
      (tester) async {
    env.auth.initialUser = member;
    env.social.wanted = () => Stream.value([shop('3', name: 'Kopi Ujung Gang')]);
    await env.pump(tester, const ProfilePage());
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Mau ke sini'));
    await tester.tap(find.text('Mau ke sini'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Kopi Ujung Gang'));
    await tester.tap(find.text('Kopi Ujung Gang'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /detail/3'), findsOneWidget);
  });

  testWidgets('"Mau ke sini" failing to load can be retried', (tester) async {
    env.auth.initialUser = member;
    var attempt = 0;
    env.social.wanted = () => attempt++ == 0
        ? Stream.error(Exception('permission-denied'))
        : Stream.value([shop('3', name: 'Kopi Ujung Gang')]);
    await env.pump(tester, const ProfilePage());
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Mau ke sini'));
    await tester.tap(find.text('Mau ke sini'));
    await tester.pumpAndSettle();
    final error = find.text('Daftar "Mau ke sini" gagal dimuat.');
    await scrollTo(tester, error);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Kopi Ujung Gang'));
  });

  testWidgets('"Keluar" signs out', (tester) async {
    env.auth.initialUser = member;
    await env.pump(tester, const ProfilePage());
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Keluar'));
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(env.auth.signOutCalls, 1);
    expect(find.text('Belum masuk'), findsOneWidget);
  });
}
