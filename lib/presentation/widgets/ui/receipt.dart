import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Torn-ticket divider: two notches cut in the card edge + a dashed line.
/// [notchColor] must match whatever is behind the card (usually the page bg).
class Perforation extends StatelessWidget {
  final Color cardColor;
  final Color notchColor;

  const Perforation({
    super.key,
    this.cardColor = AppColors.surface,
    this.notchColor = AppColors.bg,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 22,
        width: double.infinity,
        child: CustomPaint(painter: _PerforationPainter(cardColor, notchColor)),
      );
}

class _PerforationPainter extends CustomPainter {
  final Color card;
  final Color notch;
  _PerforationPainter(this.card, this.notch);

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawRect(Offset.zero & size, Paint()..color = card);
    final n = Paint()..color = notch;
    canvas.drawCircle(Offset(0, mid), 11, n);
    canvas.drawCircle(Offset(size.width, mid), 11, n);
    final dash = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 2;
    for (double x = 22; x < size.width - 22; x += 12) {
      canvas.drawLine(Offset(x, mid), Offset(math.min(x + 6, size.width - 22), mid), dash);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.card != card || old.notch != notch;
}

/// "1× Es Kopi Senja ........ Rp18K" — mono label, dot leader, value.
class ReceiptLine extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const ReceiptLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.mono;
    return Row(
      children: [
        Text(label, style: style),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '.' * 60,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: style.copyWith(color: AppColors.divider),
          ),
        ),
        const SizedBox(width: 6),
        Text(value,
            style: style.copyWith(color: valueColor, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Round, slightly rotated passport stamp: "KEDAI KE / 32 / 27·09".
class StampSeal extends StatelessWidget {
  final String top;
  final String number;
  final String bottom;
  final double size;
  final double angle;
  final Color? fill;

  const StampSeal({
    super.key,
    this.top = 'KEDAI KE',
    required this.number,
    required this.bottom,
    this.size = 74,
    this.angle = -0.17,
    this.fill = const Color(0x990E0E0E),
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(top,
                style: AppTextStyles.mono.copyWith(
                    fontSize: size * 0.095,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            Text(number,
                style: AppTextStyles.display.copyWith(
                    fontSize: size * 0.33,
                    height: 1,
                    color: AppColors.primary)),
            Text(bottom,
                style: AppTextStyles.mono.copyWith(
                    fontSize: size * 0.095,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

/// Visited-shop stamp on the passport page (photo inside a lime ring).
class PassportStamp extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String date;
  final double angle;

  const PassportStamp({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.date,
    this.angle = 0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Transform.rotate(
            angle: angle,
            child: Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: ClipOval(
                child: Opacity(
                  opacity: 0.85,
                  child: imageUrl.isEmpty
                      ? Container(color: AppColors.surfaceAlt)
                      : Image.network(imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppColors.surfaceAlt)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.mono.copyWith(
                  fontSize: 8, fontWeight: FontWeight.w700)),
          Text(date,
              style: AppTextStyles.mono
                  .copyWith(fontSize: 8, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class AchievementMedal extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool unlocked;

  const AchievementMedal({
    super.key,
    required this.icon,
    required this.label,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? null : AppColors.surface,
              gradient: unlocked
                  ? const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0x559FE444), Color(0xFF1E1E1E)])
                  : null,
              border: Border.all(
                  color: unlocked ? AppColors.primary : AppColors.divider,
                  width: 1.5),
            ),
            child: Icon(unlocked ? icon : Icons.lock_rounded,
                size: 26,
                color: unlocked ? AppColors.primary : AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTextStyles.meta.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      unlocked ? AppColors.textPrimary : AppColors.textMuted)),
        ],
      ),
    );
  }
}
