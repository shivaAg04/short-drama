import 'dart:math' as math;

/// Which still frame the scrub preview shows, and where it comes from.
abstract final class ScrubFrames {
  /// Thumbnail pixels: 2x the preview's 108 x 192, for sharp screens.
  static const width = 216;
  static const height = 384;

  /// A still of [second] for a Cloudinary-hosted video, or null when the
  /// host cannot render frames. Cloudinary turns `…/video/upload/<id>.mp4`
  /// into an image of any moment by adding `so_<seconds>` and a `.jpg`.
  static String? urlAt(String videoUrl, int second) {
    const upload = '/video/upload/';
    final at = videoUrl.indexOf(upload);
    if (at == -1 || !videoUrl.contains('res.cloudinary.com')) return null;
    final head = videoUrl.substring(0, at + upload.length);
    final path = videoUrl.substring(at + upload.length);
    final dot = path.lastIndexOf('.');
    final id = dot == -1 ? path : path.substring(0, dot);
    return '${head}c_fill,h_$height,w_$width,so_$second,q_auto/$id.jpg';
  }

  /// The last whole second that is still inside the video.
  static int lastSecond(Duration length) =>
      math.max(0, (length.inMilliseconds - 1) ~/ 1000);

  /// The second whose frame best matches [at].
  static int nearest(Duration at, Duration length) =>
      (at.inMilliseconds / 1000).round().clamp(0, lastSecond(length));
}

/// Requests an episode's frames, one per second, the first time it is
/// scrubbed, and never again.
class FramePrefetcher<T extends Object> {
  FramePrefetcher(this._frameAt, this._prefetch);

  final T? Function(int second) _frameAt;
  final void Function(T frame) _prefetch;
  bool _requested = false;

  void ensure(Duration length) {
    if (_requested || length <= Duration.zero) return;
    _requested = true;
    for (var s = 0; s <= ScrubFrames.lastSecond(length); s++) {
      final frame = _frameAt(s);
      if (frame != null) _prefetch(frame);
    }
  }
}
