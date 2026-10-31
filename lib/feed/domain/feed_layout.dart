import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/domain/feed_entry.dart';

/// Episodes in runs of [runLength], with an ad break between runs:
/// seven episodes give E1 E2 E3 AD E4 E5 E6 AD E7 (FEED-1).
///
/// The feed never ends on a break (FEED-2), and breaks listed in [dropped]
/// are left out without renumbering anything (FEED-3).
List<FeedEntry> layoutFeed(
  List<Episode> episodes, {
  int runLength = 3,
  Set<String> dropped = const {},
}) {
  final entries = <FeedEntry>[];
  var ordinal = 0;
  for (var start = 0; start < episodes.length; start += runLength) {
    entries.addAll(episodes.skip(start).take(runLength).map(EpisodeEntry.new));
    if (start + runLength >= episodes.length) break;
    final adBreak = AdBreakEntry(++ordinal);
    if (!dropped.contains(adBreak.id)) entries.add(adBreak);
  }
  return entries;
}
