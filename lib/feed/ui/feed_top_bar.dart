import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rume/core/theme/app_colors.dart';
import 'package:rume/feed/domain/feed_entry.dart';
import 'package:rume/feed/state/feed_bloc.dart';
import 'package:rume/player/state/video_pool.dart';
import 'package:rume/shared/brand_wordmark.dart';

/// Lays the wordmark and sound switch over [child]. The bar shows on any
/// touch and hides [hideAfter] the last one; it never shows on an ad.
class FeedTopBar extends StatefulWidget {
  const FeedTopBar({required this.child, super.key});

  final Widget child;

  static const hideAfter = Duration(seconds: 3);
  static const ValueKey<String> barKey = ValueKey('top-bar');
  static const ValueKey<String> soundKey = ValueKey('top-bar-sound');

  @override
  State<FeedTopBar> createState() => _FeedTopBarState();
}

class _FeedTopBarState extends State<FeedTopBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -0.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _shown, curve: Curves.easeOutCubic));

  Timer? _hide;
  bool _visible = false;

  @override
  void dispose() {
    _hide?.cancel();
    _shown.dispose();
    super.dispose();
  }

  bool get _onAd => context.read<FeedBloc>().state.focused is AdBreakEntry;

  // A raw pointer, not a gesture: it sees every touch without taking it
  // from the page below.
  void _poke(PointerDownEvent _) {
    if (_onAd) return;
    _hide?.cancel();
    _hide = Timer(FeedTopBar.hideAfter, () => _setVisible(false));
    _setVisible(true);
  }

  void _setVisible(bool visible) {
    if (!mounted || _visible == visible) return;
    setState(() => _visible = visible);
    unawaited(visible ? _shown.forward() : _shown.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FeedBloc, FeedState>(
      listenWhen: (a, b) => b.focused is AdBreakEntry,
      listener: (_, _) {
        _hide?.cancel();
        _setVisible(false);
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _poke,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_visible,
                child: FadeTransition(
                  opacity: _shown,
                  child: SlideTransition(
                    position: _slide,
                    child: const _Bar(key: FeedTopBar.barKey),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x73000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 14, 18),
          child: Row(
            children: [
              // Decoration only: a touch on it belongs to the episode.
              const IgnorePointer(child: BrandWordmark(size: 20)),
              const Spacer(),
              _SoundButton(pool: context.read<VideoPool>()),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundButton extends StatelessWidget {
  const _SoundButton({required this.pool});

  final VideoPool pool;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: pool.muted,
      builder: (context, muted, _) => Semantics(
        button: true,
        label: muted ? 'Turn sound on' : 'Mute',
        child: GestureDetector(
          key: FeedTopBar.soundKey,
          behavior: HitTestBehavior.opaque,
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            pool.toggleMute();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: muted
                  ? AppColors.primary
                  : Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                key: ValueKey(muted),
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
