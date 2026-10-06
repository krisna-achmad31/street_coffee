import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/failures.dart';
import 'package:street_coffee/presentation/blocs/location/location_bloc.dart';
import 'package:street_coffee/presentation/pages/admin/add_edit_shop_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/finders.dart';
import '../../helpers/pump_app.dart';

void main() {
  late TestEnv env;

  setUp(() async {
    env = TestEnv();
    await env.register();
    env.auth.initialUser = admin;
    env.locationBloc.add(LocationSet(jakarta));
  });
  tearDown(() => env.dispose());

  final existing = shop('42',
      name: 'Kopi Pojok',
      imageUrl: 'https://example.com/cover.jpg',
      whatsapp: '6281234567890');

  Future<void> save(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty new shop lists what is missing and saves nothing',
      (tester) async {
    await env.pump(tester, const AddEditShopPage());
    await tester.pumpAndSettle();

    expect(find.text('Tambah Kedai'), findsOneWidget);
    expect(find.text('0/8'), findsOneWidget);

    await save(tester, 'Simpan kedai');
    expect(find.text('Lengkapi dulu: foto cover, pin lokasi di peta, vibe utama'),
        findsOneWidget);
    expect(env.adminRepo.lastData, isNull);
  });

  testWidgets('required fields show inline errors', (tester) async {
    await env.pump(tester, AddEditShopPage(existingShop: existing));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nama kedai *'), '');
    final wa = find.widgetWithText(TextFormField, 'WhatsApp');
    await scrollTo(tester, wa);
    await tester.enterText(wa, '12');
    await save(tester, 'Simpan perubahan');

    await scrollTo(tester, find.text('Nomor tidak valid, contoh 812 3456 7890'));
    await scrollTo(tester, find.text('Wajib diisi'), up: true);
    expect(env.adminRepo.lastData, isNull);
  });

  testWidgets('fields scrolled off screen are still validated',
      (tester) async {
    await env.pump(tester, AddEditShopPage(existingShop: existing));
    await tester.pumpAndSettle();

    // Clear the name at the top, edit a field at the bottom (focus moves
    // away from the name), then save.
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama kedai *'), '');
    final maps = find.widgetWithText(TextFormField, 'Link Google Maps');
    await scrollTo(tester, maps);
    await tester.enterText(maps, 'https://maps.app.goo.gl/abc');
    await tester.pumpAndSettle();
    await save(tester, 'Simpan perubahan');

    expect(env.adminRepo.lastData, isNull);
    await scrollTo(tester, find.text('Wajib diisi'), up: true);
  });

  testWidgets('editing loads the shop and saves normalised data',
      (tester) async {
    await env.pump(tester, AddEditShopPage(existingShop: existing));
    await tester.pumpAndSettle();

    expect(find.text('Edit Kedai'), findsOneWidget);
    // Stored as 62…, edited after the +62 prefix.
    await scrollTo(tester, find.widgetWithText(TextFormField, '81234567890'));

    final min = find.widgetWithText(TextFormField, '12000');
    await scrollTo(tester, min);
    await tester.enterText(min, '15k');
    await tester.enterText(find.widgetWithText(TextFormField, '25000'), '10.000');
    await save(tester, 'Simpan perubahan');

    final data = env.adminRepo.lastData!;
    expect(env.adminRepo.lastUpdatedId, '42');
    expect(data.name, 'Kopi Pojok');
    expect(data.whatsappNumber, '6281234567890');
    // "15k" parsed, and a max below the min is swapped.
    expect((data.minPrice, data.maxPrice), (10000, 15000));
    expect(data.priceRange, 'Rp 10k–15k');
    expect(data.openFrom, '08:00');
    expect(data.openUntil, '23:00');
    expect(data.vibes, contains(data.vibe));
    // Saved: the form closes back to the previous screen.
    expect(find.text('Edit Kedai'), findsNothing);
  });

  testWidgets('menu items can be added and are saved', (tester) async {
    await env.pump(tester, AddEditShopPage(existingShop: existing));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Tambah menu'));
    await tester.tap(find.text('Tambah menu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Hapus menu'), findsOneWidget);

    final name = find.descendant(
        of: find.byType(ReorderableListView), matching: find.byType(TextField)).first;
    await tester.enterText(name, 'Es Kopi Susu');
    await save(tester, 'Simpan perubahan');
    expect(env.adminRepo.lastData!.menuItems.single.name, 'Es Kopi Susu');
  });

  testWidgets('a failed save keeps the form open with the reason',
      (tester) async {
    env.adminRepo.updateResult =
        const Left(ServerFailure('Kamu tidak punya akses ke data ini.'));
    await env.pump(tester, AddEditShopPage(existingShop: existing));
    await tester.pumpAndSettle();

    await save(tester, 'Simpan perubahan');
    expect(find.text('Kamu tidak punya akses ke data ini.'), findsOneWidget);
    expect(find.text('Edit Kedai'), findsOneWidget);
  });

  testWidgets('fits a 360 dp screen', (tester) async {
    await env.pump(tester, AddEditShopPage(existingShop: existing),
        size: const Size(360, 780));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
