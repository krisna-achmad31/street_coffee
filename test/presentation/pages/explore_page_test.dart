import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/failures.dart';
import 'package:street_coffee/presentation/blocs/location/location_bloc.dart';
import 'package:street_coffee/presentation/pages/explore/explore_page.dart';
import 'package:street_coffee/presentation/widgets/cards/shop_cards.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  late TestEnv env;

  setUp(() async {
    env = TestEnv();
    await env.register();
    env.shops.nearby = Right([
      shop('far', name: 'Kopi Jauh', km: 3, rating: 4.1, minPrice: 8000),
      shop('near', name: 'Kopi Dekat', km: 0.3, rating: 4.8, open: false),
      shop('mid', name: 'Kopi Tengah', km: 1, rating: 3.6),
    ]);
    env.locationBloc.add(LocationSet(jakarta));
  });
  tearDown(() => env.dispose());

  List<String> visibleNames(WidgetTester tester) => tester
      .widgetList<ShopCard>(find.byType(ShopCard))
      .map((c) => c.shop.name)
      .toList();

  testWidgets('lists shops nearest first with a result count', (tester) async {
    await env.pump(tester, const ExplorePage());
    await tester.pumpAndSettle();

    expect(find.text('3 kedai ditemukan'), findsOneWidget);
    expect(visibleNames(tester), ['Kopi Dekat', 'Kopi Tengah', 'Kopi Jauh']);
  });

  testWidgets('"Rating 4+" filters locally without a new query',
      (tester) async {
    await env.pump(tester, const ExplorePage());
    await tester.pumpAndSettle();
    final calls = env.shops.nearbyCalls.length;

    await tester.tap(find.text('Rating 4+'));
    await tester.pumpAndSettle();

    expect(find.text('2 kedai ditemukan'), findsOneWidget);
    expect(visibleNames(tester), isNot(contains('Kopi Tengah')));
    expect(env.shops.nearbyCalls.length, calls);
  });

  testWidgets('"Buka sekarang" asks the server for open shops only',
      (tester) async {
    await env.pump(tester, const ExplorePage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buka sekarang'));
    await tester.pumpAndSettle();
    expect(env.shops.nearbyCalls.last.isOpen, isTrue);

    await tester.tap(find.text('Buka sekarang'));
    await tester.pumpAndSettle();
    expect(env.shops.nearbyCalls.last.isOpen, isNull);
  });

  testWidgets('a vibe from Home arrives as an active filter chip',
      (tester) async {
    await env.pump(tester, const ExplorePage(initialVibe: 'Deep Talk'));
    await tester.pumpAndSettle();

    expect(env.shops.nearbyCalls.last.vibe, 'Deep Talk');
    expect(find.text('Deep Talk'), findsWidgets);
  });

  testWidgets('search is debounced and sends the typed query', (tester) async {
    env.shops.search = Right([shop('s', name: 'Kopi Senja')]);
    await env.pump(tester, const ExplorePage());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sen');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'senja');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(env.shops.searchCalls, ['senja']);
    expect(visibleNames(tester), ['Kopi Senja']);
  });

  testWidgets('no match offers a reset that clears filters and search',
      (tester) async {
    env.shops.search = const Right([]);
    await env.pump(tester, const ExplorePage());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'tidak ada');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada kedai yang cocok'), findsOneWidget);

    await tester.tap(find.text('Reset filter'));
    await tester.pumpAndSettle();
    expect(find.text('3 kedai ditemukan'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    env.shops.nearby = const Left(ServerFailure('Server lagi sibuk. Coba lagi sebentar.'));
    await env.pump(tester, const ExplorePage());
    await tester.pumpAndSettle();
    expect(find.text('Kedai gagal dimuat'), findsOneWidget);
    expect(find.text('Server lagi sibuk. Coba lagi sebentar.'), findsOneWidget);

    env.shops.nearby = Right([shop('1', name: 'Kopi Pulih', km: 1)]);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(visibleNames(tester), ['Kopi Pulih']);
  });

  testWidgets('tapping a shop opens its detail page', (tester) async {
    await env.pump(tester, const ExplorePage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kopi Dekat'));
    await tester.pumpAndSettle();
    expect(find.text('ROUTE /detail/near'), findsOneWidget);
  });

  testWidgets('map view pins shops, credits OSM and switches back',
      (tester) async {
    await env.pump(tester, const ExplorePage(startOnMap: true));
    await tester.pumpAndSettle();

    expect(find.text('© OpenStreetMap'), findsOneWidget);
    // The nearest pinned shop is pre-selected in the bottom card.
    expect(find.byType(ShopCard), findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    expect(find.text('3 kedai ditemukan'), findsOneWidget);
  });
}
