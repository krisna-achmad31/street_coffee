import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/firebase_paths.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/attribution_code.dart';
import '../../../core/utils/failures.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/coffee_shop_model.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/entities/commerce.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../injection_container.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';

/// Kedai Pro dashboard — leads with proof of value (PRD lubang #3):
/// customers from Street Coffee = verified redeems + WA leads marked "jadi beli".
class KedaiProDashboardPage extends StatefulWidget {
  final String shopId;
  const KedaiProDashboardPage({super.key, required this.shopId});

  @override
  State<KedaiProDashboardPage> createState() => _KedaiProDashboardPageState();
}

class _KedaiProDashboardPageState extends State<KedaiProDashboardPage> {
  final _repo = sl<CommerceRepository>();
  final _leadCtrl = TextEditingController();
  int _days = 30;
  late Future<Either<Failure, ShopInsights>> _data = _load();
  late final _shop$ = FirebaseFirestore.instance
      .collection(FirebasePaths.shops)
      .doc(widget.shopId)
      .snapshots()
      .map(CoffeeShopModel.fromFirestore);

  Future<Either<Failure, ShopInsights>> _load() => _repo.insights(widget.shopId, _days);

  void _setDays(int d) => setState(() {
        _days = d;
        _data = _load();
      });

  Future<void> _markLead() async {
    final code = AttributionCode.parse(_leadCtrl.text);
    if (code == null) {
      showAppSnack(context, 'Format kode: SC-XXXX', error: true);
      return;
    }
    final r = await _repo.markLeadConverted(shopId: widget.shopId, code: code);
    if (!mounted) return;
    r.fold((f) => showAppSnack(context, f.message, error: true), (found) {
      showAppSnack(
          context, found ? '$code ditandai jadi beli ✓' : '$code tidak ditemukan',
          error: !found);
      if (found) {
        _leadCtrl.clear();
        setState(() => _data = _load());
      }
    });
  }

