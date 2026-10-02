import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/coffee_shop.dart';
import '../../domain/entities/commerce.dart';
import '../../injection_container.dart';
import '../../presentation/blocs/admin/admin_bloc.dart';
import '../../presentation/blocs/detail/detail_bloc.dart';
import '../../presentation/blocs/explore/explore_bloc.dart';
import '../../presentation/pages/admin/add_edit_shop_page.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/commerce/cashier_page.dart';
import '../../presentation/pages/commerce/create_promo_page.dart';
import '../../presentation/pages/commerce/kedai_pro_dashboard_page.dart';
import '../../presentation/pages/commerce/kedai_pro_landing_page.dart';
import '../../presentation/pages/commerce/street_pass_page.dart';
import '../../presentation/pages/commerce/use_promo_page.dart';
import '../../presentation/pages/detail/coffee_detail_page.dart';
import '../../presentation/pages/explore/explore_page.dart';
import '../../presentation/pages/home/home_page.dart';
import '../../presentation/pages/location/pick_location_page.dart';
import '../../presentation/pages/profile/profile_page.dart';
import '../../presentation/pages/shell/main_shell.dart';
import '../../presentation/pages/social/create_drop_page.dart';
import '../../presentation/pages/social/drop_posted_page.dart';
import '../../presentation/pages/social/feed_page.dart';
import '../../presentation/pages/social/notifications_page.dart';
import '../../presentation/pages/splash/splash_page.dart';
import '../../presentation/widgets/ui/common.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String home = '/home';
  static const String explore = '/explore';
  static const String feed = '/feed';
  static const String profile = '/profile';
  static const String detail = '/detail';
  static const String pickLocation = '/pick-location';
  static const String login = '/login';
  static const String adminAddShop = '/admin/add-shop';
  static const String adminEditShop = '/admin/edit-shop';
  static const String newDrop = '/drop/new';
  static const String dropPosted = '/drop/posted';
  static const String notifications = '/notifications';
  static const String streetPass = '/street-pass';
  static const String kedaiPro = '/kedai-pro';
  static const String kedaiProDashboard = '/kedai-pro/dashboard';
  static const String createPromo = '/kedai-pro/promo/new';
  static const String cashier = '/kedai-pro/cashier';
  static const String usePromo = '/promo/use';

  static final _rootKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: splash,
    // Unknown/malformed links (e.g. an old share URL) land somewhere useful.
    errorBuilder: (c, s) => const _ExpiredPage(),
    routes: [
      GoRoute(path: splash, pageBuilder: (c, s) => _fade(s, const SplashPage())),
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: home, pageBuilder: (c, s) => _fade(s, const HomePage())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: explore,
              pageBuilder: (c, s) {
                final extra = s.extra is Map ? s.extra as Map : const {};
                // Own bloc: Explore filters must not leak into Home's lists.
                return _fade(
                  s,
                  BlocProvider(
                    create: (_) => sl<ExploreBloc>(),
                    child: ExplorePage(
                      initialVibe: extra['vibe'] is String ? extra['vibe'] : null,
                      startOnMap: extra['map'] == true,
                    ),
                  ),
                );
              },
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: feed, pageBuilder: (c, s) => _fade(s, const FeedPage())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: profile,
                pageBuilder: (c, s) => _fade(s, const ProfilePage())),
          ]),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '$detail/:id',
        pageBuilder: (c, s) => _fade(
          s,
          BlocProvider(
            create: (_) => sl<DetailBloc>(),
            child: CoffeeDetailPage(shopId: s.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: pickLocation,
          pageBuilder: (c, s) => _fade(s, const PickLocationPage())),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: login,
          pageBuilder: (c, s) => _fade(s, const LoginPage())),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: adminAddShop,
        pageBuilder: (c, s) => _fade(
          s,
          BlocProvider(
              create: (_) => sl<AdminBloc>(), child: const AddEditShopPage()),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: adminEditShop,
        pageBuilder: (c, s) => _fade(
          s,
          s.extra is CoffeeShop
              ? BlocProvider(
                  create: (_) => sl<AdminBloc>(),
                  child: AddEditShopPage(existingShop: s.extra as CoffeeShop),
                )
              : const _ExpiredPage(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: newDrop,
        pageBuilder: (c, s) =>
            _slideUp(s, CreateDropPage(initialShop: _extra<CoffeeShop>(s))),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '$dropPosted/:id',
        pageBuilder: (c, s) =>
            _fade(s, DropPostedPage(dropId: s.pathParameters['id']!)),
      ),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: notifications,
          pageBuilder: (c, s) => _fade(s, const NotificationsPage())),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: streetPass,
          pageBuilder: (c, s) => _slideUp(s, const StreetPassPage())),
      GoRoute(
          parentNavigatorKey: _rootKey,
          path: kedaiPro,
          pageBuilder: (c, s) => _fade(s, const KedaiProLandingPage())),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '$kedaiProDashboard/:shopId',
        pageBuilder: (c, s) => _fade(
            s, KedaiProDashboardPage(shopId: s.pathParameters['shopId']!)),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: createPromo,
        pageBuilder: (c, s) =>
            _fade(
                s,
                s.extra is CoffeeShop
                    ? CreatePromoPage(shop: s.extra as CoffeeShop)
                    : const _ExpiredPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '$cashier/:shopId',
        pageBuilder: (c, s) =>
            _fade(s, CashierPage(shopId: s.pathParameters['shopId']!)),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: usePromo,
        pageBuilder: (c, s) =>
            _slideUp(
                s,
                s.extra is Promo
                    ? UsePromoPage(promo: s.extra as Promo)
                    : const _ExpiredPage()),
      ),
    ],
  );

  static T? _extra<T>(GoRouterState s) => s.extra is T ? s.extra as T : null;

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

  static CustomTransitionPage _slideUp(GoRouterState s, Widget child) {
    return CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}

/// Pages that need an in-memory object (passed as `extra`) lose it after a
/// process restart or when opened from a link; show a way out, not a crash.
class _ExpiredPage extends StatelessWidget {
  const _ExpiredPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const ScreenHeader(title: '', back: true),
          Expanded(
            child: StateView(
              icon: Icons.history_rounded,
              title: 'Halaman kedaluwarsa',
              message: 'Data halaman ini sudah tidak tersedia. Buka lagi dari awal ya.',
              actionLabel: 'Ke Home',
              onAction: () => context.go(AppRouter.home),
            ),
          ),
        ]),
      ),
    );
  }
}
