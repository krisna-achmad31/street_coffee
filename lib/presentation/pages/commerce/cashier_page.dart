import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/firebase_paths.dart';
import '../../../core/utils/redeem_code.dart';
import '../../../domain/entities/commerce.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../injection_container.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/common.dart';

/// Cashier mode for shop staff (PRD lubang #1). Staff types the 6-char code
/// shown on the member's phone; the redeemPromo function decides.
class CashierPage extends StatefulWidget {
  final String shopId;
  const CashierPage({super.key, required this.shopId});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  final _repo = sl<CommerceRepository>();
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  RedeemResult? _result;
  String? _error;
  bool _checking = false;
  late final _shop$ = FirebaseFirestore.instance
      .collection(FirebasePaths.shops)
      .doc(widget.shopId)
      .snapshots();

  static const _reasons = {
    'expired': ('Kode kedaluwarsa', 'Minta member buka ulang layar promo', Icons.timer_off_outlined),
    'used_today': ('Sudah dipakai hari ini', 'Promo ini 1× per hari per member', Icons.content_copy_rounded),
    'quota_empty': ('Kuota habis', 'Ubah kuota di dashboard Kedai Pro', Icons.block_rounded),
    'not_member': ('Bukan member Street Pass', 'Promo ini khusus member', Icons.bolt_rounded),
    'not_found': ('Kode tidak dikenal', 'Cek lagi 6 karakter di layar member', Icons.help_outline_rounded),
  };

  Future<void> _check() async {
    final code = RedeemCode.normalize(_ctrl.text);
    if (code.length != RedeemCode.length) return;
    setState(() {
      _checking = true;
      _error = null;
      _result = null;
    });
    final r = await _repo.redeem(shopId: widget.shopId, code: code);
    if (!mounted) return;
    setState(() => _checking = false);
    r.fold((f) => setState(() => _error = f.message), (res) {
      HapticFeedback.mediumImpact();
      setState(() => _result = res);
    });
  }

  void _next() {
    _ctrl.clear();
    setState(() => _result = null);
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _shop$,
              builder: (context, s) => Row(children: [
                OverlayIconButton(
                  icon: Icons.arrow_back_rounded,
                  background: AppColors.surface,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                NetImage(_str(s.data?.data()?['imageUrl']),
                    width: 44, height: 44, radius: BorderRadius.circular(12)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MonoText('MODE KASIR',
                          size: 10, weight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1),
                      Text(_str(s.data?.data()?['name'], '…'),
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Text('Masukkan kode dari aplikasi member',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              maxLength: RedeemCode.length,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9A-Za-z]')),
                TextInputFormatter.withFunction(
                    (_, v) => v.copyWith(text: v.text.toUpperCase())),
              ],
              onChanged: (v) {
                if (v.length == RedeemCode.length) _check();
              },
              style: AppTextStyles.mono.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 14,
                  color: AppColors.textPrimary),
              decoration: InputDecoration(
                counterText: '',
                hintText: '······',
                fillColor: AppColors.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: _checking ? 'Memeriksa…' : 'Periksa kode',
              icon: Icons.verified_outlined,
              height: 48,
              onPressed: _checking ? null : _check,
            ),
            const SizedBox(height: 20),
            if (_error != null) _errorCard(Icons.wifi_off_rounded, 'Tidak bisa memeriksa', _error!),
            if (_result != null)
              _result!.valid ? _validCard(_result!) : _invalidCard(_result!.reason),
          ],
        ),
      ),
    );
  }

  Widget _validCard(RedeemResult r) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.onPrimary, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kode valid',
                        style: AppTextStyles.title
                            .copyWith(fontSize: 22, color: AppColors.onPrimary)),
                    MonoText('REDEEM #${r.redeemNumberToday ?? '-'} HARI INI',
                        size: 10, weight: FontWeight.w700, color: const Color(0xB30E0E0E)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x1F0E0E0E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                _line('PROMO', (r.promoTitle ?? '').toUpperCase()),
                _line('MEMBER', (r.memberName ?? '').toUpperCase()),
                _line('KUOTA TERSISA', '${r.quotaLeft ?? '-'} / ${r.dailyQuota ?? '-'}'),
              ]),
            ),
            const SizedBox(height: 14),
            Text('Potong harga sesuai promo saat pembayaran.',
                style: AppTextStyles.body.copyWith(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onPrimary)),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Selesai, kode berikutnya',
              background: AppColors.onPrimary,
              foreground: AppColors.primary,
              height: 48,
              onPressed: _next,
            ),
          ],
        ),
      );

  Widget _line(String l, String r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          MonoText(l, size: 11, color: const Color(0xB30E0E0E)),
          const Spacer(),
          Flexible(
            child: MonoText(r, size: 11, weight: FontWeight.w700, color: AppColors.onPrimary),
          ),
        ]),
      );

  Widget _invalidCard(String reason) {
    final (t, s, icon) = _reasons[reason] ?? _reasons['not_found']!;
    return Column(children: [
      _errorCard(icon, t, s),
      const SizedBox(height: 12),
      SecondaryButton(label: 'Coba kode lain', height: 44, onPressed: _next),
    ]);
  }

  Widget _errorCard(IconData icon, String t, String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.closedSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.closed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t,
                    style: AppTextStyles.body.copyWith(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.closed)),
                Text(s, style: AppTextStyles.meta.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ]),
      );
}

/// Raw doc fields may be any type (console edits); never let that crash.
String _str(Object? v, [String fallback = '']) =>
    v is String && v.trim().isNotEmpty ? v.trim() : fallback;
