import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/domain/feed_entry.dart';
import 'package:rume/feed/domain/feed_layout.dart';

part 'feed_event.dart';
part 'feed_state.dart';

/// The feed's layout and which entry is in view.
///
/// Failed ad breaks are queued and taken out only while the feed is at rest.
/// A break that isn't in view is dropped straight away: because focus is
/// held by id, the page in view keeps its content and only its index moves
/// (the screen re-seats the PageView on it). A break that is in view first
/// sets [FeedState.glideTo] to the entry after it; once the glide settles
/// the break is behind the user and is dropped like any other.
class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({required List<Episode> episodes})
    : super(FeedState(episodes: episodes)) {
    on<FeedFocused>(_onFocused);
    on<FeedScrolling>(_onScrolling);
    on<AdBreakFailed>(_onBreakFailed);
  }

  final Set<String> _queue = {};
  bool _moving = false;

  void _onFocused(FeedFocused event, Emitter<FeedState> emit) {
    final entry = state.entries.elementAtOrNull(event.page);
    if (entry == null) return;
    if (entry.id == state.focusId && state.glideTo == null) return;
    emit(state.focusOn(entry.id));
  }

  void _onScrolling(FeedScrolling event, Emitter<FeedState> emit) {
    _moving = event.active;
    _settle(emit);
  }

  void _onBreakFailed(AdBreakFailed event, Emitter<FeedState> emit) {
    if (state.dropped.contains(event.id)) return;
    _queue.add(event.id);
    _settle(emit);
  }

  void _settle(Emitter<FeedState> emit) {
    if (_moving || state.glideTo != null) return;
    for (final id in _queue.toList()) {
      final at = state.indexOf(id);
      if (at == -1) {
        _queue.remove(id);
      } else if (at == state.page) {
        // A break is never last in the layout, so at + 1 exists.
        emit(state.glidingTo(state.entries[at + 1].id));
        return;
      } else {
        _queue.remove(id);
        emit(state.without(id));
      }
    }
  }
}
