import 'package:flutter_test/flutter_test.dart';
import 'package:rume/player/domain/scrub_frames.dart';

void main() {
  group('[SCRUB-10] frame URLs', () {
    test('[SCRUB-10] a Cloudinary video gives a still of any second', () {
      expect(
        ScrubFrames.urlAt(
          'https://res.cloudinary.com/demo/video/upload/ep1.mp4',
          7,
        ),
        'https://res.cloudinary.com/demo/video/upload/'
        'c_fill,h_384,w_216,so_7,q_auto/ep1.jpg',
      );
    });

    test('[SCRUB-10] the version segment is kept', () {
      expect(
        ScrubFrames.urlAt(
          'https://res.cloudinary.com/demo/video/upload/v17934/ep1.mp4',
          0,
        ),
        'https://res.cloudinary.com/demo/video/upload/'
        'c_fill,h_384,w_216,so_0,q_auto/v17934/ep1.jpg',
      );
    });

    test('[SCRUB-10] any other host has no frames', () {
      expect(ScrubFrames.urlAt('https://example.com/ep1.mp4', 3), isNull);
    });
  });

  test('[SCRUB-8] the nearest second, kept inside the video', () {
    const length = Duration(milliseconds: 15090);
    expect(ScrubFrames.nearest(const Duration(milliseconds: 7400), length), 7);
    expect(ScrubFrames.nearest(const Duration(milliseconds: 7500), length), 8);
    expect(ScrubFrames.nearest(length, length), 15);
    expect(ScrubFrames.lastSecond(const Duration(seconds: 20)), 19);
  });

  group('[SCRUB-9] prefetching', () {
    test('[SCRUB-9] one request per second, on the first scrub only', () {
      final fetched = <int>[];
      final frames = FramePrefetcher<int>((s) => s, fetched.add)
        ..ensure(const Duration(milliseconds: 4200));
      expect(fetched, [0, 1, 2, 3, 4]);

      frames.ensure(const Duration(milliseconds: 4200));
      expect(fetched, hasLength(5));
    });

    test(
      '[SCRUB-9] [SCRUB-10] nothing is fetched when there are no frames',
      () {
        final fetched = <int>[];
        FramePrefetcher<int>(
          (s) => null,
          fetched.add,
        ).ensure(const Duration(seconds: 3));
        expect(fetched, isEmpty);
      },
    );

    test('[SCRUB-9] an unknown length waits for the next scrub', () {
      final fetched = <int>[];
      FramePrefetcher<int>((s) => s, fetched.add)
        ..ensure(Duration.zero)
        ..ensure(const Duration(seconds: 2));
      expect(fetched, [0, 1]);
    });
  });
}
