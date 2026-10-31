import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/ads/break_ad_loader.dart';

import '../helpers/fake_break_ad.dart';

const _first = 'break:1';
const _second = 'break:2';

void main() {
  late List<FakeBreakAd> made;
  late List<String> emptied;

  BreakAdLoader loader({Exception? throwOnLoad}) {
    made = [];
    emptied = [];
    return BreakAdLoader(
      make: (id, {required onFilled, required onEmpty}) {
        final ad = FakeBreakAd(id, onFilled: onFilled, onEmpty: onEmpty)
          ..throwOnLoad = throwOnLoad;
        made.add(ad);
        return ad;
      },
    )..onEmpty = emptied.add;
  }

  test('[AD-1] warming requests each break once', () {
    final ads = loader()
      ..warm([_first])
      ..warm([_first, _second]);
    expect(made.map((a) => a.breakId), [_first, _second]);
    expect(made.every((a) => a.requested), isTrue);
    expect(ads.statusOf(_first).value, isA<BreakAdPending>());
    ads.dispose();
  });

  test('[AD-1] a page that looks first still gets its ad requested', () {
    final ads = loader();
    expect(ads.statusOf(_first).value, isA<BreakAdPending>());
    ads.warm([_first]);
    expect(made, hasLength(1));
    ads.dispose();
  });

  test('[AD-1] a filled ad is handed to its page', () {
    final ads = loader()..warm([_first]);
    made.single.onFilled();
    final status = ads.statusOf(_first).value;
    expect(status, isA<BreakAdFilled>());
    expect((status as BreakAdFilled).ad, same(made.single));
    ads.dispose();
  });

  test('[AD-3] an error or no fill empties the break and says so', () {
    final ads = loader()..warm([_first]);
    made.single.onEmpty('3: No fill');

    expect(ads.statusOf(_first).value, isA<BreakAdEmpty>());
    expect(made.single.disposed, isTrue);
    expect(emptied, [_first]);
    ads.dispose();
  });

  test(
    '[AD-3] a request that throws is empty at once, not at the deadline',
    () {
      fakeAsync((async) {
        final ads = loader(throwOnLoad: Exception('No NativeAdFactory'))
          ..warm([_first]);
        async.flushMicrotasks();

        expect(emptied, [_first]);
        expect(ads.statusOf(_first).value, isA<BreakAdEmpty>());
        ads.dispose();
      });
    },
  );

  test('[AD-3] an ad still pending after 8 s counts as empty', () {
    fakeAsync((async) {
      final ads = loader()..warm([_first]);
      async.elapse(const Duration(seconds: 7));
      expect(emptied, isEmpty);

      async.elapse(const Duration(seconds: 2));
      expect(emptied, [_first]);

      // Too late: the fill is ignored.
      made.single.onFilled();
      expect(ads.statusOf(_first).value, isA<BreakAdEmpty>());
      ads.dispose();
    });
  });

  test('[AD-6] a discarded break disposes its ad and ignores late answers', () {
    final ads = loader()..warm([_first, _second]);
    made.first.onFilled();

    ads
      ..discard(_first)
      ..discard(_second);
    expect(made.every((a) => a.disposed), isTrue);

    made.last.onFilled();
    expect(ads.statusOf(_second).value, isNot(isA<BreakAdFilled>()));
    expect(emptied, isEmpty, reason: 'discarding is not a failure');
    ads.dispose();
  });

  test('[AD-6] disposing the loader disposes every ad', () {
    loader()
      ..warm([_first, _second])
      ..dispose();
    expect(made.every((a) => a.disposed), isTrue);
  });
}
