import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/redeem_code.dart';
import 'package:street_coffee/domain/entities/commerce.dart';
import 'package:street_coffee/presentation/pages/commerce/use_promo_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  late TestEnv env;

  setUp(() async {
    env = TestEnv();
    await env.register();
    env.auth.initialUser = member;
  });
  tearDown(() => env.dispose());

  const active = Membership(
      active: true, plan: 'monthly', redeemSecret: 'member-secret-123');

  testWidgets('members get the rotating code the cashier will verify',
      (tester) async {
    env.commerce.membership = () => Stream.value(active);
    final before = DateTime.now();
    await env.pump(tester, UsePromoPage(promo: promo()));
    await tester.pump();
    await tester.pump();

    // The code is shown as six boxes and announced as one label.
    final label = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label)
        .firstWhere((l) => l?.startsWith('Kode promo') ?? false)!;
    final shown = label.replaceFirst('Kode promo ', '').replaceAll(' ', '');
    final expected = {
      for (final t in [before, DateTime.now()])
        RedeemCode.generate(secret: active.redeemSecret!, promoId: 'p1', at: t),
    };
    expect(shown, hasLength(RedeemCode.length));
    expect(expected, contains(shown));

    // The server is told a member is at this counter.
    expect(env.commerce.redeemIntents, ['p1']);
    expect(find.textContaining('kuota tersisa 17'), findsOneWidget);
  });

  testWidgets('non-members see the paywall text instead of a code',
      (tester) async {
    env.commerce.membership = () => Stream.value(Membership.none);
    await env.pump(tester, UsePromoPage(promo: promo()));
    await tester.pump();
    await tester.pump();

    expect(find.text('Promo ini khusus member Street Pass.'), findsOneWidget);
  });

  testWidgets('while the membership loads it says so', (tester) async {
    final pending = StreamController<Membership>();
    addTearDown(pending.close);
    env.commerce.membership = () => pending.stream;
    await env.pump(tester, UsePromoPage(promo: promo(memberOnly: false)));
    await tester.pump();

    expect(find.text('Menyiapkan kode member…'), findsOneWidget);
  });

  testWidgets('fits a 360 dp screen', (tester) async {
    env.commerce.membership = () => Stream.value(active);
    await env.pump(tester, UsePromoPage(promo: promo()),
        size: const Size(360, 740));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
