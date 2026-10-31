import 'package:equatable/equatable.dart';

import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/domain/feed_entry.dart';
import 'package:rume/feed/state/feed_bloc.dart';
import 'package:rume/paywall/state/paywall_cubit.dart';

final class VideoSlot extends Equatable {
  const VideoSlot({required this.episode, required this.url});

  final int episode;
  final String url;

  @override
  List<Object?> get props => [episode, url];
}

/// The video controllers the feed wants right now, and which of them plays.
///
/// Slots are named by episode number rather than page, so when an ad break
/// is dropped and pages renumber, no controller is torn down or reloaded.
final class PlaybackPlan extends Equatable {
  const PlaybackPlan({required this.slots, this.active});

  factory PlaybackPlan.from(FeedState feed, PaywallState paywall) {
    final focused = feed.focused;
    // On an ad break nothing plays, but the window centres on the episode
    // after it: that is what the next swipe most likely shows.
    final centre = switch (focused) {
      EpisodeEntry(:final episode) => episode,
      _ =>
        feed.entries
            .skip(feed.page + 1)
            .whereType<EpisodeEntry>()
            .firstOrNull
            ?.episode,
    };
    if (centre == null) return empty;

    bool open(Episode e) => !paywall.isLocked(e.number);
    final episodes = feed.episodes;
    final at = episodes.indexOf(centre);
    return PlaybackPlan(
      slots: [
        for (final i in [at, at + 1, at - 1])
          if (i >= 0)
            if (episodes.elementAtOrNull(i) case final e? when open(e))
              VideoSlot(episode: e.number, url: e.videoUrl),
      ],
      active: focused is EpisodeEntry && open(focused.episode)
          ? focused.episode.number
          : null,
    );
  }

  static const empty = PlaybackPlan(slots: []);

  /// Load order: the centre episode, then the next, then the previous.
  final List<VideoSlot> slots;
  final int? active;

  @override
  List<Object?> get props => [slots, active];
}
