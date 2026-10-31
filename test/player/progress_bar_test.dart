import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/player/ui/progress_bar.dart';
import 'package:video_player/video_player.dart';

import '../helpers/fake_video_controller.dart';

// The fake's videos are 15 s long.
FakeVideoController _video({required int at, bool playing = false}) {
  final c = FakeVideoController(Uri.parse('v'));
  c.value = c.value.copyWith(
    isInitialized: true,
    isPlaying: playing,
    position: Duration(seconds: at),
  );
  return c;
}

void main() {
  late ValueNotifier<double?> scrub;

  setUp(() => scrub = ValueNotifier(null));
  tearDown(() => scrub.dispose());

  Future<void> pumpBar(
    WidgetTester tester,
    FakeVideoController video, [
    ValueNotifier<double?>? scrubbing,
  ]) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 300,
          child: ProgressBar(controller: video, scrub: scrubbing ?? scrub),
        ),
      ),
    ),
  );

  double share(WidgetTester tester) =>
      (tester.widget<CustomPaint>(find.byKey(ProgressBar.paintKey)).painter!
              as ProgressBarPainter)
          .share
          .value;

  testWidgets('[OFF-2] after a reload the bar follows the new video', (
    tester,
  ) async {
    final first = _video(at: 3);
    await pumpBar(tester, first);
    expect(share(tester), closeTo(0.2, 0.001));

    final reloaded = _video(at: 9);
    await pumpBar(tester, reloaded);
    expect(share(tester), closeTo(0.6, 0.001));

    first.value = first.value.copyWith(position: const Duration(seconds: 12));
    await tester.pump();
    expect(share(tester), closeTo(0.6, 0.001), reason: 'old video ignored');
  });

  testWidgets('[SCRUB-2] a new scrub source drives the bar', (tester) async {
    final video = _video(at: 0);
    final other = ValueNotifier<double?>(null);
    addTearDown(other.dispose);
    await pumpBar(tester, video);
    await pumpBar(tester, video, other);

    other.value = 0.3;
    await tester.pump();
    expect(share(tester), closeTo(0.3, 0.001));

    scrub.value = 0.9;
    await tester.pump();
    expect(share(tester), closeTo(0.3, 0.001), reason: 'old source ignored');
  });

  testWidgets('[SCRUB-6] a seek the player never reports is let go after '
      '800 ms, even after a long play', (tester) async {
    // Plays for a while first, so the bar's clock is well past zero.
    final video = _video(at: 1, playing: true);
    await pumpBar(tester, video);
    await tester.pump(const Duration(seconds: 5));
    video.value = video.value.copyWith(
      isPlaying: false,
      position: const Duration(milliseconds: 1500),
    );
    await tester.pump();

    scrub.value = 0.6;
    await tester.pump();
    scrub.value = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(share(tester), closeTo(0.6, 0.001), reason: 'holding the target');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 16));
    expect(share(tester), closeTo(0.1, 0.001), reason: 'gave up waiting');
  });

  String timeLabel(WidgetTester tester) =>
      (tester.widget<CustomPaint>(find.byKey(ProgressBar.timeKey)).painter!
              as TimeLabelPainter)
          .label
          .value;

  testWidgets('[PLAY-12] the time reads elapsed/total and follows the scrub', (
    tester,
  ) async {
    await pumpBar(tester, _video(at: 7));
    expect(timeLabel(tester), '0:07/0:15');

    scrub.value = 0.6;
    await tester.pump();
    expect(timeLabel(tester), '0:09/0:15');
  });

  testWidgets('[PLAY-12] the time is muted at rest and full white while '
      'scrubbing', (tester) async {
    await pumpBar(tester, _video(at: 7));
    TimeLabelPainter label() =>
        tester.widget<CustomPaint>(find.byKey(ProgressBar.timeKey)).painter!
            as TimeLabelPainter;
    expect(label().color, TimeLabelPainter.resting);

    // The bar's spring settles well within a second.
    scrub.value = 0.6;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(label().color, TimeLabelPainter.scrubbing);

    scrub.value = null;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(label().color, TimeLabelPainter.resting);
  });

  test('[PLAY-12] times read m:ss', () {
    expect(ProgressBar.clock(Duration.zero), '0:00');
    expect(ProgressBar.clock(const Duration(seconds: 65)), '1:05');
    expect(ProgressBar.clock(const Duration(minutes: 5)), '5:00');
  });

  test('[SCRUB-11] buffered ranges become shares of the video', () {
    const length = Duration(seconds: 20);
    expect(
      bufferedShares([
        DurationRange(Duration.zero, const Duration(seconds: 5)),
        DurationRange(const Duration(seconds: 10), const Duration(seconds: 25)),
        DurationRange(const Duration(seconds: 8), const Duration(seconds: 8)),
      ], length),
      [(0.0, 0.25), (0.5, 1.0)],
      reason: 'clamped to the end; empty ranges dropped',
    );
    expect(
      bufferedShares([
        DurationRange(Duration.zero, const Duration(seconds: 5)),
      ], Duration.zero),
      isEmpty,
      reason: 'length not known yet',
    );
  });

  testWidgets('[SCRUB-11] the band follows the downloaded part, ahead of the '
      'fill, and repaints only when it changes', (tester) async {
    final video = _video(at: 3);
    await pumpBar(tester, video);
    final painter =
        tester.widget<CustomPaint>(find.byKey(ProgressBar.paintKey)).painter!
            as ProgressBarPainter;
    expect(painter.buffered.value, isEmpty);

    var repaints = 0;
    painter.buffered.addListener(() => repaints++);
    video.value = video.value.copyWith(
      buffered: [DurationRange(Duration.zero, const Duration(seconds: 9))],
    );
    await tester.pump();
    expect(painter.buffered.value, [(0.0, 0.6)]);
    expect(painter.buffered.value.single.$2, greaterThan(share(tester)));

    video.value = video.value.copyWith(position: const Duration(seconds: 4));
    await tester.pump();
    expect(repaints, 1, reason: 'a position report alone changes nothing');
  });
}
