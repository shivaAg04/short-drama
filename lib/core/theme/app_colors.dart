import 'package:flutter/painting.dart';

/// Alright!TV palette, taken from alright.watch's stylesheet.
abstract final class AppColors {
  static const ink = Color(0xFF0A0A0A);
  static const inkRaised = Color(0xFF131318);
  static const ghost = Color(0xFF1A1B2C);
  static const shine = Color(0xFF2D3080);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFFA9ACD6);

  /// The logo blue: fills, borders, buttons.
  static const primary = Color(0xFF0D11D4);

  /// Readable tints of the brand blue for text and glows on dark.
  static const primaryLight = Color(0xFF6B70FF);
  static const primaryLighter = Color(0xFF9A9EFF);

  static const heart = Color(0xFFFF3040);

  static const brandGradient = LinearGradient(colors: [primary, primaryLight]);
}
