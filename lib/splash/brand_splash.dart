import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:rume/core/theme/app_colors.dart';
import 'package:rume/shared/brand_wordmark.dart';

/// Covers [child] at launch with the Alright! intro while it loads
/// underneath, then hands off by fading out and growing slightly.
///
/// It leaves once the intro has played ([minShow]) and [ready] holds a
/// value, or after [maxWait] regardless. [onLeave] fires as the fade starts.
class BrandSplash extends StatefulWidget {
  const BrandSplash({
    required this.ready,
    required this.child,
    this.onLeave,
    super.key,
  });

  final ValueListenable<Object?> ready;
  final VoidCallback? onLeave;
  final Widget child;

  static const minShow = Duration(milliseconds: 1500);
  static const maxWait = Duration(seconds: 3);
  static const exitDuration = Duration(milliseconds: 380);

  static const ValueKey<String> panelKey = ValueKey('splash-panel');
  static const ValueKey<String> overlayKey = ValueKey('splash-overlay');
  static const tagline = ['Stream.', 'Binge.', 'Drama.'];

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with TickerProviderStateMixin {
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 240,
    ratio: 0.45,
  );

  // 0 → 1 on an underdamped spring: overshoots, then settles.
  late final AnimationController _bounce = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _words = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: BrandSplash.exitDuration,
  );

  late final Timer _wordsDelay;
  late final Timer _minShow;
  late final Timer _maxWait;
  bool _introDone = false;
  bool _timedOut = false;
  bool _leaving = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _bounce.animateWith(SpringSimulation(_spring, 0, 1, 0));
    // The tagline starts as the panel reaches full size for the first time.
    _wordsDelay = Timer(
      const Duration(milliseconds: 260),
      () => _words.forward(),
    );
    _minShow = Timer(BrandSplash.minShow, () {
      _introDone = true;
      _maybeLeave();
    });
    _maxWait = Timer(BrandSplash.maxWait, () {
      _timedOut = true;
      _maybeLeave();
    });
    widget.ready.addListener(_maybeLeave);
  }

  @override
  void dispose() {
    widget.ready.removeListener(_maybeLeave);
    _wordsDelay.cancel();
    _minShow.cancel();
    _maxWait.cancel();
    _bounce.dispose();
    _words.dispose();
    _exit.dispose();
    super.dispose();
  }

  void _maybeLeave() {
    if (!mounted || _leaving || !_introDone) return;
    if (widget.ready.value == null && !_timedOut) return;
    _leaving = true;
    _maxWait.cancel();
    widget.ready.removeListener(_maybeLeave);
    widget.onLeave?.call();
    setState(() {});
    unawaited(
      _exit.forward().then((_) {
        if (mounted) setState(() => _gone = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_gone)
          // Blocks the feed until the fade starts, then lets touches through.
          AbsorbPointer(
            absorbing: !_leaving,
            child: IgnorePointer(
              ignoring: _leaving,
              child: AnimatedBuilder(
                key: BrandSplash.overlayKey,
                animation: _exit,
                builder: (context, child) {
                  final t = Curves.easeIn.transform(_exit.value);
                  return Opacity(
                    opacity: 1 - t,
                    child: Transform.scale(scale: 1 + 0.08 * t, child: child),
                  );
                },
                child: _Intro(pop: _bounce, words: _words),
              ),
            ),
          ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.pop, required this.words});

  final Animation<double> pop;
  final Animation<double> words;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: pop,
              builder: (context, child) {
                final v = pop.value;
                return Opacity(
                  opacity: (v * 2).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    // Swings in from the other side and settles at the logo's
                    // own tilt (BrandWordmark adds the -0.07).
                    angle: 0.25 * (1 - v),
                    child: Transform.scale(
                      key: BrandSplash.panelKey,
                      scale: 0.35 + 0.65 * v,
                      child: child,
                    ),
                  ),
                );
              },
              // The glow sits behind the panel and travels with it.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.55),
                      blurRadius: 60,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const BrandWordmark(size: 46),
              ),
            ),
            const SizedBox(height: 34),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, word) in BrandSplash.tagline.indexed)
                  _Word(
                    word: word,
                    // The last word in brand blue, like the site's headline.
                    color: i == BrandSplash.tagline.length - 1
                        ? AppColors.primaryLight
                        : Colors.white,
                    progress: CurvedAnimation(
                      parent: words,
                      curve: Interval(
                        i * 0.25,
                        i * 0.25 + 0.5,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.word,
    required this.color,
    required this.progress,
  });

  final String word;
  final Color color;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: FadeTransition(
        opacity: progress,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.7),
            end: Offset.zero,
          ).animate(progress),
          child: Text(
            word,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}
