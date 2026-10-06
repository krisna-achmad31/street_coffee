import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/whatsapp_launcher.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/repositories/admin_shop_repository.dart';
import '../../blocs/admin/admin_bloc.dart';
import '../../blocs/location/location_bloc.dart';
import '../../widgets/cards/shop_cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';
import '../../widgets/ui/osm_map.dart';

/// Screen 11 — Tambah / Edit Kedai (admin). Eight numbered sections with a
/// progress counter; the CTA stays pinned at the bottom.
class AddEditShopPage extends StatefulWidget {
  final CoffeeShop? existingShop; // null = create mode
  const AddEditShopPage({super.key, this.existingShop});

  @override
  State<AddEditShopPage> createState() => _AddEditShopPageState();
}

class _AddEditShopPageState extends State<AddEditShopPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  final _igCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _mapsCtrl = TextEditingController();

  File? _coverFile;
  String _existingCoverUrl = '';
  LatLng? _pin;
  TimeOfDay _openFrom = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _openUntil = const TimeOfDay(hour: 22, minute: 0);
  bool _isOpen = true;
  bool _isFeatured = false;
  String? _mainVibe;
  final Set<String> _vibes = {};
  final Set<String> _facilities = {};
  final Set<String> _categories = {};
  final List<_MenuItemState> _menu = [];

  bool get _isEdit => widget.existingShop != null;

  /// Hours have defaults, so they only count once confirmed (or when editing).
  late bool _hoursSet = _isEdit;

  static const _vibeOptions = [
    'Nongkrong Skena', 'Deep Talk', 'Manual Brew', 'Kopi Hemat', 'Santai', 'Cozy', 'Kerja',
  ];
  static const _facilityOptions = [
    'WiFi', 'Outdoor', 'Musik', 'Parkir', 'AC', 'Colokan', 'Toilet', 'No Smoking',
  ];
  static const _categoryOptions = [
    'Murah', 'Manual Brew', 'Street Coffee', 'Specialty', 'Nongkrong', 'Deep Talk', 'Kopi Hemat', 'Cozy',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.existingShop;
    if (s != null) {
      _nameCtrl.text = s.name;
      _descCtrl.text = s.description;
      _addressCtrl.text = s.address;
      // Stored as 62…; the field shows the local part after the +62 prefix.
      _waCtrl.text = s.whatsappNumber.startsWith('62')
          ? s.whatsappNumber.substring(2)
          : s.whatsappNumber;
      _minPriceCtrl.text = s.minPrice > 0 ? '${s.minPrice}' : '';
      _maxPriceCtrl.text = s.maxPrice > 0 ? '${s.maxPrice}' : '';
      // v1 never loaded these, so every edit silently erased the links.
      _igCtrl.text = s.instagramUrl ?? '';
      _tiktokCtrl.text = s.tiktokUrl ?? '';
      _mapsCtrl.text = s.googleMapsUrl ?? '';
      _pin = s.hasLocation ? LatLng(s.latitude, s.longitude) : null;
      _openFrom = _parseTime(s.openFrom) ?? _openFrom;
      _openUntil = _parseTime(s.openUntil) ?? _openUntil;
      _isOpen = s.openFlag ?? s.isOpen;
      _isFeatured = s.isFeatured;
      _mainVibe = s.vibe.isEmpty ? null : s.vibe;
      _vibes.addAll(s.vibes);
      _facilities.addAll(s.facilities);
      _categories.addAll(s.categories);
      _existingCoverUrl = s.imageUrl;
      for (final m in s.menuFavorites) {
        _menu.add(_MenuItemState(name: m.name, price: m.price, existingUrl: m.imageUrl));
      }
    }
    for (final c in [_nameCtrl, _addressCtrl, _waCtrl, _minPriceCtrl, _igCtrl]) {
      c.addListener(_refreshProgress);
    }
  }

  void _refreshProgress() => setState(() {});

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _descCtrl, _addressCtrl, _waCtrl, _minPriceCtrl,
      _maxPriceCtrl, _igCtrl, _tiktokCtrl, _mapsCtrl,
    ]) {
      c.dispose();
    }
    for (final m in _menu) {
      m.dispose();
    }
    super.dispose();
  }

  static TimeOfDay? _parseTime(String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// "15.000", "15k", "Rp 15,000" → 15000.
  static int _price(String raw) {
    final t = raw.trim().toLowerCase();
    final digits = int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return t.endsWith('k') && digits < 1000 ? digits * 1000 : digits;
  }

  bool get _hasCover => _coverFile != null || _existingCoverUrl.isNotEmpty;

  // ── Progress (spec: "Progress 5/8") ────────────────────────────────────────
  List<bool> get _sectionsDone => [
        _hasCover,
        _nameCtrl.text.trim().isNotEmpty && _addressCtrl.text.trim().isNotEmpty,
        _pin != null,
        WhatsAppLauncher.normalizePhone(_waCtrl.text).isNotEmpty &&
            _price(_minPriceCtrl.text) > 0,
        _hoursSet,
        _mainVibe != null,
        _menu.any((m) => m.nameCtrl.text.trim().isNotEmpty),
        _igCtrl.text.trim().isNotEmpty ||
            _tiktokCtrl.text.trim().isNotEmpty ||
            _mapsCtrl.text.trim().isNotEmpty,
      ];

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x != null) setState(() => _coverFile = File(x.path));
  }

  Future<void> _pickMenuImage(_MenuItemState item) async {
    final x = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (x != null) setState(() => item.imageFile = File(x.path));
  }

  Future<void> _pickTime(bool from) async {
    final t = await showTimePicker(
      context: context,
      initialTime: from ? _openFrom : _openUntil,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() {
        from ? _openFrom = t : _openUntil = t;
        _hoursSet = true;
      });
    }
  }

  void _submit() {
    final problems = <String>[
      if (!_hasCover) 'foto cover',
      if (_pin == null) 'pin lokasi di peta',
      if (_mainVibe == null) 'vibe utama',
    ];
    final formOk = _formKey.currentState!.validate();
    if (problems.isNotEmpty) {
      showAppSnack(context, 'Lengkapi dulu: ${problems.join(', ')}', error: true);
      return;
    }
    if (!formOk) return;

    var min = _price(_minPriceCtrl.text);
    var max = _price(_maxPriceCtrl.text);
    if (max == 0) max = min;
    if (max < min) (min, max) = (max, min);

    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    String k(int v) => '${(v / 1000).round()}k';

    final data = ShopFormData(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: _pin!.latitude,
      longitude: _pin!.longitude,
      priceRange: min == max ? 'Rp ${k(min)}' : 'Rp ${k(min)}–${k(max)}',
      minPrice: min,
      maxPrice: max,
      vibe: _mainVibe!,
      vibes: {_mainVibe!, ..._vibes}.toList(),
      facilities: _facilities.toList(),
      categories: _categories.toList(),
      whatsappNumber: WhatsAppLauncher.normalizePhone(_waCtrl.text),
      openFrom: _fmtTime(_openFrom),
      openUntil: _fmtTime(_openUntil),
      isOpen: _isOpen,
      isFeatured: _isFeatured,
      instagramUrl: opt(_igCtrl),
      tiktokUrl: opt(_tiktokCtrl),
      googleMapsUrl: opt(_mapsCtrl),
      coverImageFile: _coverFile,
      menuItems: [
        for (final m in _menu)
          if (m.nameCtrl.text.trim().isNotEmpty)
            MenuItemForm(
              name: m.nameCtrl.text.trim(),
              price: switch (_price(m.priceCtrl.text)) { 0 => null, final p => p },
              imageFile: m.imageFile,
              existingImageUrl: m.existingUrl.isEmpty ? null : m.existingUrl,
            ),
      ],
    );

    final bloc = context.read<AdminBloc>();
    _isEdit
        ? bloc.add(AdminUpdateShop(shopId: widget.existingShop!.id, data: data))
        : bloc.add(AdminCreateShop(data));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final done = _sectionsDone;
    final doneCount = done.where((d) => d).length;
    return BlocListener<AdminBloc, AdminState>(
      listener: (context, state) {
        if (state is AdminSuccess) {
          showAppSnack(context, state.message);
          context.pop();
        } else if (state is AdminError) {
          showAppSnack(context, state.message, error: true);
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            ScreenHeader(title: _isEdit ? 'Edit Kedai' : 'Tambah Kedai', back: true),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: doneCount / 8,
                      minHeight: 4,
                      backgroundColor: AppColors.surface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                MonoText('$doneCount/8',
                    size: 12, weight: FontWeight.w700, color: AppColors.primary),
              ]),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _Section(1, 'Foto', done[0], child: _coverPicker()),
                    _Section(2, 'Info kedai', done[1], child: _infoFields()),
                    _Section(3, 'Lokasi', done[2], child: _mapPicker()),
                    _Section(4, 'Kontak & harga', done[3], child: _contactFields()),
                    _Section(5, 'Jam & status', done[4], child: _hoursFields()),
                    _Section(6, 'Vibe & fasilitas', done[5], child: _vibeFields()),
                    _Section(7, 'Menu favorit', done[6], child: _menuFields()),
                    _Section(8, 'Sosmed', done[7], last: true, child: _socialFields()),
                  ],
                ),
              ),
            ),
            _bottomCta(),
          ]),
        ),
      ),
    );
  }

  Widget _bottomCta() => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) => SizedBox(
            width: double.infinity,
            child: PrimaryButton(
            label: _isEdit ? 'Simpan perubahan' : 'Simpan kedai',
            icon: Icons.check_rounded,
            loading: state is AdminSubmitting,
            onPressed: state is AdminSubmitting ? null : _submit,
          ),
          ),
        ),
      );

  Widget _coverPicker() {
    final Widget preview = _coverFile != null
        ? Image.file(_coverFile!, fit: BoxFit.cover)
        : _existingCoverUrl.isNotEmpty
            ? NetImage(_existingCoverUrl)
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_outlined,
                    size: 32, color: AppColors.textMuted),
                const SizedBox(height: 8),
                Text('Upload foto cover', style: AppTextStyles.meta),
                Text('Rasio 16:9, maks 1600 px',
                    style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted)),
              ]);
    return GestureDetector(
      onTap: _pickCover,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hasCover ? AppColors.primary : AppColors.divider),
          ),
          child: Stack(fit: StackFit.expand, children: [
            preview,
            if (_hasCover)
              Positioned(
                right: 10,
                bottom: 10,
                child: OverlayIconButton(
                    icon: Icons.edit_rounded, tooltip: 'Ganti foto', onPressed: _pickCover),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _infoFields() => Column(children: [
        _Field(controller: _nameCtrl, label: 'Nama kedai', required: true, maxLength: 60),
        _Field(controller: _descCtrl, label: 'Deskripsi singkat', maxLines: 3, maxLength: 280),
        _Field(controller: _addressCtrl, label: 'Alamat', required: true, maxLines: 2),
      ]);

  Widget _mapPicker() {
    final loc = context.read<LocationBloc>().state;
    final center = _pin ??
        (loc is LocationLoaded
            ? LatLng(loc.location.latitude, loc.location.longitude)
            : const LatLng(-6.2441, 106.7991));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16,
              onTap: (_, p) => setState(() => _pin = p),
            ),
            children: [
              osmTileLayer(),
              if (_pin != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _pin!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.bg, width: 3),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: AppColors.onPrimary, size: 18),
                    ),
                  ),
                ]),
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(padding: EdgeInsets.all(6), child: OsmAttribution()),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Icon(_pin == null ? Icons.touch_app_outlined : Icons.place_rounded,
            size: 14, color: _pin == null ? AppColors.textMuted : AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: _pin == null
              ? Text('Tap peta untuk menaruh pin kedai', style: AppTextStyles.meta)
              : MonoText(
                  '${_pin!.latitude.toStringAsFixed(6)}, ${_pin!.longitude.toStringAsFixed(6)}',
                  size: 11),
        ),
      ]),
    ]);
  }

  Widget _contactFields() => Column(children: [
        _Field(
          controller: _waCtrl,
          label: 'WhatsApp',
          prefix: '+62 ',
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +-]'))],
          validator: (v) {
            if ((v ?? '').trim().isEmpty) return 'Wajib diisi';
            return WhatsAppLauncher.normalizePhone(v!).isEmpty
                ? 'Nomor tidak valid, contoh 812 3456 7890'
                : null;
          },
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _Field(
              controller: _minPriceCtrl,
              label: 'Harga mulai',
              prefix: 'Rp ',
              keyboardType: TextInputType.number,
              validator: (v) => _price(v ?? '') <= 0 ? 'Wajib diisi' : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Field(
              controller: _maxPriceCtrl,
              label: 'Sampai',
              prefix: 'Rp ',
              keyboardType: TextInputType.number,
            ),
          ),
        ]),
      ]);

  Widget _hoursFields() {
    Widget timeBox(String label, TimeOfDay t, bool from) => Expanded(
          child: Material(
            color: AppColors.input,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickTime(from),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: AppTextStyles.meta.copyWith(fontSize: 11)),
                      Text(_fmtTime(t).replaceAll(':', '.'),
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 17)),
                    ]),
                  ),
                  const Icon(Icons.schedule_rounded, size: 18, color: AppColors.textMuted),
                ]),
              ),
            ),
          ),
        );
    return Column(children: [
      Row(children: [
        timeBox('Buka', _openFrom, true),
        const SizedBox(width: 12),
        timeBox('Tutup', _openUntil, false),
      ]),
      const SizedBox(height: 12),
      _SwitchRow(
        title: 'Buka sekarang',
        subtitle: 'Tersinkron real-time ke semua user',
        value: _isOpen,
        onChanged: (v) => setState(() => _isOpen = v),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        title: 'Tampilkan di Featured',
        subtitle: 'Muncul di carousel Home',
        value: _isFeatured,
        onChanged: (v) => setState(() => _isFeatured = v),
      ),
    ]);
  }

  Widget _vibeFields() {
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: OverlineLabel(t),
        );
    Widget chips(List<String> options, Set<String> selected) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              AppFilterChip(
                label: o,
                active: selected.contains(o),
                showChevron: false,
                onTap: () => setState(() =>
                    selected.contains(o) ? selected.remove(o) : selected.add(o)),
              ),
          ],
        );
    // Keep a legacy/unknown vibe selectable instead of crashing a dropdown.
    final vibeOptions = {..._vibeOptions, if (_mainVibe != null) _mainVibe!}.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      label('Vibe utama'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in vibeOptions)
          VibePill(
            emoji: vibeEmoji[v] ?? '☕',
            label: v,
            active: _mainVibe == v,
            onTap: () => setState(() => _mainVibe = v),
          ),
      ]),
      const SizedBox(height: 16),
      label('Vibe tambahan'),
      chips(_vibeOptions.where((v) => v != _mainVibe).toList(), _vibes),
      const SizedBox(height: 16),
      label('Fasilitas'),
      chips(_facilityOptions, _facilities),
      const SizedBox(height: 16),
      label('Kategori'),
      chips(_categoryOptions, _categories),
    ]);
  }

  Widget _menuFields() => Column(children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _menu.length,
          onReorderItem: (from, to) =>
              setState(() => _menu.insert(to, _menu.removeAt(from))),
          itemBuilder: (_, i) => _MenuRow(
            key: ObjectKey(_menu[i]),
            index: i,
            item: _menu[i],
            onPickImage: () => _pickMenuImage(_menu[i]),
            onRemove: () => setState(() => _menu.removeAt(i).dispose()),
            onChanged: _refreshProgress,
          ),
        ),
        if (_menu.length < 8)
          SecondaryButton(
            label: 'Tambah menu',
            icon: Icons.add_rounded,
            height: 44,
            onPressed: () => setState(() => _menu.add(_MenuItemState())),
          ),
      ]);

  Widget _socialFields() => Column(children: [
        _Field(controller: _igCtrl, label: 'Instagram', hint: '@namakedai', prefixIcon: Icons.camera_alt_outlined),
        _Field(controller: _tiktokCtrl, label: 'TikTok', hint: '@namakedai', prefixIcon: Icons.music_note_rounded),
        _Field(controller: _mapsCtrl, label: 'Link Google Maps', hint: 'https://maps.app.goo.gl/…', prefixIcon: Icons.map_outlined),
      ]);
}

