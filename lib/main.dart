import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'injection_container.dart';
import 'domain/repositories/social_repository.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/explore/explore_bloc.dart';
import 'presentation/blocs/location/location_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await initDependencies();
  runApp(const StreetCoffeeApp());
}

class StreetCoffeeApp extends StatelessWidget {
  const StreetCoffeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Singleton blocs — live for entire app session
        BlocProvider<AuthBloc>(create: (_) => sl<AuthBloc>()),
        BlocProvider<LocationBloc>(create: (_) => sl<LocationBloc>()),
        BlocProvider<ExploreBloc>(create: (_) => sl<ExploreBloc>()),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        // Social profile (handle, passport counters) is created on first login.
        listener: (_, state) {
          if (state is AuthAuthenticated) {
            sl<SocialRepository>().ensureProfile(state.user);
          }
        },
        child: MaterialApp.router(
          title: 'Street Coffee',
          theme: AppTheme.dark,
          routerConfig: AppRouter.router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            // Respect the user's font size, capped so layouts stay intact.
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.3),
            ),
            child: child!,
          ),
        ),
      ),
    );
  }
}
