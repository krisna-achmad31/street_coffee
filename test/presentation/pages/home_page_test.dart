import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/failures.dart';
import 'package:street_coffee/presentation/blocs/location/location_bloc.dart';
import 'package:street_coffee/presentation/pages/home/home_page.dart';

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

  testWidgets('loads nearby shops for the current location', (tester) async {
    env.shops.nearby = Right([
      shop('1', name: 'Kopi Senja', km: 0.35, featured: true),
      shop('2', name: 'Kopi Lorong', km: 1.2),
    ]);
    env.locationBloc.add(LocationSet(jakarta));
    await env.pump(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.text('Kebayoran Baru'), findsOneWidget);
    expect(find.text('Featured Spots'), findsOneWidget);
    await scrollTo(tester, find.text('Kopi Lorong'));
    expect(find.text('Terdekat dari kamu'), findsOneWidget);
    expect(env.shops.nearbyCalls, isNotEmpty);
  });

  testWidgets('a failed load shows a retry that reloads', (tester) async {
    env.shops.nearby = const Left(NetworkFailure());
    env.locationBloc.add(LocationSet(jakarta));
    await env.pump(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.text('Kedai gagal dimuat'), findsOneWidget);
    // The featured carousel hides instead of repeating the error.
    expect(find.text('Featured Spots'), findsNothing);

    env.shops.nearby = Right([shop('1', name: 'Kopi Senja')]);
    final calls = env.shops.nearbyCalls.length;
    await scrollTo(tester, find.text('Coba lagi'));
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(env.shops.nearbyCalls.length, calls + 1);
    expect(find.text('Kedai gagal dimuat'), findsNothing);
    await scrollTo(tester, find.text('Kopi Senja').last);
  });

  testWidgets('no shops nearby offers to change location', (tester) async {
    env.locationBloc.add(LocationSet(jakarta));
    await env.pump(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.text('Belum ada kedai'), findsOneWidget);
    expect(find.text('Ganti lokasi'), findsOneWidget);
  });

  testWidgets('denied location permission explains itself instead of spinning',
      (tester) async {
    env.location.current = const Left(LocationFailure(
        'Izin lokasi ditolak', LocationIssue.permissionDenied));
    env.locationBloc.add(LocationGetCurrent());
    await env.pump(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('lokasi'), findsWidgets);
    expect(env.shops.nearbyCalls, isEmpty);
  });

  testWidgets('guests see the Street Pass banner and it opens the pass page',
      (tester) async {
    env.locationBloc.add(LocationSet(jakarta));
    await env.pump(tester, const HomePage());
    await tester.pumpAndSettle();

    final banner = find.text('Street Pass: promo di kedai partner');
    await scrollTo(tester, banner);
    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /street-pass'), findsOneWidget);
  });

  testWidgets('trending drops appear when the feed has some', (tester) async {
    env.social.feed = (_) => Stream.value([drop('d1'), drop('d2')]);
    env.locationBloc.add(LocationSet(jakarta));
    await env.pump(tester, const HomePage());
    await tester.pumpAndSettle();

    expect(find.text('Lagi rame di-Drop 🔥'), findsOneWidget);
  });

  testWidgets('fits a 360 dp wide phone without overflow', (tester) async {
    env.shops.nearby = Right([
      shop('1', name: 'Kedai Kopi Dengan Nama Yang Sangat Panjang Sekali',
          km: 12.4, featured: true),
    ]);
    env.locationBloc.add(LocationSet(jakarta));
    await env.pump(tester, const HomePage(), size: const Size(360, 780));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
