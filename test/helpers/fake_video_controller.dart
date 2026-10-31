import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Stands in for the plugin. Initialisation is completed by the test, so
/// ordering and late results can be driven explicitly.
class FakeVideoController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  FakeVideoController(this.source)
    : super(const VideoPlayerValue(duration: Duration(seconds: 15)));

  final Uri source;
  final _init = Completer<void>();
  bool disposed = false;

  bool get initStarted => _initStarted;

  // No platform texture: VideoPlayer renders an empty box.
  @override
  int get playerId => VideoPlayerController.kUninitializedPlayerId;
  bool _initStarted = false;

  void completeInit() {
    value = value.copyWith(isInitialized: true);
    _init.complete();
  }

  void failInit() => _init.completeError(Exception('decoder failed'));

  @override
  Future<void> initialize() {
    _initStarted = true;
    return _init.future;
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> setLooping(bool looping) async =>
      value = value.copyWith(isLooping: looping);

  @override
  Future<void> setVolume(double volume) async =>
      value = value.copyWith(volume: volume);

  @override
  Future<void> seekTo(Duration position) async =>
      value = value.copyWith(position: position);

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
