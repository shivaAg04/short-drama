import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/state/feed_bloc.dart';
import 'package:rume/feed/ui/feed_top_bar.dart';
import 'package:rume/player/state/video_pool.dart';

import '../helpers/fake_video_controller.dart';

final List<Episode> _episodes = [
  for (var n = 1; n <= 7; n++)
    Episode(number: n, videoUrl: 'v$n', posterUrl: 'p$n'),
];

// The first ad break comes after E3.
const _adPage = 3;

void main() {
  late FeedBloc feed;
  late VideoPool pool;
  late int pageTaps;

  // Blocs are created inside the test body so they share its fake clock.
  Future<void> pumpBar(WidgetTester tester) async {
    feed = FeedBloc(episodes: _episodes);
    pool = VideoPool(create: FakeVideoController.new);
    pageTaps = 0;
    addTearDown(feed.close);
    addTearDown(pool.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider.value(
          value: pool,
          child: BlocProvider.value(
            value: feed,
            child: FeedTopBar(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => pageTaps++,
              ),
            ),
          ),
        ),
      ),
    );
  }

  double opacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(FeedTopBar.barKey),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  Future<void> touch(
    WidgetTester tester, [
    Offset at = const Offset(400, 400),
  ]) async {
    await tester.tapAt(at);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('[TOP-1] the feed opens with no bar', (tester) async {
    await pumpBar(tester);
    expect(opacity(tester), 0);
  });

  testWidgets('[TOP-2] a touch shows the bar and still reaches the page', (
    tester,
  ) async {
    await pumpBar(tester);
    await touch(tester);
    expect(opacity(tester), 1);
    expect(pageTaps, 1);
    await tester.pump(FeedTopBar.hideAfter);
  });

  testWidgets('[TOP-3] the bar hides 3 s after the last touch', (tester) async {
    await pumpBar(tester);
    await touch(tester);
    await tester.pump(const Duration(seconds: 2));
    await touch(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(opacity(tester), 1, reason: 'the second touch restarted the 3 s');

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(tester), 0);
  });

  testWidgets('[TOP-4] the sound button mutes and unmutes the pool', (
    tester,
  ) async {
    await pumpBar(tester);
    await touch(tester);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.tap(find.byKey(FeedTopBar.soundKey));
    await tester.pump(const Duration(milliseconds: 300));
    expect(pool.muted.value, isTrue);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(pageTaps, 1, reason: 'the button keeps its tap');

    await tester.tap(find.byKey(FeedTopBar.soundKey));
    expect(pool.muted.value, isFalse);
    await tester.pump(FeedTopBar.hideAfter);
  });

  testWidgets('[TOP-5] landing on an ad hides the bar, and touches there '
      'do not bring it back', (tester) async {
    await pumpBar(tester);
    await touch(tester);
    feed.add(const FeedFocused(_adPage));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(tester), 0);

    await touch(tester);
    expect(opacity(tester), 0);
    await tester.pump(FeedTopBar.hideAfter);
  });

  testWidgets('[TOP-6] while hidden, the sound button takes no touches', (
    tester,
  ) async {
    await pumpBar(tester);
    await touch(tester, tester.getCenter(find.byKey(FeedTopBar.soundKey)));
    expect(pool.muted.value, isFalse);
    expect(pageTaps, 1);
    await tester.pump(FeedTopBar.hideAfter);
  });
}
