part of 'feed_bloc.dart';

final class FeedState extends Equatable {
  const FeedState({
    required this.episodes,
    this.dropped = const {},
    this.focusId,
    this.glideTo,
  });

  final List<Episode> episodes;

  /// Ad breaks taken out of the feed.
  final Set<String> dropped;

  /// The entry in view; null until the user first moves, meaning page 0.
  final String? focusId;

  /// Set while the feed is being moved off a failed break onto this entry.
  final String? glideTo;

  List<FeedEntry> get entries => layoutFeed(episodes, dropped: dropped);

  /// Where [focusId] currently sits. Never stored: it is looked up in the
  /// layout, so it is right in the same frame a break is dropped.
  int get page {
    final id = focusId;
    if (id == null) return 0;
    final at = indexOf(id);
    return at == -1 ? 0 : at;
  }

  FeedEntry? get focused => entries.elementAtOrNull(page);

  int indexOf(String id) => entries.indexWhere((e) => e.id == id);

  /// Page of episode [number], or null when it isn't in the feed.
  int? pageOf(int number) {
    final at = entries.indexWhere(
      (e) => e is EpisodeEntry && e.episode.number == number,
    );
    return at == -1 ? null : at;
  }

  /// The first ad break at or after the focused page: the one whose ad
  /// should be loading now (AD-1). Null when no break is left ahead.
  String? get nextBreak =>
      entries.skip(page).whereType<AdBreakEntry>().firstOrNull?.id;

  FeedState focusOn(String id) =>
      FeedState(episodes: episodes, dropped: dropped, focusId: id);

  FeedState glidingTo(String id) => FeedState(
    episodes: episodes,
    dropped: dropped,
    focusId: focusId,
    glideTo: id,
  );

  FeedState without(String breakId) => FeedState(
    episodes: episodes,
    dropped: {...dropped, breakId},
    focusId: focusId,
    glideTo: glideTo,
  );

  @override
  List<Object?> get props => [episodes, dropped, focusId, glideTo];
}
