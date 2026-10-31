import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rume/feed/domain/episode.dart';

final class Comment extends Equatable {
  const Comment({required this.author, required this.text, required this.ago});

  final String author;
  final String text;
  final String ago;

  @override
  List<Object?> get props => [author, text, ago];
}

final class EpisodeEngagement extends Equatable {
  const EpisodeEngagement({
    required this.likes,
    required this.shares,
    required this.commentCount,
    required this.comments,
    this.liked = false,
    this.saved = false,
  });

  final bool liked;
  final bool saved;
  final int likes;
  final int shares;
  final int commentCount;

  /// Newest first. Only a sample is loaded, so this is shorter than
  /// [commentCount].
  final List<Comment> comments;

  EpisodeEngagement copyWith({
    bool? liked,
    bool? saved,
    int? likes,
    int? shares,
    int? commentCount,
    List<Comment>? comments,
  }) => EpisodeEngagement(
    liked: liked ?? this.liked,
    saved: saved ?? this.saved,
    likes: likes ?? this.likes,
    shares: shares ?? this.shares,
    commentCount: commentCount ?? this.commentCount,
    comments: comments ?? this.comments,
  );

  @override
  List<Object?> get props => [
    liked,
    saved,
    likes,
    shares,
    commentCount,
    comments,
  ];
}

final class EngagementState extends Equatable {
  const EngagementState(this.byEpisode);

  final Map<int, EpisodeEngagement> byEpisode;

  EpisodeEngagement of(int episode) => byEpisode[episode]!;

  @override
  List<Object?> get props => [byEpisode];
}

/// Likes, saves, comments and shares for this session, keyed by episode so
/// they survive swiping away and back. No backend yet: seeds come from the
/// catalogue.
class EngagementCubit extends Cubit<EngagementState> {
  EngagementCubit({required List<Episode> episodes})
    : super(
        EngagementState({
          for (final e in episodes)
            e.number: EpisodeEngagement(
              likes: e.counts.likes,
              shares: e.counts.shares,
              commentCount: e.counts.comments + _sample.length,
              comments: _sampleFor(e.number),
            ),
        }),
      );

  void toggleLike(int episode) {
    final e = state.of(episode);
    _put(
      episode,
      e.copyWith(liked: !e.liked, likes: e.likes + (e.liked ? -1 : 1)),
    );
  }

  /// Double-tap only ever likes, the way every feed app behaves.
  void likeFromDoubleTap(int episode) {
    if (!state.of(episode).liked) toggleLike(episode);
  }

  void toggleSave(int episode) {
    final e = state.of(episode);
    _put(episode, e.copyWith(saved: !e.saved));
  }

  void postComment(int episode, String text) {
    final body = text.trim();
    if (body.isEmpty) return;
    final e = state.of(episode);
    _put(
      episode,
      e.copyWith(
        commentCount: e.commentCount + 1,
        comments: [
          Comment(author: 'you', text: body, ago: 'now'),
          ...e.comments,
        ],
      ),
    );
  }

  void recordShare(int episode) {
    final e = state.of(episode);
    _put(episode, e.copyWith(shares: e.shares + 1));
  }

  void _put(int episode, EpisodeEngagement value) =>
      emit(EngagementState({...state.byEpisode, episode: value}));

  static const _sample = [
    Comment(
      author: 'zara.k',
      text: 'the way i gasped at the end 😭',
      ago: '2m',
    ),
    Comment(author: 'rohan_09', text: 'who else is binging at 2am', ago: '8m'),
    Comment(
      author: 'meera',
      text: 'she KNEW. rewatch the first 5 seconds',
      ago: '14m',
    ),
    Comment(author: 'aditya.v', text: 'this cast is unreal', ago: '31m'),
    Comment(author: 'ishaan', text: 'not the cliffhanger again 💀', ago: '1h'),
    Comment(author: 'tanvi.s', text: 'need the next one NOW', ago: '2h'),
  ];

  // Rotated per episode so pages don't all read the same.
  static List<Comment> _sampleFor(int episode) {
    final shift = episode % _sample.length;
    return [..._sample.skip(shift), ..._sample.take(shift)];
  }
}
