import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Floating capsule: Home · Explore · (＋ Drop) · Feed · Profil.
class AppTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTab;
  final VoidCallback onDrop;

  const AppTabBar({
    super.key,
    required this.currentIndex,
    required this.onTab,
    required this.onDrop,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
    (Icons.local_fire_department_outlined, Icons.local_fire_department_rounded, 'Feed'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 60,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.tabBar,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _tab(0),
                _tab(1),
                _dropButton(),
                _tab(2),
                _tab(3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final (icon, activeIcon, label) = _items[i];
    final active = i == currentIndex;
    final c = active ? AppColors.primary : AppColors.textMuted;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTab(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 48,
            decoration: BoxDecoration(
              color: active ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(active ? activeIcon : icon, size: 22, color: c),
                const SizedBox(height: 2),
                Text(label,
                    style: AppTextStyles.meta.copyWith(
                        fontSize: 10,
                        color: c,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropButton() => Semantics(
        button: true,
        label: 'Buat Drop',
        child: GestureDetector(
          onTap: onDrop,
          child: Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x669FE444), blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.add_rounded, size: 26, color: AppColors.onPrimary),
          ),
        ),
      );
}
