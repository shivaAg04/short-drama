import 'package:flutter/material.dart';

import 'package:rume/core/theme/app_colors.dart';
import 'package:rume/player/ui/episode_chip.dart';
import 'package:rume/shared/brand_wordmark.dart';

/// Branded ghost of the player shown while an ad is loading: the
/// Alright!TV wordmark plus placeholders where the caption and progress bar
/// will sit, with a soft light sweeping across them.
class BrandSkeleton extends StatefulWidget {
  const BrandSkeleton({super.key});

  @override
  State<BrandSkeleton> createState() => _BrandSkeletonState();
}

class _BrandSkeletonState extends State<BrandSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ColoredBox(
        color: AppColors.ink,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _sweep,
              builder: (context, child) => ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (rect) => LinearGradient(
                  begin: const Alignment(-1, -0.3),
                  end: const Alignment(1, 0.3),
                  colors: const [
                    AppColors.ghost,
                    AppColors.shine,
                    AppColors.ghost,
                  ],
                  stops: const [0.35, 0.5, 0.65],
                  transform: _Slide(_sweep.value),
                ).createShader(rect),
                child: child,
              ),
              child: const _Placeholders(),
            ),
            // Outside the shimmer: ShaderMask recolours every pixel under it,
            // which would paint the letters the colour of their panel.
            Center(
              child: BrandWordmark(
                color: AppColors.primaryLight.withValues(alpha: 0.6),
                panel: AppColors.ghost,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2.4 - 1.2), 0, 0);
}

/// Where the episode chip, time label and progress bar will be, at the
/// same places and sizes, so loading hands over without anything moving.
class _Placeholders extends StatelessWidget {
  const _Placeholders();

  static Widget _bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.ghost,
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: _bar(EpisodeChip.size.width, EpisodeChip.size.height),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: _bar(64, 10),
            ),
            const SizedBox(height: 14.5),
            _bar(double.infinity, 3),
          ],
        ),
      ),
    );
  }
}
