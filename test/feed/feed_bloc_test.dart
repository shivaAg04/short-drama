import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/domain/feed_entry.dart';
import 'package:rume/feed/state/feed_bloc.dart';

final List<Episode> _episodes = [
  for (var n = 1; n <= 7; n++)
    Episode(number: n, videoUrl: 'v$n', posterUrl: 'p$n'),
];

// E1 E2 E3 [break:1] E4 E5 E6 [break:2] E7, so break:1 is page 3.
const _break1 = 'break:1';
const _break1Page = 3;

FeedBloc _bloc() => FeedBloc(episodes: _episodes);

int? _episodeInView(FeedState s) => switch (s.focused) {
  EpisodeEntry(:final episode) => episode.number,
  _ => null,
};

void main() {
  test('[FEED-9] E7 is on page 8 until an earlier break is dropped', () async {
    final bloc = _bloc()..add(const AdBreakFailed(_break1));
    expect(bloc.state.pageOf(7), 8);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.pageOf(7), 7);
    await bloc.close();
  });

  blocTest<FeedBloc, FeedState>(
    '[FEED-5] a break ahead of the user is dropped and the page stays put',
    build: _bloc,
    act: (b) => b.add(const AdBreakFailed(_break1)),
    verify: (b) {
      expect(b.state.dropped, {_break1});
      expect(b.state.page, 0);
      expect(b.state.glideTo, isNull);
    },
  );

  blocTest<FeedBloc, FeedState>(
    '[FEED-6] a break behind the user is dropped; the same episode stays in '
    'view on a page one lower',
    build: _bloc,
    act: (b) => b
      ..add(const FeedFocused(5))
      ..add(const AdBreakFailed(_break1)),
    verify: (b) {
      expect(_episodeInView(b.state), 5);
      expect(b.state.page, 4);
      expect(b.state.glideTo, isNull, reason: 'a re-seat, not a glide');
    },
  );

  blocTest<FeedBloc, FeedState>(
    '[FEED-7] a break in view glides the user on, then is dropped once '
    'the feed is at rest',
    build: _bloc,
    act: (b) async {
      b
        ..add(const FeedFocused(_break1Page))
        ..add(const AdBreakFailed(_break1));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.glideTo, 'episode:4');
      expect(b.state.dropped, isEmpty);

      b
        ..add(const FeedScrolling(active: true))
        ..add(const FeedFocused(_break1Page + 1))
        ..add(const FeedScrolling(active: false));
    },
    verify: (b) {
      expect(b.state.dropped, {_break1});
      expect(b.state.glideTo, isNull);
      expect(_episodeInView(b.state), 4);
    },
  );

  blocTest<FeedBloc, FeedState>(
    '[FEED-8] nothing is dropped while the feed is moving',
    build: _bloc,
    act: (b) async {
      b
        ..add(const FeedFocused(5))
        ..add(const FeedScrolling(active: true))
        ..add(const AdBreakFailed(_break1));
      await Future<void>.delayed(Duration.zero);
      expect(b.state.dropped, isEmpty);
      b.add(const FeedScrolling(active: false));
    },
    verify: (b) => expect(b.state.dropped, {_break1}),
  );

  test('[AD-1] the next break ahead is always the one to load', () {
    String? from(int page) =>
        FeedState(episodes: _episodes, focusId: layoutIdAt(page)).nextBreak;
    expect(from(0), _break1, reason: 'requested at launch');
    expect(from(2), _break1);
    expect(from(_break1Page), _break1, reason: 'still wanted on screen');
    expect(from(_break1Page + 1), 'break:2', reason: 'once break:1 is passed');
    expect(from(8), isNull, reason: 'no break after E7');
  });

  test('[AD-1] a dropped break hands over to the one after it', () {
    final state = FeedState(episodes: _episodes).without(_break1);
    expect(state.nextBreak, 'break:2');
  });

  blocTest<FeedBloc, FeedState>(
    '[FEED-2] a failure for a break the feed does not have changes nothing',
    // Six episodes: nothing follows E6, so there is no second break.
    build: () => FeedBloc(episodes: _episodes.take(6).toList()),
    act: (b) => b.add(const AdBreakFailed('break:2')),
    expect: () => const <FeedState>[],
  );

  blocTest<FeedBloc, FeedState>(
    '[FEED-4] focusing the page already in view emits nothing',
    build: _bloc,
    seed: () => FeedState(episodes: _episodes, focusId: 'episode:2'),
    act: (b) => b
      ..add(const FeedFocused(1))
      ..add(const FeedFocused(99)),
    expect: () => const <FeedState>[],
  );
}

String layoutIdAt(int page) => FeedState(episodes: _episodes).entries[page].id;
