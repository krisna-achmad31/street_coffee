import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/redeem_code.dart';

void main() {
  group('RedeemCode', () {
    const secret = 'member-secret-123';
    const promoId = 'promoABC';

    test('is 6 chars from the unambiguous alphabet', () {
      final code = RedeemCode.forWindow(secret: secret, promoId: promoId, window: 1);
      expect(code.length, RedeemCode.length);
      for (final ch in code.split('')) {
        expect(RedeemCode.alphabet.contains(ch), isTrue, reason: ch);
      }
      expect(code, isNot(matches(RegExp('[01OI]'))));
    });

    test('is stable inside a 30 s window and changes across windows', () {
      final t0 = DateTime.utc(2026, 9, 28, 21, 4, 30); // window start
      final a = RedeemCode.generate(secret: secret, promoId: promoId, at: t0);
      final b = RedeemCode.generate(
          secret: secret, promoId: promoId, at: t0.add(const Duration(seconds: 29)));
      final c = RedeemCode.generate(
          secret: secret, promoId: promoId, at: t0.add(const Duration(seconds: 30)));
      expect(a, b);
      expect(a, isNot(c));
    });

    test('differs per member secret and per promo', () {
      final base = RedeemCode.forWindow(secret: secret, promoId: promoId, window: 42);
      expect(RedeemCode.forWindow(secret: 'other', promoId: promoId, window: 42),
          isNot(base));
      expect(RedeemCode.forWindow(secret: secret, promoId: 'other', window: 42),
          isNot(base));
    });

    // Shared test vector — functions/src/codes.test.ts asserts the same value,
    // so client and server can never drift apart silently.
    test('matches the shared server test vector', () {
      expect(
        RedeemCode.forWindow(secret: 'vector-secret', promoId: 'vector-promo', window: 58312345),
        kRedeemVector,
      );
    });

    test('secondsLeft counts down to the next window', () {
      final t = DateTime.utc(2026, 1, 1, 0, 0, 10);
      expect(RedeemCode.secondsLeft(t), 20);
    });

    test('normalize strips separators and upper-cases', () {
      expect(RedeemCode.normalize(' 7f3-k9q '), '7F3K9Q');
    });

    test('qrPayload is versioned', () {
      expect(RedeemCode.qrPayload(uid: 'u', promoId: 'p', code: 'ABCDEF'),
          'SC1|u|p|ABCDEF');
    });
  });
}

/// Keep in sync with functions/src/codes.test.ts.
const kRedeemVector = 'HR8J3H';
