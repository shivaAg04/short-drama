import 'package:flutter_test/flutter_test.dart';
import 'package:rume/player/ui/progress_bar.dart';

const _len = Duration(seconds: 15);

void main() {
  test('[SCRUB-7] a playing video advances between position updates', () {
    final share = interpolatedShare(
      reported: const Duration(seconds: 3),
      length: _len,
      sinceReport: const Duration(milliseconds: 300),
      advancing: true,
    );
    expect(share, closeTo(3.3 / 15, 1e-9));
  });

  test('[SCRUB-7] never runs more than 600 ms ahead of the last report', () {
    final share = interpolatedShare(
      reported: const Duration(seconds: 3),
      length: _len,
      sinceReport: const Duration(seconds: 5),
      advancing: true,
    );
    expect(share, closeTo(3.6 / 15, 1e-9));
  });

  test('[SCRUB-7] a paused or buffering video does not move', () {
    final share = interpolatedShare(
      reported: const Duration(seconds: 3),
      length: _len,
      sinceReport: const Duration(milliseconds: 300),
      advancing: false,
    );
    expect(share, closeTo(3 / 15, 1e-9));
  });

  test('[SCRUB-7] stays within the clip and copes with an unknown length', () {
    expect(
      interpolatedShare(
        reported: const Duration(milliseconds: 14900),
        length: _len,
        sinceReport: const Duration(milliseconds: 500),
        advancing: true,
      ),
      1,
    );
    expect(
      interpolatedShare(
        reported: Duration.zero,
        length: Duration.zero,
        sinceReport: Duration.zero,
        advancing: true,
      ),
      0,
    );
  });
}
