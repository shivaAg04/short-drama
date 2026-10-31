import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/engagement/data/share_service.dart';
import 'package:rume/engagement/state/engagement_cubit.dart';
import 'package:rume/engagement/ui/action_rail.dart';
import 'package:rume/engagement/ui/comments_sheet.dart';
import 'package:rume/feed/domain/episode.dart';

import '../helpers/fake_share_service.dart';

const _episode = Episode(
  number: 1,
  videoUrl: 'v1',
  posterUrl: 'p1',
  counts: (likes: 12480, comments: 0, shares: 999),
);

void main() {
  late EngagementCubit cubit;
  late FakeShareService sharer;

  Future<void> pumpRail(WidgetTester tester) async {
    cubit = EngagementCubit(episodes: [_episode]);
    sharer = FakeShareService();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<ShareService>.value(
          value: sharer,
          child: BlocProvider.value(
            value: cubit,
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomRight,
                child: ActionRail(episode: _episode, likeKey: GlobalKey()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('[RAIL-1] like, comment, share and save with counts', (
    tester,
  ) async {
    await pumpRail(tester);
    expect(find.byKey(ActionRail.likeButtonKey), findsOneWidget);
    expect(find.byKey(ActionRail.commentButtonKey), findsOneWidget);
    expect(find.byKey(ActionRail.shareButtonKey), findsOneWidget);
    expect(find.byKey(ActionRail.saveButtonKey), findsOneWidget);
    expect(find.text('12.4K'), findsOneWidget);
    expect(find.text('999'), findsOneWidget);
  });

  testWidgets('[RAIL-2] tapping like fills the heart and bumps the count', (
    tester,
  ) async {
    await pumpRail(tester);
    await tester.tap(find.byKey(ActionRail.likeButtonKey));
    await tester.pump();
    expect(cubit.state.of(1).liked, isTrue);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('[RAIL-3] tapping save fills the bookmark', (tester) async {
    await pumpRail(tester);
    await tester.tap(find.byKey(ActionRail.saveButtonKey));
    await tester.pump();
    expect(cubit.state.of(1).saved, isTrue);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('[RAIL-4] comment opens the sheet and posting adds to the top', (
    tester,
  ) async {
    await pumpRail(tester);
    await tester.tap(find.byKey(ActionRail.commentButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(CommentsSheet), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'need ep 7 now');
    await tester.tap(find.byKey(CommentsSheet.sendKey));
    await tester.pumpAndSettle();
    expect(cubit.state.of(1).comments.first.text, 'need ep 7 now');
    expect(find.text('need ep 7 now'), findsOneWidget);
  });

  testWidgets('[RAIL-5] share opens the system sheet and counts a share', (
    tester,
  ) async {
    await pumpRail(tester);
    await tester.tap(find.byKey(ActionRail.shareButtonKey));
    await tester.pumpAndSettle();
    expect(sharer.shared, [1]);
    expect(cubit.state.of(1).shares, 1000);
    expect(find.text('1K'), findsOneWidget);
  });

  testWidgets('[RAIL-9] liking sends a ripple out of the heart; unliking not', (
    tester,
  ) async {
    await pumpRail(tester);
    double burst() =>
        (tester
                    .widget<CustomPaint>(find.byKey(ActionRail.likeBurstKey))
                    .painter!
                as RailBurstPainter)
            .progress
            .value;
    expect(burst(), 0);

    await tester.tap(find.byKey(ActionRail.likeButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(burst(), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ActionRail.likeButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(burst(), 1, reason: 'no new ripple when unliking');
    await tester.pumpAndSettle();
  });

  testWidgets('[RAIL-4] the keyboard send key posts too', (tester) async {
    await pumpRail(tester);
    await tester.tap(find.byKey(ActionRail.commentButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'from the keyboard');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(cubit.state.of(1).comments.first.text, 'from the keyboard');
  });

  testWidgets('[RAIL-2] pressing like and sliding off does not like', (
    tester,
  ) async {
    await pumpRail(tester);
    final press = await tester.startGesture(
      tester.getCenter(find.byKey(ActionRail.likeButtonKey)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await press.moveBy(const Offset(-200, 0));
    await press.up();
    await tester.pumpAndSettle();
    expect(cubit.state.of(1).liked, isFalse);
  });
}
