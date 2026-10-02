import 'dart:async';
import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/failures.dart';
import 'package:street_coffee/data/demo/demo_feed_simulator.dart';
import 'package:street_coffee/data/demo/demo_social_repository.dart';
import 'package:street_coffee/domain/entities/app_user.dart';
import 'package:street_coffee/domain/entities/social.dart';
import 'package:street_coffee/domain/repositories/social_repository.dart';

/// Only the members the demo repository forwards in these tests.
class _FakeReal implements SocialRepository {
  final feed = StreamController<List<Drop>>.broadcast();
  final cheered = <String>[];

  @override
  Stream<List<Drop>> watchFeed(FeedTab tab, {String? uid}) => feed.stream;

  @override
  Future<Either<Failure, void>> setCheers(
      String dropId, String uid, bool on) async {
    cheered.add(dropId);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Drop _real(String id, DateTime at) => Drop(
      id: id,
      userId: 'u1',
      userHandle: '@real',
      userIsPass: false,
      shopId: 's1',
      shopName: 'Real',
      shopVibe: '',
      photoUrls: const [],
      caption: '',
      rating: 5,
      vibe: '',
      stampNumber: 1,
      isFirstAtShop: false,
      cheersCount: 9999,
      commentCount: 0,
      createdAt: at,
      publishAt: at,
    );

void main() {
  final t0 = DateTime(2026, 10, 2, 9);
  DemoFeedSimulator sim() =>
      DemoFeedSimulator(random: Random(7), clock: () => t0, newDropEvery: 2);

  group('DemoFeedSimulator', () {
    test('seeds a newest-first timeline of demo ids', () {
      final drops = sim().feed(FeedTab.nearby);
      expect(drops, isNotEmpty);
      expect(drops.every((d) => isDemoId(d.id) && isDemoId(d.shopId)), isTrue);
      for (var i = 1; i < drops.length; i++) {
        expect(drops[i - 1].publishAt.isAfter(drops[i].publishAt), isTrue);
      }
    });

    test('friends tab needs a uid; trending sorts by cheers', () {
      final s = sim();
      expect(s.feed(FeedTab.friends), isEmpty);
      expect(s.feed(FeedTab.friends, uid: 'me'), isNotEmpty);
      final t = s.feed(FeedTab.trending);
      for (var i = 1; i < t.length; i++) {
        expect(t[i - 1].cheersCount >= t[i].cheersCount, isTrue);
      }
    });

    test('step publishes new drops and keeps something live', () {
      final s = sim();
      final before = s.feed(FeedTab.nearby).length;
      s
        ..step()
        ..step();
      expect(s.feed(FeedTab.nearby).length, before + 1);
      expect(s.liveCheckins(), isNotEmpty);
    });

    test('cheers toggle is idempotent and counted', () {
      final s = sim();
      final d = s.feed(FeedTab.nearby).first;
      s
        ..setCheers(d.id, 'me', true)
        ..setCheers(d.id, 'me', true);
      expect(s.drop(d.id)!.cheersCount, d.cheersCount + 1);
      expect(s.cheered(d.id, 'me'), isTrue);
      s.setCheers(d.id, 'me', false);
      expect(s.drop(d.id)!.cheersCount, d.cheersCount);
    });

    test('ticker runs only while watched', () async {
      final s = sim();
      expect(s.isRunning, isFalse);
      final sub = s.watch(() => s.feed(FeedTab.nearby)).listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(s.isRunning, isTrue);
      await sub.cancel();
      expect(s.isRunning, isFalse);
      s.dispose();
    });
  });

  group('DemoSocialRepository', () {
    test('merges real drops into the demo feed, sorted by publishAt', () async {
      final real = _FakeReal();
      final repo = DemoSocialRepository(real, simulator: sim());
      final out = <List<Drop>>[];
      final sub = repo.watchFeed(FeedTab.nearby).listen(out.add);
      await Future<void>.delayed(Duration.zero);
      real.feed.add([_real('r1', t0.add(const Duration(minutes: 1)))]);
      await Future<void>.delayed(Duration.zero);
      expect(out.last.first.id, 'r1');
      expect(out.last.skip(1).every((d) => isDemoId(d.id)), isTrue);
      await sub.cancel();
    });

    test('a failing real stream falls back to demo only', () async {
      final real = _FakeReal();
      final repo = DemoSocialRepository(real, simulator: sim());
      final out = <List<Drop>>[];
      final sub = repo.watchFeed(FeedTab.nearby).listen(out.add);
      real.feed.addError(Exception('permission-denied'));
      await Future<void>.delayed(Duration.zero);
      expect(out.last, isNotEmpty);
      await sub.cancel();
    });

    test('demo interactions stay local, real ones are forwarded', () async {
      final real = _FakeReal();
      final s = sim();
      final repo = DemoSocialRepository(real, simulator: s);
      final demoId = s.feed(FeedTab.nearby).first.id;
      await repo.setCheers(demoId, 'me', true);
      await repo.setCheers('real-drop', 'me', true);
      expect(real.cheered, ['real-drop']);
      expect(s.cheered(demoId, 'me'), isTrue);

      final before = s.drop(demoId)!.commentCount;
      await repo.addDropComment(
          demoId,
          const AppUser(uid: 'me', email: 'a@b.c', displayName: 'Krisna', isAdmin: false),
          '  enak!  ');
      expect(s.comments(demoId).first.text, 'enak!');
      expect(s.drop(demoId)!.commentCount, before + 1);
      s.dispose();
    });
  });
}
