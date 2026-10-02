import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../blocs/location/location_bloc.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.8, end: 1.0)
      .animate(CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
  ));
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
  );

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationBloc>().add(LocationGetLast());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _goHome() async {
    if (_navigated) return;
    _navigated = true;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    context.go(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listener: (context, state) {
        if (state is LocationLoaded || state is LocationError) _goHome();
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.1),
              radius: 0.9,
              colors: [Color(0xFF1C2A10), AppColors.bg],
              stops: [0, 0.7],
            ),
          ),
          child: SizedBox.expand(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Stack(
                children: [
                  Center(
                    child: FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale: _scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x669FE444), blurRadius: 60),
                                ],
                              ),
                              child: const Icon(Icons.coffee_rounded,
                                  size: 50, color: AppColors.onPrimary),
                            ),
                            const SizedBox(height: 20),
                            Text('STREET\nCOFFEE',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.display.copyWith(
                                    fontSize: 40,
                                    height: 0.95,
                                    letterSpacing: -1)),
                            const SizedBox(height: 12),
                            Text('Temukan kopi di skenamu',
                                style: AppTextStyles.body.copyWith(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 72,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: _progress.value,
                                minHeight: 4,
                                backgroundColor: AppColors.surfaceAlt,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('Mencari kedai di sekitarmu…',
                              style: AppTextStyles.meta.copyWith(
                                  fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
