import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/repositories/commerce_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../ui/buttons.dart';
import '../ui/common.dart';

/// Confirmation sheet before leaving for WhatsApp (replaces v1's
/// auto-redirect overlay). The attribution code is logged as a lead here.
Future<void> showWaConfirmSheet(
  BuildContext context, {
  required CoffeeShop shop,
  MenuFavorite? menu,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WaConfirmSheet(shop: shop, menu: menu),
  );
}

class _WaConfirmSheet extends StatefulWidget {
  final CoffeeShop shop;
  final MenuFavorite? menu;
  const _WaConfirmSheet({required this.shop, this.menu});

  @override
  State<_WaConfirmSheet> createState() => _WaConfirmSheetState();
}

class _WaConfirmSheetState extends State<_WaConfirmSheet> {
  final _repo = sl<CommerceRepository>();
  final _msg = TextEditingController();
  int _qty = 1;
  String? _code;
  bool _editing = false;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : null;
    _repo.logWaLead(shop: widget.shop, uid: uid).then((r) {
      if (!mounted) return;
      setState(() => _code = r.fold((_) => null, (c) => c));
      _rebuildMessage();
    });
    _rebuildMessage();
  }

  void _rebuildMessage() {
    if (_editing) return;
    _msg.text = WhatsAppLauncher.buildOrderMessage(
      shopName: widget.shop.name,
      menuItem: widget.menu?.name,
      quantity: _qty,
      attributionCode: _code,
    );
  }

  Future<void> _open() async {
    setState(() => _opening = true);
    var text = _msg.text;
    // Keep attribution even if the user rewrote the message.
    if (_code != null && !text.contains(_code!)) text = '$text\n(kode: $_code)';
    final ok = await WhatsAppLauncher.openChat(
        phone: widget.shop.whatsappNumber, message: text);
    if (!mounted) return;
    setState(() => _opening = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      showAppSnack(context, 'WhatsApp tidak tersedia di perangkat ini',
          error: true);
    }
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.whatsapp.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: AppColors.whatsapp, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pesan ke ${widget.shop.name}',
                          style: AppTextStyles.section),
                      Text('Kamu akan diarahkan ke WhatsApp penjual',
                          style: AppTextStyles.meta
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            if (menu != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    NetImage(menu.imageUrl,
                        width: 52, height: 52, radius: BorderRadius.circular(10)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(menu.name,
                              style: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                          if (menu.price != null)
                            Text(Fmt.rupiahShort(menu.price! * _qty),
                                style: AppTextStyles.cardTitle.copyWith(
                                    fontSize: 13, color: AppColors.primary)),
                        ],
                      ),
                    ),
                    _Stepper(
                      value: _qty,
                      onChanged: (v) => setState(() {
                        _qty = v;
                        _rebuildMessage();
                      }),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text('Pesan otomatis',
                      style: AppTextStyles.meta.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _editing = !_editing),
                  child: Row(
                    children: [
                      Icon(_editing ? Icons.check_rounded : Icons.edit_rounded,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(_editing ? 'Selesai' : 'Ubah',
                          style: AppTextStyles.badge.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              decoration: const BoxDecoration(
                color: AppColors.whatsappBubble,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _msg,
                    enabled: _editing,
                    maxLines: null,
                    style: AppTextStyles.body
                        .copyWith(fontSize: 13, color: const Color(0xFFE6F6EC)),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${Fmt.hhmm(DateTime.now())} ✓✓',
                      style: AppTextStyles.meta.copyWith(
                          fontSize: 10, color: const Color(0xFF8FD1A8))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Buka WhatsApp',
              icon: Icons.open_in_new_rounded,
              loading: _opening,
              onPressed: widget.shop.whatsappNumber.isEmpty ? null : _open,
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, VoidCallback? f, bool primary) => Material(
          color: primary ? AppColors.primary : AppColors.surfaceAlt,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: f,
            child: SizedBox(
              width: 28,
              height: 28,
              child: Icon(i,
                  size: 14,
                  color: primary ? AppColors.onPrimary : AppColors.textPrimary),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppColors.bg, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          btn(Icons.remove_rounded, value > 1 ? () => onChanged(value - 1) : null,
              false),
          SizedBox(
            width: 28,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
          ),
          btn(Icons.add_rounded, value < 20 ? () => onChanged(value + 1) : null,
              true),
        ],
      ),
    );
  }
}
