import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/redeem_code.dart';
import '../../../domain/entities/commerce.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';
import '../../widgets/ui/receipt.dart';

/// Member side of redeem (PRD lubang #1): a 6-char code that rotates every
/// 30 s, plus QR, a live clock and the member's name so a screenshot is
/// easy to spot. Validation happens only on the server (redeemPromo).
class UsePromoPage extends StatefulWidget {
  final Promo promo;
  const UsePromoPage({super.key, required this.promo});

  @override
  State<UsePromoPage> createState() => _UsePromoPageState();
}

class _UsePromoPageState extends State<UsePromoPage> {
  final _repo = sl<CommerceRepository>();
  late final String _uid;
  late final String _name;
  StreamSubscription<Membership>? _sub;
  Membership? _membership;
  Timer? _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state as AuthAuthenticated;
    _uid = auth.user.uid;
    _name = auth.user.displayName;
    _sub = _repo.watchMembership(_uid).listen((m) => setState(() => _membership = m));
    _repo.openRedeemIntent(uid: _uid, promoId: widget.promo.id, shopId: widget.promo.shopId);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      // Re-announce presence each window so the cashier lookup stays warm.
      if (RedeemCode.windowFor(now) != RedeemCode.windowFor(_now)) {
        _repo.openRedeemIntent(uid: _uid, promoId: widget.promo.id, shopId: widget.promo.shopId);
      }
      setState(() => _now = now);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.promo;
    final secret = _membership?.redeemSecret;
    final memberOk = !p.memberOnly || (_membership?.active ?? false);
    final code = secret == null
        ? null
        : RedeemCode.generate(secret: secret, promoId: p.id, at: _now);
    final left = RedeemCode.secondsLeft(_now);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 0.9,
            colors: [Color(0xFF1C2A10), AppColors.bg],
            stops: [0, 0.75],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            const ScreenHeader(
                title: 'Pakai Promo', back: true, backIcon: Icons.close_rounded),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          NetImage(p.shopImageUrl,
                              width: 48, height: 48, radius: BorderRadius.circular(12)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MonoText(p.shopName.toUpperCase(),
                                    size: 10,
                                    weight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.8),
                                Text(p.title,
                                    style: AppTextStyles.cardTitle.copyWith(
                                        fontSize: 15, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                          if (p.memberOnly) const PassTag(),
                        ]),
                      ),
                      const Perforation(notchColor: Color(0xFF151A10)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
                        child: !memberOk || code == null
                            ? _notReady(memberOk)
                            : _codeBody(code, left),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      for (final (n, t) in const [
                        ('1', 'Tunjukkan layar ini ke kasir'),
                        ('2', 'Kasir memasukkan kode atau scan QR'),
                        ('3', 'Diskon langsung dipotong saat bayar'),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: MonoText(n,
                                  weight: FontWeight.w700, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(t,
                                  style: AppTextStyles.body.copyWith(
                                      fontSize: 13, color: AppColors.textSecondary)),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Berlaku 1× per hari · kuota tersisa ${p.quotaLeft} · s/d ${p.endAt.day}/${p.endAt.month}. '
                    'Screenshot tidak berlaku — kode hanya valid di aplikasi.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.meta
                        .copyWith(fontSize: 11, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _notReady(bool memberOk) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          memberOk
              ? 'Menyiapkan kode member…'
              : 'Promo ini khusus member Street Pass.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      );

  Widget _codeBody(String code, int left) => Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: RedeemCode.qrPayload(uid: _uid, promoId: widget.promo.id, code: code),
            size: 160,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.bg),
            dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square, color: AppColors.bg),
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Kode promo ${code.split('').join(' ')}',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final ch in code.split(''))
                Container(
                  width: 40,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(ch,
                      style: AppTextStyles.mono.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: left / RedeemCode.periodSeconds,
            minHeight: 4,
            backgroundColor: AppColors.surfaceAlt,
          ),
        ),
        const SizedBox(height: 8),
        MonoText('KODE BERGANTI DALAM $left DTK', size: 10, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: MonoText(
            'LIVE · ${Fmt.hhmm(_now)}:${_now.second.toString().padLeft(2, '0')} · ${_name.toUpperCase()}',
            size: 10,
            weight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ]);
}
