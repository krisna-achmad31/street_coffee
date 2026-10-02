import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/utils/attribution_code.dart';
import '../../core/utils/failures.dart';
import '../../domain/entities/coffee_shop.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/repositories/commerce_repository.dart';
import '../models/coffee_shop_model.dart';
import '../models/json_reader.dart';
import '../models/social_models.dart';

class CommerceRepositoryImpl implements CommerceRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final SharedPreferences _prefs;

  CommerceRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required SharedPreferences prefs,
  })  : _db = firestore,
        _functions = functions,
        _prefs = prefs;

  static String _day(DateTime t) => AttributionCode.dayKey(t);

  @override
  Stream<List<Promo>> watchShopPromos(String shopId) => _db
      .collection(FirebasePaths.promos)
      .where('shopId', isEqualTo: shopId)
      .where('endAt', isGreaterThan: Timestamp.now())
      .snapshots()
      .map((s) {
        final now = DateTime.now();
        return parseEach(s.docs, (d) => PromoModel.fromDoc(d, now: now))
            .where((p) => !p.startAt.isAfter(now) && p.endAt.isAfter(now))
            .toList();
      });

  @override
  Future<Either<Failure, String>> createPromo(PromoInput input) async {
    try {
      final ref = await _db.collection(FirebasePaths.promos).add({
        'shopId': input.shopId,
        'shopName': input.shopName,
        'shopImageUrl': input.shopImageUrl,
        'type': input.type.name,
        'title': input.title,
        'menuName': input.menuName,
        'normalPrice': input.normalPrice,
        'promoPrice': input.promoPrice,
        'dailyQuota': input.dailyQuota,
        'startAt': Timestamp.fromDate(input.startAt),
        'endAt': Timestamp.fromDate(input.endAt),
        'memberOnly': input.memberOnly,
        // Discount is funded by the shop — recorded explicitly for billing.
        'fundedBy': 'shop',
        'usage': <String, int>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Right(ref.id);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menerbitkan promo.'));
    }
  }

  @override
  Stream<Membership> watchMembership(String uid) => _db
          .collection(FirebasePaths.memberships)
          .doc(uid)
          .snapshots()
          .map(MembershipModel.fromDoc)
          // A denied/offline read means "not a member", never a broken screen.
          .handleError((Object e) => debugPrint('watchMembership: $e'));

  @override
  Future<Either<Failure, void>> openRedeemIntent({
    required String uid,
    required String promoId,
    required String shopId,
  }) async {
    try {
      await _db.collection(FirebasePaths.redeemIntents).add({
        'uid': uid,
        'promoId': promoId,
        'shopId': shopId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menyiapkan kode.'));
    }
  }

  @override
  Future<Either<Failure, RedeemResult>> redeem({
    required String shopId,
    required String code,
  }) async {
    try {
      // Untyped call: on Android the payload arrives as Map<Object?, Object?>,
      // so call<Map<String, dynamic>> throws a cast error.
      final res = await _functions
          .httpsCallable('redeemPromo')
          .call({'shopId': shopId, 'code': code});
      return Right(RedeemResultModel.fromCallable(res.data));
    } catch (e) {
      return Left(Failure.from(e, 'Validasi gagal. Coba lagi.'));
    }
  }

  @override
  Future<String> visitorId() async {
    const key = 'visitor_id';
    final existing = _prefs.getString(key);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _prefs.setString(key, id);
    return id;
  }

  @override
  Future<Either<Failure, String>> logWaLead({
    required CoffeeShop shop,
    String? uid,
  }) async {
    final now = DateTime.now();
    final visitor = uid ?? await visitorId();
    final code = AttributionCode.generate(
        visitorId: visitor, shopId: shop.id, at: now);
    try {
      final ref = _db.collection(FirebasePaths.shopLeads(shop.id)).doc(code);
      final stat =
          _db.collection(FirebasePaths.shopStats(shop.id)).doc(_day(now));
      // Same visitor + shop + day = one lead; never reset a converted lead.
      await _db.runTransaction((tx) async {
        if ((await tx.get(ref)).exists) return;
        tx.set(ref, {
          'code': code,
          'uid': uid,
          'visitorId': visitor,
          'day': _day(now),
          'converted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(stat, {'day': _day(now), 'waLeads': FieldValue.increment(1)},
            SetOptions(merge: true));
      });
    } catch (_) {
      // Already logged today, offline, or denied — never block the order.
    }
    return Right(code);
  }

  @override
  Future<Either<Failure, bool>> markLeadConverted({
    required String shopId,
    required String code,
  }) async {
    try {
      final ref = _db.collection(FirebasePaths.shopLeads(shopId)).doc(code);
      final snap = await ref.get();
      if (!snap.exists) return const Right(false);
      final lead = Json.of(snap.data());
      if (lead.boolean('converted')) return const Right(true);
      final created = lead.date('createdAt') ?? DateTime.now();
      final batch = _db.batch()
        ..update(ref, {
          'converted': true,
          'convertedAt': FieldValue.serverTimestamp(),
        })
        ..set(
          _db.collection(FirebasePaths.shopStats(shopId)).doc(_day(created)),
          {'day': _day(created), 'convertedLeads': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      await batch.commit();
      return const Right(true);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menandai lead.'));
    }
  }

  @override
  Stream<List<CoffeeShop>> watchOwnedShops(String uid) => _db
      .collection(FirebasePaths.shops)
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map((s) => parseEach(s.docs, CoffeeShopModel.fromFirestore))
      .handleError((Object e) => debugPrint('watchOwnedShops: $e'));

  @override
  Future<void> recordShopView(String shopId) async {
    try {
      await _stat(shopId, DateTime.now(), {'views': FieldValue.increment(1)});
    } catch (_) {}
  }

  Future<void> _stat(String shopId, DateTime at, Map<String, Object> inc) =>
      _db
          .collection(FirebasePaths.shopStats(shopId))
          .doc(_day(at))
          .set({'day': _day(at), ...inc}, SetOptions(merge: true));

  /// Reads only the per-day counters (drops, redemptions, hours and menu
  /// mentions are maintained by Cloud Functions), so a 90-day view is ~90 reads.
  @override
  Future<Either<Failure, ShopInsights>> insights(
      String shopId, int days) async {
    try {
      final now = DateTime.now();
      final from = now.subtract(Duration(days: days));
      final monthKey = _day(now).substring(0, 6);
      final prevMonth = DateTime(now.year, now.month - 1);
      final prevKey = _day(prevMonth).substring(0, 6);

      final results = await Future.wait([
        _db
            .collection(FirebasePaths.shopStats(shopId))
            .where('day', isGreaterThanOrEqualTo: _day(from))
            .get(),
        _db
            .collection(FirebasePaths.shopFollowers(shopId))
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
            .count()
            .get(),
        _db
            .collection(FirebasePaths.shopStats(shopId))
            .where('day', isGreaterThanOrEqualTo: '${monthKey}01')
            .get(),
        _db.collection(FirebasePaths.revenueShare(prevKey)).doc(shopId).get(),
        _db.collection(FirebasePaths.shops).doc(shopId).get(),
      ]);
      final stats = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final followers = results[1] as AggregateQuerySnapshot;
      final month = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final payout = results[3] as DocumentSnapshot<Map<String, dynamic>>;
      final shop = results[4] as DocumentSnapshot<Map<String, dynamic>>;

      int sum(QuerySnapshot<Map<String, dynamic>> q, String f) => q.docs
          .fold(0, (a, d) => a + Json.of(d.data()).integer(f).clamp(0, 1 << 31));

      final hourly = List<int>.filled(24, 0);
      final topMenu = <String, int>{};
      for (final d in stats.docs) {
        final data = Json.of(d.data());
        for (var h = 0; h < 24; h++) {
          hourly[h] += data.integer('h${h.toString().padLeft(2, '0')}').clamp(0, 1 << 31);
        }
        data.obj('menu').raw.forEach((k, v) {
          final n = Json.asInt(v) ?? 0;
          if (k.trim().isNotEmpty && n > 0) topMenu[k] = (topMenu[k] ?? 0) + n;
        });
      }
      final shopData = Json.of(shop.data());
      final minP = shopData.integer('minPrice').clamp(0, 1 << 31);
      final maxP = shopData.integer('maxPrice').clamp(0, 1 << 31);

      return Right(ShopInsights(
        views: sum(stats, 'views'),
        waLeads: sum(stats, 'waLeads'),
        convertedLeads: sum(stats, 'convertedLeads'),
        redemptions: sum(stats, 'redemptions'),
        drops: sum(stats, 'drops'),
        newFollowers: followers.count ?? 0,
        hourly: hourly,
        topMenu: topMenu,
        revenueSharePoints: sum(month, 'redemptions'),
        lastPayoutRupiah: Json.of(payout.data()).intOrNull('amount'),
        avgTicketRupiah: ((minP + maxP) / 2).round(),
      ));
    } catch (e) {
      return Left(Failure.from(e, 'Gagal memuat dashboard.'));
    }
  }
}
