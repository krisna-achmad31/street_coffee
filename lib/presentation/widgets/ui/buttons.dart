import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Lime, 52 tall, radius 16 — "Button Primary" in the .pen file.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Color background;
  final Color foreground;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.background = AppColors.primary,
    this.foreground = AppColors.onPrimary,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: foreground),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: foreground),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.button.copyWith(color: foreground)),
                  ),
                ],
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.button.copyWith(color: AppColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round 40px button, dark translucent — sits on photos (back, share, edit).
class OverlayIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color background;
  final double size;
  final String? tooltip;

  const OverlayIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.background = AppColors.overlay,
    this.size = 40,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(icon, size: 19, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Small pill action used in receipts and dashboards.
class PillButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool active;
  final VoidCallback? onTap;

  const PillButton({
    super.key,
    this.label,
    this.icon,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.onPrimary : AppColors.textPrimary;
    return Material(
      color: active ? AppColors.primary : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 15, color: fg),
              if (icon != null && label != null) const SizedBox(width: 6),
              if (label != null)
                Text(label!,
                    style: AppTextStyles.meta.copyWith(
                        color: fg, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
