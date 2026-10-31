import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:rume/core/theme/app_colors.dart';
import 'package:video_player/video_player.dart';

/// Where the bar should be drawn between the plugin's position reports
/// (roughly every 500 ms), so a playing video moves smoothly. Never runs more
/// than [maxLead] ahead of the last report, in case reports stall.
double interpolatedShare({
  required Duration reported,
  required Duration length,
  required Duration sinceReport,
  required bool advancing,
  Duration maxLead = const Duration(milliseconds: 600),
}) {
  final total = length.inMicroseconds;
  if (total <= 0) return 0;
  final lead = advancing
      ? math.min(sinceReport.inMicroseconds, maxLead.inMicroseconds)
      : 0;
  return ((reported.inMicroseconds + lead) / total).clamp(0.0, 1.0);
}

/// The player's downloaded ranges as shares of [length], for the lighter
/// band on the track (SCRUB-11). Empty until the length is known.
List<(double, double)> bufferedShares(
  List<DurationRange> ranges,
  Duration length,
) {
  final total = length.inMicroseconds;
  if (total <= 0) return const [];
  double at(Duration d) => (d.inMicroseconds / total).clamp(0.0, 1.0);
  return [
    for (final r in ranges)
      if (r.end > r.start) (at(r.start), at(r.end)),
  ];
}

/// Custom-painted progress bar. While [scrub] is set it shows that instead
/// of playback and swells on a spring. Playback is pushed to the painter
/// through listenables, so position updates repaint and never rebuild.
class ProgressBar extends StatefulWidget {
  const ProgressBar({required this.controller, required this.scrub, super.key});

  final VideoPlayerController controller;

  /// Share of the video the finger is on, while scrubbing.
  final ValueListenable<double?> scrub;

  static const ValueKey<String> paintKey = ValueKey('progress-paint');
  static const ValueKey<String> timeKey = ValueKey('progress-time');

  /// `m:ss`, as the label above the bar shows it.
  static String clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  static const double resting = 3;
  static const double scrubbing = 10;

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar>
    with TickerProviderStateMixin {
  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 400,
    ratio: 0.6,
  );

  // The seek target is held until the player gets within this of it.
  static const _caughtUp = 0.02;
  static const _holdAtMost = Duration(milliseconds: 800);

  late final AnimationController _thickness = AnimationController.unbounded(
    vsync: this,
    value: ProgressBar.resting,
  );
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<double> _share = ValueNotifier(0);
  // Set only when the ranges change, not on every position report.
  final ValueNotifier<List<(double, double)>> _buffered = ValueNotifier(
    const [],
  );
  // Only changes when the shown second does, so the label repaints once a
  // second however often the bar does.
  final ValueNotifier<String> _time = ValueNotifier('');

  // The bar's clock. The ticker's elapsed time restarts from zero whenever
  // it starts again, so each run is added onto where the last one ended.
  Duration _now = Duration.zero;
  Duration _clockBase = Duration.zero;
  Duration _reported = Duration.zero;
  Duration _reportedAt = Duration.zero;
  double? _landing;
  Duration _landingAt = Duration.zero;
  double? _lastScrub;

  VideoPlayerValue get _video => widget.controller.value;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onVideo);
    widget.scrub.addListener(_onScrub);
    _reported = _video.position;
    _buffered.value = bufferedShares(_video.buffered, _video.duration);
    _refresh();
    _syncTicker();
  }

  @override
  void didUpdateWidget(ProgressBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onVideo);
      widget.controller.addListener(_onVideo);
      _landing = null;
      _onVideo();
    }
    if (old.scrub != widget.scrub) {
      old.scrub.removeListener(_onScrub);
      widget.scrub.addListener(_onScrub);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVideo);
    widget.scrub.removeListener(_onScrub);
    _ticker.dispose();
    _thickness.dispose();
    _share.dispose();
    _buffered.dispose();
    _time.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _now = _clockBase + elapsed;
    _refresh();
  }

  void _onVideo() {
    if (_video.position != _reported) {
      _reported = _video.position;
      _reportedAt = _now;
    }
    final buffered = bufferedShares(_video.buffered, _video.duration);
    if (!listEquals(buffered, _buffered.value)) _buffered.value = buffered;
    _refresh();
    _syncTicker();
  }

  void _onScrub() {
    final scrub = widget.scrub.value;
    if (scrub == null && _lastScrub != null) {
      _landing = _lastScrub;
      _landingAt = _now;
    } else if (scrub != null) {
      _landing = null;
    }
    _lastScrub = scrub;

    final target = scrub == null ? ProgressBar.resting : ProgressBar.scrubbing;
    _thickness.animateWith(
      SpringSimulation(_spring, _thickness.value, target, _thickness.velocity),
    );
    _refresh();
    _syncTicker();
  }

  void _refresh() {
    final playing = interpolatedShare(
      reported: _reported,
      length: _video.duration,
      sinceReport: _now - _reportedAt,
      advancing: _video.isPlaying && !_video.isBuffering,
    );

    final landing = _landing;
    if (landing != null &&
        ((playing - landing).abs() < _caughtUp ||
            _now - _landingAt > _holdAtMost)) {
      _landing = null;
    }

    _share.value = widget.scrub.value ?? _landing ?? playing;
    final length = _video.duration;
    _time.value =
        '${ProgressBar.clock(length * _share.value)}/'
        '${ProgressBar.clock(length)}';
  }

  // Ticks only while something moves: playback or a landing seek.
  void _syncTicker() {
    final run = _video.isPlaying || _landing != null;
    if (run && !_ticker.isActive) {
      _clockBase = _now;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            key: ProgressBar.timeKey,
            size: const Size(double.infinity, 18),
            painter: TimeLabelPainter(label: _time, thickness: _thickness),
          ),
          CustomPaint(
            key: ProgressBar.paintKey,
            size: const Size(double.infinity, 24),
            painter: ProgressBarPainter(
              share: _share,
              buffered: _buffered,
              thickness: _thickness,
              scrub: widget.scrub,
            ),
          ),
        ],
      ),
    );
  }
}

