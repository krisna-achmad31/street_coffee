import 'package:dartz/dartz.dart';

import '../../core/utils/failures.dart';
import '../entities/coffee_shop.dart';
import '../entities/commerce.dart';

class PromoInput {
  final String shopId;
  final String shopName;
  final String shopImageUrl;
  final PromoType type;
  final String menuName;
  final int normalPrice;
  final int promoPrice;
  final int dailyQuota;
  final DateTime startAt;
  final DateTime endAt;
  final bool memberOnly;

  const PromoInput({
    required this.shopId,
    required this.shopName,
    required this.shopImageUrl,
    required this.type,
    required this.menuName,
    required this.normalPrice,
    required this.promoPrice,
    required this.dailyQuota,
    required this.startAt,
    required this.endAt,
    required this.memberOnly,
  });

  String get title => switch (type) {
        PromoType.bundling =>
          '$menuName cuma ${(promoPrice / 1000).round()}k',
        PromoType.discount =>
          '$menuName jadi ${(promoPrice / 1000).round()}k',
        PromoType.freeItem => 'Gratis $menuName',
      };
}

abstract class CommerceRepository {
  // Promos (discount funded by the shop).
  Stream<List<Promo>> watchShopPromos(String shopId);
  Future<Either<Failure, String>> createPromo(PromoInput input);

  // Street Pass membership.
  Stream<Membership> watchMembership(String uid);

  /// Member opened "Pakai Promo": lets the server narrow the code lookup to
  /// members who are at this counter right now.
  Future<Either<Failure, void>> openRedeemIntent({
    required String uid,
    required String promoId,
    required String shopId,
  });

  /// Cashier side — validated by the `redeemPromo` Cloud Function.
  Future<Either<Failure, RedeemResult>> redeem({
    required String shopId,
    required String code,
  });

  // WhatsApp attribution.
  Future<String> visitorId();
  Future<Either<Failure, String>> logWaLead({
    required CoffeeShop shop,
    String? uid,
  });
  Future<Either<Failure, bool>> markLeadConverted({
    required String shopId,
    required String code,
  });

  // Kedai Pro.
  Stream<List<CoffeeShop>> watchOwnedShops(String uid);
  Future<void> recordShopView(String shopId);
  Future<Either<Failure, ShopInsights>> insights(String shopId, int days);
}
