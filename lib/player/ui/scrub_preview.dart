import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:rume/core/theme/app_colors.dart';

/// Rides above the finger while scrubbing: the `mm:ss / mm:ss` pill, and
/// above it the frame at that moment when one is available.
class ScrubPreview extends StatelessWidget {
  const ScrubPreview({
    required this.at,
    required this.length,
    this.frame,
    super.key,
  });

  final Duration at;
  final Duration length;
  final ImageProvider? frame;

  static const Size size = Size(132, 38);
  static const Size thumb = Size(108, 192);
  static const double _gap = 6;
  static const ValueKey<String> frameKey = ValueKey('scrub-frame');

  /// The whole preview, so the caller can keep it on screen.
  static Size sizeFor({required bool withFrame}) =>
      withFrame ? Size(size.width, thumb.height + _gap + size.height) : size;

  /// mm:ss, e.g. 00:05.
  static String clock(Duration d) {
    final seconds = d.inSeconds;
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final frame = this.frame;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (frame != null) ...[
          _Thumb(frame: frame),
          const SizedBox(height: _gap),
        ],
        _pill(),
      ],
    );
  }

  Widget _pill() {
    return SizedBox.fromSize(
      size: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size.height / 2),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.55),
              border: Border.all(
                color: AppColors.primaryLight.withValues(alpha: 0.6),
              ),
              borderRadius: BorderRadius.circular(size.height / 2),
            ),
            child: Center(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: clock(at),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    TextSpan(
                      text: ' / ${clock(length)}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.frame});

  final ImageProvider frame;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Container(
      width: ScrubPreview.thumb.width,
      height: ScrubPreview.thumb.height,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.6),
        ),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 16)],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image(
          key: ScrubPreview.frameKey,
          image: frame,
          fit: BoxFit.cover,
          // Holds the last frame while the next second's one loads.
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
