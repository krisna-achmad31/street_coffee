import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/failures.dart';
import 'package:street_coffee/domain/entities/app_user.dart';
import 'package:street_coffee/domain/entities/coffee_shop.dart';
import 'package:street_coffee/domain/entities/comment.dart';
import 'package:street_coffee/domain/entities/commerce.dart';
import 'package:street_coffee/domain/entities/social.dart';
import 'package:street_coffee/domain/entities/user_location.dart';
import 'package:street_coffee/domain/repositories/admin_shop_repository.dart';
import 'package:street_coffee/domain/repositories/auth_repository.dart';
import 'package:street_coffee/domain/repositories/coffee_shop_repository.dart';
import 'package:street_coffee/domain/repositories/comment_repository.dart';
import 'package:street_coffee/domain/repositories/commerce_repository.dart';
import 'package:street_coffee/domain/repositories/location_repository.dart';
import 'package:street_coffee/domain/repositories/social_repository.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────────────

const jakarta = UserLocation(
    latitude: -6.2441, longitude: 106.7991, districtName: 'Kebayoran Baru');

const bandung =
    UserLocation(latitude: -6.9175, longitude: 107.6191, cityName: 'Bandung');

const member = AppUser(
    uid: 'u1', email: 'raka@example.com', displayName: 'Raka', isAdmin: false);

const admin = AppUser(
    uid: 'a1', email: 'admin@example.com', displayName: 'Admin', isAdmin: true);

CoffeeShop shop(
  String id, {
  String? name,
  double rating = 4.5,
  int minPrice = 12000,
  double? km,
  bool featured = false,
  bool open = true,
  String vibe = 'Deep Talk',
  String whatsapp = '6281234567890',
  String imageUrl = '',
  double lat = -6.245,
  double lng = 106.80,
  List<String> facilities = const ['WiFi'],
  List<MenuFavorite> menu = const [],
}) =>
    CoffeeShop(
      id: id,
      name: name ?? 'Kedai $id',
      address: 'Jl. Senopati No. $id',
      latitude: lat,
      longitude: lng,
      rating: rating,
      reviewCount: 12,
      priceRange: 'Rp 12k–25k',
      minPrice: minPrice,
      maxPrice: minPrice + 13000,
      vibe: vibe,
      vibes: [vibe],
      facilities: facilities,
      categories: const ['Street Coffee'],
      imageUrl: imageUrl,
      galleryUrls: const [],
      menuFavorites: menu,
      whatsappNumber: whatsapp,
      isOpen: open,
      openUntil: '23:00',
      openFrom: '08:00',
      isFeatured: featured,
      description: 'Kopi susu gula aren di pinggir jalan.',
      distanceKm: km,
      openFlag: open,
    );

Drop drop(String id, {String shopId = 's1', int cheers = 3}) => Drop(
      id: id,
      userId: 'u9',
      userHandle: '@nadia',
      userIsPass: false,
      shopId: shopId,
      shopName: 'Kedai $shopId',
      shopVibe: 'Deep Talk',
      photoUrls: const [],
      caption: 'Es kopi susu-nya juara $id',
      menuItem: 'Es Kopi Susu',
      menuPrice: 18000,
      rating: 5,
      vibe: 'Deep Talk',
      stampNumber: 4,
      isFirstAtShop: false,
      cheersCount: cheers,
      commentCount: 1,
      createdAt: DateTime(2026, 10, 1, 20),
      publishAt: DateTime(2026, 10, 1, 20),
    );

Promo promo({bool memberOnly = true}) => Promo(
      id: 'p1',
      shopId: 's1',
      shopName: 'Kedai s1',
      shopImageUrl: '',
      type: PromoType.bundling,
      title: 'Kopi + roti cuma 20k',
      menuName: 'Kopi + roti',
      normalPrice: 28000,
      promoPrice: 20000,
      dailyQuota: 20,
      usedToday: 3,
      startAt: DateTime(2026),
      endAt: DateTime(2027),
      memberOnly: memberOnly,
    );

// ─── Repositories ─────────────────────────────────────────────────────────────

/// Results are queued per call; the last one repeats. A [Completer] lets a
/// test hold a response back to check latest-wins ordering.
class FakeCoffeeShopRepository implements CoffeeShopRepository {
  Either<Failure, List<CoffeeShop>> nearby = const Right([]);
  Either<Failure, List<CoffeeShop>> search = const Right([]);
  Either<Failure, CoffeeShop> byId = const Left(NotFoundFailure());
  final List<Completer<void>> gates = [];

  final nearbyCalls = <({String? vibe, bool? isOpen, int? maxPrice})>[];
  final searchCalls = <String>[];
  final byIdCalls = <String>[];

  @override
  Future<Either<Failure, List<CoffeeShop>>> getNearbyShops({
    required UserLocation location,
    String? vibeFilter,
    bool? isOpenFilter,
    int? maxPriceFilter,
  }) async {
    nearbyCalls
        .add((vibe: vibeFilter, isOpen: isOpenFilter, maxPrice: maxPriceFilter));
    if (gates.isNotEmpty) await gates.removeAt(0).future;
    return nearby;
  }

  @override
  Future<Either<Failure, List<CoffeeShop>>> searchShops({
    required String query,
    required UserLocation location,
  }) async {
    searchCalls.add(query);
    return search;
  }

  @override
  Future<Either<Failure, CoffeeShop>> getShopById(String id) async {
    byIdCalls.add(id);
    return byId;
  }

  @override
  Future<Either<Failure, List<CoffeeShop>>> getFeaturedShops() async =>
      nearby.map((l) => l.where((s) => s.isFeatured).toList());
}

