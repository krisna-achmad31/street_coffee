import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class FacilityIcon extends StatelessWidget {
  final String facility;

  const FacilityIcon({super.key, required this.facility});

  static const _facilityMap = {
    'WiFi': (Icons.wifi_rounded, 'WiFi'),
    'Outdoor': (Icons.deck_rounded, 'Outdoor'),
    'Musik': (Icons.music_note_rounded, 'Musik'),
    'Parkir': (Icons.local_parking_rounded, 'Parkir'),
    'AC': (Icons.ac_unit_rounded, 'AC'),
    'Colokan': (Icons.electrical_services_rounded, 'Colokan'),
    'Toilet': (Icons.wc_rounded, 'Toilet'),
    'No Smoking': (Icons.smoke_free_rounded, 'No Smoking'),
  };

  @override
  Widget build(BuildContext context) {
    final data = _facilityMap[facility] ??
        (Icons.check_circle_rounded, facility);

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(data.$1, color: AppColors.textSecondary, size: 22),
        ),
        const SizedBox(height: 4),
        Text(data.$2, style: AppTextStyles.caption),
      ],
    );
  }
}