  @override
  void dispose() {
    _leadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<CoffeeShop>(
          stream: _shop$,
          builder: (context, shopSnap) {
            final shop = shopSnap.data;
            return Column(children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () {
                    final next = _load();
                    setState(() => _data = next);
                    return next;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      _header(shop),
                      const SizedBox(height: 20),
                      Segmented<int>(
                        items: const [(7, '7 hari', null), (30, '30 hari', null), (90, '90 hari', null)],
                        value: _days,
                        onChanged: _setDays,
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<Either<Failure, ShopInsights>>(
                        future: _data,
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Column(children: [
                              Skeleton(height: 180, radius: 16),
                              SizedBox(height: 12),
                              Skeleton(height: 200, radius: 16),
                            ]);
                          }
                          return snap.data!.fold(
                            (f) => StateView(
                              icon: Icons.insights_rounded,
                              title: 'Dashboard belum bisa dimuat',
                              message: f.message,
                              danger: true,
                              actionLabel: 'Coba lagi',
                              actionIcon: Icons.refresh_rounded,
                              onAction: () => setState(() => _data = _load()),
                            ),
                            (i) => _body(i, shop),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Row(children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Mode kasir',
                      icon: Icons.point_of_sale_rounded,
                      onPressed: () => context.push('${AppRouter.cashier}/${widget.shopId}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Buat promo',
                      icon: Icons.campaign_rounded,
                      onPressed: shop == null
                          ? null
                          : () => context.push(AppRouter.createPromo, extra: shop),
                    ),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _header(CoffeeShop? shop) => Row(children: [
        OverlayIconButton(
          icon: Icons.arrow_back_rounded,
          background: AppColors.surface,
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: 12),
        NetImage(shop?.imageUrl ?? '', width: 48, height: 48, radius: BorderRadius.circular(14)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(shop?.name ?? '…',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
                ),
                if (shop?.isPro ?? false) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, size: 15, color: AppColors.primary),
                ],
              ]),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (shop?.isPro ?? false) ? AppColors.primary : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text((shop?.proTier ?? 'basic').toUpperCase(),
                      style: AppTextStyles.badge.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: (shop?.isPro ?? false) ? AppColors.onPrimary : AppColors.textSecondary)),
                ),
                if (!(shop?.isPro ?? false)) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => context.push(AppRouter.kedaiPro),
                    child: Text('Upgrade', style: AppTextStyles.badge),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ]);

  Widget _body(ShopInsights i, CoffeeShop? shop) {
    final pro = shop?.isPro ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _proofCard(i),
        const SizedBox(height: 12),
        Row(children: [
          _kpi(Icons.visibility_outlined, 'Dilihat', Fmt.compact(i.views)),
          const SizedBox(width: 10),
          _kpi(Icons.chat_bubble_outline_rounded, 'Lead WA berkode', Fmt.compact(i.waLeads)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _kpi(Icons.photo_camera_outlined, 'Drop & check-in', Fmt.compact(i.drops)),
          const SizedBox(width: 10),
          _kpi(Icons.person_add_alt_rounded, 'Pengikut baru', Fmt.compact(i.newFollowers)),
        ]),
        const SizedBox(height: 12),
        _revenueShare(i),
        const SizedBox(height: 12),
        if (pro) ...[
          _hourly(i),
          const SizedBox(height: 12),
          _topMenu(i),
        ] else
          _lockedCard(),
      ],
    );
  }

  Widget _proofCard(ShopInsights i) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x559FE444)),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF2A3D12), Color(0xFF161A12)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoText('PELANGGAN DARI STREET COFFEE · $_days HARI',
                size: 10, weight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.6),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${i.customersFromApp}',
                  style: AppTextStyles.display.copyWith(fontSize: 40, height: 1)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('≈ ${Fmt.rupiahShort(i.estimatedRevenue)} omzet',
                    style: AppTextStyles.meta.copyWith(fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _mini('${i.redemptions}', 'REDEEM PROMO'),
              const SizedBox(width: 8),
              _mini('${i.convertedLeads}', 'LEAD WA DITANDAI'),
            ]),
            const SizedBox(height: 12),
            Container(
              height: 44,
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _leadCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: AppTextStyles.mono.copyWith(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Tempel kode lead, mis. SC-7F3K',
                    ),
                    onSubmitted: (_) => _markLead(),
                  ),
                ),
                FilledButton(
                  onPressed: _markLead,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Jadi beli'),
                ),
              ]),
            ),
            const SizedBox(height: 6),
            Text('Kode ada di baris terakhir chat WhatsApp dari pembeli.',
                style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      );

  Widget _mini(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v, style: AppTextStyles.cardTitle),
              MonoText(l, size: 9, color: AppColors.textMuted),
            ],
          ),
        ),
      );

  Widget _kpi(IconData icon, String label, String v) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              Text(v, style: AppTextStyles.title.copyWith(fontSize: 24)),
              Text(label, style: AppTextStyles.meta.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      );

  Widget _revenueShare(ShopInsights i) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.handshake_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bagi hasil Street Pass',
                    style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
                MonoText('${i.revenueSharePoints} POIN BULAN INI · CAIR TGL 1',
                    size: 10, color: AppColors.textMuted),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(i.lastPayoutRupiah == null ? '-' : Fmt.rupiahShort(i.lastPayoutRupiah!),
                style: AppTextStyles.cardTitle.copyWith(fontSize: 17, color: AppColors.primary)),
            Text('bulan lalu', style: AppTextStyles.meta.copyWith(fontSize: 10)),
          ]),
        ]),
      );

  Widget _hourly(ShopInsights i) {
    const hours = [8, 10, 12, 14, 16, 18, 20, 22];
    final buckets = [for (final h in hours) i.hourly[h] + i.hourly[(h + 1) % 24]];
    final peak = buckets.fold<int>(0, (a, b) => a > b ? a : b);
    final peakIdx = peak == 0 ? -1 : buckets.indexOf(peak);
    final quietIdx = peak == 0
        ? -1
        : buckets.indexOf(buckets.reduce((a, b) => a < b ? a : b));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Jam ramai', style: AppTextStyles.cardTitle)),
            Text('dari check-in & redeem', style: AppTextStyles.meta.copyWith(fontSize: 11)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var k = 0; k < hours.length; k++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: '${hours[k]}.00–${hours[k] + 2}.00: ${buckets[k]}',
                            child: Container(
                              height: peak == 0 ? 4 : 4 + 80 * buckets[k] / peak,
                              decoration: BoxDecoration(
                                color: k == peakIdx ? AppColors.primary : const Color(0x559FE444),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('${hours[k]}',
                              style: AppTextStyles.meta.copyWith(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (peakIdx >= 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Puncak jam ${hours[peakIdx]}–${hours[peakIdx] + 2}. '
                    'Coba promo di jam ${hours[quietIdx]}–${hours[quietIdx] + 2} buat ngisi jam sepi.',
                    style: AppTextStyles.meta.copyWith(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _topMenu(ShopInsights i) {
    final top = i.topMenu.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final list = top.take(3).toList();
    final max = list.isEmpty ? 1 : list.first.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paling sering di-Drop', style: AppTextStyles.cardTitle),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Text('Belum ada Drop yang menyebut menu.', style: AppTextStyles.meta)
          else
            for (var k = 0; k < list.length; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(
                    width: 18,
                    child: Text('${k + 1}',
                        style: AppTextStyles.cardTitle.copyWith(color: AppColors.textMuted)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(list[k].key, style: AppTextStyles.body.copyWith(fontSize: 13)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: list[k].value / max,
                            minHeight: 5,
                            backgroundColor: AppColors.surfaceAlt,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${list[k].value} drop',
                      style: AppTextStyles.meta.copyWith(fontWeight: FontWeight.w600)),
                ]),
              ),
        ],
      ),
    );
  }

  Widget _lockedCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Jam ramai & menu terpopuler tersedia di Kedai Pro.',
                style: AppTextStyles.meta.copyWith(fontSize: 13)),
          ),
          TextButton(
            onPressed: () => context.push(AppRouter.kedaiPro),
            child: const Text('Lihat paket'),
          ),
        ]),
      );
}
