import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/constants/firebase_paths.dart';
import '../../core/utils/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/social.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/entities/coffee_shop.dart';
import '../models/coffee_shop_model.dart';
import '../models/comment_model.dart';
import '../models/json_reader.dart';
import '../models/social_models.dart';

/// Firestore-backed social layer. Counters (cheers, comments, stamps,
/// followers) are maintained by Cloud Functions (functions/src/social.ts);
/// the client only writes the source documents.
class SocialRepositoryImpl implements SocialRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  SocialRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _db = firestore,
        _storage = storage;

  CollectionReference<Map<String, dynamic>> get _drops =>
      _db.collection(FirebasePaths.drops);

  @override
  Future<Either<Failure, UserProfile>> ensureProfile(AppUser user) async {
    try {
      final ref = _db.collection(FirebasePaths.users).doc(user.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        final handle = _handleFrom(user);
        await ref.set({
          'handle': handle,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'bio': '',
          'dropsCount': 0,
          'followersCount': 0,
          'followingCount': 0,
          'stampsCount': 0,
          'areasCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return Right(UserProfile(
          uid: user.uid,
          handle: handle,
          displayName: user.displayName,
          photoUrl: user.photoUrl,
        ));
      }
      return Right(UserProfileModel.fromDoc(snap));
    } catch (e) {
      return Left(Failure.from(e, 'Gagal memuat profil.'));
    }
  }

  String _handleFrom(AppUser u) {
    final base = u.displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final suffix =
        u.uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').padRight(3, '0').substring(0, 3).toLowerCase();
    return base.isEmpty ? 'kopi$suffix' : '$base$suffix';
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) => _db
      .collection(FirebasePaths.users)
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? UserProfileModel.fromDoc(s) : null);

  /// Published = not hidden and past its "tunda lokasi" delay. The minute of
  /// slack keeps queries inside the security rule despite client clock skew.
  Query<Map<String, dynamic>> get _published => _drops
      .where('hidden', isEqualTo: false)
      .where('publishAt',
          isLessThanOrEqualTo: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(minutes: 1))));

  @override
  Stream<List<Drop>> watchFeed(FeedTab tab, {String? uid}) {
    final Query<Map<String, dynamic>> q = switch (tab) {
      FeedTab.nearby =>
        _published.orderBy('publishAt', descending: true).limit(30),
      FeedTab.trending => _published
          .where('publishAt',
              isGreaterThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7))))
          .orderBy('publishAt', descending: true)
          .limit(60),
      FeedTab.friends => uid == null
          ? _published.limit(0)
          : _published
              .where('followerIds', arrayContains: uid)
              .orderBy('publishAt', descending: true)
              .limit(30),
    };
    return q.snapshots().map((s) {
      final list = parseEach(s.docs, DropModel.fromDoc);
      if (tab == FeedTab.trending) {
        list.sort((a, b) => b.cheersCount.compareTo(a.cheersCount));
      }
      return list;
    });
  }

  @override
  Stream<List<Drop>> watchShopDrops(String shopId) => _published
      .where('shopId', isEqualTo: shopId)
      .orderBy('publishAt', descending: true)
      .limit(40)
      .snapshots()
      .map((s) => parseEach(s.docs, DropModel.fromDoc));

  @override
  Stream<List<Drop>> watchUserDrops(String uid) => _drops
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(90)
      .snapshots()
      .map((s) => parseEach(s.docs, DropModel.fromDoc));

  @override
  Stream<Drop?> watchDrop(String dropId) => _drops
      .doc(dropId)
      .snapshots()
      .map((s) => s.exists ? DropModel.fromDoc(s) : null);

  @override
  Stream<List<LiveCheckin>> watchLiveCheckins() => _published
      .where('publishAt',
          isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 2))))
      .orderBy('publishAt', descending: true)
      .limit(40)
      .snapshots()
      .map((s) {
        final byShop = <String, List<Drop>>{};
        for (final d in parseEach(s.docs, DropModel.fromDoc)) {
          if (d.shopId.isEmpty) continue;
          byShop.putIfAbsent(d.shopId, () => []).add(d);
        }
        return byShop.values
            .map((ds) => LiveCheckin(
                  shopId: ds.first.shopId,
                  shopName: ds.first.shopName,
                  shopImageUrl: ds.first.coverUrl,
                  userPhotos: ds.map((d) => d.userPhotoUrl).take(3).toList(),
                  handles: ds.map((d) => d.userHandle).toSet().toList(),
                ))
            .toList();
      });

  @override
  Future<Either<Failure, String>> createDrop(
      AppUser author, CreateDropInput input) async {
    try {
      final ref = _drops.doc();
      final urls = <String>[];
      for (var i = 0; i < input.photos.length; i++) {
        final task = await _storage
            .ref(FirebasePaths.dropPhoto(author.uid, ref.id, i))
            .putFile(input.photos[i],
                SettableMetadata(contentType: 'image/jpeg'));
        urls.add(await task.ref.getDownloadURL());
      }
      final profile = await _db
          .collection(FirebasePaths.users)
          .doc(author.uid)
          .get();
      final now = DateTime.now();
      final publishAt =
          input.delayLocation ? now.add(const Duration(hours: 1)) : now;
      await ref.set({
        'userId': author.uid,
        'userHandle': Json.of(profile.data()).strOrNull('handle') ?? author.displayName,
        'userPhotoUrl': author.photoUrl,
        'userIsPass': Json.of(profile.data()).boolean('isPass'),
        'shopId': input.shopId,
        'shopName': input.shopName,
        'shopVibe': input.shopVibe,
        'photoUrls': urls,
        'caption': input.caption,
        'menuItem': input.menuItem,
        'menuPrice': input.menuPrice,
        'rating': input.rating,
        'vibe': input.shopVibe,
        'latitude': input.latitude,
        'longitude': input.longitude,
        // Filled in by onDropCreated after GPS + stamp checks.
        'stampNumber': 0,
        'isFirstAtShop': false,
        'cheersCount': 0,
        'commentCount': 0,
        'hidden': false,
        'followerIds': <String>[],
        'createdAt': Timestamp.fromDate(now),
        'publishAt': Timestamp.fromDate(publishAt),
      });
      return Right(ref.id);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal posting Drop. Coba lagi.'));
    }
  }

  @override
  Stream<bool> watchCheered(String dropId, String uid) => _db
      .collection(FirebasePaths.dropCheers(dropId))
      .doc(uid)
      .snapshots()
      .map((s) => s.exists);

  @override
  Future<Either<Failure, void>> setCheers(
      String dropId, String uid, bool cheered) async {
    try {
      final ref = _db.collection(FirebasePaths.dropCheers(dropId)).doc(uid);
      if (cheered) {
        await ref.set({'createdAt': FieldValue.serverTimestamp()});
      } else {
        await ref.delete();
      }
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal kirim Cheers.'));
    }
  }

  @override
  Stream<List<Comment>> watchDropComments(String dropId) => _db
      .collection(FirebasePaths.dropComments(dropId))
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => parseEach(s.docs, CommentModel.fromFirestore)
          .where((c) => c.text.isNotEmpty)
          .toList());

  @override
  Future<Either<Failure, void>> addDropComment(
      String dropId, AppUser author, String text) async {
    try {
      await _db.collection(FirebasePaths.dropComments(dropId)).add({
        'shopId': '',
        'userId': author.uid,
        'userName': author.displayName,
        'userPhotoUrl': author.photoUrl,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal kirim komentar.'));
    }
  }

  @override
  Future<Either<Failure, void>> report({
    required String reporterUid,
    required String targetType,
    required String targetId,
    required ReportReason reason,
    required bool blockAuthor,
    String? authorUid,
  }) async {
    try {
      await _db.collection(FirebasePaths.reports).add({
        'reporterUid': reporterUid,
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason.name,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (blockAuthor && authorUid != null) {
        await _db
            .collection(FirebasePaths.users)
            .doc(reporterUid)
            .collection('blocked')
            .doc(authorUid)
            .set({'createdAt': FieldValue.serverTimestamp()});
      }
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal kirim laporan.'));
    }
  }

  @override
  Stream<List<Stamp>> watchStamps(String uid) => _db
      .collection(FirebasePaths.userStamps(uid))
      .orderBy('firstVisit', descending: true)
      .snapshots()
      .map((s) => parseEach(s.docs, StampModel.fromDoc));

  @override
  List<Badge> computeBadges(List<Drop> drops, int stamps) {
    final nightDrops = drops.where((d) => d.createdAt.hour >= 22).length;
    final manualBrewShops = drops
        .where((d) => d.vibe.toLowerCase().contains('manual'))
        .map((d) => d.shopId)
        .toSet()
        .length;
    final cheapShops = drops
        .where((d) => (d.menuPrice ?? 1 << 30) < 20000)
        .map((d) => d.shopId)
        .toSet()
        .length;
    return [
      Badge(
          id: 'night_owl',
          name: 'Night Owl',
          description: '5× check-in di atas jam 10 malam',
          unlocked: nightDrops >= 5),
      Badge(
          id: 'manual_brew',
          name: 'Manual Brew Hunter',
          description: '10 kedai manual brew',
          unlocked: manualBrewShops >= 10),
      Badge(
          id: 'first_drop',
          name: 'First Drop',
          description: 'Orang pertama nge-Drop di sebuah kedai',
          unlocked: drops.any((d) => d.isFirstAtShop)),
      Badge(
          id: 'kopi_hemat',
          name: 'Kopi Hemat',
          description: '10 kedai di bawah Rp20rb',
          unlocked: cheapShops >= 10),
      Badge(
          id: 'skena_legend',
          name: 'Skena Legend',
          description: 'Capai Level 5 (40 stempel)',
          unlocked: stamps >= 40),
    ];
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String uid) => _db
      .collection(FirebasePaths.userNotifications(uid))
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => parseEach(s.docs, NotificationModel.fromDoc));

  @override
  Future<Either<Failure, void>> markNotificationsRead(String uid) async {
    try {
      final unread = await _db
        .collection(FirebasePaths.userNotifications(uid))
        .where('read', isEqualTo: false)
        .limit(100)
        .get();
      if (unread.docs.isEmpty) return const Right(null);
      final batch = _db.batch();
      for (final d in unread.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menandai notifikasi.'));
    }
  }

  @override
  Future<Either<Failure, List<RegularEntry>>> regulars(String shopId) async {
    try {
      final now = DateTime.now();
      final monthKey = '${now.year}${now.month.toString().padLeft(2, '0')}';
      final snap = await _db
          .collection(FirebasePaths.shops)
          .doc(shopId)
          .collection('regulars_$monthKey')
          .orderBy('checkins', descending: true)
          .limit(10)
          .get();
      return Right(parseEach(snap.docs, RegularEntryModel.fromDoc)
          .where((r) => r.checkins > 0)
          .toList());
    } catch (e) {
      return Left(Failure.from(e, 'Gagal memuat Regulars.'));
    }
  }

  @override
  Stream<bool> watchWant(String uid, String shopId) => _db
      .collection(FirebasePaths.userWants(uid))
      .doc(shopId)
      .snapshots()
      .map((s) => s.exists);

  @override
  Future<Either<Failure, void>> setWant(
      String uid, String shopId, bool want) async {
    try {
      final ref = _db.collection(FirebasePaths.userWants(uid)).doc(shopId);
      want
          ? await ref.set({'createdAt': FieldValue.serverTimestamp()})
          : await ref.delete();
      return const Right(null);
    } catch (e) {
      return Left(Failure.from(e, 'Gagal menyimpan kedai.'));
    }
  }

  @override
  Stream<List<CoffeeShop>> watchWantedShops(String uid) => _db
          .collection(FirebasePaths.userWants(uid))
          .orderBy('createdAt', descending: true)
          .limit(60)
          .snapshots()
          .asyncMap((s) async {
        final ids = s.docs.map((d) => d.id).where((id) => id.isNotEmpty).toList();
        final byId = <String, CoffeeShop>{};
        // whereIn accepts at most 10 values per query.
        for (var i = 0; i < ids.length; i += 10) {
          final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
          final snap = await _db
              .collection(FirebasePaths.shops)
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final shop in parseEach(snap.docs, CoffeeShopModel.fromFirestore)) {
            byId[shop.id] = shop;
          }
        }
        return [for (final id in ids) if (byId[id] != null) byId[id]!];
      });
}
