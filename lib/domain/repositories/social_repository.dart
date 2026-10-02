import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../core/utils/failures.dart';
import '../entities/app_user.dart';
import '../entities/comment.dart';
import '../entities/coffee_shop.dart';
import '../entities/social.dart';

enum FeedTab { nearby, friends, trending }

class CreateDropInput {
  final String shopId;
  final String shopName;
  final String shopVibe;
  final List<File> photos;
  final String caption;
  final String? menuItem;
  final int? menuPrice;
  final int rating;
  final bool delayLocation;
  final double latitude;
  final double longitude;

  const CreateDropInput({
    required this.shopId,
    required this.shopName,
    required this.shopVibe,
    required this.photos,
    required this.caption,
    this.menuItem,
    this.menuPrice,
    required this.rating,
    required this.delayLocation,
    required this.latitude,
    required this.longitude,
  });
}

enum ReportReason { spam, inappropriate, harassment, wrongInfo, other }

abstract class SocialRepository {
  /// Creates users/{uid} on first login and returns the profile.
  Future<Either<Failure, UserProfile>> ensureProfile(AppUser user);
  Stream<UserProfile?> watchProfile(String uid);

  Stream<List<Drop>> watchFeed(FeedTab tab, {String? uid});
  Stream<List<Drop>> watchShopDrops(String shopId);
  Stream<List<Drop>> watchUserDrops(String uid);
  Stream<Drop?> watchDrop(String dropId);
  Stream<List<LiveCheckin>> watchLiveCheckins();

  Future<Either<Failure, String>> createDrop(
      AppUser author, CreateDropInput input);

  Stream<bool> watchCheered(String dropId, String uid);
  Future<Either<Failure, void>> setCheers(
      String dropId, String uid, bool cheered);

  Stream<List<Comment>> watchDropComments(String dropId);
  Future<Either<Failure, void>> addDropComment(
      String dropId, AppUser author, String text);

  Future<Either<Failure, void>> report({
    required String reporterUid,
    required String targetType,
    required String targetId,
    required ReportReason reason,
    required bool blockAuthor,
    String? authorUid,
  });

  Stream<List<Stamp>> watchStamps(String uid);
  List<Badge> computeBadges(List<Drop> drops, int stamps);

  Stream<List<AppNotification>> watchNotifications(String uid);
  Future<Either<Failure, void>> markNotificationsRead(String uid);

  Future<Either<Failure, List<RegularEntry>>> regulars(String shopId);

  Stream<bool> watchWant(String uid, String shopId);
  Future<Either<Failure, void>> setWant(String uid, String shopId, bool want);

  /// "Mau ke sini" list, newest first. Shops deleted since are dropped.
  Stream<List<CoffeeShop>> watchWantedShops(String uid);
}
