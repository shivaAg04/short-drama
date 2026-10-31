import 'package:flutter_test/flutter_test.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/state/feed_bloc.dart';
import 'package:rume/paywall/state/paywall_cubit.dart';
import 'package:rume/player/domain/playback_plan.dart';

final List<Episode> _episodes = [
  for (var n = 1; n <= 7; n++)
    Episode(number: n, videoUrl: 'v$n', posterUrl: 'p$n'),
];

// E1 E2 E3 [break:1] E4 E5 E6 [break:2] E7: E4 is page 4, E7 page 8.
PlaybackPlan _planAt(int page, {bool unlocked = false}) {
  final layout = FeedState(episodes: _episodes);
  return PlaybackPlan.from(
    layout.focusOn(layout.entries[page].id),
    PaywallState(unlocked: unlocked),
  );
}

List<int> _window(PlaybackPlan plan) => [for (final s in plan.slots) s.episode];

void main() {
  test('[PLAY-2] only the focused episode is active', () {
    expect(_planAt(4).active, 4);
  });

  test('[PLAY-3] the window is the focused episode and one either side', () {
    expect(_window(_planAt(4)), [4, 5, 3]);
    expect(_window(_planAt(0)), [1, 2]);
  });

  test('[PLAY-4] the next episode is warmed before the previous one', () {
    expect(_window(_planAt(1)).take(2), [2, 3]);
  });

  test('[PLAY-4] an ad page plays nothing but warms the episode after it', () {
    final plan = _planAt(3);
    expect(plan.active, isNull);
    expect(_window(plan).first, 4);
  });

  test('[PLAY-6] [PAY-2] a locked episode never gets a slot', () {
    final plan = _planAt(8);
    expect(plan.active, isNull);
    expect(_window(plan), isNot(contains(7)));
    expect(_window(_planAt(6)), [6, 5]);
  });

  test('[PAY-8] after unlock the episode plays', () {
    expect(_planAt(8, unlocked: true).active, 7);
  });
}
