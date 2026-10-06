import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:street_coffee/core/utils/failures.dart';
import 'package:street_coffee/domain/entities/comment.dart';
import 'package:street_coffee/domain/usecases/coffee_shop_usecases.dart';
import 'package:street_coffee/domain/usecases/location_usecases.dart';
import 'package:street_coffee/presentation/blocs/admin/admin_bloc.dart';
import 'package:street_coffee/presentation/blocs/auth/auth_bloc.dart';
import 'package:street_coffee/presentation/blocs/comment/comment_bloc.dart';
import 'package:street_coffee/presentation/blocs/detail/detail_bloc.dart';
import 'package:street_coffee/presentation/blocs/explore/explore_bloc.dart';
import 'package:street_coffee/presentation/blocs/location/location_bloc.dart';

import '../../helpers/fakes.dart';

/// Lets queued events and fake futures finish.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  group('ExploreBloc', () {
    late FakeCoffeeShopRepository repo;
    late ExploreBloc bloc;
    late List<ExploreState> states;

    setUp(() {
      repo = FakeCoffeeShopRepository();
      bloc = ExploreBloc(
          getNearbyShops: GetNearbyShops(repo), searchShops: SearchShops(repo));
      states = [];
      bloc.stream.listen(states.add);
    });
    tearDown(() => bloc.close());

    test('load → loading then loaded', () async {
      repo.nearby = Right([shop('1'), shop('2')]);
      bloc.add(const ExploreLoadShops(jakarta));
      await _settle();
      expect(states.first, isA<ExploreLoading>());
      expect((states.last as ExploreLoaded).shops.length, 2);
    });

    test('empty and failing loads become distinct states', () async {
      bloc.add(const ExploreLoadShops(jakarta));
      await _settle();
      expect(states.last, const ExploreEmpty('Belum ada kedai di area kamu'));

      repo.nearby = const Left(NetworkFailure());
      bloc.add(const ExploreRefresh(jakarta));
      await _settle();
      expect(states.last, isA<ExploreError>());
      expect((states.last as ExploreError).message, contains('internet'));
    });

    test('refresh keeps the list on screen (no loading state)', () async {
      repo.nearby = Right([shop('1')]);
      bloc.add(const ExploreLoadShops(jakarta));
      await _settle();
      states.clear();
      bloc.add(const ExploreRefresh(jakarta));
      await _settle();
      expect(states.whereType<ExploreLoading>(), isEmpty);
    });

    test('filters are passed to the query and kept in the state', () async {
      repo.nearby = Right([shop('1')]);
      bloc.add(const ExploreLoadShops(jakarta));
      bloc.add(const ExploreFilterChanged(vibe: 'Deep Talk', isOpen: true, maxPrice: 20000));
      await _settle();
      expect(repo.nearbyCalls.last,
          (vibe: 'Deep Talk', isOpen: true, maxPrice: 20000));
      final s = states.last as ExploreLoaded;
      expect(s.activeVibe, 'Deep Talk');
      expect(s.isOpenFilter, isTrue);
      expect(s.maxPriceFilter, 20000);
    });

    test('a filter before any location is remembered, not fetched', () async {
      bloc.add(const ExploreFilterChanged(vibe: 'Santai'));
      await _settle();
      expect(repo.nearbyCalls, isEmpty);
      bloc.add(const ExploreLoadShops(jakarta));
      await _settle();
      expect(repo.nearbyCalls.single.vibe, 'Santai');
    });

    test('search uses the trimmed query; blank search falls back to nearby',
        () async {
      repo.search = Right([shop('9', name: 'Kopi Kenangan Senja')]);
      bloc.add(const ExploreSearchChanged(query: '  senja ', location: jakarta));
      await _settle();
      expect(repo.searchCalls, ['senja']);
      expect((states.last as ExploreLoaded).shops.single.id, '9');

      repo.search = const Right([]);
      bloc.add(const ExploreSearchChanged(query: 'zzz', location: jakarta));
      await _settle();
      expect(states.last, const ExploreEmpty('Kedai tidak ditemukan'));

      bloc.add(const ExploreSearchChanged(query: '   ', location: jakarta));
      await _settle();
      expect(repo.searchCalls.length, 2);
      expect(repo.nearbyCalls, hasLength(1));
    });

    test('latest request wins even if an older one answers last', () async {
      final slow = Completer<void>();
      repo.gates.add(slow);
      repo.nearby = Right([shop('old')]);
      bloc.add(const ExploreLoadShops(jakarta)); // held by the gate
      await _settle();

      repo.nearby = Right([shop('new')]);
      bloc.add(const ExploreFilterChanged(vibe: 'Santai'));
      await _settle();
      slow.complete(); // the stale answer arrives late
      await _settle();

      final loaded = states.whereType<ExploreLoaded>().toList();
      expect(loaded, hasLength(1));
      expect(loaded.single.shops.single.id, 'new');
    });
  });

  group('LocationBloc', () {
    late FakeLocationRepository repo;
    late LocationBloc bloc;

    setUp(() {
      repo = FakeLocationRepository();
      bloc = LocationBloc(
        getCurrentLocation: GetCurrentLocation(repo),
        getLastSavedLocation: GetLastSavedLocation(repo),
      );
    });
    tearDown(() => bloc.close());

    test('uses the saved location without asking the GPS', () async {
      repo.saved = const Right(jakarta);
      bloc.add(LocationGetLast());
      await _settle();
      expect(bloc.state, const LocationLoaded(jakarta));
      expect(repo.currentCalls, 0);
    });

    test('no (or unreadable) saved location falls back to the GPS', () async {
      repo.saved = const Left(CacheFailure());
      bloc.add(LocationGetLast());
      await _settle();
      expect(repo.currentCalls, 1);
      expect(bloc.state, const LocationLoaded(jakarta));
    });

    test('permission problems are flagged for the "Izin lokasi" screen',
        () async {
      repo.current = const Left(LocationFailure(
          'Izin ditolak permanen', LocationIssue.permissionDeniedForever));
      bloc.add(LocationGetCurrent());
      await _settle();
      final s = bloc.state as LocationError;
      expect(s.isPermission, isTrue);

      repo.current = const Left(LocationFailure());
      bloc.add(LocationGetCurrent());
      await _settle();
      expect((bloc.state as LocationError).isPermission, isFalse);
    });

    test('a manually picked location replaces the current one', () async {
      bloc.add(const LocationSet(bandung));
      await _settle();
      expect(bloc.state, const LocationLoaded(bandung));
    });
  });

  group('DetailBloc', () {
    test('loads a shop or reports why it could not', () async {
      final repo = FakeCoffeeShopRepository()..byId = Right(shop('7'));
      final bloc = DetailBloc(getShopById: GetShopById(repo));
      bloc.add(const DetailLoadShop('7'));
      await _settle();
      expect((bloc.state as DetailLoaded).shop.id, '7');

      repo.byId = const Left(NotFoundFailure());
      bloc.add(const DetailLoadShop('gone'));
      await _settle();
      expect(bloc.state, const DetailError('Data tidak ditemukan'));
      await bloc.close();
    });
  });

  group('CommentBloc', () {
    late FakeCommentRepository repo;
    late CommentBloc bloc;

    setUp(() {
      repo = FakeCommentRepository();
      bloc = CommentBloc(repository: repo);
    });
    tearDown(() => bloc.close());

    final c = Comment(
        id: 'c1',
        shopId: 's1',
        userId: 'u1',
        userName: 'Raka',
        text: 'Mantap',
        createdAt: DateTime(2026));

    test('streams comments and survives a stream error', () async {
      bloc.add(const CommentWatch('s1'));
      await _settle();
      expect(bloc.state, isA<CommentLoading>());

      repo.controller.add([c]);
      await _settle();
      expect(bloc.state, CommentLoaded([c]));

      repo.controller.addError(Exception('boom'));
      await _settle();
      expect(bloc.state, const CommentError('Review gagal dimuat.'));
    });

    test('a failed post is reported once, without dropping the list',
        () async {
      bloc.add(const CommentWatch('s1'));
      await _settle();
      repo.controller.add([c]);
      await _settle();

      final errors = <String>[];
      bloc.failures.listen(errors.add);
      repo.addResult = const Left(NetworkFailure());
      bloc.add(const CommentAdd(
          shopId: 's1', userId: 'u1', userName: 'Raka', text: 'Halo'));
      await _settle();

      expect(repo.added, ['Halo']);
      expect(errors, hasLength(1));
      expect(bloc.state, CommentLoaded([c]));
    });
  });

  group('AdminBloc', () {
    test('create/toggle succeed and failures surface as AdminError', () async {
      final repo = FakeAdminShopRepository();
      final bloc = AdminBloc(repository: repo);
      final states = <AdminState>[];
      bloc.stream.listen(states.add);

      bloc.add(AdminToggleOpen(shopId: 's1', isOpen: false));
      await _settle();
      expect(repo.lastIsOpen, isFalse);
      expect(states.last, const AdminSuccess(message: 'Status: TUTUP'));

      repo.updateResult = const Left(ServerFailure('Kamu tidak punya akses ke data ini.'));
      bloc.add(const AdminDeleteShop('s1'));
      await _settle();
      expect(states.last, const AdminError('Kamu tidak punya akses ke data ini.'));
      await bloc.close();
    });
  });

  group('AuthBloc', () {
    test('follows auth changes, sign-in and sign-out', () async {
      final repo = FakeAuthRepository();
      final bloc = AuthBloc(authRepository: repo)..add(AuthStarted());
      await _settle();

      repo.controller.add(member);
      await _settle();
      expect(bloc.state, const AuthAuthenticated(member));

      bloc.add(AuthSignOut());
      await _settle();
      expect(bloc.state, isA<AuthUnauthenticated>());
      expect(repo.signOutCalls, 1);

      repo.signIn = const Left(ServerFailure('Login dibatalkan'));
      bloc.add(AuthSignInGoogle());
      await _settle();
      expect(bloc.state, const AuthError('Login dibatalkan'));
      await bloc.close();
    });
  });
}
