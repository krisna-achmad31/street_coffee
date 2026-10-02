import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/attribution_code.dart';
import 'package:street_coffee/core/utils/formatters.dart';
import 'package:street_coffee/core/utils/whatsapp_launcher.dart';
import 'package:street_coffee/domain/entities/social.dart';

void main() {
  group('AttributionCode', () {
    final day = DateTime(2026, 9, 28, 10);

    test('has the SC-XXXX shape', () {
      final code = AttributionCode.generate(visitorId: 'u1', shopId: 's1', at: day);
      expect(code, matches(AttributionCode.pattern));
    });

    test('is stable for the same visitor, shop and day', () {
      final a = AttributionCode.generate(visitorId: 'u1', shopId: 's1', at: day);
      final b = AttributionCode.generate(
          visitorId: 'u1', shopId: 's1', at: day.add(const Duration(hours: 8)));
      expect(a, b);
    });

    test('changes on another day or shop', () {
      final a = AttributionCode.generate(visitorId: 'u1', shopId: 's1', at: day);
      expect(
          AttributionCode.generate(
              visitorId: 'u1', shopId: 's1', at: day.add(const Duration(days: 1))),
          isNot(a));
      expect(AttributionCode.generate(visitorId: 'u1', shopId: 's2', at: day),
          isNot(a));
    });

    test('parse accepts the formats owners paste', () {
      expect(AttributionCode.parse('SC-7F3K'), 'SC-7F3K');
      expect(AttributionCode.parse('(kode: SC-7F3K)'), 'SC-7F3K');
      expect(AttributionCode.parse('sc 7f3k'), 'SC-7F3K');
      expect(AttributionCode.parse('halo'), isNull);
    });
  });

  group('WhatsApp message', () {
    test('appends the attribution code on its own line', () {
      final m = WhatsAppLauncher.buildOrderMessage(
          shopName: 'Kopi Senja', menuItem: 'Es Kopi', quantity: 2, attributionCode: 'SC-7F3K');
      expect(m, contains('2× Es Kopi'));
      expect(m.split('\n').last, '(kode: SC-7F3K)');
    });

    test('works without a menu item', () {
      final m = WhatsAppLauncher.buildOrderMessage(shopName: 'Kopi Senja', menuItem: null);
      expect(m, contains('Apakah masih buka?'));
    });
  });

  group('Fmt', () {
    test('rupiah', () {
      expect(Fmt.rupiah(30000), 'Rp30.000');
      expect(Fmt.rupiah(1250000), 'Rp1.250.000');
      expect(Fmt.rupiahShort(18000), 'Rp18k');
      expect(Fmt.rupiahShort(4100000), 'Rp4,1jt');
    });

    test('compact', () {
      expect(Fmt.compact(48), '48');
      expect(Fmt.compact(1234), '1,2rb');
    });

    test('stars', () => expect(Fmt.stars(4), '★★★★☆'));
  });

  group('PassportLevel', () {
    test('thresholds', () {
      expect(PassportLevel.of(0).name, 'Pendatang');
      expect(PassportLevel.of(32).name, 'Kopi Nomad');
      expect(PassportLevel.of(40).name, 'Skena Legend');
      expect(PassportLevel.next(32)!.minStamps, 40);
      expect(PassportLevel.next(99), isNull);
    });

    test('passport number is stable per uid', () {
      const p = UserProfile(uid: 'abc', handle: 'h', displayName: 'N');
      expect(p.passportNo, matches(RegExp(r'^SC-\d{4}-JKS$')));
      expect(p.passportNo, const UserProfile(uid: 'abc', handle: 'x', displayName: 'Y').passportNo);
    });
  });
}
