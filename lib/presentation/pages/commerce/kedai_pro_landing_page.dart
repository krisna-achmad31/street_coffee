import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/common.dart';

/// For shop owners: what Kedai Pro gives, tiers, and a claim request.
class KedaiProLandingPage extends StatelessWidget {
  const KedaiProLandingPage({super.key});

  static const _features = [
    (Icons.verified_outlined, 'Badge verified & akun resmi', 'Posting sebagai kedai, balas & sematkan komentar'),
    (Icons.campaign_outlined, 'Promo ke follower & feed', 'Promo muncul di Feed "Sekitar" pengguna terdekat'),
    (Icons.auto_awesome_rounded, 'Slot Featured', 'Tampil di carousel Home & pin khusus di Peta (berlabel Bersponsor)'),
    (Icons.insights_rounded, 'Bukti pelanggan', 'Redeem promo + lead WA berkode, jam ramai, menu favorit'),
    (Icons.handshake_outlined, 'Partner Street Pass', 'Dapat pelanggan member + bagi hasil tiap redeem'),
  ];

  static const _tiers = [
    ('Basic', 'Gratis', null, ['Klaim & edit info kedai', 'Balas review', '1 promo partner aktif'], false, null),
    ('Gerobak', 'Rp29rb', '/bln', ['Badge verified', '2 promo post / bulan', 'Dashboard ringkas'], false, 'UNTUK GEROBAK'),
    ('Pro', 'Rp99rb', '/bln', ['Verified + akun resmi', '4 promo post / bulan', 'Analytics lengkap'], true, 'POPULER'),
    ('Pro+', 'Rp249rb', '/bln', ['Semua fitur Pro', 'Featured 7 hari / bulan', 'Boost post & multi cabang'], false, null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.6, -0.8),
                radius: 1.2,
                colors: [Color(0xFF2A3D12), AppColors.bg],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      OverlayIconButton(
                          icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.overlay,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          const Icon(Icons.storefront_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Untuk pemilik kedai',
                              style: AppTextStyles.meta.copyWith(
                                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 60),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.verified_rounded, size: 13, color: AppColors.onPrimary),
                        const SizedBox(width: 5),
                        Text('KEDAI PRO',
                            style: AppTextStyles.badge.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: AppColors.onPrimary)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text('Bikin kedaimu jadi tongkrongan berikutnya.',
                        style: AppTextStyles.display.copyWith(fontSize: 28)),
                    const SizedBox(height: 12),
                    Text(
                      'Pencari kopi di sekitarmu nge-Drop tiap minggu. Pastikan mereka nemu kedaimu duluan — dan kamu bisa lihat buktinya.',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.list(children: [
            Text('Yang kamu dapat', style: AppTextStyles.section),
            const SizedBox(height: 14),
            for (final (icon, t, s) in _features)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
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
            const SizedBox(height: 12),
            Text('Pilih paket', style: AppTextStyles.section),
            const SizedBox(height: 12),
            for (final (name, price, per, items, hl, tag) in _tiers)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hl ? AppColors.primarySoft : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: hl ? AppColors.primary : AppColors.divider, width: hl ? 2 : 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(name,
                          style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: hl ? AppColors.primary : AppColors.textPrimary)),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(tag,
                              style: AppTextStyles.badge.copyWith(
                                  fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.onPrimary)),
                        ),
                      ],
                      const Spacer(),
                      Text(price, style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
                      if (per != null)
                        Text(per, style: AppTextStyles.meta.copyWith(fontSize: 11)),
                    ]),
                    const SizedBox(height: 10),
                    for (final it in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(it, style: AppTextStyles.meta),
                        ]),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Klaim kedaimu — Pro gratis 3 bulan',
              icon: Icons.storefront_rounded,
              onPressed: () {
                final auth = context.read<AuthBloc>().state;
                if (auth is! AuthAuthenticated) {
                  context.push(AppRouter.login);
                } else {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => _ClaimSheet(uid: auth.user.uid),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            Text(
              'Verifikasi 1–2 hari kerja lewat OTP WhatsApp kedai. Pembayaran paket via transfer / QRIS di web — tanpa potongan toko aplikasi.',
              textAlign: TextAlign.center,
              style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ClaimSheet extends StatefulWidget {
  final String uid;
  const _ClaimSheet({required this.uid});

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  final _name = TextEditingController();
  final _wa = TextEditingController();
  final _address = TextEditingController();
  bool _sending = false;

  bool get _valid =>
      _name.text.trim().length >= 3 &&
      _wa.text.trim().length >= 9 &&
      _address.text.trim().length >= 8;

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('shop_claims').add({
        'uid': widget.uid,
        'shopName': _name.text.trim(),
        'whatsapp': '62${_wa.text.trim().replaceFirst(RegExp(r'^0'), '')}',
        'address': _address.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnack(context, 'Klaim terkirim. Kami hubungi kedaimu via WhatsApp untuk verifikasi.');
    } catch (e) {
      if (mounted) showAppSnack(context, 'Gagal mengirim klaim: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _wa.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Klaim kedai', style: AppTextStyles.section),
          const SizedBox(height: 4),
          Text('Isi data kedai. Kami kirim OTP ke nomor WhatsApp kedai untuk verifikasi.',
              style: AppTextStyles.meta.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            style: AppTextStyles.body,
            decoration: const InputDecoration(labelText: 'Nama kedai'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _wa,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.body,
            decoration: const InputDecoration(labelText: 'WhatsApp kedai', prefixText: '+62 '),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _address,
            onChanged: (_) => setState(() {}),
            style: AppTextStyles.body,
            decoration: const InputDecoration(labelText: 'Alamat'),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Kirim klaim',
            loading: _sending,
            onPressed: _valid ? _submit : null,
          ),
        ],
      ),
    );
  }
}
