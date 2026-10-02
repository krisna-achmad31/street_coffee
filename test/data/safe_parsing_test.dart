import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/links.dart';
import 'package:street_coffee/core/utils/whatsapp_launcher.dart';
import 'package:street_coffee/data/models/coffee_shop_model.dart';
import 'package:street_coffee/data/models/json_reader.dart';
import 'package:street_coffee/data/models/social_models.dart';
import 'package:street_coffee/domain/entities/coffee_shop.dart';
import 'package:street_coffee/domain/entities/social.dart';
import 'package:street_coffee/presentation/blocs/transformers.dart';

// ignore: subtype_of_sealed_class
/// Minimal snapshot: the models only use id, exists and data().
class _Doc implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;
  _Doc(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data;
  @override
  bool get exists => _data != null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('Json coercion', () {
    test('numbers arrive as int, double or string', () {
      final j = Json.of({'a': 4.0, 'b': '12', 'c': '4,5', 'd': double.nan, 'e': true});
      expect(j.integer('a'), 4);
      expect(j.integer('b'), 12);
      expect(j.dbl('c'), 4.5);
      expect(j.dblOrNull('d'), isNull);
      expect(j.integer('e'), 0);
      expect(j.integer('missing', 7), 7);
    });

    test('dates from Timestamp, millis, seconds, ISO, garbage', () {
      final t = DateTime(2026, 10, 2, 9);
      final j = Json.of({
        'ts': Timestamp.fromDate(t),
        'ms': t.millisecondsSinceEpoch,
        's': t.millisecondsSinceEpoch ~/ 1000,
        'iso': t.toIso8601String(),
        'bad': 'kemarin',
      });
      expect(j.date('ts'), t);
      expect(j.date('ms'), t);
      expect(j.date('s'), t);
      expect(j.date('iso'), t);
      expect(j.date('bad'), isNull);
    });

    test('string lists tolerate mixed, blank, duplicate and lone values', () {
      expect(Json.asStringList(['WiFi', null, 3, ' ', 'WiFi', {'x': 1}]), ['WiFi', '3']);
      expect(Json.asStringList('Santai'), ['Santai']);
      expect(Json.asStringList(42), isEmpty);
    });

    test('non-string map keys (callable payloads on Android)', () {
      final Map<Object?, Object?> raw = {'valid': true, 1: 'x'};
      expect(Json.of(raw).boolean('valid'), isTrue);
      expect(Json.of(raw).str('1'), 'x');
    });

    test('only http(s) urls survive', () {
      expect(Json.url('https://x.id/a.jpg'), 'https://x.id/a.jpg');
      expect(Json.url('gs://bucket/a.jpg'), '');
      expect(Json.url(12), '');
    });

    test('parseEach skips the item that throws', () {
      final out = parseEach<int, int>([1, 2, 3], (i) => i == 2 ? throw StateError('x') : i);
      expect(out, [1, 3]);
    });
  });

  group('CoffeeShopModel.fromMap', () {
    test('a console-typed document with every type wrong still parses', () {
      final s = CoffeeShopModel.fromMap({
        'name': 123,
        'latitude': '-6.24',
        'longitude': 106.79,
        'rating': '9',
        'reviewCount': 12.0,
        'minPrice': '15000',
        'maxPrice': 5000,
        'vibes': 'Santai',
        'facilities': ['WiFi', null],
        'imageUrl': 'not a url',
        'galleryUrls': ['https://x.id/1.jpg', 'oops', 7],
        'menuFavorites': [
          {'name': 'Es Kopi Susu', 'price': '18000'},
          {'name': '', 'price': 1},
          'garbage',
          {'name': 'Air', 'price': -5},
        ],
        'whatsappNumber': '0812-3456-7890',
        'isOpen': 'true',
        'openFrom': '7.30',
        'openUntil': '99:99',
        'pro': 'yes',
      }, 'id1', now: DateTime(2026, 10, 2, 12));
      expect(s.name, '123');
      expect(s.latitude, -6.24);
      expect(s.rating, 5);
      expect(s.reviewCount, 12);
      expect(s.minPrice, 15000);
      expect(s.maxPrice, 15000, reason: 'max < min is lifted to min');
      expect(s.vibes, ['Santai']);
      expect(s.facilities, ['WiFi']);
      expect(s.imageUrl, '');
      expect(s.galleryUrls, ['https://x.id/1.jpg']);
      expect(s.menuFavorites.map((m) => m.name), ['Es Kopi Susu', 'Air']);
      expect(s.menuFavorites.first.price, 18000);
      expect(s.menuFavorites.last.price, isNull);
      expect(s.whatsappNumber, '6281234567890');
      expect(s.isOpen, isTrue);
      expect(s.openFrom, '07:30');
      expect(s.openUntil, '22:00');
      expect(s.proTier, 'basic');
      expect(s.hasLocation, isTrue);
    });

    test('empty document gives safe defaults', () {
      final s = CoffeeShopModel.fromMap({}, 'x');
      expect(s.displayName, 'Kedai tanpa nama');
      expect(s.hasLocation, isFalse);
      expect(s.canOrderViaWa, isFalse);
      expect(s.distanceText, '');
    });

    test('out-of-range coordinates are treated as missing', () {
      final s = CoffeeShopModel.fromMap({'latitude': 106.8, 'longitude': -6.2}, 'x');
      expect(s.hasLocation, isFalse);
    });

    test('expired Kedai Pro falls back to basic', () {
      final past = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));
      final future = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
      expect(CoffeeShopModel.fromMap({'pro': {'tier': 'pro', 'until': past}}, 'a').proTier, 'basic');
      expect(CoffeeShopModel.fromMap({'pro': {'tier': 'pro', 'until': future}}, 'b').proTier, 'pro');
    });
  });

  test('open flag only counts inside opening hours (incl. overnight)', () {
    CoffeeShop at(int h, String from, String until) => CoffeeShopModel.fromMap(
        {'isOpen': true, 'openFrom': from, 'openUntil': until}, 'x',
        now: DateTime(2026, 10, 2, h, 30));
    expect(at(12, '08:00', '13:00').isOpen, isTrue);
    expect(at(23, '08:00', '13:00').isOpen, isFalse, reason: 'stale flag');
    expect(at(23, '18:00', '02:00').isOpen, isTrue);
    expect(at(1, '18:00', '02:00').isOpen, isTrue);
    expect(at(3, '18:00', '02:00').isOpen, isFalse);
    expect(CoffeeShopModel.fromMap({'isOpen': false}, 'x', now: DateTime(2026, 1, 1, 12)).isOpen,
        isFalse);
  });

  group('social / commerce models', () {
    test('Drop with wrong types and missing fields', () {
      final d = DropModel.fromDoc(_Doc('d1', {
        'rating': 4.6,
        'cheersCount': -3,
        'photoUrls': ['https://x.id/p.jpg', 5],
        'menuPrice': '0',
      }));
      expect(d.rating, 5);
      expect(d.cheersCount, 0);
      expect(d.coverUrl, 'https://x.id/p.jpg');
      expect(d.menuPrice, isNull);
      expect(d.userHandle, 'anonim');
      expect(d.publishAt, d.createdAt);
    });

    test('deleted document (null data) never throws', () {
      expect(() => DropModel.fromDoc(_Doc('x', null)), returnsNormally);
      expect(() => UserProfileModel.fromDoc(_Doc('x', null)), returnsNormally);
      expect(() => StampModel.fromDoc(_Doc('x', null)), returnsNormally);
      expect(() => NotificationModel.fromDoc(_Doc('x', null)), returnsNormally);
      expect(() => PromoModel.fromDoc(_Doc('x', null)), returnsNormally);
      expect(() => RegularEntryModel.fromDoc(_Doc('x', null)), returnsNormally);
    });

    test('unknown notification kind falls back', () {
      final n = NotificationModel.fromDoc(_Doc('n', {'kind': 'mystery', 'read': 1}));
      expect(n.kind, NotificationKind.cheers);
      expect(n.read, isTrue);
    });

    test('promo: negative quota, missing end date, today usage', () {
      final now = DateTime(2026, 10, 2, 10);
      final p = PromoModel.fromDoc(
        _Doc('p', {
          'dailyQuota': -5,
          'usage': {'20261002': '3'},
          'startAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
        }),
        now: now,
      );
      expect(p.dailyQuota, 0);
      expect(p.quotaLeft, 0, reason: 'clamp(0, negative) used to throw');
      expect(p.usedToday, 3);
      expect(p.isActiveAt(now), isFalse, reason: 'no endAt = not running forever');
    });

    test('membership: missing doc and string date', () {
      expect(MembershipModel.fromDoc(_Doc('u', null)).active, isFalse);
      final m = MembershipModel.fromDoc(_Doc('u', {
        'activeUntil': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
        'plan': 'yearly',
      }));
      expect(m.active, isTrue);
      expect(m.plan, 'yearly');
    });

    test('redeem callable payload with loose types', () {
      final Map<Object?, Object?> payload = {
        'valid': 'true',
        'reason': 'weird',
        'redeemNumberToday': 2.0,
        'quotaLeft': '7',
      };
      final r = RedeemResultModel.fromCallable(payload);
      expect(r.valid, isTrue);
      expect(r.reason, 'ok');
      expect(r.redeemNumberToday, 2);
      expect(r.quotaLeft, 7);
      expect(RedeemResultModel.fromCallable(null).reason, 'not_found');
    });
  });

  group('phone & links', () {
    test('WhatsApp numbers in every local format', () {
      expect(WhatsAppLauncher.normalizePhone('0812 3456 7890'), '6281234567890');
      expect(WhatsAppLauncher.normalizePhone('+62 812-3456-7890'), '6281234567890');
      expect(WhatsAppLauncher.normalizePhone('81234567890'), '6281234567890');
      expect(WhatsAppLauncher.normalizePhone('12'), '');
      expect(WhatsAppLauncher.normalizePhone(''), '');
    });

    test('social links from handles, bare domains and junk', () {
      expect(socialUri('@kopikenangan', LinkKind.instagram).toString(),
          'https://www.instagram.com/kopikenangan/');
      expect(socialUri('tiktok.com/@kedai', LinkKind.tiktok).toString(),
          'https://tiktok.com/@kedai');
      expect(socialUri('kedai', LinkKind.tiktok).toString(), 'https://www.tiktok.com/@kedai');
      expect(socialUri('https://maps.app.goo.gl/abc', LinkKind.maps)!.host, 'maps.app.goo.gl');
      expect(socialUri('Jl. Melawai 6', LinkKind.maps)!.host, 'www.google.com');
      expect(socialUri('not a handle!!', LinkKind.instagram), isNull);
      expect(socialUri('   ', LinkKind.instagram), isNull);
      expect(socialUri(null, LinkKind.maps), isNull);
    });
  });

  test('restartable: a newer event cancels the older handler', () async {
    final events = StreamController<int>();
    final out = <String>[];
    final sub = restartable<int>(events.stream, (e) async* {
      await Future<void>.delayed(Duration(milliseconds: e == 1 ? 50 : 1));
      yield e;
    }).listen((e) => out.add('done $e'));
    events
      ..add(1)
      ..add(2);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(out, ['done 2']);
    await sub.cancel();
    await events.close();
  });
}
