import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:rume/ads/ad_config.dart';
import 'package:rume/ads/break_ad.dart';

/// What an ad break's page should show.
sealed class BreakAdStatus {
  const BreakAdStatus();
}

final class BreakAdPending extends BreakAdStatus {
  const BreakAdPending();
}

final class BreakAdFilled extends BreakAdStatus {
  const BreakAdFilled(this.ad);

  final BreakAd ad;
}

final class BreakAdEmpty extends BreakAdStatus {
  const BreakAdEmpty(this.why);

  final String why;
}

/// Requests each break's ad ahead of the user (AD-1) and is the only owner
/// of the ads it makes: it disposes one when its break leaves the feed, when
/// it fails, and on [dispose] (AD-6).
///
/// A failure of any kind (error, no fill, a thrown request, the [timeout])
/// ends in [BreakAdEmpty] and a call to [onEmpty] (AD-3).
class BreakAdLoader {
  BreakAdLoader({BreakAdMaker? make, this.timeout = AdConfig.loadTimeout})
    : _make = make ?? GamBreakAd.new;

  final BreakAdMaker _make;
  final Duration timeout;

  /// Told the id of every break whose ad came back empty.
  void Function(String breakId)? onEmpty;

  final Map<String, _Load> _loads = {};
  bool _closed = false;

  ValueListenable<BreakAdStatus> statusOf(String breakId) =>
      _entry(breakId).status;

  /// Requests the ad for each of [breakIds] not yet requested.
  void warm(Iterable<String> breakIds) {
    if (_closed) return;
    for (final id in breakIds) {
      final load = _entry(id);
      if (!load.requested) _request(id, load);
    }
  }

  /// [breakId] left the feed: its ad is disposed and any late answer about
  /// it is ignored.
  void discard(String breakId) {
    final load = _loads[breakId];
    if (_closed || load == null) return;
    load.stop();
    if (load.status.value is! BreakAdEmpty) {
      load.status.value = const BreakAdEmpty('discarded');
    }
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    for (final load in _loads.values) {
      load
        ..stop()
        ..status.dispose();
    }
    _loads.clear();
  }

  _Load _entry(String id) => _loads.putIfAbsent(id, _Load.new);

  void _request(String id, _Load load) {
    load.requested = true;
    late final BreakAd ad;
    // Answers count only for the ad this break is still waiting on.
    bool waiting() =>
        !_closed &&
        identical(load.ad, ad) &&
        load.status.value is BreakAdPending;

    ad = _make(
      id,
      onFilled: () {
        if (!waiting()) return;
        load.deadline?.cancel();
        load.status.value = BreakAdFilled(ad);
      },
      onEmpty: (why) {
        if (waiting()) _empty(id, load, why);
      },
    );
    load
      ..ad = ad
      ..deadline = Timer(timeout, () => _empty(id, load, 'timed out'));
    // A malformed request (say, an unregistered native factory) throws
    // instead of calling back; treat it as empty now, not at the deadline.
    unawaited(
      ad.load().then<void>(
        (_) {},
        onError: (Object error) {
          if (waiting()) _empty(id, load, '$error');
        },
      ),
    );
  }

  void _empty(String id, _Load load, String why) {
    if (_closed) return;
    debugPrint('ad break $id (${AdConfig.unitFor(id)}) empty: $why');
    load
      ..stop()
      ..status.value = BreakAdEmpty(why);
    onEmpty?.call(id);
  }
}

class _Load {
  final ValueNotifier<BreakAdStatus> status = ValueNotifier(
    const BreakAdPending(),
  );
  bool requested = false;
  BreakAd? ad;
  Timer? deadline;

  void stop() {
    deadline?.cancel();
    deadline = null;
    final owned = ad;
    ad = null;
    if (owned != null) unawaited(owned.dispose());
  }
}
