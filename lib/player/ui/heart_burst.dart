import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:rume/core/theme/app_colors.dart';

/// A heart that pops at [at], then flies on a curve into the rail's like
/// icon (wherever [target] says it is), shrinking as it goes. [onArrive]
/// fires as it lands, then it fades into the icon and calls [onDone].
///
/// Without a target it just drifts up and fades, liking at the pop.
class HeartBurst extends StatefulWidget {
  const HeartBurst({
    required this.at,
    required this.onDone,
    this.target,
    this.onArrive,
    super.key,
  });

  final Offset at;
  final Offset? Function()? target;
  final VoidCallback? onArrive;
  final VoidCallback onDone;

  static const double size = 140;
  static const ValueKey<String> scaleKey = ValueKey('heart-scale');

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst> with TickerProviderStateMixin {
  // Damping ratio 0.42: the heart swells past full size, then settles.
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.42,
  );

  // Phases of [_life]: pop and hold, fly, sink into the icon.
  static const _flyFrom = 0.3;
  static const _land = 0.85;
  static const _iconScale = 0.3;

  late final AnimationController _swell = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  // Each heart leans a little, one way or the other depending on where the
  // finger landed, and straightens as it flies off.
  late final double _lean = math.sin(widget.at.dx * 0.7 + widget.at.dy) * 0.22;
  Offset? _to;
  bool _arrived = false;

  @override
  void initState() {
    super.initState();
    _swell.animateWith(SpringSimulation(_spring, 0, 1, 0));
    _life.addListener(_onTick);
    unawaited(
      _life.forward().then((_) {
        if (mounted) widget.onDone();
      }),
    );
  }

  @override
  void dispose() {
    _swell.dispose();
    _life.dispose();
    super.dispose();
  }

  void _onTick() {
    final t = _life.value;
    // Resolved at take-off, so it is wherever the icon is by then.
    if (t >= _flyFrom && _to == null && widget.target != null) {
      _to = widget.target!();
    }
    final landsAt = _to == null ? _flyFrom : _land;
    if (!_arrived && t >= landsAt) {
      _arrived = true;
      widget.onArrive?.call();
    }
  }

  // Quadratic curve: leaves sideways, drops into the icon.
  Offset _pathAt(Offset from, Offset to, double p) {
    final control = Offset(to.dx, from.dy);
    final a = Offset.lerp(from, control, p)!;
    final b = Offset.lerp(control, to, p)!;
    return Offset.lerp(a, b, p)!;
  }

  @override
  Widget build(BuildContext context) {
    const size = HeartBurst.size;
    return AnimatedBuilder(
      animation: Listenable.merge([_swell, _life]),
      builder: (context, heart) {
        final t = _life.value;
        final to = _to;
        final pop = math.max<double>(0, _swell.value);

        Offset centre;
        double scale;
        double opacity;
        if (to == null) {
          final fade = t < 0.55 ? 0.0 : (t - 0.55) / 0.45;
          centre = widget.at + Offset(0, -48 * Curves.easeIn.transform(fade));
          scale = pop * (1 + 0.15 * fade);
          opacity = 1 - fade;
        } else {
          final fly = ((t - _flyFrom) / (_land - _flyFrom)).clamp(0.0, 1.0);
          final p = Curves.easeInOutCubic.transform(fly);
          centre = _pathAt(widget.at, to, p);
          scale = pop * (1 - (1 - _iconScale) * p);
          opacity = t < _land ? 1 : 1 - (t - _land) / (1 - _land);
        }

        return Positioned(
          left: centre.dx - size / 2,
          top: centre.dy - size / 2,
          width: size,
          height: size,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: CustomPaint(
                painter: _RingPainter(
                  Curves.easeOutCubic.transform(math.min(1, t / 0.4)),
                ),
                child: Transform(
                  key: HeartBurst.scaleKey,
                  alignment: Alignment.center,
                  transform: Matrix4.rotationZ(_lean * (1 - t))
                    ..multiply(Matrix4.diagonal3Values(scale, scale, 1)),
                  child: heart,
                ),
              ),
            ),
          ),
        );
      },
      child: Center(
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B7A), AppColors.heart],
          ).createShader(rect),
          child: const Icon(
            Icons.favorite_rounded,
            size: 96,
            shadows: [Shadow(color: Color(0x66000000), blurRadius: 18)],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    canvas.drawCircle(
      size.center(Offset.zero),
      24 + progress * (size.width / 2 - 24),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - progress)
        ..color = AppColors.heart.withValues(alpha: 0.7 * (1 - progress)),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
