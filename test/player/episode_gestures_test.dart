import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/engagement/data/share_service.dart';
import 'package:rume/engagement/state/engagement_cubit.dart';
import 'package:rume/engagement/ui/action_rail.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/state/feed_bloc.dart';
import 'package:rume/paywall/state/paywall_cubit.dart';
import 'package:rume/player/domain/playback_plan.dart';
import 'package:rume/player/domain/scrub_frames.dart';
import 'package:rume/player/state/video_pool.dart';
import 'package:rume/player/ui/episode_chip.dart';
import 'package:rume/player/ui/episode_page.dart';
import 'package:rume/player/ui/heart_burst.dart';
import 'package:rume/player/ui/load_failed_card.dart';
import 'package:rume/player/ui/progress_bar.dart';
import 'package:rume/player/ui/scrub_preview.dart';
import 'package:rume/shared/brand_skeleton.dart';

import '../helpers/fake_share_service.dart';
import '../helpers/fake_video_controller.dart';

const _episode = Episode(number: 1, videoUrl: 'v1', posterUrl: 'p1');

// Hosted where frames can be rendered (SCRUB-10).
const _framed = Episode(
  number: 1,
  videoUrl: 'https://res.cloudinary.com/demo/video/upload/ep1.mp4',
  posterUrl: 'p1',
);

// Long enough to need more than two lines (PLAY-13).
const _described = Episode(
  number: 1,
  videoUrl: 'v1',
  posterUrl: 'p1',
  series: 'Alright Originals',
  description:
      'A stranger shows up at the door with a name nobody has said out loud '
      'in years. Everyone pretends not to recognise it. Not everyone is good '
      'at pretending, and by the end of the night the whole house knows '
      'exactly who she is and why she came back after all this time away.',
);

// The test surface is 800 x 600.
const _width = 800.0;

