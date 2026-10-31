import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:rume/core/theme/app_colors.dart';
import 'package:rume/paywall/ui/shimmer_button.dart';

/// Sits on a lockable episode. While [locked] the poster underneath is
/// blurred, even while the page is swiped in. When [focused] the card springs
/// up with its content staggered; leaving drops it, and coming back replays
/// the entrance. Unlocking drops the card and clears the blur.
class PaywallOverlay extends StatefulWidget {
  const PaywallOverlay({
    required this.episodeNumber,
    required this.locked,
    required this.focused,
    required this.purchasing,
    required this.onUnlock,
    this.posters = const [],
    super.key,
  });

  final int episodeNumber;
  final bool locked;
  final bool focused;
  final bool purchasing;
  final VoidCallback onUnlock;

  /// Clips fanned out at the top of the card, the locked episode's first
  /// (PAY-11). Empty shows a lock icon instead.
  final List<String> posters;

  static const ValueKey<String> cardKey = ValueKey('paywall-card');
  static const ValueKey<String> titleKey = ValueKey('paywall-title');
  static const ValueKey<String> ctaKey = ValueKey('paywall-cta');
  static const ValueKey<String> fanKey = ValueKey('paywall-fan');

  @override
  State<PaywallOverlay> createState() => _PaywallOverlayState();
}

class _PaywallOverlayState extends State<PaywallOverlay>
    with TickerProviderStateMixin {
  static const double _maxSigma = 24;

  // Damping ratio 0.5: the card rises past its resting place, then settles.
  static final _bounce = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 210,
    ratio: 0.5,
  );

  late final AnimationController _blur = AnimationController(
    vsync: this,
    value: widget.locked ? 1 : 0,
    duration: const Duration(milliseconds: 420),
  );

  // How much of the card is below the screen edge: 1 hidden, 0 at rest.
  // The bounce takes it below 0, so the controller has no bounds.
  late final AnimationController _hidden = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  // Drives the content cascade; each line picks its own slice of it.
  late final AnimationController _cascade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  bool get _showCard => widget.locked && widget.focused;

  @override
  void initState() {
    super.initState();
    if (_showCard) _rise();
  }

  @override
  void didUpdateWidget(PaywallOverlay old) {
    super.didUpdateWidget(old);
    final shown = old.locked && old.focused;
    if (_showCard != shown) _showCard ? _rise() : _sink();
    // Unlocking is one-way for the session, so the blur only ever lifts.
    if (old.locked && !widget.locked) {
      _blur.animateTo(0, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _blur.dispose();
    _hidden.dispose();
    _cascade.dispose();
    super.dispose();
  }

  void _rise() {
    _hidden
      ..value = 1
      ..animateWith(SpringSimulation(_bounce, 1, 0, 0));
    _cascade.forward(from: 0);
  }

  void _sink() {
    _hidden.animateTo(
      1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_blur, _hidden]),
      builder: (context, _) {
        final cardOut = _hidden.value < 1 || _showCard;
        if (_blur.value == 0 && !cardOut) return const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_blur.value > 0)
              IgnorePointer(
                ignoring: !widget.locked,
                // Eats taps and double-taps so a locked episode can't be
                // liked; drags pass through, so the feed can still go back.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  onDoubleTap: () {},
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: _maxSigma * _blur.value,
                        sigmaY: _maxSigma * _blur.value,
                      ),
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: 0.3 * _blur.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (cardOut)
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionalTranslation(
                  key: PaywallOverlay.cardKey,
                  translation: Offset(0, _hidden.value),
                  child: SafeArea(top: false, child: _cardContent(context)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _cardContent(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      decoration: BoxDecoration(
        color: AppColors.inkRaised,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 40,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.posters.isEmpty)
            _Cascade(
              clock: _cascade,
              order: 0,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: AppColors.brandGradient,
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.white),
              ),
            )
          else
            _ClipFan(
              key: PaywallOverlay.fanKey,
              posters: widget.posters,
              episodeNumber: widget.episodeNumber,
              open: _cascade.drive(_Cascade.curveFor(0)),
            ),
          const SizedBox(height: 16),
          _Cascade(
            key: PaywallOverlay.titleKey,
            clock: _cascade,
            order: 1,
            child: Text(
              'Episode ${widget.episodeNumber} is locked',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontSize: 22),
            ),
          ),
          const SizedBox(height: 6),
          _Cascade(
            clock: _cascade,
            order: 2,
            child: Text(
              "You've reached the twist. Unlock to see what happens next.",
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
          const SizedBox(height: 22),
          _Cascade(
            key: PaywallOverlay.ctaKey,
            clock: _cascade,
            order: 3,
            child: ShimmerButton(
              label: 'Unlock Episode',
              busy: widget.purchasing,
              onTap: widget.onUnlock,
            ),
          ),
          const SizedBox(height: 14),
          _Cascade(
            clock: _cascade,
            order: 4,
            child: Center(
              child: Text(
                'Swipe down for earlier episodes',
                style: text.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of the card's content. Lines enter in [order], each fading in
/// while it lifts the last few pixels into place, a beat after the line
/// above it.
class _Cascade extends StatelessWidget {
  const _Cascade({
    required this.clock,
    required this.order,
    required this.child,
    super.key,
  });

  final Animation<double> clock;
  final int order;
  final Widget child;

  static const double _beat = 0.13;
  static const double _length = 0.45;
  static const double _lift = 18;

  static Animatable<double> curveFor(int order) => CurveTween(
    curve: Interval(
      order * _beat,
      order * _beat + _length,
      curve: Curves.easeOutQuart,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = clock.drive(curveFor(order));
    return FadeTransition(
      opacity: t,
      child: AnimatedBuilder(
        animation: t,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _lift * (1 - t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// The locked clip up front, the ones beside it tilted out behind, on a soft
/// brand glow. [open] fans the side cards out from behind the front one
/// (PAY-11).
class _ClipFan extends StatelessWidget {
  const _ClipFan({
    required this.posters,
    required this.episodeNumber,
    required this.open,
    super.key,
  });

  final List<String> posters;
  final int episodeNumber;
  final Animation<double> open;

  static const Size _card = Size(104, 150);
  static const double _tilt = 0.2;
  static const double _spread = 74;

  @override
  Widget build(BuildContext context) {
    final sides = posters.skip(1).take(2).toList();
    return SizedBox(
      height: _card.height + 24,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: open,
        builder: (context, _) {
          final t = open.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Container(
                  width: 260,
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primaryLight.withValues(alpha: 0.4),
                        AppColors.primaryLight.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              for (final (i, url) in sides.indexed)
                Transform.translate(
                  offset: Offset((i == 0 ? -1 : 1) * _spread * t, 8 * t),
                  child: Transform.rotate(
                    angle: (i == 0 ? -1 : 1) * _tilt * t,
                    child: Transform.scale(
                      scale: 0.86,
                      child: _Clip(url: url, size: _card, dim: true),
                    ),
                  ),
                ),
              Transform.scale(
                scale: 0.8 + 0.2 * t,
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: _Clip(
                    url: posters.first,
                    size: _card,
                    label: 'EP $episodeNumber',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Clip extends StatelessWidget {
  const _Clip({
    required this.url,
    required this.size,
    this.label,
    this.dim = false,
  });

  final String url;
  final Size size;
  final String? label;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: AppColors.ghost,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: dim ? 0.35 : 0),
                  Colors.black.withValues(alpha: dim ? 0.55 : 0.6),
                ],
              ),
            ),
          ),
          if (label != null) ...[
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(color: Colors.white38),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