/// The `0:07/0:15` above the bar, painted so a new second repaints this
/// strip and rebuilds nothing. Muted at rest, it brightens with the bar while
/// scrubbing (PLAY-12).
class TimeLabelPainter extends CustomPainter {
  TimeLabelPainter({required this.label, required this.thickness})
    : super(repaint: Listenable.merge([label, thickness]));

  final ValueListenable<String> label;

  /// The bar's thickness, which says how far into a scrub it is.
  final Animation<double> thickness;

  static const Color resting = Color(0x73FFFFFF);
  static const Color scrubbing = Color(0xFFFFFFFF);

  /// Follows the bar's spring, so it brightens and fades with it.
  Color get color => Color.lerp(
    resting,
    scrubbing,
    ((thickness.value - ProgressBar.resting) /
            (ProgressBar.scrubbing - ProgressBar.resting))
        .clamp(0.0, 1.0),
  )!;

  static const _style = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: label.value,
        style: _style.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Inset to line up with the episode chip above it.
    text
      ..paint(canvas, Offset(2, (size.height - text.height) / 2))
      ..dispose();
  }

  @override
  bool shouldRepaint(TimeLabelPainter old) =>
      old.label != label || old.thickness != thickness;
}

class ProgressBarPainter extends CustomPainter {
  ProgressBarPainter({
    required this.share,
    required this.buffered,
    required this.thickness,
    required this.scrub,
  }) : super(repaint: Listenable.merge([share, buffered, thickness, scrub]));

  static const _fill = LinearGradient(
    colors: [AppColors.primaryLight, AppColors.primaryLighter],
  );

  final ValueListenable<double> share;

  /// Downloaded ranges, as shares of the video (SCRUB-11).
  final ValueListenable<List<(double, double)>> buffered;
  final Animation<double> thickness;
  final ValueListenable<double?> scrub;

  @override
  void paint(Canvas canvas, Size size) {
    final t = thickness.value.clamp(1.0, 20.0);
    final y = size.height / 2;
    final radius = Radius.circular(t / 2);
    final filled = size.width * share.value;

    canvas.drawRRect(
      RRect.fromLTRBR(0, y - t / 2, size.width, y + t / 2, radius),
      Paint()..color = const Color(0x40FFFFFF),
    );
    final band = Paint()..color = const Color(0x73FFFFFF);
    for (final (start, end) in buffered.value) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          size.width * start,
          y - t / 2,
          size.width * end,
          y + t / 2,
          radius,
        ),
        band,
      );
    }
    final fill = RRect.fromLTRBR(0, y - t / 2, filled, y + t / 2, radius);
    canvas
      // A soft glow, so a thin bar still reads over a dark scene.
      ..drawRRect(
        fill,
        Paint()
          ..color = AppColors.primaryLight.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawRRect(
        fill,
        // The brand's lighter end: its deep blue vanishes on a dark video at
        // this width. Spans the whole bar, so the colour under a point never
        // shifts as the fill grows.
        Paint()
          ..shader = _fill.createShader(
            Rect.fromLTWH(0, 0, size.width, size.height),
          ),
      );

    // The thumb grows in with the bar.
    final grow =
        ((t - ProgressBar.resting) /
                (ProgressBar.scrubbing - ProgressBar.resting))
            .clamp(0.0, 1.0);
    if (grow > 0) {
      final thumb = Offset(filled.clamp(0, size.width), y);
      canvas
        ..drawCircle(
          thumb,
          9 * grow,
          Paint()
            ..color = const Color(0x55000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        )
        ..drawCircle(thumb, 8 * grow, Paint()..color = AppColors.primaryLight)
        ..drawCircle(thumb, 5 * grow, Paint()..color = const Color(0xFFFFFFFF));
    }
  }

  @override
  bool shouldRepaint(ProgressBarPainter old) =>
      old.share != share ||
      old.buffered != buffered ||
      old.thickness != thickness ||
      old.scrub != scrub;
}
