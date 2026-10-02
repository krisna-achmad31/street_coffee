import 'package:equatable/equatable.dart';

/// Ids minted by the in-memory demo feed (debug builds); never in Firestore.
bool isDemoId(String id) => id.startsWith('demo_');

/// A check-in post: photo + receipt (shop, item, rating, vibe) + caption.
class Drop extends Equatable {
  final String id;
  final String userId;
  final String userHandle;
  final String? userPhotoUrl;
  final bool userIsPass;
  final String shopId;
  final String shopName;
  final String shopVibe;
  final List<String> photoUrls;
  final String caption;
  final String? menuItem;
  final int? menuPrice;
  final int rating; // 1..5
  final String vibe;

  /// Nth distinct shop in the author's passport when this was posted.
  final int stampNumber;

  /// First Drop ever at this shop (badge "First Drop").
  final bool isFirstAtShop;
  final int cheersCount;
  final int commentCount;
  final DateTime createdAt;

  /// "Tunda lokasi": hidden from other users until this time.
  final DateTime publishAt;
  final double? distanceKm;

  const Drop({
    required this.id,
    required this.userId,
    required this.userHandle,
    this.userPhotoUrl,
    required this.userIsPass,
    required this.shopId,
    required this.shopName,
    required this.shopVibe,
    required this.photoUrls,
    required this.caption,
    this.menuItem,
    this.menuPrice,
    required this.rating,
    required this.vibe,
    required this.stampNumber,
    required this.isFirstAtShop,
    required this.cheersCount,
    required this.commentCount,
    required this.createdAt,
    required this.publishAt,
    this.distanceKm,
  });

  String get coverUrl => photoUrls.isEmpty ? '' : photoUrls.first;

  @override
  List<Object?> get props => [id, cheersCount, commentCount];
}

/// One stamp per distinct shop in the user's passport.
class Stamp extends Equatable {
  final String shopId;
  final String shopName;
  final String imageUrl;
  final DateTime firstVisit;
  final String? area;

  const Stamp({
    required this.shopId,
    required this.shopName,
    required this.imageUrl,
    required this.firstVisit,
    this.area,
  });

  @override
  List<Object?> get props => [shopId];
}

class UserProfile extends Equatable {
  final String uid;
  final String handle;
  final String displayName;
  final String? photoUrl;
  final String bio;
  final int dropsCount;
  final int followersCount;
  final int followingCount;
  final int stampsCount;
  final int areasCount;
  final bool isPass;
  final DateTime? passUntil;

  const UserProfile({
    required this.uid,
    required this.handle,
    required this.displayName,
    this.photoUrl,
    this.bio = '',
    this.dropsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.stampsCount = 0,
    this.areasCount = 0,
    this.isPass = false,
    this.passUntil,
  });

  /// SC-0032-JKS style number, stable per uid.
  String get passportNo {
    final n = uid.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) % 10000);
    return 'SC-${n.toString().padLeft(4, '0')}-JKS';
  }

  @override
  List<Object?> get props => [uid, dropsCount, stampsCount, isPass];
}

class PassportLevel {
  final int level;
  final String name;
  final int minStamps;
  const PassportLevel(this.level, this.name, this.minStamps);

  static const all = [
    PassportLevel(1, 'Pendatang', 0),
    PassportLevel(2, 'Penikmat', 5),
    PassportLevel(3, 'Pencari', 15),
    PassportLevel(4, 'Kopi Nomad', 25),
    PassportLevel(5, 'Skena Legend', 40),
  ];

  static PassportLevel of(int stamps) =>
      all.lastWhere((l) => stamps >= l.minStamps);

  static PassportLevel? next(int stamps) {
    final i = all.indexOf(of(stamps));
    return i + 1 < all.length ? all[i + 1] : null;
  }
}

class Badge extends Equatable {
  final String id;
  final String name;
  final String description;
  final bool unlocked;

  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.unlocked,
  });

  @override
  List<Object?> get props => [id, unlocked];
}

enum NotificationKind { cheers, comment, promo, follow, badge, regulars }

class AppNotification extends Equatable {
  final String id;
  final NotificationKind kind;
  final String text;
  final String? actorPhotoUrl;
  final String? thumbUrl;
  final String? targetId;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.text,
    this.actorPhotoUrl,
    this.thumbUrl,
    this.targetId,
    required this.read,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, read];
}

class RegularEntry extends Equatable {
  final String uid;
  final String handle;
  final String? photoUrl;
  final int checkins;

  const RegularEntry({
    required this.uid,
    required this.handle,
    this.photoUrl,
    required this.checkins,
  });

  @override
  List<Object?> get props => [uid, checkins];
}

/// A friend currently checked in (drop within the last 2 hours).
class LiveCheckin extends Equatable {
  final String shopId;
  final String shopName;
  final String shopImageUrl;
  final List<String?> userPhotos;
  final List<String> handles;

  const LiveCheckin({
    required this.shopId,
    required this.shopName,
    required this.shopImageUrl,
    required this.userPhotos,
    required this.handles,
  });

  @override
  List<Object?> get props => [shopId, handles];
}
