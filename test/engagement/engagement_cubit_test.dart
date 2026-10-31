import 'package:flutter_test/flutter_test.dart';
import 'package:rume/engagement/state/engagement_cubit.dart';
import 'package:rume/feed/domain/episode.dart';

final List<Episode> _episodes = [
  for (var n = 1; n <= 3; n++)
    Episode(
      number: n,
      videoUrl: 'v$n',
      posterUrl: 'p$n',
      counts: (likes: 100 * n, comments: 0, shares: 10 * n),
    ),
];

void main() {
  late EngagementCubit cubit;

  setUp(() => cubit = EngagementCubit(episodes: _episodes));
  tearDown(() => cubit.close());

  EpisodeEngagement of(int n) => cubit.state.of(n);

  test('[RAIL-7] each episode starts from its catalogue counts', () {
    expect(of(2).likes, 200);
    expect(of(2).liked, isFalse);
    expect(of(2).comments, isNotEmpty);
  });

  test('[RAIL-2] toggling like moves the count by one each way', () {
    cubit.toggleLike(1);
    expect(of(1).liked, isTrue);
    expect(of(1).likes, 101);
    cubit.toggleLike(1);
    expect(of(1).liked, isFalse);
    expect(of(1).likes, 100);
  });

  test('[LIKE-5] a double-tap like never unlikes', () {
    cubit
      ..likeFromDoubleTap(1)
      ..likeFromDoubleTap(1);
    expect(of(1).liked, isTrue);
    expect(of(1).likes, 101);
  });

  test('[RAIL-3] toggling save', () {
    cubit.toggleSave(3);
    expect(of(3).saved, isTrue);
    cubit.toggleSave(3);
    expect(of(3).saved, isFalse);
  });

  test('[RAIL-4] a posted comment goes to the top and bumps the count', () {
    final before = of(1).commentCount;
    cubit.postComment(1, '  that ending  ');
    expect(of(1).comments.first.text, 'that ending');
    expect(of(1).commentCount, before + 1);

    cubit.postComment(1, '   ');
    expect(of(1).commentCount, before + 1, reason: 'blank is ignored');
  });

  test('[RAIL-5] a completed share bumps the count', () {
    cubit.recordShare(2);
    expect(of(2).shares, 21);
  });

  test('[RAIL-7] state is per episode', () {
    cubit
      ..toggleLike(1)
      ..toggleSave(2);
    expect(of(2).liked, isFalse);
    expect(of(1).saved, isFalse);
  });
}
