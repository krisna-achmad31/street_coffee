import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'injection_container.dart';
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
      child: MaterialApp.router(
        title: 'Street Coffee',
        theme: AppTheme.dark,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        ),
      ),
    );
  }
}
