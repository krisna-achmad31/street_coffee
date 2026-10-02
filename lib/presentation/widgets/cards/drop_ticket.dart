import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/social.dart';
import '../ui/buttons.dart';
import '../ui/chips.dart';
import '../ui/common.dart';
import '../ui/receipt.dart';

/// The social post, drawn as a coffee receipt: photo → perforation →
/// shop + mono line items → caption → Cheers / komentar / bagikan / mau ke sini.
class DropTicket extends StatelessWidget {
  final Drop drop;
  final bool cheered;
  final bool wanted;
  final VoidCallback? onCheers;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onWant;
  final VoidCallback? onShop;
  final VoidCallback? onMore;

  const DropTicket({
    super.key,
    required this.drop,
    this.cheered = false,
    this.wanted = false,
    this.onCheers,
    this.onComment,
    this.onShare,
    this.onWant,
    this.onShop,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final cheers = drop.cheersCount;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 360,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(drop.coverUrl),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xCC0E0E0E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              MonoText(
                                '${Fmt.hhmm(drop.createdAt)} · ${Fmt.timeAgo(drop.createdAt).toUpperCase()}',
                                size: 10,
                                color: AppColors.textPrimary,
                                weight: FontWeight.w700,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (drop.stampNumber > 0)
                          StampSeal(
                            number: drop.stampNumber.toString().padLeft(2, '0'),
                            bottom: Fmt.ddmm(drop.createdAt),
                          ),
                        if (onMore != null) ...[
                          const SizedBox(width: 6),
                          OverlayIconButton(
                              icon: Icons.more_horiz_rounded,
                              size: 34,
                              onPressed: onMore),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Perforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: onShop,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(drop.shopName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.section.copyWith(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3)),
                              const SizedBox(height: 3),
                              MonoText(drop.shopVibe.toUpperCase(),
                                  size: 10,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.5),
                            ],
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.north_east_rounded,
                              size: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (drop.menuItem != null)
                    ReceiptLine(
                      label: '1× ${drop.menuItem}',
                      value: drop.menuPrice == null
                          ? '-'
                          : Fmt.rupiahShort(drop.menuPrice!).toUpperCase(),
                    ),
                  const SizedBox(height: 6),
                  ReceiptLine(
                      label: 'RATING',
                      value: Fmt.stars(drop.rating),
                      valueColor: AppColors.star),
                  const SizedBox(height: 6),
                  ReceiptLine(
                      label: 'VIBE',
                      value: drop.vibe.toUpperCase(),
                      valueColor: AppColors.primary),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                          url: drop.userPhotoUrl, name: drop.userHandle, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(drop.userHandle,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.body.copyWith(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                ),
                                if (drop.userIsPass) ...[
                                  const SizedBox(width: 6),
                                  const PassTag(),
                                ],
                              ],
                            ),
                            if (drop.caption.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(drop.caption,
                                  style: AppTextStyles.body.copyWith(
                                      color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      PillButton(
                        icon: Icons.coffee_rounded,
                        label: '${Fmt.compact(cheers)} Cheers',
                        active: cheered,
                        onTap: onCheers,
                      ),
                      const SizedBox(width: 8),
                      PillButton(
                        icon: Icons.mode_comment_outlined,
                        label: Fmt.compact(drop.commentCount),
                        onTap: onComment,
                      ),
                      const SizedBox(width: 8),
                      PillButton(icon: Icons.ios_share_rounded, onTap: onShare),
                      const Spacer(),
                      PillButton(
                        icon: wanted
                            ? Icons.where_to_vote_rounded
                            : Icons.add_location_alt_outlined,
                        active: wanted,
                        onTap: onWant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
