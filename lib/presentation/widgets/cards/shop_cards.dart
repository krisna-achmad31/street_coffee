import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../domain/entities/coffee_shop.dart';
import '../ui/chips.dart';
import '../ui/common.dart';

const vibeEmoji = {
  'Nongkrong Skena': '☕',
  'Deep Talk': '💬',
  'Manual Brew': '🫗',
  'Kopi Hemat': '💰',
  'Santai': '🌿',
  'Cozy': '🛋️',
  'Kerja': '💻',
};

/// List card: photo · name + WA button · rating · distance · price · status · vibe.
class ShopCard extends StatelessWidget {
  final CoffeeShop shop;
  final VoidCallback onTap;
  final VoidCallback? onWhatsApp;
  final bool elevated;

  const ShopCard({
    super.key,
    required this.shop,
    required this.onTap,
    this.onWhatsApp,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: elevated ? 12 : 0,
      shadowColor: Colors.black,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              NetImage(shop.imageUrl,
                  width: 96, height: 96, radius: BorderRadius.circular(12)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(shop.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.cardTitle),
                        ),
                        if (onWhatsApp != null) ...[
                          const SizedBox(width: 8),
                          _WaButton(enabled: shop.isOpen, onTap: onWhatsApp!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: AppColors.star),
                        const SizedBox(width: 3),
                        Text(shop.rating.toStringAsFixed(1),
                            style: AppTextStyles.meta.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                        if (shop.distanceText.isNotEmpty) ...[
                          _dot,
                          Text(shop.distanceText, style: AppTextStyles.meta),
                        ],
                        if (shop.priceRange.isNotEmpty) ...[
                          _dot,
                          Flexible(
                            child: Text(shop.priceRange,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.meta),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusBadge(isOpen: shop.isOpen, text: shop.statusText),
                        const SizedBox(width: 6),
                        if (shop.vibe.isNotEmpty)
                          Flexible(
                            child: Text(
                              '${vibeEmoji[shop.vibe] ?? '☕'} ${shop.vibe}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.meta.copyWith(
                                  fontSize: 11, color: AppColors.textMuted),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _dot = Padding(
    padding: EdgeInsets.symmetric(horizontal: 6),
    child: Text('·', style: TextStyle(color: AppColors.textMuted)),
  );
}

class _WaButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _WaButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.primary : AppColors.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.chat_bubble_outline_rounded,
              size: 16,
              color: enabled ? AppColors.onPrimary : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class FeaturedCard extends StatelessWidget {
  final CoffeeShop shop;
  final VoidCallback onTap;

  const FeaturedCard({super.key, required this.shop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 220,
          height: 260,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetImage(shop.imageUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                    colors: [Colors.transparent, Color(0xE6000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Short label: on a 360 dp phone "Buka · s/d 23.00"
                        // plus the distance pill overflowed the 220 px card.
                        Flexible(
                          child: StatusBadge(
                            isOpen: shop.isOpen,
                            text: shop.isOpen ? 'Buka' : 'Tutup',
                            background: const Color(0xB30E0E0E),
                          ),
                        ),
                        const Spacer(),
                        if (shop.distanceText.isNotEmpty)
                          _pill(Icons.near_me_rounded, shop.distanceText),
                      ],
                    ),
                    if (shop.isSponsored) ...[
                      const SizedBox(height: 6),
                      _pill(Icons.campaign_rounded, 'Bersponsor'),
                    ],
                    const Spacer(),
                    Text(shop.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.section),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: AppColors.star),
                        const SizedBox(width: 3),
                        Text(shop.rating.toStringAsFixed(1),
                            style: AppTextStyles.meta.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                        const Text('  ·  ',
                            style: TextStyle(color: AppColors.textSecondary)),
                        Flexible(
                          child: Text(shop.vibe,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.meta),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xB30E0E0E),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: AppColors.textPrimary),
            const SizedBox(width: 4),
            Text(text,
                style: AppTextStyles.badge
                    .copyWith(color: AppColors.textPrimary)),
          ],
        ),
      );
}
