import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/ads/ad_break_page.dart';
import 'package:rume/ads/break_ad_loader.dart';
import 'package:rume/player/ui/heart_burst.dart';
import 'package:rume/shared/brand_skeleton.dart';

import '../helpers/fake_break_ad.dart';

const _break = 'break:1';

void main() {
  late BreakAdLoader ads;
  late FakeBreakAd ad;

  Future<void> pumpPage(WidgetTester tester) async {
    ads = BreakAdLoader(
      make: (id, {required onFilled, required onEmpty}) =>
          ad = FakeBreakAd(id, onFilled: onFilled, onEmpty: onEmpty),
    )..warm([_break]);
    addTearDown(ads.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<BreakAdLoader>.value(
          value: ads,
          child: const Scaffold(body: AdBreakPage(breakId: _break)),
        ),
      ),
    );
  }

  testWidgets('[AD-2] a pending ad shows the branded skeleton', (tester) async {
    await pumpPage(tester);
    expect(find.byType(BrandSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(FakeBreakAd.viewKey), findsNothing);
    ads.dispose(); // stops the load deadline timer
  });

  testWidgets('[AD-7] a filled ad covers the page and the skeleton fades', (
    tester,
  ) async {
    await pumpPage(tester);
    ad.onFilled();
    await tester.pump();

    expect(
      tester.getSize(find.byKey(FakeBreakAd.viewKey)),
      const Size(800, 600),
    );
    // Nothing in the page fades or moves the native view itself.
    for (final type in [Opacity, FadeTransition, Transform]) {
      expect(
        find.ancestor(
          of: find.byKey(FakeBreakAd.viewKey),
          matching: find.descendant(
            of: find.byType(AdBreakPage),
            matching: find.byType(type),
          ),
        ),
        findsNothing,
      );
    }

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BrandSkeleton), findsNothing);
  });

  testWidgets('[AD-4] taps reach the ad and episode gestures do nothing', (
    tester,
  ) async {
    await pumpPage(tester);
    ad.onFilled();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 400));

    expect(ad.taps, 2);
    expect(find.byType(HeartBurst), findsNothing);
  });
}
