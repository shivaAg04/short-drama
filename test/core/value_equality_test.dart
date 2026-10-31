import 'package:flutter_test/flutter_test.dart';
import 'package:rume/engagement/state/engagement_cubit.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/domain/feed_entry.dart';
import 'package:rume/feed/state/feed_bloc.dart';
import 'package:rume/player/domain/playback_plan.dart';

// Values compare by content. Blocs and listeners rely on it: an equal state
// is not emitted again, a different one always is.
void main() {
  test('[FEED-4] an entry is equal to another with the same id', () {
    final four = int.parse('4');
    final e4 = Episode(number: four, videoUrl: 'v4', posterUrl: 'p4');
    expect(EpisodeEntry(e4), EpisodeEntry(e4));
    expect(AdBreakEntry(four - 3), AdBreakEntry(four - 3));
    expect(AdBreakEntry(four - 3), isNot(AdBreakEntry(four - 2)));
  });

  test('[FEED-7] a glide is part of the state, so a new one is emitted', () {
    const state = FeedState(episodes: []);
    expect(state.glidingTo('episode:4'), state.glidingTo('episode:4'));
    expect(state.glidingTo('episode:4'), isNot(state));
    expect(state.without('break:1'), isNot(state));
  });

  test('[PLAY-3] the same plan twice is equal, so the pool is not '
      'disturbed', () {
    const plan = PlaybackPlan(
      active: 2,
      slots: [
        VideoSlot(episode: 2, url: 'v2'),
        VideoSlot(episode: 3, url: 'v3'),
      ],
    );
    expect(
      plan,
      const PlaybackPlan(
        active: 2,
        slots: [
          VideoSlot(episode: 2, url: 'v2'),
          VideoSlot(episode: 3, url: 'v3'),
        ],
      ),
    );
    expect(plan, isNot(PlaybackPlan.empty));
  });

  test('[RAIL-4] a comment is its author, text and time', () {
    const c = Comment(author: 'riya', text: 'ep 7 now!!', ago: 'now');
    expect(c, const Comment(author: 'riya', text: 'ep 7 now!!', ago: 'now'));
    expect(c, isNot(const Comment(author: 'riya', text: 'ep 7', ago: 'now')));
  });

  test('[PLAY-3] a video slot is its episode and URL', () {
    // Built at run time: identical constants would never be compared.
    final two = int.parse('2');
    expect(
      VideoSlot(episode: two, url: 'v2'),
      VideoSlot(episode: two, url: 'v2'),
    );
    expect(
      VideoSlot(episode: two, url: 'v2'),
      isNot(VideoSlot(episode: two + 1, url: 'v2')),
    );
  });

  test('[FEED-8] a scrolling event says whether the feed is moving', () {
    // Built at run time: a constant event never runs its constructor.
    final moving = bool.parse('true');
    expect(FeedScrolling(active: moving).active, isTrue);
    expect(FeedScrolling(active: !moving).active, isFalse);
  });
}
