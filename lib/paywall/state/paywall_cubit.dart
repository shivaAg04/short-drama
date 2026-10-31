import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rume/feed/state/feed_bloc.dart' show FeedState;

final class PaywallState extends Equatable {
  const PaywallState({
    this.lockedEpisode = 7,
    this.unlocked = false,
    this.purchasing = false,
  });

  /// Episodes numbered from here on are paid. No video controller is created
  /// for them while [unlocked] is false (PAY-1).
  final int lockedEpisode;
  final bool unlocked;
  final bool purchasing;

  bool isLocked(int episodeNumber) =>
      !unlocked && episodeNumber >= lockedEpisode;

  @override
  List<Object?> get props => [lockedEpisode, unlocked, purchasing];
}

/// Whether the paid episodes are open for this session. The page the lock
/// falls on is not stored here; it is looked up with [FeedState.pageOf]
/// whenever needed, so it follows the feed when an ad slot is dropped.
///
/// The simulated purchase runs in the cubit, not the button, so its result
/// still lands if the user swipes away while it is in flight.
class PaywallCubit extends Cubit<PaywallState> {
  PaywallCubit({
    int lockedEpisode = 7,
    this.purchaseDelay = const Duration(milliseconds: 700),
  }) : super(PaywallState(lockedEpisode: lockedEpisode));

  /// Simulated purchase time (no store integration in this build).
  final Duration purchaseDelay;

  Future<void> unlock() async {
    if (state.unlocked || state.purchasing) return;
    emit(PaywallState(lockedEpisode: state.lockedEpisode, purchasing: true));
    await Future<void>.delayed(purchaseDelay);
    if (isClosed) return;
    emit(PaywallState(lockedEpisode: state.lockedEpisode, unlocked: true));
  }
}
