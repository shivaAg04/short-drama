import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/ui/feed_screen.dart';
import 'package:rume/player/state/video_pool.dart';
import 'package:rume/player/ui/episode_page.dart';
import 'package:rume/shared/brand_skeleton.dart';
import 'package:rume/splash/brand_splash.dart';

import '../helpers/fake_video_controller.dart';

final List<Episode> _episodes = [
  for (var n = 1; n <= 7; n++)
    Episode(number: n, videoUrl: 'v$n', posterUrl: 'p$n'),
];

Widget _app() => MaterialApp(
  home: FeedScreen(
    episodes: _episodes,
    pool: VideoPool(create: FakeVideoController.new),
    splash: false,
  ),
);

void main() {
  testWidgets('[PLAY-1] the feed is a vertical PageView', (tester) async {
    await tester.pumpWidget(_app());
    final pager = tester.widget<PageView>(find.byType(PageView));
    expect(pager.scrollDirection, Axis.vertical);
  });

  testWidgets(
    '[PLAY-5] a loading episode shows its poster, no shimmer or spinner',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.byType(Poster), findsWidgets);
      expect(find.byType(BrandSkeleton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets('[SPLASH-3] [SPLASH-5] the first video loads behind the splash '
      'silently and starts playing as it leaves', (tester) async {
    final created = <FakeVideoController>[];
    await tester.pumpWidget(
      MaterialApp(
        home: FeedScreen(
          episodes: _episodes,
          pool: VideoPool(
            create: (uri) {
              final c = FakeVideoController(uri);
              created.add(c);
              return c;
            },
          ),
        ),
      ),
    );
    expect(find.byType(BrandSplash), findsOneWidget);
    final first = created.single;
    expect(first.initStarted, isTrue);

    first.completeInit();
    await tester.pump();
    expect(first.value.isPlaying, isFalse, reason: 'held under the splash');

    await tester.pump(BrandSplash.minShow);
    expect(first.value.isPlaying, isTrue);
    // The fade's first frame comes after the splash decides to leave.
    await tester.pump(
      BrandSplash.exitDuration + const Duration(milliseconds: 20),
    );
    await tester.pump();
    expect(find.byKey(BrandSplash.overlayKey), findsNothing);
  });
}
