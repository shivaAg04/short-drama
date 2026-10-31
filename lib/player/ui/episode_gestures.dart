import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rume/engagement/state/engagement_cubit.dart';
import 'package:rume/player/domain/scrub_frames.dart';
import 'package:rume/player/state/video_pool.dart';
import 'package:rume/player/ui/heart_burst.dart';
import 'package:rume/player/ui/progress_bar.dart';
import 'package:rume/player/ui/scrub_preview.dart';
import 'package:video_player/video_player.dart';

/// Everything a finger can do on an episode: tap to pause, double-tap to
/// like, drag sideways anywhere to scrub. Only episodes build this, so ad
/// pages get none of it.
///
/// Scrub and finger state live in notifiers, so dragging rebuilds the
/// preview bubble and repaints the bar, never the video.
class EpisodeGestures extends StatefulWidget {
  const EpisodeGestures({
    required this.episode,
    required this.controller,
    this.likeTarget,
    this.frameAt,
    super.key,
  });

  final int episode;
  final VideoPlayerController controller;

  /// A still of the video at a given second, for the scrub preview; null, or
  /// returning null, means the preview shows the time alone.
  final ImageProvider? Function(int second)? frameAt;

  /// The rail's like icon, which double-tap hearts fly into.
  final GlobalKey? likeTarget;

  @override
  State<EpisodeGestures> createState() => _EpisodeGesturesState();
}

class _EpisodeGesturesState extends State<EpisodeGestures> {
  static const _maxHearts = 6;
  static const _bubbleGap = 42.0;
  static const _edge = 8.0;

  final ValueNotifier<double?> _scrub = ValueNotifier(null);
  final ValueNotifier<Offset?> _finger = ValueNotifier(null);
  final List<(int, Offset)> _hearts = [];
  int _heartIds = 0;
  Offset _doubleTapAt = Offset.zero;
  double _width = 1;

  late final VideoPool _pool = context.read<VideoPool>();
  late final FramePrefetcher<ImageProvider> _frames = FramePrefetcher(
    (second) => widget.frameAt?.call(second),
    (frame) =>
        unawaited(precacheImage(frame, context, onError: (error, stack) {})),
  );

  @override
  void dispose() {
    _scrub.dispose();
    _finger.dispose();
    super.dispose();
  }

  /// Centre of the rail's like icon in this layer's coordinates.
  Offset? _likeIconCentre() {
    final icon = widget.likeTarget?.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    if (icon is! RenderBox || self is! RenderBox || !icon.attached) {
      return null;
    }
    return self.globalToLocal(
      icon.localToGlobal(icon.size.center(Offset.zero)),
    );
  }

  void _landLike() {
    unawaited(HapticFeedback.selectionClick());
    context.read<EngagementCubit>().likeFromDoubleTap(widget.episode);
  }

  void _like() {
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      if (_hearts.length == _maxHearts) _hearts.removeAt(0);
      _hearts.add((_heartIds++, _doubleTapAt));
    });
  }

  void _scrubTo(Offset finger) {
    _finger.value = finger;
    _scrub.value = (finger.dx / _width).clamp(0.0, 1.0);
  }

  void _scrubStart(DragStartDetails d) {
    unawaited(HapticFeedback.selectionClick());
    _frames.ensure(widget.controller.value.duration);
    _scrubTo(d.localPosition);
  }

  void _scrubEnd() {
    final share = _scrub.value;
    if (share != null) {
      _pool.seek(widget.episode, widget.controller.value.duration * share);
    }
    _scrubCancel();
  }

  void _scrubCancel() {
    _finger.value = null;
    _scrub.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _width = box.maxWidth;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pool.togglePause,
              onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
              onDoubleTap: _like,
              onHorizontalDragStart: _scrubStart,
              onHorizontalDragUpdate: (d) => _scrubTo(d.localPosition),
              onHorizontalDragEnd: (_) => _scrubEnd(),
              onHorizontalDragCancel: _scrubCancel,
            ),
            _PauseIndicator(episode: widget.episode),
            for (final (id, at) in _hearts)
              HeartBurst(
                key: ValueKey(id),
                at: at,
                target: _likeIconCentre,
                onArrive: _landLike,
                onDone: () =>
                    setState(() => _hearts.removeWhere((h) => h.$1 == id)),
              ),
            ValueListenableBuilder<Offset?>(
              valueListenable: _finger,
              builder: (context, finger, _) {
                if (finger == null) return const SizedBox.shrink();
                final length = widget.controller.value.duration;
                final at = length * (_scrub.value ?? 0);
                final frame = widget.frameAt?.call(
                  ScrubFrames.nearest(at, length),
                );
                final size = ScrubPreview.sizeFor(withFrame: frame != null);
                return Positioned(
                  left: (finger.dx - size.width / 2).clamp(
                    _edge,
                    box.maxWidth - size.width - _edge,
                  ),
                  top: (finger.dy - _bubbleGap - size.height).clamp(
                    _edge,
                    box.maxHeight - size.height - _edge,
                  ),
                  child: ScrubPreview(at: at, length: length, frame: frame),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: IgnorePointer(
                    child: ProgressBar(
                      controller: widget.controller,
                      scrub: _scrub,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PauseIndicator extends StatelessWidget {
  const _PauseIndicator({required this.episode});

  final int episode;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<int?>(
        valueListenable: context.read<VideoPool>().paused,
        builder: (context, paused, _) {
          final shown = paused == episode;
          return Center(
            child: AnimatedScale(
              scale: shown ? 1 : 1.4,
              duration: const Duration(milliseconds: 260),
              curve: shown ? Curves.easeOutBack : Curves.easeIn,
              child: AnimatedOpacity(
                opacity: shown ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: shown
                    ? Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: Color(0x66000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      )
                    : const SizedBox(width: 76, height: 76),
              ),
            ),
          );
        },
      ),
    );
  }
}
