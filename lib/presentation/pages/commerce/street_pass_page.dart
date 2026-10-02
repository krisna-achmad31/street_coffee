import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../data/services/street_pass_billing.dart';
import '../../../domain/entities/commerce.dart';
import '../../../domain/entities/social.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/common.dart';

class StreetPassPage extends StatefulWidget {
  const StreetPassPage({super.key});

  @override
  State<StreetPassPage> createState() => _StreetPassPageState();
}

class _StreetPassPageState extends State<StreetPassPage> {
  final _billing = sl<StreetPassBilling>();
  Map<String, ProductDetails> _products = const {};
  String _plan = StreetPassBilling.yearlyId;
  BillingStatus _status = const BillingStatus.idle();
  StreamSubscription<BillingStatus>? _sub;

  static const _benefits = [
    (Icons.confirmation_number_outlined, 'Promo eksklusif di kedai partner', 'Diskon & bundling tiap minggu'),
    (Icons.auto_awesome_rounded, 'Frame & badge eksklusif', 'Share card kamu beda sendiri'),
    (Icons.bar_chart_rounded, 'Coffee Wrapped', 'Rekap ngopi setahun + statistik paspor lengkap'),
    (Icons.bookmark_add_outlined, 'Koleksi tanpa batas', 'Simpan & kelompokkan kedai favorit'),
    (Icons.rocket_launch_outlined, 'Akses awal kedai baru', 'Jadi yang pertama nge-Drop'),
  ];

  @override
  void initState() {
    super.initState();
    _billing.products().then((p) {
      if (mounted) setState(() => _products = p);
    });
    _sub = _billing.status.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
      if (s.state == 'error') showAppSnack(context, s.message ?? 'Pembelian gagal', error: true);
      if (s.state == 'success') showAppSnack(context, 'Selamat datang di Street Pass ⚡');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _buy() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      context.push(AppRouter.login);
      return;
    }
    final product = _products[_plan];
    if (product == null) {
      showAppSnack(context, 'Toko aplikasi belum tersedia di perangkat ini', error: true);
      return;
    }
    _billing.buy(product);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : null;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.85),
            radius: 1.1,
            colors: [Color(0xFF2F4A10), AppColors.bg],
            stops: [0, 0.8],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<Membership>(
            stream: uid == null
                ? Stream.value(Membership.none)
                : sl<CommerceRepository>().watchMembership(uid),
            builder: (context, m) {
              final member = m.data?.active ?? false;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  Row(children: [
                    OverlayIconButton(
                      icon: Icons.close_rounded,
                      background: AppColors.surface,
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _billing.restore,
                      child: Text('Pulihkan pembelian',
                          style: AppTextStyles.meta.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _PassCard(uid: uid, name: auth is AuthAuthenticated ? auth.user.displayName : 'Kamu'),
                  const SizedBox(height: 24),
                  Text('Ngopi lebih hemat, flexing lebih keren.',
                      style: AppTextStyles.display.copyWith(fontSize: 26)),
                  const SizedBox(height: 8),
                  Text('Cukup 2× pakai promo partner, langganan setahun sudah balik modal.',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 22),
                  for (final (icon, t, s) in _benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, size: 19, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                              Text(s, style: AppTextStyles.meta.copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  if (member)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        'Street Pass aktif sampai ${m.data!.activeUntil!.day}/${m.data!.activeUntil!.month}/${m.data!.activeUntil!.year}. Kelola langganan di Google Play / App Store.',
                        style: AppTextStyles.body.copyWith(color: AppColors.primary),
                      ),
                    )
                  else ...[
                    Row(children: [
                      _plan0(StreetPassBilling.monthlyId, 'Bulanan', 'Rp19rb', 'per bulan', null),
                      const SizedBox(width: 10),
                      _plan0(StreetPassBilling.yearlyId, 'Tahunan', 'Rp149rb', '≈ Rp12,4rb/bulan', 'HEMAT 35%'),
                    ]),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Coba gratis 7 hari',
                      icon: Icons.bolt_rounded,
                      loading: _status.state == 'pending',
                      onPressed: _buy,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Lalu ${_products[_plan]?.price ?? (_plan == StreetPassBilling.yearlyId ? 'Rp149.000/tahun' : 'Rp19.000/bulan')}. '
                      'Batalkan kapan saja lewat Google Play / App Store.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.favorite_border_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('Drop, Cheers & komentar tetap gratis selamanya',
                            style: AppTextStyles.meta),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _plan0(String id, String name, String fallbackPrice, String per, String? note) {
    final sel = _plan == id;
    final price = _products[id]?.price ?? fallbackPrice;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _plan = id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sel ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? AppColors.primary : AppColors.divider, width: sel ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(name,
                      style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel ? AppColors.primary : AppColors.textSecondary)),
                ),
                Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 20, color: sel ? AppColors.primary : AppColors.textMuted),
              ]),
              const SizedBox(height: 6),
              Text(price, style: AppTextStyles.title.copyWith(fontSize: 20)),
              Text(per, style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted)),
              if (note != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(note,
                      style: AppTextStyles.badge.copyWith(
                          fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.onPrimary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  final String? uid;
  final String name;
  const _PassCard({required this.uid, required this.name});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        height: 196,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.passGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x409FE444), blurRadius: 40, offset: Offset(0, 18)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.coffee_rounded, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text('STREET PASS',
                  style: AppTextStyles.cardTitle.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.onPrimary)),
              const Spacer(),
              const Icon(Icons.contactless_rounded, color: AppColors.onPrimary),
            ]),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MonoText('MEMBER', size: 9, weight: FontWeight.w700, color: Color(0x990E0E0E)),
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.section.copyWith(
                            fontWeight: FontWeight.w800, color: AppColors.onPrimary)),
                  ],
                ),
              ),
              if (uid != null)
                StreamBuilder<UserProfile?>(
                  stream: sl<SocialRepository>().watchProfile(uid!),
                  builder: (context, p) => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${p.data?.stampsCount ?? 0}',
                          style: AppTextStyles.display.copyWith(
                              fontSize: 30, height: 1, color: AppColors.onPrimary)),
                      Text('kedai dikunjungi',
                          style: AppTextStyles.meta.copyWith(
                              fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xB30E0E0E))),
                    ],
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
