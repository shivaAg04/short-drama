import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/engagement/data/share_service.dart';
import 'package:rume/engagement/state/engagement_cubit.dart';
import 'package:rume/engagement/ui/action_rail.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/state/feed_bloc.dart';
import 'package:rume/paywall/state/paywall_cubit.dart';
import 'package:rume/paywall/ui/paywall_overlay.dart';
import 'package:rume/paywall/ui/shimmer_button.dart';
import 'package:rume/player/state/video_pool.dart';
import 'package:rume/player/ui/episode_page.dart';

import '../helpers/fake_share_service.dart';
import '../helpers/fake_video_controller.dart';

final List<Episode> _episodes = [
  for (var n = 1; n <= 7; n++)
    Episode(number: n, videoUrl: 'v$n', posterUrl: 'p$n'),
];

// With both ad breaks in the feed, E7 is the ninth page.
const _e7Page = 8;

void main() {
  late FeedBloc feed;
  late PaywallCubit paywall;
  late VideoPool pool;

  // Built per test, inside testWidgets: blocs made in setUp would run on the
  // real clock, not the test's, and their events would never arrive.
  Widget harness() {
    feed = FeedBloc(episodes: _episodes);
    paywall = PaywallCubit();
    pool = VideoPool(create: FakeVideoController.new);
    final engagement = EngagementCubit(episodes: _episodes);
    addTearDown(engagement.close);
    addTearDown(feed.close);
    addTearDown(paywall.close);
    return MaterialApp(
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
          child: Scaffold(body: EpisodePage(episode: _episodes.last, total: 7)),
        ),
      ),
    );
  }

  // Lets the bloc emit (async), then builds the frame that reacts to it.
  Future<void> focus(WidgetTester tester, int page) async {
    feed.add(FeedFocused(page));
    await tester.pump(Duration.zero);
    await tester.pump();
  }

  double cardOffset(WidgetTester tester) => tester
      .widget<FractionalTranslation>(find.byKey(PaywallOverlay.cardKey))
      .translation
      .dy;

  double opacityOf(WidgetTester tester, Key key) => tester
      .widget<FadeTransition>(
        find
            .descendant(
              of: find.byKey(key),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  testWidgets('[PAY-1] [PAY-5] the poster is blurred before the user lands', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byKey(PaywallOverlay.cardKey), findsNothing);
  });

  testWidgets('[RAIL-8] a locked episode has no rail', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.byType(ActionRail), findsNothing);
  });

  testWidgets('[PAY-1] landing shows the paywall in the same frame', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await focus(tester, _e7Page);
    expect(find.byKey(PaywallOverlay.cardKey), findsOneWidget);
    expect(find.text('Unlock Episode'), findsOneWidget);
  });

  testWidgets('[PAY-6] the card slides up and overshoots before settling', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await focus(tester, _e7Page);
    expect(cardOffset(tester), closeTo(1, 0.01));

    var highest = 1.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      highest = cardOffset(tester) < highest ? cardOffset(tester) : highest;
    }
    expect(highest, lessThan(0), reason: 'card should overshoot its rest');
    expect(cardOffset(tester), closeTo(0, 0.02));
  });

  testWidgets('[PAY-6] the title arrives before the call to action', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await focus(tester, _e7Page);
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      opacityOf(tester, PaywallOverlay.titleKey),
      greaterThan(opacityOf(tester, PaywallOverlay.ctaKey)),
    );
  });

  testWidgets('[PAY-4] returning to the locked episode replays the entrance', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await focus(tester, _e7Page);
    await tester.pump(const Duration(seconds: 2));
    expect(cardOffset(tester), closeTo(0, 0.02));

    await focus(tester, _e7Page - 1);
    await tester.pump(const Duration(seconds: 1));
    await focus(tester, _e7Page);
    expect(cardOffset(tester), closeTo(1, 0.01));
  });

  testWidgets('[PAY-7] the button shimmers once every 3 seconds', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await focus(tester, _e7Page);
    bool glinting() => tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(ShimmerButton),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((p) => p.foregroundPainter)
        .whereType<GlintPainter>()
        .single
        .lit;

    expect(glinting(), isFalse, reason: 'waits for the cascade');
    await tester.pump(ShimmerButton.firstGlint);
    await tester.pump(const Duration(milliseconds: 200));
    expect(glinting(), isTrue);

    await tester.pump(ShimmerButton.glint);
    expect(glinting(), isFalse, reason: 'idle between glints');

    await tester.pump(ShimmerButton.interval - ShimmerButton.glint);
    expect(glinting(), isTrue);

    // The painter draws on a canvas only mid-glint.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('[PAY-8] unlocking dismisses the paywall and clears the blur', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await focus(tester, _e7Page);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Unlock Episode'));
    await tester.pump();
    expect(find.text('Unlocking…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(paywall.state.unlocked, isTrue);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byKey(PaywallOverlay.cardKey), findsNothing);
  });

  testWidgets('[PAY-2] taps and double-taps on a locked episode do nothing', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await focus(tester, _e7Page);
    await tester.pump(const Duration(seconds: 1));

    await tester.tapAt(const Offset(400, 60));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(const Offset(400, 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(400, 60));
    await tester.pump(const Duration(milliseconds: 400));
    expect(paywall.state.isLocked(7), isTrue);
    expect(paywall.state.purchasing, isFalse);
  });

  testWidgets('[PAY-8] pressing unlock and sliding off buys nothing', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await focus(tester, _e7Page);
    await tester.pump(const Duration(seconds: 1));

    final press = await tester.startGesture(
      tester.getCenter(find.text('Unlock Episode')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await press.moveBy(const Offset(0, -200));
    await press.up();
    await tester.pump(const Duration(milliseconds: 800));
    expect(paywall.state.purchasing, isFalse);
    expect(paywall.state.unlocked, isFalse);
  });

  testWidgets('[PLAY-11] a locked episode shows its chip', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Episode 7/7'), findsOneWidget);
  });

  testWidgets('[PAY-11] the card opens on a fan of the locked clip and its '
      'two nearest episodes', (tester) async {
    await tester.pumpWidget(harness());
    await focus(tester, _e7Page);
    final fan = find.byKey(PaywallOverlay.fanKey);
    expect(fan, findsOneWidget);

    List<double> tilts() => tester
        .widgetList<Transform>(
          find.descendant(of: fan, matching: find.byType(Transform)),
        )
        .map((t) => t.transform.getRotation().entry(1, 0))
        .where((sin) => sin != 0)
        .toList();
    expect(tilts(), isEmpty, reason: 'closed as the card starts to rise');

    await tester.pump(const Duration(seconds: 1));
    final posters = tester
        .widgetList<Image>(
          find.descendant(of: fan, matching: find.byType(Image)),
        )
        .map((i) => (i.image as NetworkImage).url)
        .toList();
    expect(posters, [
      'p6',
      'p5',
      'p7',
    ], reason: 'sides behind, locked in front');
    expect(
      find.descendant(of: fan, matching: find.text('EP 7')),
      findsOneWidget,
    );
    expect(tilts(), hasLength(2));
    expect(tilts().first, lessThan(0));
    expect(tilts().last, greaterThan(0));
  });

  testWidgets('[PAY-6] without posters the card leads with a lock icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PaywallOverlay(
          episodeNumber: 7,
          locked: true,
          focused: true,
          purchasing: false,
          onUnlock: () {},
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(PaywallOverlay.fanKey), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
  });
}