void main() {
  late FakeVideoController video;
  late VideoPool pool;
  late EngagementCubit engagement;

  // Blocs are created inside the test body so they share its fake clock.
  Future<void> pumpReadyEpisode(
    WidgetTester tester, {
    bool fail = false,
    bool finish = true,
    Episode episode = _episode,
  }) async {
    final feed = FeedBloc(episodes: [_episode]);
    final paywall = PaywallCubit();
    engagement = EngagementCubit(episodes: [_episode]);
    addTearDown(feed.close);
    addTearDown(paywall.close);
    addTearDown(engagement.close);
    pool = VideoPool(
      create: (uri) => video = FakeVideoController(uri),
      deferDispose: (dispose) => dispose(),
    );
    addTearDown(pool.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: pool),
            RepositoryProvider<ShareService>.value(value: FakeShareService()),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: feed),
              BlocProvider.value(value: paywall),
              BlocProvider.value(value: engagement),
            ],
            // Stands in for the feed's vertical PageView, which competes with
            // the scrub in the gesture arena.
            child: Scaffold(
              body: GestureDetector(
                onVerticalDragUpdate: (_) {},
                child: EpisodePage(episode: episode, total: 1),
              ),
            ),
          ),
        ),
      ),
    );
    pool.update(
      const PlaybackPlan(active: 1, slots: [VideoSlot(episode: 1, url: 'v1')]),
    );
    if (finish) fail ? video.failInit() : video.completeInit();
    await tester.pump();
    await tester.pump();
  }

  Future<void> doubleTapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(at);
    await tester.pump();
  }

  // Gesture timers (double-tap) and hearts must finish before teardown.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 2));

  ProgressBarPainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byKey(ProgressBar.paintKey)).painter!
          as ProgressBarPainter;

  testWidgets('[LIKE-1] a double-tap puts a heart on the touch point', (
    tester,
  ) async {
    await pumpReadyEpisode(tester);
    await doubleTapAt(tester, const Offset(220, 310));

    final heart = find.byType(HeartBurst);
    expect(heart, findsOneWidget);
    expect(tester.getCenter(heart), const Offset(220, 310));
    await settle(tester);
  });

  testWidgets('[LIKE-2] the heart springs past full size, then fades away', (
    tester,
  ) async {
    await pumpReadyEpisode(tester);
    await doubleTapAt(tester, const Offset(400, 300));

    var largest = 0.0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final scale = tester
          .widget<Transform>(find.byKey(HeartBurst.scaleKey))
          .transform
          .getMaxScaleOnAxis();
      if (scale > largest) largest = scale;
    }
    expect(largest, greaterThan(1.05));

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HeartBurst), findsNothing);
  });

  testWidgets('[LIKE-5] the heart flies into the like icon, then likes', (
    tester,
  ) async {
    await pumpReadyEpisode(tester);
    const from = Offset(200, 200);
    await doubleTapAt(tester, from);
    final target = tester.getCenter(find.byKey(ActionRail.likeButtonKey));

    await tester.pump(const Duration(milliseconds: 200));
    final early =
        (tester.getCenter(find.byKey(HeartBurst.scaleKey)) - target).distance;
    await tester.pump(const Duration(milliseconds: 650));
    final late =
        (tester.getCenter(find.byKey(HeartBurst.scaleKey)) - target).distance;
    expect(late, lessThan(early / 3));
    expect(engagement.state.of(1).liked, isFalse, reason: 'not landed yet');

    await tester.pump(const Duration(milliseconds: 400));
    expect(engagement.state.of(1).liked, isTrue);
    await settle(tester);
    expect(find.byType(HeartBurst), findsNothing);
  });

  testWidgets('[RAIL-1] a playable episode shows the rail', (tester) async {
    await pumpReadyEpisode(tester);
    expect(find.byType(ActionRail), findsOneWidget);
  });

  testWidgets('[LIKE-3] quick double-taps stack independent hearts', (
    tester,
  ) async {
    await pumpReadyEpisode(tester);
    await doubleTapAt(tester, const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 350));
    await doubleTapAt(tester, const Offset(500, 300));

    expect(find.byType(HeartBurst), findsNWidgets(2));
    await settle(tester);
  });

  testWidgets('[PLAY-8] a single tap pauses and a second one resumes', (
    tester,
  ) async {
    await pumpReadyEpisode(tester);
    expect(video.value.isPlaying, isTrue);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 350));
    expect(video.value.isPlaying, isFalse);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 350));
    expect(video.value.isPlaying, isTrue);
  });

  testWidgets('[SCRUB-1] the progress bar is custom painted', (tester) async {
    await pumpReadyEpisode(tester);
    expect(painter(tester), isA<ProgressBarPainter>());
  });

  testWidgets('[SCRUB-2] [SCRUB-5] a horizontal drag anywhere scrubs, '
      'with the preview above the finger', (tester) async {
    await pumpReadyEpisode(tester);
    final drag = await tester.startGesture(const Offset(100, 300));
    await drag.moveTo(const Offset(130, 300));
    await drag.moveTo(const Offset(_width / 2, 280));
    await tester.pump();

    expect(find.text('00:07 / 00:15'), findsOneWidget);
    final bubble = tester.getRect(find.byType(ScrubPreview));
    expect(bubble.center.dx, closeTo(_width / 2, 0.5));
    expect(bubble.bottom, lessThan(280));

    await drag.up();
    await settle(tester);
  });

  testWidgets('[SCRUB-5] the preview stays on screen at the edges', (
    tester,
  ) async {
    await pumpReadyEpisode(tester);
    final drag = await tester.startGesture(const Offset(400, 300));
    await drag.moveTo(const Offset(430, 300));
    await drag.moveTo(const Offset(_width - 2, 300));
    await tester.pump();

    final bubble = tester.getRect(find.byType(ScrubPreview));
    expect(bubble.right, lessThanOrEqualTo(_width));
    await drag.up();
    await settle(tester);
  });

  testWidgets('[SCRUB-3] a vertical drag does not scrub', (tester) async {
    await pumpReadyEpisode(tester);
    final drag = await tester.startGesture(const Offset(400, 400));
    await drag.moveTo(const Offset(400, 370));
    await drag.moveTo(const Offset(410, 150));
    await tester.pump();

    expect(find.byType(ScrubPreview), findsNothing);
    await drag.up();
    await settle(tester);
  });

  testWidgets('[SCRUB-4] the bar swells while scrubbing and settles after', (
    tester,
  ) async {
    await pumpReadyEpisode(tester);
    final resting = painter(tester).thickness.value;

    final drag = await tester.startGesture(const Offset(100, 300));
    await drag.moveTo(const Offset(140, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(painter(tester).thickness.value, greaterThan(resting * 2.5));

    await drag.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(painter(tester).thickness.value, closeTo(resting, 0.1));
  });

  testWidgets('[SCRUB-6] releasing seeks and the bar holds the target', (
    tester,
  ) async {
    await pumpReadyEpisode(tester);
    final drag = await tester.startGesture(const Offset(100, 300));
    await drag.moveTo(const Offset(140, 300));
    await drag.moveTo(const Offset(_width * 0.6, 300));
    await drag.up();
    await tester.pump();

    expect(video.value.position, const Duration(seconds: 9));
    expect(painter(tester).share.value, closeTo(0.6, 0.01));
    expect(find.byType(ScrubPreview), findsNothing);
    await settle(tester);
  });

  testWidgets('[OFF-1] a failed video shows the card, not the skeleton', (
    tester,
  ) async {
    await pumpReadyEpisode(tester, fail: true);
    expect(find.byType(LoadFailedCard), findsOneWidget);
    expect(find.text("Couldn't load this episode"), findsOneWidget);
    expect(find.byType(BrandSkeleton), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('[OFF-3] [OFF-2] Try again reloads, and success swaps the card '
      'for the playing video', (tester) async {
    await pumpReadyEpisode(tester, fail: true);
    final failed = video;

    await tester.tap(find.byKey(LoadFailedCard.retryKey));
    await tester.pump();
    expect(video, isNot(same(failed)), reason: 'a new attempt started');
    expect(find.byType(LoadFailedCard), findsOneWidget);

    video.completeInit();
    await tester.pump();
    await tester.pump();
    expect(find.byType(LoadFailedCard), findsNothing);
    expect(video.value.isPlaying, isTrue);
    await settle(tester);
  });

  Image? frameShown(WidgetTester tester) {
    final found = find.byKey(ScrubPreview.frameKey);
    return found.evaluate().isEmpty ? null : tester.widget<Image>(found);
  }

  testWidgets('[SCRUB-8] the preview shows the frame at the nearest second, '
      'above the time', (tester) async {
    await pumpReadyEpisode(tester, episode: _framed);
    final drag = await tester.startGesture(const Offset(100, 300));
    await drag.moveTo(const Offset(130, 300));
    await drag.moveTo(const Offset(_width / 2, 300));
    await tester.pump();

    // 15 s × 0.5 = 7.5 s → the frame at 8 s.
    expect(
      frameShown(tester)!.image,
      NetworkImage(ScrubFrames.urlAt(_framed.videoUrl, 8)!),
    );
    expect(frameShown(tester)!.gaplessPlayback, isTrue);
    final thumb = tester.getRect(find.byKey(ScrubPreview.frameKey));
    final time = tester.getRect(find.text('00:07 / 00:15'));
    expect(thumb.bottom, lessThan(time.top));
    expect(tester.getRect(find.byType(ScrubPreview)).bottom, lessThan(300));

    await drag.moveTo(const Offset(_width * 0.6, 300));
    await tester.pump();
    expect(
      frameShown(tester)!.image,
      NetworkImage(ScrubFrames.urlAt(_framed.videoUrl, 9)!),
    );
    await drag.up();
    await settle(tester);
  });

  testWidgets('[SCRUB-10] a video the host cannot render shows the time '
      'alone', (tester) async {
    await pumpReadyEpisode(tester);
    final drag = await tester.startGesture(const Offset(100, 300));
    await drag.moveTo(const Offset(130, 300));
    await drag.moveTo(const Offset(_width / 2, 300));
    await tester.pump();

    expect(find.text('00:07 / 00:15'), findsOneWidget);
    expect(frameShown(tester), isNull);
    await drag.up();
    await settle(tester);
  });

  testWidgets('[PLAY-11] [PLAY-5] while the video loads the poster and '
      'chip show, with no shimmer', (tester) async {
    await pumpReadyEpisode(tester, finish: false);
    expect(find.text('Episode 1/1'), findsOneWidget);
    expect(find.byType(Poster), findsOneWidget);
    expect(find.byType(BrandSkeleton), findsNothing);

    video.completeInit();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Episode 1/1'), findsOneWidget);
    final chip = tester.getSize(find.byType(EpisodeChip));
    expect(chip.height, EpisodeChip.size.height);
    expect(chip.width, lessThan(200), reason: 'hugs its label');
  });

  testWidgets('[PLAY-11] a failed episode keeps its chip', (tester) async {
    await pumpReadyEpisode(tester, fail: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Episode 1/1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('[PLAY-13] the series and a two-line description sit under '
      'the chip; a tap opens it upwards, another closes it', (tester) async {
    await pumpReadyEpisode(tester, episode: _described);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Alright Originals'), findsOneWidget);

    final description = find.byType(EpisodeDescription);
    Text text() => tester.widget<Text>(
      find.descendant(of: description, matching: find.byType(Text)),
    );
    expect(text().maxLines, 2);
    expect(text().overflow, TextOverflow.ellipsis);
    final chip = tester.getTopLeft(find.byType(EpisodeChip));
    final closed = tester.getSize(description).height;
    expect(tester.getTopLeft(description).dy, greaterThan(chip.dy));

    await tester.tap(description);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(text().maxLines, isNull);
    expect(tester.getSize(description).height, greaterThan(closed));
    expect(
      tester.getTopLeft(find.byType(EpisodeChip)).dy,
      lessThan(chip.dy),
      reason: 'grows upwards',
    );

    await tester.tap(description);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(text().maxLines, 2);
    expect(tester.getSize(description).height, closed);
    await settle(tester);
  });

  testWidgets('[PLAY-13] tapping the description neither pauses nor likes', (
    tester,
  ) async {
    await pumpReadyEpisode(tester, episode: _described);
    await tester.pump(const Duration(milliseconds: 300));
    final description = find.byType(EpisodeDescription);

    await tester.tap(description);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(description);
    await tester.pump(const Duration(milliseconds: 350));
    expect(video.value.isPlaying, isTrue);
    expect(find.byType(HeartBurst), findsNothing);
    await settle(tester);
  });
}
