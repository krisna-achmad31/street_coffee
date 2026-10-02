import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/coffee_shop.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/social.dart';
import '../../domain/repositories/social_repository.dart';
import 'demo_feed_simulator.dart';

/// Wraps the real [SocialRepository] and overlays [DemoFeedSimulator] data
/// on the feed, live check-ins and Drop interactions. Anything about a
/// `demo_` id stays in memory; everything else goes to [_inner].
///
/// On by default in debug builds; toggle with
/// `--dart-define=DEMO_FEED=false` (or `=true` for a profile/release demo).
class DemoSocialRepository implements SocialRepository {
  static const enabled =
      bool.fromEnvironment('DEMO_FEED', defaultValue: kDebugMode);

  final SocialRepository _inner;
  final DemoFeedSimulator _sim;

  DemoSocialRepository(this._inner, {DemoFeedSimulator? simulator})
      : _sim = simulator ?? DemoFeedSimulator();

  // ------------------------------------------------------ merged streams

  @override
  Stream<List<Drop>> watchFeed(FeedTab tab, {String? uid}) => _merge(
        _inner.watchFeed(tab, uid: uid),
        _sim.watch(() => _sim.feed(tab, uid: uid)),
        tab == FeedTab.trending
            ? (a, b) => b.cheersCount.compareTo(a.cheersCount)
            : (a, b) => b.publishAt.compareTo(a.publishAt),
      );

  @override
  Stream<List<LiveCheckin>> watchLiveCheckins() => _merge(
        _inner.watchLiveCheckins(),
        _sim.watch(_sim.liveCheckins),
        (a, b) => b.handles.length.compareTo(a.handles.length),
      );

  @override
  Stream<List<Drop>> watchShopDrops(String shopId) => isDemoId(shopId)
      ? _sim.watch(() => _sim.shopDrops(shopId))
      : _inner.watchShopDrops(shopId);

  @override
  Stream<List<Drop>> watchUserDrops(String uid) => isDemoId(uid)
      ? _sim.watch(() => _sim.userDrops(uid))
      : _inner.watchUserDrops(uid);

  @override
  Stream<Drop?> watchDrop(String dropId) => isDemoId(dropId)
      ? _sim.watch(() => _sim.drop(dropId))
      : _inner.watchDrop(dropId);

  // -------------------------------------------------------- interactions

  @override
  Stream<bool> watchCheered(String dropId, String uid) => isDemoId(dropId)
      ? _sim.watch(() => _sim.cheered(dropId, uid)).distinct()
      : _inner.watchCheered(dropId, uid);

  @override
  Future<Either<Failure, void>> setCheers(
      String dropId, String uid, bool cheered) async {
    if (!isDemoId(dropId)) return _inner.setCheers(dropId, uid, cheered);
    _sim.setCheers(dropId, uid, cheered);
    return const Right(null);
  }

  @override
  Stream<List<Comment>> watchDropComments(String dropId) => isDemoId(dropId)
      ? _sim.watch(() => _sim.comments(dropId))
      : _inner.watchDropComments(dropId);

  @override
  Future<Either<Failure, void>> addDropComment(
      String dropId, AppUser author, String text) async {
    if (!isDemoId(dropId)) return _inner.addDropComment(dropId, author, text);
    _sim.addComment(
        dropId,
        Comment(
          id: 'demo_c_me_${DateTime.now().microsecondsSinceEpoch}',
          shopId: '',
          userId: author.uid,
          userName: author.displayName,
          userPhotoUrl: author.photoUrl,
          text: text.trim(),
          createdAt: DateTime.now(),
        ));
    return const Right(null);
  }

  @override
  Stream<bool> watchWant(String uid, String shopId) => isDemoId(shopId)
      ? _sim.watch(() => _sim.wanted(uid, shopId)).distinct()
      : _inner.watchWant(uid, shopId);

  @override
  Future<Either<Failure, void>> setWant(
      String uid, String shopId, bool want) async {
    if (!isDemoId(shopId)) return _inner.setWant(uid, shopId, want);
    _sim.setWant(uid, shopId, want);
    return const Right(null);
  }

  /// Reports on demo content are accepted and dropped.
  @override
  Future<Either<Failure, void>> report({
    required String reporterUid,
    required String targetType,
    required String targetId,
    required ReportReason reason,
    required bool blockAuthor,
    String? authorUid,
  }) async {
    if (isDemoId(targetId)) return const Right(null);
    return _inner.report(
      reporterUid: reporterUid,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      blockAuthor: blockAuthor,
      authorUid: authorUid,
    );
  }

  // ---------------------------------------------------------- passthrough

  @override
  Future<Either<Failure, UserProfile>> ensureProfile(AppUser user) =>
      _inner.ensureProfile(user);

  @override
  Stream<UserProfile?> watchProfile(String uid) => _inner.watchProfile(uid);

  @override
  Future<Either<Failure, String>> createDrop(
          AppUser author, CreateDropInput input) =>
      _inner.createDrop(author, input);

  @override
  Stream<List<Stamp>> watchStamps(String uid) => _inner.watchStamps(uid);

  @override
  List<Badge> computeBadges(List<Drop> drops, int stamps) =>
      _inner.computeBadges(drops, stamps);

  @override
  Stream<List<AppNotification>> watchNotifications(String uid) =>
      _inner.watchNotifications(uid);

  @override
  Future<Either<Failure, void>> markNotificationsRead(String uid) =>
      _inner.markNotificationsRead(uid);

  @override
  Future<Either<Failure, List<RegularEntry>>> regulars(String shopId) =>
      _inner.regulars(shopId);

  @override
  Stream<List<CoffeeShop>> watchWantedShops(String uid) =>
      _inner.watchWantedShops(uid);

  /// Real items + demo items, re-sorted. A failing real stream (no Firebase,
  /// rules, offline) degrades to "demo only" instead of an error screen.
  static Stream<List<T>> _merge<T>(
    Stream<List<T>> real,
    Stream<List<T>> demo,
    int Function(T, T) compare,
  ) =>
      Stream.multi((c) {
        var r = <T>[];
        var d = <T>[];
        var gotDemo = false;
        void emit() {
          if (gotDemo) c.add([...r, ...d]..sort(compare));
        }

        final subs = [
          real.listen((v) {
            r = v;
            emit();
          }, onError: (Object e) {
            debugPrint('DemoSocialRepository: real stream failed: $e');
            r = <T>[];
            emit();
          }),
          demo.listen((v) {
            d = v;
            gotDemo = true;
            emit();
          }),
        ];
        c.onCancel = () => Future.wait(subs.map((s) => s.cancel()));
      });
}
