import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/entities/coffee_shop.dart';

class NearbyCard extends StatelessWidget {
  final CoffeeShop shop;
  final VoidCallback onTap;
  final VoidCallback onWhatsAppTap;

  const NearbyCard({
    super.key,
    required this.shop,
    required this.onTap,
    required this.onWhatsAppTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: shop.imageUrl,
                width: 100,
                height: 110,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 100,
                  height: 110,
                  color: AppColors.bgCardAlt,
                  child: const Icon(Icons.coffee,
                      color: AppColors.textMuted, size: 32),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: AppTextStyles.headingSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vibe: ${shop.vibe}',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          shop.priceRange,
                          style: AppTextStyles.priceTag,
                        ),
                        const Spacer(),
                        _buildWhatsAppButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppButton() {
    return GestureDetector(
      onTap: onWhatsAppTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_rounded, color: AppColors.bgDark, size: 14),
            const SizedBox(width: 4),
            Text('PESAN', style: AppTextStyles.button.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
