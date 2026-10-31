import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/ads/break_ad_loader.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/ui/feed_screen.dart';
import 'package:rume/paywall/ui/paywall_overlay.dart';
import 'package:rume/player/state/video_pool.dart';

import '../helpers/fake_break_ad.dart';
import '../helpers/fake_video_controller.dart';

// The real FeedScreen, driven by flings: the PageView, its physics, the
// blocs, the pool and the ad loader are the app's own. Fakes stand in for
// the video plugin and the ad SDK only.

// Eight, so there is an episode beyond the lock on E7.
final List<Episode> _episodes = [
  for (var n = 1; n <= 8; n++)
    Episode(number: n, videoUrl: 'v$n', posterUrl: 'p$n'),
];

// Ten pages: E1–E3, a break, E4–E6, a break, E7 (locked), E8.

void main() {
  late List<FakeVideoController> videos;
  late List<FakeBreakAd> ads;

  Future<void> pumpFeed(WidgetTester tester) async {
    videos = [];
    ads = [];
    await tester.pumpWidget(
      MaterialApp(
        home: FeedScreen(
          episodes: _episodes,
          splash: false,
          pool: VideoPool(
            create: (uri) {
              final c = FakeVideoController(uri);
              videos.add(c);
              return c;
            },
            deferDispose: (dispose) => dispose(),
            keepScreenAwake: ({required awake}) {},
          ),
          ads: BreakAdLoader(
            make: (id, {required onFilled, required onEmpty}) {
              final ad = FakeBreakAd(id, onFilled: onFilled, onEmpty: onEmpty);
              ads.add(ad);
              return ad;
            },
          ),
        ),
      ),
    );
  }

  FakeVideoController? video(int episode) {
    for (final c in videos.reversed) {
      if (c.source.toString() == 'v$episode' && !c.disposed) return c;
    }
    return null;
  }

  bool playing(int episode) => video(episode)?.value.isPlaying ?? false;

  // Finishes every pending load; neighbours start only after the focused
  // video, hence the rounds.
  Future<void> loadAll(WidgetTester tester) async {
    for (var round = 0; round < 3; round++) {
      for (final c in videos.where(
        (c) => c.initStarted && !c.value.isInitialized && !c.disposed,
      )) {
        c.completeInit();
      }
      await tester.pump();
      await tester.pump();
    }
  }

  Future<void> swipeUp(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(0, -300), 1500);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await loadAll(tester);
  }

  int pageCount(WidgetTester tester) =>
      (tester.widget<PageView>(find.byType(PageView)).childrenDelegate
              as SliverChildBuilderDelegate)
          .childCount!;

  // Unmounts the screen, which disposes the loader and its deadline timers.
  Future<void> close(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets('[AD-1] the first ad is requested at launch, the second as '
      'soon as the first break is passed', (tester) async {
    await pumpFeed(tester);
    expect(ads.map((a) => a.breakId), ['break:1']);

    await loadAll(tester);
    ads.single.onFilled();
    for (var page = 0; page < 3; page++) {
      await swipeUp(tester);
    }
    expect(ads.map((a) => a.breakId), ['break:1'], reason: 'on the break');

    await swipeUp(tester);
    expect(ads.map((a) => a.breakId), ['break:1', 'break:2']);
    await close(tester);
  });

  testWidgets('[PLAY-2] swiping up plays the next episode and pauses the one '
      'before', (tester) async {
    await pumpFeed(tester);
    await loadAll(tester);
    expect(playing(1), isTrue);

    await swipeUp(tester);
    expect(playing(2), isTrue);
    expect(playing(1), isFalse);
    await close(tester);
  });

  testWidgets('[AD-3] [FEED-5] an ad that fails to load leaves the feed, and '
      'the next swipe lands on the episode after it', (tester) async {
    await pumpFeed(tester);
    await loadAll(tester);
    await swipeUp(tester);
    expect(pageCount(tester), 10);

    ads.firstWhere((a) => a.breakId == 'break:1').onEmpty('no fill');
    await tester.pump();
    await tester.pump();
    expect(pageCount(tester), 9);

    await swipeUp(tester);
    await swipeUp(tester);
    expect(playing(4), isTrue, reason: 'E3 is followed by E4 now');
    await close(tester);
  });

  testWidgets('[FEED-6] a break behind the user leaves without the page on '
      'screen moving, even for a frame', (tester) async {
    await pumpFeed(tester);
    await loadAll(tester);
    for (var page = 0; page < 5; page++) {
      await swipeUp(tester);
    }
    expect(playing(5), isTrue);
    final e5 = find.byKey(const ValueKey('episode:5'));
    expect(tester.getTopLeft(e5), Offset.zero);

    ads.firstWhere((a) => a.breakId == 'break:1').onEmpty('no fill');
    await tester.pump(); // the bloc emits
    await tester.pump(); // the frame drawn with the break gone

    expect(pageCount(tester), 9);
    expect(tester.getTopLeft(e5), Offset.zero);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 4);
    expect(playing(5), isTrue, reason: 'the video was not reloaded');
    await close(tester);
  });

  testWidgets('[PAY-2] [PAY-3] the feed cannot be swiped past the locked '
      'episode, which never gets a player', (tester) async {
    await pumpFeed(tester);
    await loadAll(tester);
    for (var page = 0; page < 8; page++) {
      await swipeUp(tester);
    }
    expect(video(7), isNull);
    expect(find.text('Unlock Episode'), findsOneWidget);

    await swipeUp(tester);
    await swipeUp(tester);
    expect(playing(8), isFalse);
    final card = tester.getRect(find.byKey(PaywallOverlay.cardKey));
    expect(card.top, lessThan(600), reason: 'still on E7, card on screen');
    await close(tester);
  });

  testWidgets('[PAY-8] unlocking plays the episode and opens the feed beyond '
      'it', (tester) async {
    await pumpFeed(tester);
    await loadAll(tester);
    for (var page = 0; page < 8; page++) {
      await swipeUp(tester);
    }
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Unlock Episode'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await loadAll(tester);
    expect(playing(7), isTrue);

    await swipeUp(tester);
    expect(playing(8), isTrue);
    expect(playing(7), isFalse);
    await close(tester);
  });

  testWidgets('[PLAY-7] leaving the app pauses; coming back resumes', (
    tester,
  ) async {
    await pumpFeed(tester);
    await loadAll(tester);
    expect(playing(1), isTrue);

    // Through every state in between, as the OS reports them.
    Future<void> goTo(List<AppLifecycleState> states) async {
      states.forEach(tester.binding.handleAppLifecycleStateChanged);
      await tester.pump();
    }

    await goTo(const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    expect(playing(1), isFalse);

    await goTo(const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    expect(playing(1), isTrue);
    await close(tester);
  });

  testWidgets('[FEED-7] an ad that fails while on screen glides on to the '
      'next episode, then leaves the feed', (tester) async {
    await pumpFeed(tester);
    await loadAll(tester);
    for (var page = 0; page < 3; page++) {
      await swipeUp(tester);
    }
    expect(pageCount(tester), 10, reason: 'on the ad page');

    ads.firstWhere((a) => a.breakId == 'break:1').onEmpty('timed out');
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await loadAll(tester);
    expect(playing(4), isTrue);
    expect(pageCount(tester), 9);
    await close(tester);
  });
}