// ── Pieces ───────────────────────────────────────────────────────────────────

/// Numbered section: lime number (✓ when complete) + title + body,
/// joined to the next section by a thin rail.
class _Section extends StatelessWidget {
  final int number;
  final String title;
  final bool done;
  final Widget child;
  final bool last;
  const _Section(this.number, this.title, this.done, {required this.child, this.last = false});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? AppColors.primary : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: done ? AppColors.primary : AppColors.divider),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 15, color: AppColors.onPrimary)
                : MonoText('$number', size: 11, weight: FontWeight.w700),
          ),
          if (!last)
            Expanded(child: Container(width: 1, color: AppColors.divider, margin: const EdgeInsets.symmetric(vertical: 4))),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 12),
                child: Text(title, style: AppTextStyles.section.copyWith(fontSize: 17)),
              ),
              child,
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefix;
  final IconData? prefixIcon;
  final bool required;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.prefix,
    this.prefixIcon,
    this.required = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: AppTextStyles.body,
        textCapitalization: maxLines > 1 ? TextCapitalization.sentences : TextCapitalization.none,
        validator: validator ??
            (required ? (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null : null),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          labelStyle: AppTextStyles.meta,
          prefixText: prefix,
          prefixStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18, color: AppColors.textMuted),
          counterStyle: AppTextStyles.meta.copyWith(fontSize: 10, color: AppColors.textMuted),
          errorStyle: AppTextStyles.meta.copyWith(color: AppColors.closed, fontSize: 11),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.closed),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.closed),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
            Text(subtitle, style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final int index;
  final _MenuItemState item;
  final VoidCallback onPickImage;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _MenuRow({
    super.key,
    required this.index,
    required this.item,
    required this.onPickImage,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String hint, {String? prefix}) => InputDecoration(
          hintText: hint,
          prefixText: prefix,
          isDense: true,
          fillColor: AppColors.surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.drag_indicator_rounded, color: AppColors.textMuted, size: 20),
          ),
        ),
        GestureDetector(
          onTap: onPickImage,
          child: SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: item.imageFile != null
                  ? Image.file(item.imageFile!, fit: BoxFit.cover)
                  : NetImage(item.existingUrl, fallbackIcon: Icons.add_a_photo_outlined),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(children: [
            TextField(
              controller: item.nameCtrl,
              style: AppTextStyles.body.copyWith(fontSize: 13),
              decoration: deco('Nama menu'),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: item.priceCtrl,
              keyboardType: TextInputType.number,
              style: AppTextStyles.body.copyWith(fontSize: 13),
              decoration: deco('Harga', prefix: 'Rp '),
            ),
          ]),
        ),
        IconButton(
          tooltip: 'Hapus menu',
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.closed, size: 20),
          onPressed: onRemove,
        ),
      ]),
    );
  }
}

class _MenuItemState {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  File? imageFile;
  final String existingUrl;

  _MenuItemState({String name = '', int? price, this.existingUrl = ''})
      : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(text: price?.toString() ?? '');

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}
