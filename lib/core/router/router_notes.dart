// This file shows how DetailBloc is provided per-page.
// In app_router.dart, wrap CoffeeDetailPage with BlocProvider.

// Update app_router.dart GoRoute for detail:
//
// GoRoute(
//   path: '$detail/:id',
//   name: 'detail',
//   pageBuilder: (context, state) {
//     final shopId = state.pathParameters['id']!;
//     return _buildPage(
//       state,
//       BlocProvider(
//         create: (_) => sl<DetailBloc>(),
//         child: CoffeeDetailPage(shopId: shopId),
//       ),
//     );
//   },
// ),
//
// Also add this import in app_router.dart:
// import 'package:flutter_bloc/flutter_bloc.dart';
// import '../../injection_container.dart';
// import '../../presentation/blocs/detail/detail_bloc.dart';