class FakeLocationRepository extends Fake implements LocationRepository {
  Either<Failure, UserLocation> current = const Right(jakarta);
  Either<Failure, UserLocation?> saved = const Right(null);
  int currentCalls = 0;

  @override
  Future<Either<Failure, UserLocation>> getCurrentLocation() async {
    currentCalls++;
    return current;
  }

  @override
  Future<Either<Failure, UserLocation?>> getLastSavedLocation() async => saved;
}

class FakeAuthRepository implements AuthRepository {
  final controller = StreamController<AppUser?>.broadcast();
  Either<Failure, AppUser> signIn = const Right(member);
  int signOutCalls = 0;

  /// Who is signed in when the app starts (null = guest).
  AppUser? initialUser;

  @override
  Stream<AppUser?> get authStateChanges async* {
    yield initialUser;
    yield* controller.stream;
  }

  @override
  AppUser? get currentUser => null;

  @override
  Future<Either<Failure, AppUser>> signInWithGoogle() async => signIn;

  @override
  Future<Either<Failure, void>> signOut() async {
    signOutCalls++;
    return const Right(null);
  }
}

class FakeCommentRepository implements CommentRepository {
  final controller = StreamController<List<Comment>>.broadcast();
  Either<Failure, void> addResult = const Right(null);
  final added = <String>[];

  /// When set, the watch starts with these comments.
  List<Comment>? initial;

  @override
  Stream<List<Comment>> watchComments(String shopId) async* {
    if (initial != null) yield initial!;
    yield* controller.stream;
  }

  @override
  Future<Either<Failure, void>> addComment({
    required String shopId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    required String text,
    double? rating,
  }) async {
    added.add(text);
    return addResult;
  }

  @override
  Future<Either<Failure, void>> deleteComment({
    required String shopId,
    required String commentId,
  }) async =>
      addResult;
}

class FakeAdminShopRepository implements AdminShopRepository {
  Either<Failure, String> createResult = const Right('new-id');
  Either<Failure, void> updateResult = const Right(null);
  ShopFormData? lastData;
  String? lastUpdatedId;
  bool? lastIsOpen;

  @override
  Future<Either<Failure, String>> createShop({required ShopFormData data}) async {
    lastData = data;
    return createResult;
  }

  @override
  Future<Either<Failure, void>> updateShop(
      {required String shopId, required ShopFormData data}) async {
    lastUpdatedId = shopId;
    lastData = data;
    return updateResult;
  }

  @override
  Future<Either<Failure, void>> deleteShop(String shopId) async => updateResult;

  @override
  Future<Either<Failure, void>> setIsOpen(String shopId, bool isOpen) async {
    lastIsOpen = isOpen;
    return updateResult;
  }

  @override
  Future<Either<Failure, String>> uploadGalleryImage(
          {required String shopId, required File imageFile}) async =>
      const Right('https://example.com/g.jpg');
}

/// Streams default to "loaded and empty"; set a field to change one.
class FakeSocialRepository extends Fake implements SocialRepository {
  Stream<List<Drop>> Function(FeedTab tab) feed = (_) => Stream.value(const []);
  Stream<List<LiveCheckin>> live = Stream.value(const []);
  Stream<List<CoffeeShop>> Function() wanted = () => Stream.value(const []);
  Stream<UserProfile?> profile = Stream.value(null);
  final feedTabs = <FeedTab>[];
  final wantWrites = <(String, bool)>[];

  @override
  Stream<List<Drop>> watchFeed(FeedTab tab, {String? uid}) {
    feedTabs.add(tab);
    return feed(tab);
  }

  @override
  Stream<List<LiveCheckin>> watchLiveCheckins() => live;

  @override
  Stream<List<Drop>> watchShopDrops(String shopId) => Stream.value(const []);

  @override
  Stream<List<Drop>> watchUserDrops(String uid) => Stream.value(const []);

  @override
  Stream<UserProfile?> watchProfile(String uid) => profile;

  @override
  Stream<List<Stamp>> watchStamps(String uid) => Stream.value(const []);

  @override
  List<Badge> computeBadges(List<Drop> drops, int stamps) => const [];

  @override
  Stream<bool> watchCheered(String dropId, String uid) => Stream.value(false);

  @override
  Stream<bool> watchWant(String uid, String shopId) => Stream.value(false);

  @override
  Future<Either<Failure, void>> setWant(
      String uid, String shopId, bool want) async {
    wantWrites.add((shopId, want));
    return const Right(null);
  }

  @override
  Stream<List<CoffeeShop>> watchWantedShops(String uid) => wanted();

  @override
  Future<Either<Failure, List<RegularEntry>>> regulars(String shopId) async =>
      const Right([]);
}

class FakeCommerceRepository extends Fake implements CommerceRepository {
  Stream<Membership> Function() membership =
      () => Stream.value(Membership.none);
  Stream<List<Promo>> promos = Stream.value(const []);
  final redeemIntents = <String>[];

  @override
  Stream<Membership> watchMembership(String uid) => membership();

  @override
  Stream<List<Promo>> watchShopPromos(String shopId) => promos;

  @override
  Future<void> recordShopView(String shopId) async {}

  @override
  Stream<List<CoffeeShop>> watchOwnedShops(String uid) => Stream.value(const []);

  @override
  Future<Either<Failure, void>> openRedeemIntent({
    required String uid,
    required String promoId,
    required String shopId,
  }) async {
    redeemIntents.add(promoId);
    return const Right(null);
  }

  @override
  Future<String> visitorId() async => 'visitor-1';

  @override
  Future<Either<Failure, String>> logWaLead(
          {required CoffeeShop shop, String? uid}) async =>
      const Right('SC-TEST');
}
