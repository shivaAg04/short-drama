import 'package:flutter/material.dart';

import 'package:rume/core/theme/app_colors.dart';

/// `Episode 3/7` on the brand gradient. `BrandSkeleton` draws a pill of the
/// same [size] in its place while an ad loads.
class EpisodeChip extends StatelessWidget {
  const EpisodeChip({required this.number, required this.total, super.key});

  final int number;
  final int total;

  static const Size size = Size(124, 34);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.height,
      constraints: BoxConstraints(minWidth: size.width),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size.height / 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Centred, but only as wide as the label: an aligned Container would
      // stretch to fill the row.
      child: Center(
        widthFactor: 1,
        child: Text(
          'Episode $number/$total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
