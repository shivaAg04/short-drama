import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rume/player/domain/playback_plan.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

typedef VideoControllerFactory = VideoPlayerController Function(Uri uri);

/// The only owner of video controllers. Screens describe what they want with
/// a [PlaybackPlan]; the pool creates, plays, pauses and disposes.
///
/// Each episode exposes its controller through [controllerFor], so a page
/// rebuilds only when its own video becomes ready or goes away.
class VideoPool {
  VideoPool({
    VideoControllerFactory? create,
    void Function(VoidCallback dispose)? deferDispose,
    void Function({required bool awake})? keepScreenAwake,
    this.retryEvery = const Duration(seconds: 3),
  }) : _create = create ?? VideoPlayerController.networkUrl,
       _deferDispose = deferDispose ?? _afterFrame,
       _keepScreenAwake = keepScreenAwake ?? _wakelock;

  final VideoControllerFactory _create;
  final void Function(VoidCallback) _deferDispose;
  final void Function({required bool awake}) _keepScreenAwake;

  /// How often episodes that failed to load are tried again.
  final Duration retryEvery;

  final Map<int, VideoPlayerController> _loading = {};
  final Map<int, VideoPlayerController> _ready = {};
  final Map<int, ValueNotifier<VideoPlayerController?>> _published = {};
  final Set<int> _failed = {};
  final Map<int, ValueNotifier<bool>> _failedFlags = {};
  Timer? _retry;
  final ValueNotifier<int?> _paused = ValueNotifier(null);
  final ValueNotifier<bool> _muted = ValueNotifier(false);

  PlaybackPlan _plan = PlaybackPlan.empty;
  int? _playing;
  bool _awake = false;
  final Set<Object> _holds = {};
  bool _disposed = false;

  /// The episode the user paused with a tap, if any. Cleared when the
  /// focused episode changes.
  ValueListenable<int?> get paused => _paused;

  /// Sound is on or off for the whole feed, not per episode.
  ValueListenable<bool> get muted => _muted;

  /// Null until the episode's video is initialised and ready to show.
  ValueListenable<VideoPlayerController?> controllerFor(int episode) =>
      _notifier(episode);

  /// True from an episode's first failed load until a load succeeds, so the
  /// page keeps its error card through the retries in between.
  ValueListenable<bool> failedFor(int episode) => _failedFlag(episode);

  /// Tries every failed episode again now, instead of at the next tick.
  void retry() {
    if (_disposed) return;
    _retry?.cancel();
    _retry = null;
    _failed.clear();
    _startLoads();
  }

  void update(PlaybackPlan plan) {
    if (_disposed) return;
    _plan = plan;
    final wanted = {for (final s in plan.slots) s.episode};

    for (final episode in [..._ready.keys, ..._loading.keys]) {
      if (!wanted.contains(episode)) _release(episode);
    }
    for (final MapEntry(key: episode, value: flag) in _failedFlags.entries) {
      if (!wanted.contains(episode)) flag.value = false;
    }
    _failed.removeWhere((e) => !wanted.contains(e));
    if (_failed.isEmpty) {
      _retry?.cancel();
      _retry = null;
    }
    if (_paused.value != plan.active) _paused.value = null;

    _applyPlayback();
    _startLoads();
  }

  void togglePause() {
    final active = _plan.active;
    if (_disposed || active == null || !_ready.containsKey(active)) return;
    _paused.value = _paused.value == active ? null : active;
    _applyPlayback();
  }

  void toggleMute() {
    if (_disposed) return;
    _muted.value = !_muted.value;
    for (final c in _ready.values) {
      unawaited(c.setVolume(_volume));
    }
  }

  double get _volume => _muted.value ? 0 : 1;

  void seek(int episode, Duration to) {
    final controller = _ready[episode];
    if (controller != null) unawaited(controller.seekTo(to));
  }

