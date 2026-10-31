import 'package:equatable/equatable.dart';

import 'package:rume/feed/domain/episode.dart';

/// A full-screen page of the feed.
///
/// Code that tracks a page holds on to its [id]: dropping an ad break shifts
/// every page index after it, but leaves ids alone.
sealed class FeedEntry extends Equatable {
  const FeedEntry();

  String get id;

  @override
  List<Object?> get props => [id];
}

final class EpisodeEntry extends FeedEntry {
  const EpisodeEntry(this.episode);

  final Episode episode;

  @override
  String get id => 'episode:${episode.number}';
}

final class AdBreakEntry extends FeedEntry {
  const AdBreakEntry(this.ordinal);

  /// 1 for the first break in the feed, 2 for the second, and so on.
  final int ordinal;

  @override
  String get id => 'break:$ordinal';
}
