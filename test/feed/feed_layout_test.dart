import 'package:flutter_test/flutter_test.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/domain/feed_entry.dart';
import 'package:rume/feed/domain/feed_layout.dart';

List<Episode> _episodes(int count) => [
  for (var n = 1; n <= count; n++)
    Episode(number: n, videoUrl: 'v$n', posterUrl: 'p$n'),
];

String _shape(List<FeedEntry> entries) => [
  for (final e in entries)
    switch (e) {
      EpisodeEntry(:final episode) => 'E${episode.number}',
      AdBreakEntry() => 'AD',
    },
].join(' ');

void main() {
  test('[FEED-1] an ad break follows every third episode', () {
    expect(_shape(layoutFeed(_episodes(7))), 'E1 E2 E3 AD E4 E5 E6 AD E7');
  });

  test('[FEED-2] the feed never ends on a break', () {
    expect(_shape(layoutFeed(_episodes(6))), 'E1 E2 E3 AD E4 E5 E6');
    expect(_shape(layoutFeed(_episodes(2))), 'E1 E2');
  });

  test('[FEED-3] dropped breaks vanish and episodes keep their numbers', () {
    final entries = layoutFeed(_episodes(7), dropped: {'break:1'});
    expect(_shape(entries), 'E1 E2 E3 E4 E5 E6 AD E7');
  });

  test('[FEED-4] ids survive a break being dropped', () {
    final before = [for (final e in layoutFeed(_episodes(7))) e.id];
    final after = [
      for (final e in layoutFeed(_episodes(7), dropped: {'break:1'})) e.id,
    ];
    expect(after, before.where((id) => id != 'break:1').toList());
  });
}