  /// Pauses everything while any [reason] holds it, e.g. the app being in
  /// the background or the splash still covering the feed. Holds for
  /// different reasons do not release each other.
  void setHeld({required bool held, Object reason = #background}) {
    if (_disposed) return;
    final changed = held ? _holds.add(reason) : _holds.remove(reason);
    if (changed) _applyPlayback();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    _setAwake(awake: false);
    for (final c in [..._ready.values, ..._loading.values]) {
      unawaited(c.pause().catchError((_) {}));
      _deferDispose(() => unawaited(c.dispose()));
    }
    _ready.clear();
    _loading.clear();
    for (final n in _published.values) {
      n.dispose();
    }
    _published.clear();
    for (final n in _failedFlags.values) {
      n.dispose();
    }
    _failedFlags.clear();
    _paused.dispose();
    _muted.dispose();
  }

  ValueNotifier<VideoPlayerController?> _notifier(int episode) =>
      _published.putIfAbsent(episode, () => ValueNotifier(null));

  ValueNotifier<bool> _failedFlag(int episode) =>
      _failedFlags.putIfAbsent(episode, () => ValueNotifier(false));

  void _scheduleRetry() {
    if (_disposed || _retry != null) return;
    _retry = Timer(retryEvery, () {
      _retry = null;
      retry();
    });
  }

  void _startLoads() {
    final active = _plan.active;
    // The focused video gets the bandwidth first; neighbours wait for it.
    final activeSettled =
        active == null ||
        _ready.containsKey(active) ||
        _failed.contains(active) ||
        !_plan.slots.any((s) => s.episode == active);

    for (final slot in _plan.slots) {
      final e = slot.episode;
      if (_ready.containsKey(e) || _loading.containsKey(e)) continue;
      if (_failed.contains(e)) continue;
      if (e != active && !activeSettled) continue;
      unawaited(_load(slot));
    }
  }

  Future<void> _load(VideoSlot slot) async {
    final episode = slot.episode;
    final controller = _create(Uri.parse(slot.url));
    _loading[episode] = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_volume);
    } on Object catch (error) {
      // Any failure (network, codec, platform) is handled the same way.
      debugPrint('video ${slot.url} failed: $error');
      if (identical(_loading[episode], controller)) {
        _loading.remove(episode);
        _failed.add(episode);
        if (!_disposed) {
          _failedFlag(episode).value = true;
          _scheduleRetry();
        }
      }
      _deferDispose(() => unawaited(controller.dispose()));
      if (!_disposed) _startLoads();
      return;
    }

    // Left the window (or the pool closed) while initialising.
    if (_disposed || !identical(_loading[episode], controller)) {
      unawaited(controller.dispose());
      return;
    }

    _loading.remove(episode);
    _ready[episode] = controller;
    _notifier(episode).value = controller;
    _failedFlag(episode).value = false;
    _applyPlayback();
    _startLoads();
  }

  void _release(int episode) {
    _loading.remove(episode);
    final controller = _ready.remove(episode);
    if (controller == null) return;
    if (_playing == episode) _playing = null;
    _published[episode]?.value = null;
    unawaited(controller.pause());
    // The page may still hold it until its next build.
    _deferDispose(() => unawaited(controller.dispose()));
  }

  void _applyPlayback() {
    final active = _plan.active;
    final target = _holds.isNotEmpty || _paused.value == active ? null : active;

    final previous = _playing;
    if (previous != null && previous != _plan.active) {
      // Reels restart when you come back to them.
      final c = _ready[previous];
      if (c != null) unawaited(c.seekTo(Duration.zero));
    }

    for (final MapEntry(key: episode, value: c) in _ready.entries) {
      if (episode == target) {
        if (!c.value.isPlaying) unawaited(c.play());
      } else {
        // Not gated on isPlaying: buffering players report false and then
        // resume on their own.
        unawaited(c.pause());
      }
    }
    _playing = _ready.containsKey(_plan.active) ? _plan.active : null;
    _setAwake(awake: _ready.containsKey(target));
  }

  // Only on change: each call is a platform message.
  void _setAwake({required bool awake}) {
    if (_awake == awake) return;
    _awake = awake;
    _keepScreenAwake(awake: awake);
  }

  static void _wakelock({required bool awake}) =>
      unawaited(WakelockPlus.toggle(enable: awake).catchError((_) {}));

  static void _afterFrame(VoidCallback dispose) {
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => dispose())
      ..ensureVisualUpdate();
  }
}
