import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/ui/common.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const _benefits = [
    (Icons.star_outline_rounded, 'Kasih rating & review kedai'),
    (Icons.approval_rounded, 'Kumpulkan stempel di paspor kopimu'),
    (Icons.chat_bubble_outline_rounded, 'Pesan langsung via WhatsApp'),
  ];

  void _leave(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(AppRouter.home);

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) _leave(context);
        if (state is AuthError) showAppSnack(context, state.message, error: true);
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/login_bg.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surface)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.4, 0.62],
                  colors: [Color(0x4D0E0E0E), Color(0xCC0E0E0E), AppColors.bg],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.coffee_rounded,
                            size: 34, color: AppColors.onPrimary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('STREET\nCOFFEE',
                        style: AppTextStyles.display.copyWith(
                            fontSize: 40, height: 0.95, letterSpacing: -1)),
                    const SizedBox(height: 12),
                    Text('Temukan kopi di skenamu.',
                        style: AppTextStyles.body.copyWith(
                            fontSize: 16, color: AppColors.textSecondary)),
                    const SizedBox(height: 28),
                    for (final (icon, text) in _benefits)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, size: 16, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(text, style: AppTextStyles.body)),
                        ]),
                      ),
                    const SizedBox(height: 16),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) => GoogleSignInButton(
                        loading: state is AuthLoading,
                        onTap: () =>
                            context.read<AuthBloc>().add(AuthSignInGoogle()),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _leave(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Lanjut tanpa login',
                              style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    Text(
                      'Dengan masuk, kamu setuju dengan Ketentuan & Kebijakan Privasi.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.meta
                          .copyWith(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White Google button — the same everywhere (login + guest profile).
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onTap,
    this.loading = false,
    this.label = 'Lanjut dengan Google',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4285F4)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('G',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4285F4))),
                  const SizedBox(width: 12),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F1F1F))),
                ],
              ),
      ),
    );
  }
}
