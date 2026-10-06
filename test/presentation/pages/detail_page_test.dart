import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/failures.dart';
import 'package:street_coffee/domain/entities/coffee_shop.dart';
import 'package:street_coffee/domain/entities/comment.dart';
import 'package:street_coffee/presentation/blocs/location/location_bloc.dart';
import 'package:street_coffee/presentation/pages/detail/coffee_detail_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/finders.dart';
import '../../helpers/pump_app.dart';

void main() {
  late TestEnv env;

  setUp(() async {
    env = TestEnv();
    await env.register();
    env.comments.initial = const [];
    env.shops.byId = Right(shop('7',
        name: 'Kopi Senja Senopati',
        facilities: const ['WiFi', 'Colokan', 'Outdoor'],
        menu: const [MenuFavorite(name: 'Es Kopi Susu', imageUrl: '', price: 18000)]));
    env.locationBloc.add(LocationSet(jakarta));
  });
  tearDown(() => env.dispose());

  testWidgets('shows the shop with distance, menu and a WhatsApp CTA',
      (tester) async {
    await env.pump(tester, const CoffeeDetailPage(shopId: '7'));
    await tester.pumpAndSettle();

    expect(env.shops.byIdCalls, ['7']);
    expect(find.text('Kopi Senja Senopati'), findsOneWidget);
    expect(find.text('Pesan via WA'), findsOneWidget);
    expect(find.text('dari kamu'), findsOneWidget);
    await scrollTo(tester, find.text('Es Kopi Susu'));
    await scrollTo(tester, find.text('Belum ada review. Jadi yang pertama!'));
  });

  testWidgets('a shop without WhatsApp disables ordering', (tester) async {
    env.shops.byId = Right(shop('8', whatsapp: ''));
    await env.pump(tester, const CoffeeDetailPage(shopId: '8'));
    await tester.pumpAndSettle();

    expect(find.text('WA belum tersedia'), findsOneWidget);
  });

  testWidgets('a missing shop explains and retries', (tester) async {
    env.shops.byId = const Left(NotFoundFailure());
    await env.pump(tester, const CoffeeDetailPage(shopId: 'gone'));
    await tester.pumpAndSettle();

    expect(find.text('Kedai tidak bisa dimuat'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(env.shops.byIdCalls, ['gone', 'gone']);
  });

  testWidgets('guests are sent to login for "Mau ke sini" and Drop',
      (tester) async {
    await env.pump(tester, const CoffeeDetailPage(shopId: '7'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mau ke sini'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /login'), findsOneWidget);
    expect(env.social.wantWrites, isEmpty);
  });

  testWidgets('members can mark "Mau ke sini"', (tester) async {
    env.auth.initialUser = member;
    await env.pump(tester, const CoffeeDetailPage(shopId: '7'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mau ke sini'));
    await tester.pumpAndSettle();
    expect(env.social.wantWrites, [('7', true)]);
  });

  testWidgets('members can post a review', (tester) async {
    env.auth.initialUser = member;
    await env.pump(tester, const CoffeeDetailPage(shopId: '7'));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextField, 'Tulis review kamu…');
    await scrollTo(tester, field);
    await tester.enterText(field, 'Gula arennya pas');
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();
    expect(env.comments.added, ['Gula arennya pas']);
  });

  testWidgets('existing reviews are listed', (tester) async {
    env.comments.initial = [
      Comment(
          id: 'c1',
          shopId: '7',
          userId: 'u2',
          userName: 'Nadia',
          text: 'Tempatnya enak buat deep talk',
          rating: 5,
          createdAt: DateTime(2026, 9, 30)),
    ];
    await env.pump(tester, const CoffeeDetailPage(shopId: '7'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Tempatnya enak buat deep talk'));
  });

  testWidgets('admins get the admin controls', (tester) async {
    env.auth.initialUser = admin;
    await env.pump(tester, const CoffeeDetailPage(shopId: '7'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit kedai'), findsOneWidget);
    await scrollTo(tester, find.text('Mode admin'));
  });

  testWidgets('long names and many facilities fit 360 dp', (tester) async {
    env.shops.byId = Right(shop('9',
        name: 'Kedai Kopi Tepi Jalan Dengan Nama Yang Panjang Sekali Banget',
        facilities: const ['WiFi', 'Outdoor', 'Musik', 'Parkir', 'AC', 'Colokan', 'Toilet', 'No Smoking']));
    await env.pump(tester, const CoffeeDetailPage(shopId: '9'),
        size: const Size(360, 780));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
