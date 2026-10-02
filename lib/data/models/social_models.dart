import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/commerce.dart';
import '../../domain/entities/social.dart';
import 'json_reader.dart';

String? _photo(Object? v) {
  final u = Json.url(v);
  return u.isEmpty ? null : u;
}

int _count(Json d, String k) => d.integer(k).clamp(0, 1 << 31);

class DropModel {
  DropModel._();

  static Drop fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = Json.of(doc.data());
    // Pending serverTimestamp() reads back as null on the writer's device.
    final created = d.date('createdAt') ?? DateTime.now();
    final price = d.intOrNull('menuPrice');
    return Drop(
      id: doc.id,
      userId: d.str('userId'),
      userHandle: d.strOrNull('userHandle') ?? 'anonim',
      userPhotoUrl: _photo(d.raw['userPhotoUrl']),
      userIsPass: d.boolean('userIsPass'),
      shopId: d.str('shopId'),
      shopName: d.strOrNull('shopName') ?? 'Kedai',
      shopVibe: d.str('shopVibe'),
      photoUrls: d.strings('photoUrls').map(Json.url).where((u) => u.isNotEmpty).toList(),
      caption: d.str('caption').trim(),
      menuItem: d.strOrNull('menuItem'),
      menuPrice: price != null && price > 0 ? price : null,
      rating: d.integer('rating').clamp(0, 5),
      vibe: d.str('vibe'),
      stampNumber: _count(d, 'stampNumber'),
      isFirstAtShop: d.boolean('isFirstAtShop'),
      cheersCount: _count(d, 'cheersCount'),
      commentCount: _count(d, 'commentCount'),
      createdAt: created,
      publishAt: d.date('publishAt') ?? created,
    );
  }
}

class UserProfileModel {
  UserProfileModel._();

  static UserProfile fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = Json.of(doc.data());
    final passUntil = d.date('passUntil');
    final name = d.str('displayName').trim();
    return UserProfile(
      uid: doc.id,
      handle: d.strOrNull('handle') ?? (name.isEmpty ? 'kopi' : name),
      displayName: name,
      photoUrl: _photo(d.raw['photoUrl']),
      bio: d.str('bio').trim(),
      dropsCount: _count(d, 'dropsCount'),
      followersCount: _count(d, 'followersCount'),
      followingCount: _count(d, 'followingCount'),
      stampsCount: _count(d, 'stampsCount'),
      areasCount: _count(d, 'areasCount'),
      isPass: passUntil != null && passUntil.isAfter(DateTime.now()),
      passUntil: passUntil,
    );
  }
}

class StampModel {
  StampModel._();

  static Stamp fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = Json.of(doc.data());
    return Stamp(
      shopId: doc.id,
      shopName: d.strOrNull('shopName') ?? 'Kedai',
      imageUrl: Json.url(d.raw['imageUrl']),
      firstVisit: d.date('firstVisit') ?? DateTime.now(),
      area: d.strOrNull('area'),
    );
  }
}

class NotificationModel {
  NotificationModel._();

  static AppNotification fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = Json.of(doc.data());
    final kind = d.str('kind');
    return AppNotification(
      id: doc.id,
      kind: NotificationKind.values.firstWhere(
        (k) => k.name == kind,
        orElse: () => NotificationKind.cheers,
      ),
      text: d.str('text').trim(),
      actorPhotoUrl: _photo(d.raw['actorPhotoUrl']),
      thumbUrl: _photo(d.raw['thumbUrl']),
      targetId: d.strOrNull('targetId'),
      read: d.boolean('read'),
      createdAt: d.date('createdAt') ?? DateTime.now(),
    );
  }
}

class PromoModel {
  PromoModel._();

  /// `usage.{yyyymmdd}` is incremented by the redeemPromo function.
  static Promo fromDoc(DocumentSnapshot<Map<String, dynamic>> doc,
      {DateTime? now}) {
    final d = Json.of(doc.data());
    final t = now ?? DateTime.now();
    final today =
        '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
    final type = d.str('type');
    final start = d.date('startAt') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final normal = d.integer('normalPrice').clamp(0, 1 << 31);
    final promo = d.integer('promoPrice').clamp(0, 1 << 31);
    return Promo(
      id: doc.id,
      shopId: d.str('shopId'),
      shopName: d.str('shopName'),
      shopImageUrl: Json.url(d.raw['shopImageUrl']),
      type: PromoType.values.firstWhere((p) => p.name == type,
          orElse: () => PromoType.bundling),
      title: d.strOrNull('title') ?? 'Promo',
      menuName: d.str('menuName'),
      normalPrice: normal,
      promoPrice: promo,
      dailyQuota: d.integer('dailyQuota').clamp(0, 1 << 31),
      usedToday: d.obj('usage').integer(today).clamp(0, 1 << 31),
      startAt: start,
      // No end date = treat as already ended rather than running forever.
      endAt: d.date('endAt') ?? start,
      memberOnly: d.boolean('memberOnly', true),
    );
  }
}

class MembershipModel {
  MembershipModel._();

  static Membership fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return Membership.none;
    final d = Json.of(doc.data());
    final until = d.date('activeUntil');
    return Membership(
      active: until != null && until.isAfter(DateTime.now()),
      plan: d.strOrNull('plan'),
      activeUntil: until,
      redeemSecret: d.strOrNull('redeemSecret'),
    );
  }
}

class RedeemResultModel {
  RedeemResultModel._();

  static const _reasons = {
    'ok', 'expired', 'used_today', 'quota_empty', 'not_member', 'not_found'
  };

  static RedeemResult fromCallable(Object? data) {
    final d = Json.of(data);
    final reason = d.str('reason');
    final valid = d.boolean('valid');
    return RedeemResult(
      valid: valid,
      reason: _reasons.contains(reason) ? reason : (valid ? 'ok' : 'not_found'),
      promoTitle: d.strOrNull('promoTitle'),
      memberName: d.strOrNull('memberName'),
      redeemNumberToday: d.intOrNull('redeemNumberToday'),
      quotaLeft: d.intOrNull('quotaLeft'),
      dailyQuota: d.intOrNull('dailyQuota'),
    );
  }
}

class RegularEntryModel {
  RegularEntryModel._();

  static RegularEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = Json.of(doc.data());
    return RegularEntry(
      uid: doc.id,
      handle: d.strOrNull('handle') ?? 'anonim',
      photoUrl: _photo(d.raw['photoUrl']),
      checkins: _count(d, 'checkins'),
    );
  }
}
