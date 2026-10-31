import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rume/core/theme/app_colors.dart';
import 'package:rume/engagement/data/share_service.dart';
import 'package:rume/engagement/domain/compact_count.dart';
import 'package:rume/engagement/state/engagement_cubit.dart';
import 'package:rume/engagement/ui/comments_sheet.dart';
import 'package:rume/feed/domain/episode.dart';

/// Like, comment, share and save down the right edge. [likeKey] marks the
/// like icon so the double-tap heart can fly into it.
class ActionRail extends StatelessWidget {
  const ActionRail({required this.episode, required this.likeKey, super.key});

  final Episode episode;
  final GlobalKey likeKey;

  static const ValueKey<String> likeButtonKey = ValueKey('rail-like');
  static const ValueKey<String> commentButtonKey = ValueKey('rail-comment');
  static const ValueKey<String> shareButtonKey = ValueKey('rail-share');
  static const ValueKey<String> saveButtonKey = ValueKey('rail-save');
  static const ValueKey<String> likeBurstKey = ValueKey('rail-like-burst');

  static const _shadow = [Shadow(color: Color(0x80000000), blurRadius: 12)];

  Future<void> _share(BuildContext context) async {
    unawaited(HapticFeedback.selectionClick());
    final engagement = context.read<EngagementCubit>();
    final shared = await context.read<ShareService>().share(episode);
    if (shared) engagement.recordShare(episode.number);
  }

  void _openComments(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    final engagement = context.read<EngagementCubit>();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (_) => BlocProvider.value(
          value: engagement,
          child: CommentsSheet(episode: episode.number),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EngagementCubit, EngagementState, EpisodeEngagement>(
      selector: (s) => s.of(episode.number),
      builder: (context, e) {
        final engagement = context.read<EngagementCubit>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RailButton(
              key: likeButtonKey,
              label: compactCount(e.likes),
              active: e.liked,
              burstKey: likeBurstKey,
              burst: AppColors.heart,
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                engagement.toggleLike(episode.number);
              },
              icon: SizedBox(
                key: likeKey,
                child: Icon(
                  e.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 32,
                  color: e.liked ? AppColors.heart : Colors.white,
                  shadows: _shadow,
                ),
              ),
            ),
            _RailButton(
              key: commentButtonKey,
              label: compactCount(e.commentCount),
              onTap: () => _openComments(context),
              icon: const Icon(
                Icons.mode_comment_outlined,
                size: 29,
                color: Colors.white,
                shadows: _shadow,
              ),
            ),
            _RailButton(
              key: shareButtonKey,
              label: compactCount(e.shares),
              onTap: () => _share(context),
              // Tilted like the paper plane every feed app uses.
              icon: Transform.rotate(
                angle: -math.pi / 9,
                child: const Icon(
                  Icons.send_outlined,
                  size: 28,
                  color: Colors.white,
                  shadows: _shadow,
                ),
              ),
            ),
            _RailButton(
              key: saveButtonKey,
              active: e.saved,
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                engagement.toggleSave(episode.number);
              },
              icon: Icon(
                e.saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 31,
                color: e.saved ? AppColors.primaryLighter : Colors.white,
                shadows: _shadow,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// An icon with an optional count. It shrinks under the finger, and pops on
/// an underdamped spring when [active] turns on, sending out a ripple in the
/// [burst] colour if one is given.
class _RailButton extends StatefulWidget {
  const _RailButton({
    required this.icon,
    required this.onTap,
    this.label,
    this.active = false,
    this.burst,
    this.burstKey,
    super.key,
  });

  final Widget icon;
  final String? label;
  final bool active;
  final Color? burst;
  final Key? burstKey;
  final VoidCallback onTap;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton>
    with TickerProviderStateMixin {
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 520,
    ratio: 0.35,
  );

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(_RailButton old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      // Kick it small with upward velocity: it overshoots, then settles.
      _scale.animateWith(SpringSimulation(_spring, 0.6, 1, 14));
      if (widget.burst != null) _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _press(bool down) {
    _scale.animateWith(
      SpringSimulation(_spring, _scale.value, down ? 0.85 : 1, _scale.velocity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              key: widget.burstKey,
              painter: widget.burst == null
                  ? null
                  : RailBurstPainter(progress: _burst, color: widget.burst!),
              child: ScaleTransition(scale: _scale, child: widget.icon),
            ),
            if (label != null) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  shadows: ActionRail._shadow,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A ring that grows out of the icon and thins away, with dots thrown past
/// it. Paints outside its own box, around whatever it wraps.
class RailBurstPainter extends CustomPainter {
  RailBurstPainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  static const _dots = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0 || t == 1) return;
    final out = Curves.easeOutCubic.transform(t);
    final centre = size.center(Offset.zero);
    final base = size.shortestSide / 2;

    canvas.drawCircle(
      centre,
      base * (0.8 + 0.9 * out),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - out)
        ..color = color.withValues(alpha: 1 - t),
    );

    final dot = Paint()..color = color.withValues(alpha: 1 - t * t);
    for (var i = 0; i < _dots; i++) {
      final angle = i * 2 * math.pi / _dots + math.pi / _dots;
      final reach = base * (1.1 + 1.1 * out);
      canvas.drawCircle(
        centre + Offset(math.cos(angle), math.sin(angle)) * reach,
        2.6 * (1 - t),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(RailBurstPainter old) =>
      old.progress != progress || old.color != color;
}
