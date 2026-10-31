import 'package:flutter/material.dart';

import 'package:rume/core/theme/app_colors.dart';

/// "alright!" on the logo's tilted panel.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    this.size = 42,
    this.color = Colors.white,
    this.panel = AppColors.primary,
    super.key,
  });

  /// Font size; the panel's padding and corners scale with it.
  final double size;
  final Color color;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    final unit = size / 42;
    return Transform.rotate(
      angle: -0.07,
      child: Container(
        padding: EdgeInsets.fromLTRB(22 * unit, 6 * unit, 22 * unit, 10 * unit),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(6 * unit),
        ),
        child: Text(
          'alright!',
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2 * unit,
          ),
        ),
      ),
    );
  }
}
