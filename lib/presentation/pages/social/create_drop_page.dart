import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/repositories/social_repository.dart';
import '../../../injection_container.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/explore/explore_bloc.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/chips.dart';
import '../../widgets/ui/common.dart';

/// A stamp only counts when the photo is taken at the shop.
const double kCheckinRadiusMeters = 150;

class CreateDropPage extends StatefulWidget {
  final CoffeeShop? initialShop;
  const CreateDropPage({super.key, this.initialShop});

  @override
  State<CreateDropPage> createState() => _CreateDropPageState();
}

class _CreateDropPageState extends State<CreateDropPage> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();
  final _otherMenu = TextEditingController();
  final List<File> _photos = [];
  int _selectedPhoto = 0;

  Position? _pos;
  String? _gpsError;
  CoffeeShop? _shop;
  double? _distance;

  MenuFavorite? _menu;
  bool _otherSelected = false;
  int _rating = 4;
  bool _delay = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _shop = widget.initialShop;
    _locate();
  }

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _gpsError = 'Izinkan lokasi supaya Drop dapat stempel');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  timeLimit: Duration(seconds: 15)));
      if (!mounted) return;
      setState(() => _pos = pos);
      _resolveShop();
    } catch (e) {
      if (mounted) setState(() => _gpsError = 'GPS tidak tersedia');
    }
  }

  void _resolveShop() {
    final pos = _pos;
    if (pos == null) return;
    double dist(CoffeeShop s) => Geolocator.distanceBetween(
        pos.latitude, pos.longitude, s.latitude, s.longitude);
    if (_shop != null) {
      // No coordinates = can't verify; the server-side GPS check decides.
      setState(() => _distance = _shop!.hasLocation ? dist(_shop!) : null);
      return;
    }
    final st = context.read<ExploreBloc>().state;
    final candidates = st is ExploreLoaded
        ? st.shops.where((s) => s.hasLocation).toList()
        : const <CoffeeShop>[];
    if (candidates.isEmpty) return;
    final nearest = candidates.reduce((a, b) => dist(a) <= dist(b) ? a : b);
    setState(() {
      _shop = nearest;
      _distance = dist(nearest);
    });
  }

  bool get _atShop => _distance != null && _distance! <= kCheckinRadiusMeters;

  Future<void> _addPhotos({bool camera = false}) async {
    final picked = camera
        ? [await _picker.pickImage(source: ImageSource.camera, maxWidth: 1440, imageQuality: 82)]
        : await _picker.pickMultiImage(maxWidth: 1440, imageQuality: 82, limit: 5);
    final files = picked.whereType<XFile>().map((x) => File(x.path)).toList();
    if (files.isEmpty) return;
    setState(() {
      // take() throws on a negative count once 5 photos are already picked.
      _photos.addAll(files.take((5 - _photos.length).clamp(0, 5)));
      if (_photos.isNotEmpty) _selectedPhoto = _photos.length - 1;
    });
  }

  Future<void> _pickShop() async {
    final st = context.read<ExploreBloc>().state;
    if (st is! ExploreLoaded) return;
    final chosen = await showModalBottomSheet<CoffeeShop>(
      context: context,
      useSafeArea: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text('Pilih kedai', style: AppTextStyles.section),
          const SizedBox(height: 12),
          for (final s in st.shops)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MenuTile(
                icon: Icons.storefront_rounded,
                title: s.name,
                subtitle: s.distanceText,
                onTap: () => Navigator.pop(context, s),
              ),
            ),
        ],
      ),
    );
    if (chosen != null) {
      setState(() {
        _shop = chosen;
        _menu = null;
      });
      _resolveShop();
    }
  }

  Future<void> _post() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated || _shop == null || _pos == null) return;
    setState(() => _posting = true);
    final menuName = _otherSelected ? _otherMenu.text.trim() : _menu?.name;
    final result = await sl<SocialRepository>().createDrop(
      auth.user,
      CreateDropInput(
        shopId: _shop!.id,
        shopName: _shop!.name,
        shopVibe: _shop!.vibe,
        photos: _photos,
        caption: _caption.text.trim(),
        menuItem: (menuName?.isEmpty ?? true) ? null : menuName,
        menuPrice: _otherSelected ? null : _menu?.price,
        rating: _rating,
        delayLocation: _delay,
        latitude: _pos!.latitude,
        longitude: _pos!.longitude,
      ),
    );
    if (!mounted) return;
    setState(() => _posting = false);
    result.fold(
      (f) => showAppSnack(context, f.message, error: true),
      (id) => context.pushReplacement('${AppRouter.dropPosted}/$id'),
    );
  }

  @override
  void dispose() {
    _caption.dispose();
    _otherMenu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPost = _photos.isNotEmpty && _shop != null && _atShop && !_posting;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          ScreenHeader(
            title: 'Drop Baru',
            back: true,
            backIcon: Icons.close_rounded,
            trailing: FilledButton(
              onPressed: canPost ? _post : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.surfaceAlt,
                shape: const StadiumBorder(),
              ),
              child: _posting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onPrimary))
                  : Text('Posting',
                      style: AppTextStyles.button.copyWith(fontSize: 14)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                _photoArea(),
                const SizedBox(height: 20),
                TextField(
                  controller: _caption,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 280,
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(
                    hintText: 'Ceritain vibe-nya… #DeepTalk',
                    fillColor: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 12),
                _label(Icons.location_on_outlined, 'Kedai'),
                _shopTile(),
                if (_shop != null) ...[
                  const SizedBox(height: 20),
                  _label(Icons.coffee_outlined, 'Yang kamu pesan'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in _shop!.menuFavorites)
                      AppFilterChip(
                        label: m.name,
                        active: _menu == m && !_otherSelected,
                        showChevron: false,
                        onTap: () => setState(() {
                          _menu = _menu == m ? null : m;
                          _otherSelected = false;
                        }),
                      ),
                    AppFilterChip(
                      label: '+ Lainnya',
                      active: _otherSelected,
                      showChevron: false,
                      onTap: () => setState(() => _otherSelected = !_otherSelected),
                    ),
                  ]),
                  if (_otherSelected) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otherMenu,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(hintText: 'Nama menu'),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                _label(Icons.star_outline_rounded, 'Rating cepat'),
                Row(children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i bintang',
                      onPressed: () => setState(() => _rating = i),
                      icon: Icon(Icons.star_rounded,
                          size: 30,
                          color: i <= _rating ? AppColors.star : AppColors.textMuted),
                    ),
                  const SizedBox(width: 6),
                  Text(const ['', 'Kurang', 'Biasa', 'Oke', 'Enak!', 'Juara!'][_rating],
                      style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.star)),
                ]),
                const SizedBox(height: 20),
                _label(Icons.shield_outlined, 'Privasi'),
                _toggle('Tunda lokasi',
                    'Drop baru muncul ±1 jam setelah kamu posting', _delay,
                    (v) => setState(() => _delay = v)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(text,
              style: AppTextStyles.meta
                  .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _photoArea() {
    if (_photos.isEmpty) {
      return Row(children: [
        Expanded(
          child: _bigPick(Icons.photo_camera_rounded, 'Kamera',
              () => _addPhotos(camera: true)),
        ),
        const SizedBox(width: 12),
        Expanded(child: _bigPick(Icons.photo_library_rounded, 'Galeri', _addPhotos)),
      ]);
    }
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(fit: StackFit.expand, children: [
            Image.file(_photos[_selectedPhoto], fit: BoxFit.cover),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.overlay,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${_selectedPhoto + 1} / ${_photos.length}',
                    style: AppTextStyles.meta.copyWith(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: OverlayIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Hapus foto',
                onPressed: () => setState(() {
                  _photos.removeAt(_selectedPhoto);
                  _selectedPhoto = 0;
                }),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 56,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < _photos.length; i++)
            GestureDetector(
              onTap: () => setState(() => _selectedPhoto = i),
              child: Container(
                width: 56,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: i == _selectedPhoto ? AppColors.primary : Colors.transparent,
                      width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(_photos[i], fit: BoxFit.cover),
              ),
            ),
          if (_photos.length < 5)
            GestureDetector(
              onTap: _addPhotos,
              child: Container(
                width: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.textMuted),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _bigPick(IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _shopTile() {
    if (_shop == null) {
      return MenuTile(
        icon: Icons.storefront_outlined,
        title: _gpsError ?? 'Mendeteksi kedai terdekat…',
        subtitle: 'Ketuk untuk pilih manual',
        onTap: _pickShop,
      );
    }
    final ok = _atShop;
    return InkWell(
      onTap: _pickShop,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ok ? AppColors.primarySoft : AppColors.closedSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ok ? AppColors.primary : AppColors.closed),
        ),
        child: Row(children: [
          NetImage(_shop!.imageUrl,
              width: 40, height: 40, radius: BorderRadius.circular(10)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_shop!.name,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      size: 12, color: ok ? AppColors.primary : AppColors.closed),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _distance == null
                          ? (_gpsError ?? 'Mengecek lokasi…')
                          : ok
                              ? 'Kamu di sini · terdeteksi otomatis'
                              : 'Kamu ${_distance! < 1000 ? '${_distance!.round()} m' : '${(_distance! / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'} dari kedai — datang dulu ya',
                      style: AppTextStyles.meta.copyWith(
                          fontSize: 11,
                          color: ok ? AppColors.primary : AppColors.closed),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          Text('Ganti',
              style: AppTextStyles.meta.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _toggle(String t, String s, bool v, ValueChanged<bool> on) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(s, style: AppTextStyles.meta.copyWith(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Switch(value: v, onChanged: on),
        ]),
      );
}
