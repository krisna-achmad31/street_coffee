import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../../../domain/repositories/admin_shop_repository.dart';
import '../../blocs/admin/admin_bloc.dart';

class AddEditShopPage extends StatefulWidget {
  final CoffeeShop? existingShop; // null = create mode
  const AddEditShopPage({super.key, this.existingShop});

  @override
  State<AddEditShopPage> createState() => _AddEditShopPageState();
}

class _AddEditShopPageState extends State<AddEditShopPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _priceRangeCtrl = TextEditingController();
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  final _openFromCtrl = TextEditingController();
  final _openUntilCtrl = TextEditingController();
  final _igCtrl = TextEditingController();
  final _tiktokCtrl = TextEditingController();
  final _mapsCtrl = TextEditingController();

  // State
  File? _coverFile;
  String? _existingCoverUrl;
  double _lat = -6.2088;
  double _lng = 106.8456;
  bool _isOpen = true;
  bool _isFeatured = false;
  String _selectedVibe = 'Nongkrong Skena';
  final List<String> _selectedVibes = [];
  final List<String> _selectedFacilities = [];
  final List<String> _selectedCategories = [];
  final List<_MenuItemState> _menuItems = [];

  bool get _isEditMode => widget.existingShop != null;

  static const _vibeOptions = [
    'Nongkrong Skena', 'Deep Talk', 'Manual Brew',
    'Kopi Hemat', 'Santai', 'Cozy', 'Kerja',
  ];
  static const _facilityOptions = [
    'WiFi', 'Outdoor', 'Musik', 'Parkir', 'AC', 'Colokan', 'Toilet',
  ];
  static const _categoryOptions = [
    'Murah', 'Manual Brew', 'Street Coffee', 'Specialty',
    'Nongkrong', 'Deep Talk', 'Kopi Hemat', 'Cozy',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) _populateFromExisting();
  }

  void _populateFromExisting() {
    final s = widget.existingShop!;
    _nameCtrl.text = s.name;
    _descCtrl.text = s.description;
    _addressCtrl.text = s.address;
    _waCtrl.text = s.whatsappNumber;
    _priceRangeCtrl.text = s.priceRange;
    _minPriceCtrl.text = s.minPrice.toString();
    _maxPriceCtrl.text = s.maxPrice.toString();
    _openFromCtrl.text = s.openFrom;
    _openUntilCtrl.text = s.openUntil;
    _lat = s.latitude;
    _lng = s.longitude;
    _isOpen = s.isOpen;
    _selectedVibe = s.vibe;
    _selectedVibes.addAll(s.vibes);
    _selectedFacilities.addAll(s.facilities);
    _selectedCategories.addAll(s.categories);
    _existingCoverUrl = s.imageUrl;
    for (final m in s.menuFavorites) {
      _menuItems.add(_MenuItemState(
        nameCtrl: TextEditingController(text: m.name),
        priceCtrl: TextEditingController(text: m.price?.toString() ?? ''),
        existingUrl: m.imageUrl,
      ));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _addressCtrl.dispose();
    _waCtrl.dispose(); _priceRangeCtrl.dispose();
    _minPriceCtrl.dispose(); _maxPriceCtrl.dispose();
    _openFromCtrl.dispose(); _openUntilCtrl.dispose();
    _igCtrl.dispose(); _tiktokCtrl.dispose(); _mapsCtrl.dispose();
    for (final m in _menuItems) { m.nameCtrl.dispose(); m.priceCtrl.dispose(); }
    super.dispose();
  }

  Future<void> _pickCover() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile != null) setState(() => _coverFile = File(xfile.path));
  }

  Future<void> _pickMenuImage(int index) async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xfile != null) {
      setState(() => _menuItems[index].imageFile = File(xfile.path));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_coverFile == null && _existingCoverUrl == null) {
      _showSnack('Upload foto cover dulu');
      return;
    }

    final menuItems = _menuItems
        .map((m) => MenuItemForm(
              name: m.nameCtrl.text.trim(),
              price: int.tryParse(m.priceCtrl.text.trim()),
              imageFile: m.imageFile,
              existingImageUrl: m.existingUrl,
            ))
        .toList();

    final formData = ShopFormData(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: _lat,
      longitude: _lng,
      priceRange: _priceRangeCtrl.text.trim(),
      minPrice: int.tryParse(_minPriceCtrl.text.trim()) ?? 0,
      maxPrice: int.tryParse(_maxPriceCtrl.text.trim()) ?? 0,
      vibe: _selectedVibe,
      vibes: _selectedVibes,
      facilities: _selectedFacilities,
      categories: _selectedCategories,
      whatsappNumber: _waCtrl.text.trim(),
      openFrom: _openFromCtrl.text.trim(),
      openUntil: _openUntilCtrl.text.trim(),
      isOpen: _isOpen,
      isFeatured: _isFeatured,
      instagramUrl: _igCtrl.text.trim().isEmpty ? null : _igCtrl.text.trim(),
      tiktokUrl: _tiktokCtrl.text.trim().isEmpty ? null : _tiktokCtrl.text.trim(),
      googleMapsUrl: _mapsCtrl.text.trim().isEmpty ? null : _mapsCtrl.text.trim(),
      coverImageFile: _coverFile,
      menuItems: menuItems,
    );

    if (_isEditMode) {
      context.read<AdminBloc>().add(AdminUpdateShop(
            shopId: widget.existingShop!.id,
            data: formData,
          ));
    } else {
      context.read<AdminBloc>().add(AdminCreateShop(formData));
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listener: (context, state) {
        if (state is AdminSuccess) {
          _showSnack(state.message);
          context.pop();
        }
        if (state is AdminError) {
          _showSnack('Error: ${state.message}');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(
          backgroundColor: AppColors.bgDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: Text(
            _isEditMode ? 'Edit Kedai' : 'Tambah Kedai Baru',
            style: AppTextStyles.headingMedium,
          ),
          actions: [
            BlocBuilder<AdminBloc, AdminState>(
              builder: (context, state) {
                if (state is AdminSubmitting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                return TextButton(
                  onPressed: _submit,
                  child: Text('SIMPAN',
                      style: AppTextStyles.labelPrimary.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                );
              },
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              // ── Cover Photo ────────────────────────────────────────────────
              _sectionTitle('Foto Cover *'),
              _buildCoverPicker(),
              const SizedBox(height: 24),

              // ── Info Dasar ────────────────────────────────────────────────
              _sectionTitle('Informasi Dasar'),
              _field(
                controller: _nameCtrl,
                label: 'Nama Kedai *',
                validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _descCtrl,
                label: 'Deskripsi',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _addressCtrl,
                label: 'Alamat *',
                validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),

              // ── Lokasi (Map) ──────────────────────────────────────────────
              _sectionTitle('Lokasi di Peta *'),
              Text(
                'Tap pada peta untuk pin lokasi kedai',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 10),
              _buildMapPicker(),
              const SizedBox(height: 8),
              Text(
                'Lat: ${_lat.toStringAsFixed(6)}, Lng: ${_lng.toStringAsFixed(6)}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 24),

              // ── Kontak ────────────────────────────────────────────────────
              _sectionTitle('Kontak & Harga'),
              _field(
                controller: _waCtrl,
                label: 'WhatsApp (628xxx) *',
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    v!.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _minPriceCtrl,
                      label: 'Harga Min (Rp)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _maxPriceCtrl,
                      label: 'Harga Max (Rp)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                controller: _priceRangeCtrl,
                label: 'Label Harga (e.g. Rp 15k-35k)',
              ),
              const SizedBox(height: 24),

              // ── Jam Operasional ───────────────────────────────────────────
              _sectionTitle('Jam Operasional'),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _openFromCtrl,
                      label: 'Buka (HH:MM)',
                      hint: '08:00',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _openUntilCtrl,
                      label: 'Tutup (HH:MM)',
                      hint: '23:00',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildToggleRow(
                label: 'Status Sekarang',
                value: _isOpen,
                onLabel: 'BUKA',
                offLabel: 'TUTUP',
                onChanged: (v) => setState(() => _isOpen = v),
                activeColor: AppColors.open,
              ),
              const SizedBox(height: 8),
              _buildToggleRow(
                label: 'Featured di Home',
                value: _isFeatured,
                onLabel: 'YA',
                offLabel: 'TIDAK',
                onChanged: (v) => setState(() => _isFeatured = v),
                activeColor: AppColors.primary,
              ),
              const SizedBox(height: 24),

              // ── Vibe ──────────────────────────────────────────────────────
              _sectionTitle('Vibe Utama'),
              _buildDropdown(
                value: _selectedVibe,
                items: _vibeOptions,
                onChanged: (v) => setState(() => _selectedVibe = v!),
              ),
              const SizedBox(height: 12),
              _sectionTitle('Multi-Vibe'),
              _buildChipGroup(
                options: _vibeOptions,
                selected: _selectedVibes,
              ),
              const SizedBox(height: 24),

              // ── Fasilitas ─────────────────────────────────────────────────
              _sectionTitle('Fasilitas'),
              _buildChipGroup(
                options: _facilityOptions,
                selected: _selectedFacilities,
              ),
              const SizedBox(height: 24),

              // ── Kategori ──────────────────────────────────────────────────
              _sectionTitle('Kategori / Tag'),
              _buildChipGroup(
                options: _categoryOptions,
                selected: _selectedCategories,
              ),
              const SizedBox(height: 24),

              // ── Menu Items ────────────────────────────────────────────────
              _buildMenuSection(),
              const SizedBox(height: 24),

              // ── Sosmed ────────────────────────────────────────────────────
              _sectionTitle('Media Sosial & Link'),
              _field(
                controller: _igCtrl,
                label: 'Instagram URL',
                hint: 'https://instagram.com/...',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _tiktokCtrl,
                label: 'TikTok URL',
                hint: 'https://tiktok.com/@...',
              ),
              const SizedBox(height: 12),
              _field(
                controller: _mapsCtrl,
                label: 'Google Maps URL',
                hint: 'https://maps.app.goo.gl/...',
              ),
              const SizedBox(height: 32),

              // Submit button
              BlocBuilder<AdminBloc, AdminState>(
                builder: (context, state) => GestureDetector(
                  onTap: state is AdminSubmitting ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: state is AdminSubmitting
                          ? AppColors.bgCard
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: state is AdminSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Text(
                              _isEditMode ? 'UPDATE KEDAI' : 'TAMBAH KEDAI',
                              style: AppTextStyles.button,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: AppTextStyles.headingSmall),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyMedium,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTextStyles.bodySmall,
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.closed),
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
    return GestureDetector(
      onTap: _pickCover,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _coverFile != null || _existingCoverUrl != null
                ? AppColors.primary
                : AppColors.divider,
            width: 1.5,
          ),
        ),
        child: _coverFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(
                  _coverFile!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
            : _existingCoverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      _existingCoverUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded,
                          size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      Text('Tap untuk upload foto cover',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
      ),
    );
  }

  Widget _buildMapPicker() {
    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(_lat, _lng),
            initialZoom: 14,
            onTap: (tapPos, latLng) {
              setState(() {
                _lat = latLng.latitude;
                _lng = latLng.longitude;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.streetcoffee.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_lat, _lng),
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: AppColors.bgDark, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required String onLabel,
    required String offLabel,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppTextStyles.bodyMedium),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleOption(
                label: onLabel,
                isActive: value,
                activeColor: activeColor,
                onTap: () => onChanged(true),
              ),
              _toggleOption(
                label: offLabel,
                isActive: !value,
                activeColor: AppColors.closed,
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggleOption({
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: activeColor, width: 1)
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isActive ? activeColor : AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AppColors.bgCard,
        underline: const SizedBox.shrink(),
        style: AppTextStyles.bodyMedium,
        items: items
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildChipGroup({
    required List<String> options,
    required List<String> selected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                selected.remove(opt);
              } else {
                selected.add(opt);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.15)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
              ),
            ),
            child: Text(
              opt,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Menu Favorit', style: AppTextStyles.headingSmall),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _menuItems.add(_MenuItemState(
                    nameCtrl: TextEditingController(),
                    priceCtrl: TextEditingController(),
                  ));
                });
              },
              icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
              label: Text('Tambah', style: AppTextStyles.labelPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._menuItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Menu ${index + 1}',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.closed, size: 20),
                      onPressed: () =>
                          setState(() => _menuItems.removeAt(index)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Menu photo picker
                GestureDetector(
                  onTap: () => _pickMenuImage(index),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.bgCardAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: item.imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.file(item.imageFile!,
                                fit: BoxFit.cover, width: double.infinity),
                          )
                        : item.existingUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(item.existingUrl!,
                                    fit: BoxFit.cover, width: double.infinity),
                              )
                            : const Center(
                                child: Icon(Icons.restaurant_menu_rounded,
                                    color: AppColors.textMuted),
                              ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: item.nameCtrl,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Nama menu',
                    hintStyle: AppTextStyles.bodySmall,
                    filled: true,
                    fillColor: AppColors.bgCardAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: item.priceCtrl,
                  style: AppTextStyles.bodyMedium,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Harga (e.g. 25000)',
                    hintStyle: AppTextStyles.bodySmall,
                    prefixText: 'Rp ',
                    prefixStyle: AppTextStyles.bodySmall,
                    filled: true,
                    fillColor: AppColors.bgCardAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _MenuItemState {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  File? imageFile;
  String? existingUrl;

  _MenuItemState({
    required this.nameCtrl,
    required this.priceCtrl,
    this.imageFile,
    this.existingUrl,
  });
}
