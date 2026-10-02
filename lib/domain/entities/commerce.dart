import 'package:equatable/equatable.dart';

enum PromoType { bundling, discount, freeItem }

/// A partner promo. The discount is funded by the shop (see PRD §Model bisnis).
class Promo extends Equatable {
  final String id;
  final String shopId;
  final String shopName;
  final String shopImageUrl;
  final PromoType type;
  final String title;
  final String menuName;
  final int normalPrice;
  final int promoPrice;
  final int dailyQuota;
  final int usedToday;
  final DateTime startAt;
  final DateTime endAt;
  final bool memberOnly;

  const Promo({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.shopImageUrl,
    required this.type,
    required this.title,
    required this.menuName,
    required this.normalPrice,
    required this.promoPrice,
    required this.dailyQuota,
    required this.usedToday,
    required this.startAt,
    required this.endAt,
    required this.memberOnly,
  });

  int get quotaLeft => (dailyQuota - usedToday).clamp(0, dailyQuota);

  int get savingPercent => normalPrice <= 0
      ? 0
      : (((normalPrice - promoPrice) / normalPrice) * 100).round();

  bool isActiveAt(DateTime t) =>
      !t.isBefore(startAt) && t.isBefore(endAt) && quotaLeft > 0;

  @override
  List<Object?> get props => [id, usedToday];
}

/// Result of a cashier validating a member's rotating code.
class RedeemResult extends Equatable {
  final bool valid;

  /// ok | expired | used_today | quota_empty | not_member | not_found
  final String reason;
  final String? promoTitle;
  final String? memberName;
  final int? redeemNumberToday;
  final int? quotaLeft;
  final int? dailyQuota;

  const RedeemResult({
    required this.valid,
    required this.reason,
    this.promoTitle,
    this.memberName,
    this.redeemNumberToday,
    this.quotaLeft,
    this.dailyQuota,
  });

  @override
  List<Object?> get props => [valid, reason, redeemNumberToday];
}

class Membership extends Equatable {
  final bool active;
  final String? plan; // monthly | yearly
  final DateTime? activeUntil;

  /// Per-member secret used to derive rotating redeem codes.
  final String? redeemSecret;

  const Membership({
    required this.active,
    this.plan,
    this.activeUntil,
    this.redeemSecret,
  });

  static const none = Membership(active: false);

  @override
  List<Object?> get props => [active, plan, activeUntil];
}

/// Proof-of-value numbers for the Kedai Pro dashboard.
class ShopInsights extends Equatable {
  final int views;
  final int waLeads;
  final int convertedLeads;
  final int redemptions;
  final int drops;
  final int newFollowers;

  /// Check-ins per hour of day (0..23) over the period.
  final List<int> hourly;

  /// menu name -> times mentioned in Drops.
  final Map<String, int> topMenu;

  /// Points this month (= verified redemptions) and last settled payout.
  final int revenueSharePoints;
  final int? lastPayoutRupiah;
  final int avgTicketRupiah;

  const ShopInsights({
    required this.views,
    required this.waLeads,
    required this.convertedLeads,
    required this.redemptions,
    required this.drops,
    required this.newFollowers,
    required this.hourly,
    required this.topMenu,
    required this.revenueSharePoints,
    this.lastPayoutRupiah,
    required this.avgTicketRupiah,
  });

  int get customersFromApp => redemptions + convertedLeads;

  int get estimatedRevenue => customersFromApp * avgTicketRupiah;

  @override
  List<Object?> get props => [views, waLeads, redemptions, drops];
}
