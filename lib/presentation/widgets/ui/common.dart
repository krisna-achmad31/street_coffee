import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'buttons.dart';

/// Network image with the dark placeholder used everywhere.
class NetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BorderRadius? radius;
  final IconData fallbackIcon;

  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.radius,
    this.fallbackIcon = Icons.coffee_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: AppColors.textMuted),
    );
    final img = url.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(width: width, height: height, color: AppColors.surfaceAlt),
            errorWidget: (_, __, ___) => fallback,
          );
    return radius == null ? img : ClipRRect(borderRadius: radius!, child: img);
  }
}

/// Rounded-square avatar (circles are reserved for stamps).
class UserAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  final double radius;
  final Color? borderColor;

  const UserAvatar({
    super.key,
    this.url,
    required this.name,
    this.size = 36,
    this.radius = 10,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url == null || url!.isEmpty
          ? Text(initial,
              style: AppTextStyles.cardTitle
                  .copyWith(fontSize: size * 0.4, color: AppColors.primary))
          : NetImage(url!, width: size, height: size),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.section)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: AppTextStyles.badge.copyWith(fontSize: 13)),
          ),
      ],
    );
  }
}

class OverlineLabel extends StatelessWidget {
  final String text;
  const OverlineLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppTextStyles.overline);
}

class MonoText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final FontWeight weight;
  final double letterSpacing;

  const MonoText(
    this.text, {
    super.key,
    this.size = 12,
    this.color = AppColors.textSecondary,
    this.weight = FontWeight.w400,
    this.letterSpacing = 0,
  });

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.mono.copyWith(
            fontSize: size,
            color: color,
            fontWeight: weight,
            letterSpacing: letterSpacing),
      );
}

/// Screen title row: optional back button + Syne 24 title + trailing.
class ScreenHeader extends StatelessWidget {
  final String title;
  final bool back;
  final IconData backIcon;
  final Widget? trailing;
  final VoidCallback? onBack;

  const ScreenHeader({
    super.key,
    required this.title,
    this.back = false,
    this.backIcon = Icons.arrow_back_rounded,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          if (back) ...[
            OverlayIconButton(
              icon: backIcon,
              background: AppColors.surface,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          // Syne 24/800 is wide: on 360 dp phones shrink a long title to fit
          // instead of cutting it ("Tambah Ke…").
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(title, style: AppTextStyles.title, maxLines: 1),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SearchTrigger extends StatelessWidget {
  final String hint;
  final VoidCallback? onTap;
  final VoidCallback? onFilter;
  final bool filterActive;

  const SearchTrigger({
    super.key,
    this.hint = 'Cari kedai, menu, atau vibe…',
    this.onTap,
    this.onFilter,
    this.filterActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(hint,
                  style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis),
            ),
            if (onFilter != null)
              GestureDetector(
                onTap: onFilter,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: filterActive ? AppColors.primary : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.tune_rounded,
                      size: 16,
                      color: filterActive
                          ? AppColors.onPrimary
                          : AppColors.textPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool highlighted;
  final IconData trailing;

  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.highlighted = false,
    this.trailing = Icons.chevron_right_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AppColors.onPrimary : AppColors.textPrimary;
    return Material(
      color: highlighted ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: highlighted ? AppColors.onPrimary : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 18,
                    color: highlighted
                        ? AppColors.primary
                        : AppColors.textSecondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.body.copyWith(
                            color: fg,
                            fontWeight:
                                highlighted ? FontWeight.w700 : FontWeight.w500)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: AppTextStyles.meta
                              .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(trailing,
                  size: 18,
                  color: highlighted ? AppColors.onPrimary : AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class FacilityItem extends StatelessWidget {
  final String facility;
  const FacilityItem(this.facility, {super.key});

  static const _icons = {
    'WiFi': Icons.wifi_rounded,
    'Outdoor': Icons.park_rounded,
    'Musik': Icons.music_note_rounded,
    'Parkir': Icons.local_parking_rounded,
    'AC': Icons.ac_unit_rounded,
    'Colokan': Icons.power_rounded,
    'Toilet': Icons.wc_rounded,
    'No Smoking': Icons.smoke_free_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_icons[facility] ?? Icons.check_circle_rounded,
                size: 22, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(facility,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.meta.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class Skeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceAlt,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Empty / error / permission state: ringed icon + text + action.
class StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool danger;
  final Widget? secondary;

  const StateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.danger = false,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final c = danger ? AppColors.closed : AppColors.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: danger ? AppColors.closedSoft : AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: c),
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTextStyles.section.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                    label: actionLabel!, icon: actionIcon, onPressed: onAction),
              ),
            ],
            if (secondary != null) ...[
              const SizedBox(height: 8),
              secondary!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact error for a section inside a page (a tab, a strip, a sheet list).
class InlineError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const InlineError(this.message, {super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 22),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: AppTextStyles.meta.copyWith(color: AppColors.textSecondary)),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: Text('Coba lagi',
                style: AppTextStyles.badge.copyWith(fontSize: 13)),
          ),
      ]),
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.closed : AppColors.surfaceAlt,
    ));
}
