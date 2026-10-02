import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_tab_bar.dart';
import '../../widgets/ui/location_problem.dart';

/// Hosts the four tab branches and the floating capsule tab bar.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: LocationResumeRetry(child: shell),
      bottomNavigationBar: AppTabBar(
        currentIndex: shell.currentIndex,
        onTab: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        onDrop: () {
          final loggedIn = context.read<AuthBloc>().state is AuthAuthenticated;
          context.push(loggedIn ? AppRouter.newDrop : AppRouter.login);
        },
      ),
    );
  }
}
