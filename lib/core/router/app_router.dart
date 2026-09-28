import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/coffee_shop.dart';
import '../../injection_container.dart';
import '../../presentation/blocs/admin/admin_bloc.dart';
import '../../presentation/blocs/detail/detail_bloc.dart';
import '../../presentation/pages/admin/add_edit_shop_page.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/detail/coffee_detail_page.dart';
import '../../presentation/pages/explore/explore_list_page.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/location/pick_location_page.dart';
import '../../presentation/pages/splash/splash_page.dart';

class AppRouter {
  AppRouter._();

  static const String splash       = '/';
  static const String home         = '/home';
  static const String explore      = '/explore';
  static const String detail       = '/detail';
  static const String pickLocation = '/pick-location';
  static const String login        = '/login';
  static const String adminAddShop  = '/admin/add-shop';
  static const String adminEditShop = '/admin/edit-shop';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        pageBuilder: (c, s) => _fade(s, const SplashPage()),
      ),
      GoRoute(
        path: home,
        pageBuilder: (c, s) => _fade(s, const HomePage()),
      ),
      GoRoute(
        path: explore,
        pageBuilder: (c, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return _fade(s, ExploreListPage(initialVibe: extra?['vibe']));
        },
      ),
      GoRoute(
        path: '$detail/:id',
        pageBuilder: (c, s) {
          final shopId = s.pathParameters['id']!;
          return _fade(
            s,
            BlocProvider(
              create: (_) => sl<DetailBloc>(),
              child: CoffeeDetailPage(shopId: shopId),
            ),
          );
        },
      ),
      GoRoute(
        path: pickLocation,
        pageBuilder: (c, s) => _fade(s, const PickLocationPage()),
      ),
      GoRoute(
        path: login,
        pageBuilder: (c, s) => _fade(s, const LoginPage()),
      ),
      GoRoute(
        path: adminAddShop,
        pageBuilder: (c, s) => _fade(
          s,
          BlocProvider(
            create: (_) => sl<AdminBloc>(),
            child: const AddEditShopPage(),
          ),
        ),
      ),
      GoRoute(
        path: adminEditShop,
        pageBuilder: (c, s) {
          final shop = s.extra as CoffeeShop;
          return _fade(
            s,
            BlocProvider(
              create: (_) => sl<AdminBloc>(),
              child: AddEditShopPage(existingShop: shop),
            ),
          );
        },
      ),
    ],
  );

  static CustomTransitionPage _fade(GoRouterState s, Widget child) {
    return CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}