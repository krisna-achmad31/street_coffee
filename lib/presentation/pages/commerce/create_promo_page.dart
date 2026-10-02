import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/entities/commerce.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../injection_container.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';

/// Owner creates a partner promo. The copy states plainly that the discount
/// is funded by the shop and earns revenue-share points (PRD lubang #2).
class CreatePromoPage extends StatefulWidget {
  final CoffeeShop shop;
  const CreatePromoPage({super.key, required this.shop});

  @override
  State<CreatePromoPage> createState() => _CreatePromoPageState();
}

class _CreatePromoPageState extends State<CreatePromoPage> {
  PromoType _type = PromoType.bundling;
  MenuFavorite? _menu;
  int _qty = 2;
  final _price = TextEditingController();
  final _quota = TextEditingController(text: '50');
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(const Duration(days: 7)),
  );
  bool _memberOnly = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.shop.menuFavorites.isNotEmpty) {
      _menu = widget.shop.menuFavorites.first;
    }
  }

  int get _normal => (_menu?.price ?? 0) * (_type == PromoType.bundling ? _qty : 1);
  int get _promo => int.tryParse(_price.text.replaceAll('.', '')) ?? 0;
  int get _saving0 => _normal <= 0 ? 0 : (((_normal - _promo) / _normal) * 100).round();

  String get _menuLabel => _type == PromoType.bundling
      ? '$_qty× ${_menu?.name ?? ''}'
      : _menu?.name ?? '';

  bool get _valid =>
      _menu != null &&
      (int.tryParse(_quota.text) ?? 0) > 0 &&
      (_type == PromoType.freeItem || (_promo > 0 && _promo < _normal));

  Future<void> _submit() async {
    setState(() => _saving = true);
    final r = await sl<CommerceRepository>().createPromo(PromoInput(
      shopId: widget.shop.id,
      shopName: widget.shop.name,
      shopImageUrl: widget.shop.imageUrl,
      type: _type,
      menuName: _menuLabel,
      normalPrice: _normal,
      promoPrice: _type == PromoType.freeItem ? 0 : _promo,
      dailyQuota: int.tryParse(_quota.text) ?? 0,
      startAt: DateTime(_range.start.year, _range.start.month, _range.start.day),
      endAt: DateTime(_range.end.year, _range.end.month, _range.end.day, 23, 59),
      memberOnly: _memberOnly,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    r.fold((f) => showAppSnack(context, f.message, error: true), (_) {
      showAppSnack(context, 'Promo terbit! Member di sekitar akan melihatnya.');
      context.pop();
    });
  }

  @override
  void dispose() {
    _price.dispose();
    _quota.dispose();
    super.dispose();
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 18),
        child: Text(t,
            style: AppTextStyles.meta.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final menus = widget.shop.menuFavorites;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const ScreenHeader(title: 'Buat Promo', back: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _label('Jenis promo'),
                Segmented<PromoType>(
                  items: const [
                    (PromoType.bundling, 'Bundling', null),
                    (PromoType.discount, 'Potongan', null),
                    (PromoType.freeItem, 'Gratis item', null),
                  ],
                  value: _type,
                  onChanged: (t) => setState(() => _type = t),
                ),
                _label('Menu'),
                if (menus.isEmpty)
                  Text('Tambahkan menu favorit di data kedai dulu.',
                      style: AppTextStyles.meta)
                else
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in menus)
                      AppFilterChip(
                        label: '${m.name}${m.price == null ? '' : ' · ${Fmt.rupiahShort(m.price!)}'}',
                        active: _menu == m,
                        showChevron: false,
                        onTap: () => setState(() => _menu = m),
                      ),
                  ]),
                if (_type == PromoType.bundling) ...[
                  _label('Jumlah dalam bundling'),
                  Row(children: [
                    for (final q in [2, 3, 4])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AppFilterChip(
                          label: '$q×',
                          active: _qty == q,
                          showChevron: false,
                          onTap: () => setState(() => _qty = q),
                        ),
                      ),
                    const Spacer(),
                    MonoText('NORMAL ${Fmt.rupiah(_normal).toUpperCase()}',
                        size: 10, color: AppColors.textMuted),
                  ]),
                ],
                if (_type != PromoType.freeItem) ...[
                  _label('Harga promo'),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {}),
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
                        decoration: const InputDecoration(prefixText: 'Rp ', hintText: '30000'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_promo > 0 && _normal > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _promo < _normal ? AppColors.primarySoft : AppColors.closedSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: MonoText(
                          _promo < _normal ? 'HEMAT $_saving0%' : 'HARUS < NORMAL',
                          size: 11,
                          weight: FontWeight.w700,
                          color: _promo < _normal ? AppColors.primary : AppColors.closed,
                        ),
                      ),
                  ]),
                ],
                _label('Kuota & periode'),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _quota,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                          labelText: 'Kuota / hari', prefixIcon: Icon(Icons.people_outline_rounded)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final r = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                          initialDateRange: _range,
                        );
                        if (r != null) setState(() => _range = r);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Periode', prefixIcon: Icon(Icons.calendar_today_rounded)),
                        child: Text(
                            '${_range.start.day}/${_range.start.month} – ${_range.end.day}/${_range.end.month}',
                            style: AppTextStyles.body),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('Khusus member',
                                style: AppTextStyles.body
                                    .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            const PassTag(),
                          ]),
                          Text('Dapat poin bagi hasil dan badge Partner di peta',
                              style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Switch(value: _memberOnly, onChanged: (v) => setState(() => _memberOnly = v)),
                  ]),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x559FE444)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.handshake_outlined, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text('Cara kerja pendanaan', style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                      ]),
                      const SizedBox(height: 12),
                      for (final (n, t) in const [
                        ('1', 'Diskon ditanggung kedaimu sebagai biaya marketing.'),
                        ('2', 'Setiap redeem terverifikasi = 1 poin bagi hasil.'),
                        ('3', 'Akhir bulan, 20% pendapatan Street Pass dibagi ke kedai partner sesuai poin.'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: MonoText(n, size: 11, weight: FontWeight.w700, color: AppColors.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(t,
                                    style: AppTextStyles.meta.copyWith(height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: PrimaryButton(
              label: 'Terbitkan promo',
              icon: Icons.campaign_rounded,
              loading: _saving,
              onPressed: _valid ? _submit : null,
            ),
          ),
        ]),
      ),
    );
  }
}
