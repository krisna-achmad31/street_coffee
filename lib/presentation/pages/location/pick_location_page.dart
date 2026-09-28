import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../blocs/location/location_bloc.dart';

class PickLocationPage extends StatefulWidget {
  const PickLocationPage({super.key});

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  final _searchController = TextEditingController();

  static const _savedLocations = [
    ('home', 'Rumah', 'Jakarta Selatan'),
    ('work', 'Kantor', 'Jakarta Selatan'),
  ];

  static const _recentLocations = [
    'Blok M, Jakarta Selatan',
    'Kebayoran Baru, Jakarta Selatan',
    'Senopati, Jakarta Selatan',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Pilih Lokasi', style: AppTextStyles.headingMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Cari Jalan atau Area...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Use current location
          _buildActionTile(
            icon: Icons.my_location_rounded,
            iconColor: AppColors.primary,
            label: 'Lokasi Saat Ini',
            onTap: _useCurrentLocation,
            isAction: true,
          ),
          const SizedBox(height: 20),
          Text('Lokasi Tersimpan', style: AppTextStyles.headingSmall),
          const SizedBox(height: 10),
          ..._savedLocations.map((loc) => _buildSavedTile(
                icon: loc.$1 == 'home'
                    ? Icons.home_rounded
                    : Icons.work_rounded,
                title: loc.$2,
                subtitle: loc.$3,
              )),
          const SizedBox(height: 8),
          _buildActionTile(
            icon: Icons.map_rounded,
            iconColor: AppColors.primary,
            label: 'Cari di Peta',
            onTap: () {},
            isAction: true,
          ),
          const SizedBox(height: 20),
          Text('Lokasi Terakhir Dicari', style: AppTextStyles.headingSmall),
          const SizedBox(height: 10),
          ..._recentLocations.map((loc) => _buildRecentTile(loc)),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    bool isAction = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isAction
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: isAction
              ? Border.all(color: AppColors.primary, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textMuted),
      onTap: () {},
    );
  }

  Widget _buildRecentTile(String location) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.location_on_rounded,
            color: AppColors.primary, size: 20),
      ),
      title: Text(location, style: AppTextStyles.bodyMedium),
      subtitle: Text(location, style: AppTextStyles.caption),
      onTap: () {},
    );
  }

  void _useCurrentLocation() {
    context.read<LocationBloc>().add(LocationGetCurrent());
    context.pop();
  }
}
