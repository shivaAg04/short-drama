import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'package:rume/core/theme/app_colors.dart';

/// The paywall's call to action. A slanted glint crosses the pill every
/// [interval] (PAY-7). Between glints its controller is stopped, so a waiting
/// button schedules no frames.
class ShimmerButton extends StatefulWidget {
  const ShimmerButton({
    required this.label,
    required this.onTap,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;

  /// A purchase is in flight: the label changes and taps are ignored.
  final bool busy;

  static const interval = Duration(seconds: 3);
  static const glint = Duration(milliseconds: 850);

  /// The first glint waits for the card's cascade to reach the button.
  static const firstGlint = Duration(milliseconds: 600);

  @override
  State<ShimmerButton> createState() => _ShimmerButtonState();
}

class _ShimmerButtonState extends State<ShimmerButton>
    with TickerProviderStateMixin {
  late final AnimationController _glint = AnimationController(
    vsync: this,
    duration: ShimmerButton.glint,
  );

  // Pressed depth: 1 at rest, dips on touch and springs back on release.
  late final AnimationController _depth = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  static final _release = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 600,
    ratio: 0.35,
  );

  Timer? _cadence;

  @override
  void initState() {
    super.initState();
    _cadence = Timer(ShimmerButton.firstGlint, () {
      _shine();
      _cadence = Timer.periodic(ShimmerButton.interval, (_) => _shine());
    });
  }

  @override
  void dispose() {
    _cadence?.cancel();
    _glint.dispose();
    _depth.dispose();
    super.dispose();
  }

  void _shine() {
    if (!widget.busy) _glint.forward(from: 0);
  }

  void _sink() => _depth.animateTo(
    0.95,
    duration: const Duration(milliseconds: 90),
    curve: Curves.easeOut,
  );

  void _rise() =>
      _depth.animateWith(SpringSimulation(_release, _depth.value, 1, 0));

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _sink() : null,
        onTapUp: enabled ? (_) => _rise() : null,
        onTapCancel: _rise,
        onTap: enabled
            ? () {
                unawaited(HapticFeedback.selectionClick());
                widget.onTap!();
              }
            : null,
        child: ScaleTransition(
          scale: _depth,
          child: RepaintBoundary(
            child: CustomPaint(
              foregroundPainter: GlintPainter(_glint),
              child: _pill(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill() => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: AppColors.brandGradient,
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.55),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: SizedBox(
      height: 56,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.busy ? 'Unlocking…' : widget.label,
            key: ValueKey(widget.busy),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Paints the glint for [progress] in 0..1: a soft white band, slanted,
/// travelling from wholly left of the pill to wholly right of it. Paints
/// nothing while the controller is idle.
class GlintPainter extends CustomPainter {
  GlintPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  bool get lit => progress.isAnimating;

  @override
  void paint(Canvas canvas, Size size) {
    if (!lit) return;
    final band = size.width * 0.3;
    final slant = size.height * 0.4;
    final travel = size.width + band + slant;
    final left =
        -band - slant + travel * Curves.easeInOutSine.transform(progress.value);

    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      )
      ..translate(left + slant, 0)
      ..skew(-slant / size.height, 0);
    final rect = Rect.fromLTWH(0, 0, band, size.height);
    canvas
      ..drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x00FFFFFF), Color(0xA6FFFFFF), Color(0x00FFFFFF)],
          ).createShader(rect),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(GlintPainter old) => old.progress != progress;
}
