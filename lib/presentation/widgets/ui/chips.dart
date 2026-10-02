import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  final bool isOpen;
  final String text;
  final Color? background;

  const StatusBadge({
    super.key,
    required this.isOpen,
    required this.text,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final c = isOpen ? AppColors.open : AppColors.closed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? (isOpen ? AppColors.primarySoft : AppColors.closedSoft),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(text, style: AppTextStyles.badge.copyWith(color: c)),
        ],
      ),
    );
  }
}

/// Pill with an emoji circle — scrolls horizontally, no manual line breaks.
class VibePill extends StatelessWidget {
  final String emoji;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const VibePill({
    super.key,
    required this.emoji,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primarySoft : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: active ? AppColors.primary : AppColors.divider),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final bool showChevron;

  const AppFilterChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.onPrimary : AppColors.textSecondary;
    return Material(
      color: active ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: active ? AppColors.primary : AppColors.divider),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: fg,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
              if (showChevron || active) ...[
                const SizedBox(width: 6),
                Icon(active ? Icons.close_rounded : Icons.expand_more_rounded,
                    size: 15, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "⚡ PASS" tag next to member usernames.
class PassTag extends StatelessWidget {
  const PassTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.passGradientEnd]),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 10, color: AppColors.onPrimary),
          const SizedBox(width: 2),
          Text('PASS',
              style: AppTextStyles.badge.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.onPrimary)),
        ],
      ),
    );
  }
}

/// Lime pill segmented control (Feed tabs, profile tabs, promo type).
class Segmented<T> extends StatelessWidget {
  final List<(T, String, IconData?)> items;
  final T value;
  final ValueChanged<T> onChanged;

  const Segmented({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (v, label, icon) in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 38,
                  decoration: BoxDecoration(
                    color: v == value ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon,
                            size: 15,
                            color: v == value
                                ? AppColors.onPrimary
                                : AppColors.textMuted),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            fontWeight:
                                v == value ? FontWeight.w700 : FontWeight.w500,
                            color: v == value
                                ? AppColors.onPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
