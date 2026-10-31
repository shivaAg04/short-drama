part of 'feed_bloc.dart';

sealed class FeedEvent {
  const FeedEvent();
}

/// The PageView reports [page] as the page in view.
final class FeedFocused extends FeedEvent {
  const FeedFocused(this.page);

  final int page;
}

/// A drag, fling or glide on the feed began ([active]) or came to rest.
final class FeedScrolling extends FeedEvent {
  const FeedScrolling({required this.active});

  final bool active;
}

/// The ad for break [id] errored, came back empty or timed out.
final class AdBreakFailed extends FeedEvent {
  const AdBreakFailed(this.id);

  final String id;
}
