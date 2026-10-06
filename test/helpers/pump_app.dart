import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:street_coffee/core/theme/app_theme.dart';
import 'package:street_coffee/domain/repositories/admin_shop_repository.dart';
import 'package:street_coffee/domain/repositories/comment_repository.dart';
import 'package:street_coffee/domain/repositories/commerce_repository.dart';
import 'package:street_coffee/domain/repositories/social_repository.dart';
import 'package:street_coffee/domain/usecases/coffee_shop_usecases.dart';
import 'package:street_coffee/domain/usecases/location_usecases.dart';
import 'package:street_coffee/injection_container.dart';
import 'package:street_coffee/presentation/blocs/admin/admin_bloc.dart';
import 'package:street_coffee/presentation/blocs/auth/auth_bloc.dart';
import 'package:street_coffee/presentation/blocs/comment/comment_bloc.dart';
import 'package:street_coffee/presentation/blocs/detail/detail_bloc.dart';
import 'package:street_coffee/presentation/blocs/explore/explore_bloc.dart';
import 'package:street_coffee/presentation/blocs/location/location_bloc.dart';

import 'fakes.dart';

/// Everything a page can reach, backed by in-memory fakes (no Firebase).
class TestEnv {
  final shops = FakeCoffeeShopRepository();
  final location = FakeLocationRepository();
  final auth = FakeAuthRepository();
  final comments = FakeCommentRepository();
  final adminRepo = FakeAdminShopRepository();
  final social = FakeSocialRepository();
  final commerce = FakeCommerceRepository();

  late final authBloc = AuthBloc(authRepository: auth);
  late final locationBloc = LocationBloc(
    getCurrentLocation: GetCurrentLocation(location),
    getLastSavedLocation: GetLastSavedLocation(location),
  );
  late final exploreBloc = ExploreBloc(
      getNearbyShops: GetNearbyShops(shops), searchShops: SearchShops(shops));
  late final detailBloc = DetailBloc(getShopById: GetShopById(shops));
  late final adminBloc = AdminBloc(repository: adminRepo);

  /// Pages read some repositories straight from the service locator.
  Future<void> register() async {
    await sl.reset();
    sl.registerSingleton<SocialRepository>(social);
    sl.registerSingleton<CommerceRepository>(commerce);
    sl.registerSingleton<CommentRepository>(comments);
    sl.registerSingleton<AdminShopRepository>(adminRepo);
    sl.registerFactory(() => CommentBloc(repository: comments));
    sl.registerFactory(() => AdminBloc(repository: adminRepo));
  }

  Future<void> dispose() async {
    await authBloc.close();
    await locationBloc.close();
    await exploreBloc.close();
    await detailBloc.close();
    await adminBloc.close();
    await sl.reset();
  }

  /// Pumps [page] (at "/page") inside the app theme. Navigation to any other route
  /// lands on a stub that prints the location, so taps can be asserted.
  Future<void> pump(WidgetTester tester, Widget page,
      {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('ROUTE ${s.uri}'));
    // The page sits on top of a stub "/" so it can pop back after saving.
    final router = GoRouter(initialLocation: '/page', routes: [
      GoRoute(path: '/', builder: stub, routes: [
        GoRoute(path: 'page', builder: (_, __) => page),
      ]),
      for (final p in const [
        '/home', '/explore', '/feed', '/profile', '/login', '/pick-location',
        '/street-pass', '/notifications', '/drop/new', '/detail/:id',
      ])
        GoRoute(path: p, builder: stub),
    ]);
    addTearDown(router.dispose);
    // Resolve who is signed in before the page reads it in initState.
    authBloc.add(AuthStarted());
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authBloc),
        BlocProvider.value(value: locationBloc),
        BlocProvider.value(value: exploreBloc),
        BlocProvider.value(value: detailBloc),
        BlocProvider.value(value: adminBloc),
      ],
      child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    ));
  }
}
