import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/splash/brand_splash.dart';

void main() {
  late ValueNotifier<Object?> ready;
  late int left;
  late int feedTaps;

  Future<void> pumpSplash(WidgetTester tester) async {
    ready = ValueNotifier(null);
    addTearDown(ready.dispose);
    left = 0;
    feedTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BrandSplash(
          ready: ready,
          onLeave: () => left++,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => feedTaps++,
          ),
        ),
      ),
    );
  }

  double panelScale(WidgetTester tester) => tester
      .widget<Transform>(find.byKey(BrandSplash.panelKey))
      .transform
      .entry(0, 0);

  double wordOpacity(WidgetTester tester, String word) => tester
      .widget<FadeTransition>(
        find
            .ancestor(
              of: find.text(word),
              matching: find.byType(FadeTransition),
            )
            .first,
      )
      .opacity
      .value;

  // Runs the splash out so no timer outlives the test.
  Future<void> finish(WidgetTester tester) async {
    ready.value = Object();
    await tester.pump(BrandSplash.maxWait);
    await tester.pump(BrandSplash.exitDuration);
  }

  testWidgets('[SPLASH-1] the panel springs in, overshoots and settles', (
    tester,
  ) async {
    await pumpSplash(tester);
    expect(panelScale(tester), lessThan(0.5));

    var largest = 0.0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final s = panelScale(tester);
      if (s > largest) largest = s;
    }
    expect(largest, greaterThan(1.03));
    await tester.pump(const Duration(milliseconds: 500));
    expect(panelScale(tester), closeTo(1, 0.01));
    await finish(tester);
  });

  testWidgets('[SPLASH-2] the tagline arrives one word at a time', (
    tester,
  ) async {
    await pumpSplash(tester);
    expect(wordOpacity(tester, 'Stream.'), 0);

    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(const Duration(milliseconds: 300));
    final stream = wordOpacity(tester, 'Stream.');
    final binge = wordOpacity(tester, 'Binge.');
    final drama = wordOpacity(tester, 'Drama.');
    expect(stream, greaterThan(binge));
    expect(binge, greaterThan(drama));

    await tester.pump(const Duration(seconds: 1));
    expect(wordOpacity(tester, 'Drama.'), 1);
    await finish(tester);
  });

  testWidgets('[SPLASH-4] a ready feed still waits for the intro', (
    tester,
  ) async {
    await pumpSplash(tester);
    ready.value = Object();
    await tester.pump(const Duration(milliseconds: 1400));
    expect(left, 0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(left, 1);
    await finish(tester);
  });

  testWidgets('[SPLASH-4] after the intro it leaves as soon as the feed is '
      'ready', (tester) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(left, 0);

    ready.value = Object();
    expect(left, 1);
    await finish(tester);
  });

  testWidgets('[SPLASH-4] it gives up waiting after 3 s', (tester) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 2990));
    expect(left, 0);
    await tester.pump(const Duration(milliseconds: 10));
    expect(left, 1);
    await finish(tester);
  });

  testWidgets('[SPLASH-5] it fades out growing, then leaves the tree', (
    tester,
  ) async {
    await pumpSplash(tester);
    ready.value = Object();
    await tester.pump(BrandSplash.minShow);
    await tester.pump(const Duration(milliseconds: 250));

    final overlay = find.byKey(BrandSplash.overlayKey);
    final opacity = tester
        .widget<Opacity>(
          find.descendant(of: overlay, matching: find.byType(Opacity)).first,
        )
        .opacity;
    expect(opacity, inExclusiveRange(0, 1));

    await tester.pump(BrandSplash.exitDuration);
    expect(overlay, findsNothing);
    expect(left, 1);
  });

  testWidgets('[SPLASH-6] touches during the splash do not reach the feed', (
    tester,
  ) async {
    await pumpSplash(tester);
    await tester.tapAt(const Offset(400, 300));
    expect(feedTaps, 0);

    await finish(tester);
    await tester.tapAt(const Offset(400, 300));
    expect(feedTaps, 1);
  });
}
