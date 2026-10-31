import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/player/domain/playback_plan.dart';
import 'package:rume/player/state/video_pool.dart';

import '../helpers/fake_video_controller.dart';

void main() {
  late List<FakeVideoController> created;
  late VideoPool pool;
  late List<bool> screenAwake;

  FakeVideoController controllerOf(int episode) =>
      created.lastWhere((c) => c.source.toString() == 'v$episode');

  PlaybackPlan plan(int? active, List<int> episodes) => PlaybackPlan(
    active: active,
    slots: [for (final e in episodes) VideoSlot(episode: e, url: 'v$e')],
  );

  setUp(() {
    created = [];
    screenAwake = [];
    pool = VideoPool(
      create: (uri) {
        final c = FakeVideoController(uri);
        created.add(c);
        return c;
      },
      deferDispose: (dispose) => dispose(),
      keepScreenAwake: ({required awake}) => screenAwake.add(awake),
    );
  });

  tearDown(() => pool.dispose());

  test(
    '[PLAY-4] the active episode initialises before its neighbours',
    () async {
      pool.update(plan(2, [2, 3, 1]));
      expect(created.map((c) => c.source.toString()), ['v2']);

      controllerOf(2).completeInit();
      await pumpEventQueue();
      expect(created.map((c) => c.source.toString()), ['v2', 'v3', 'v1']);
    },
  );

  test(
    '[PLAY-1] [PLAY-2] the active episode loops and plays, others pause',
    () async {
      pool.update(plan(2, [2, 3, 1]));
      controllerOf(2).completeInit();
      await pumpEventQueue();
      controllerOf(3).completeInit();
      controllerOf(1).completeInit();
      await pumpEventQueue();

      expect(controllerOf(2).value.isPlaying, isTrue);
      expect(controllerOf(2).value.isLooping, isTrue);
      expect(controllerOf(3).value.isPlaying, isFalse);
      expect(controllerOf(1).value.isPlaying, isFalse);
      expect(pool.controllerFor(2).value, same(controllerOf(2)));
    },
  );

  test('[PLAY-2] moving on pauses the old episode and rewinds it', () async {
    pool.update(plan(2, [2, 3]));
    controllerOf(2).completeInit();
    await pumpEventQueue();
    controllerOf(3).completeInit();
    await pumpEventQueue();
    await controllerOf(2).seekTo(const Duration(seconds: 4));

    pool.update(plan(3, [3, 4, 2]));
    await pumpEventQueue();

    expect(controllerOf(2).value.isPlaying, isFalse);
    expect(controllerOf(2).value.position, Duration.zero);
    expect(controllerOf(3).value.isPlaying, isTrue);
  });

  test('[PLAY-3] controllers leaving the window are disposed', () async {
    pool.update(plan(2, [2, 3, 1]));
    controllerOf(2).completeInit();
    await pumpEventQueue();
    final first = controllerOf(1)..completeInit();
    await pumpEventQueue();

    pool.update(plan(3, [3, 4, 2]));

    expect(first.disposed, isTrue);
    expect(pool.controllerFor(1).value, isNull);
    expect(created.where((c) => !c.disposed).length, lessThanOrEqualTo(3));
  });

  test(
    '[PLAY-3] a load that lands after its episode left is disposed',
    () async {
      pool.update(plan(1, [1]));
      final late = controllerOf(1);
      pool.update(plan(5, [5]));

      late.completeInit();
      await pumpEventQueue();

      expect(late.disposed, isTrue);
      expect(pool.controllerFor(1).value, isNull);
    },
  );

  test(
    '[PLAY-7] holding pauses everything and releasing resumes the active',
    () async {
      pool.update(plan(2, [2]));
      controllerOf(2).completeInit();
      await pumpEventQueue();

      pool.setHeld(held: true);
      expect(controllerOf(2).value.isPlaying, isFalse);

      pool.setHeld(held: false);
      expect(controllerOf(2).value.isPlaying, isTrue);
    },
  );

  test(
    'a failed load is disposed and retried when the episode returns',
    () async {
      pool.update(plan(2, [2]));
      final broken = controllerOf(2)..failInit();
      await pumpEventQueue();
      expect(broken.disposed, isTrue);

      pool
        ..update(plan(4, [4]))
        ..update(plan(2, [2]));
      expect(controllerOf(2), isNot(same(broken)));
    },
  );

  test('[PLAY-8] a user pause sticks until the episode changes', () async {
    pool.update(plan(2, [2, 3]));
    controllerOf(2).completeInit();
    await pumpEventQueue();
    controllerOf(3).completeInit();
    await pumpEventQueue();

    pool.togglePause();
    expect(controllerOf(2).value.isPlaying, isFalse);
    expect(pool.paused.value, 2);

    // Unrelated plan updates (an ad removed elsewhere) don't resume it.
    pool.update(plan(2, [2, 3]));
    expect(controllerOf(2).value.isPlaying, isFalse);

    pool.update(plan(3, [3, 2]));
    expect(pool.paused.value, isNull);
    expect(controllerOf(3).value.isPlaying, isTrue);
  });

  test('[SCRUB-6] seeking moves the episode to the target', () async {
    pool.update(plan(2, [2]));
    controllerOf(2).completeInit();
    await pumpEventQueue();

    pool.seek(2, const Duration(seconds: 9));
    expect(controllerOf(2).value.position, const Duration(seconds: 9));
  });

  test(
    '[PLAY-9] mute silences ready videos and ones that load later',
    () async {
      pool.update(plan(2, [2, 3]));
      controllerOf(2).completeInit();
      await pumpEventQueue();

      pool.toggleMute();
      expect(pool.muted.value, isTrue);
      expect(controllerOf(2).value.volume, 0);

      controllerOf(3).completeInit();
      await pumpEventQueue();
      expect(controllerOf(3).value.volume, 0);

      pool.toggleMute();
      expect(controllerOf(2).value.volume, 1);
      expect(controllerOf(3).value.volume, 1);
    },
  );

  test(
    '[SPLASH-3] holds for different reasons do not release each other',
    () async {
      pool.update(plan(1, [1]));
      controllerOf(1).completeInit();
      await pumpEventQueue();

      pool
        ..setHeld(held: true, reason: #splash)
        ..setHeld(held: true)
        ..setHeld(held: false);
      expect(controllerOf(1).value.isPlaying, isFalse);

      pool.setHeld(held: false, reason: #splash);
      expect(controllerOf(1).value.isPlaying, isTrue);
    },
  );

  group('[PLAY-10] the screen stays awake only while a video plays', () {
    Future<void> playing(int episode) async {
      pool.update(plan(episode, [episode]));
      controllerOf(episode).completeInit();
      await pumpEventQueue();
    }

    test('[PLAY-10] not before the video is ready, then on', () async {
      pool.update(plan(1, [1]));
      expect(screenAwake, isEmpty);
      controllerOf(1).completeInit();
      await pumpEventQueue();
      expect(screenAwake, [true]);
    });

    test('[PLAY-10] a tap pause releases it, resuming takes it back', () async {
      await playing(1);
      pool
        ..togglePause()
        ..togglePause();
      expect(screenAwake, [true, false, true]);
    });

    test(
      '[PLAY-10] an ad or the paywall (no active episode) releases it',
      () async {
        await playing(1);
        pool.update(plan(null, [1]));
        expect(screenAwake, [true, false]);
      },
    );

    test('[PLAY-10] a hold (background, splash) releases it', () async {
      await playing(1);
      pool
        ..setHeld(held: true)
        ..setHeld(held: false);
      expect(screenAwake, [true, false, true]);
    });

    test('[PLAY-10] disposing the pool releases it', () async {
      await playing(1);
      pool.dispose();
      expect(screenAwake.last, isFalse);
    });
  });

  group('failed loads', () {
    test('[OFF-2] a failed episode is retried every 3 s; the flag holds '
        'through the retries and clears when one succeeds', () {
      fakeAsync((async) {
        pool.update(plan(1, [1]));
        controllerOf(1).failInit();
        async.flushMicrotasks();
        expect(pool.failedFor(1).value, isTrue);
        expect(created, hasLength(1));

        async.elapse(const Duration(milliseconds: 2900));
        expect(created, hasLength(1), reason: 'not before 3 s');
        async.elapse(const Duration(milliseconds: 100));
        expect(created, hasLength(2));
        expect(pool.failedFor(1).value, isTrue, reason: 'no flicker');

        controllerOf(1).failInit();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 3));
        expect(created, hasLength(3));

        controllerOf(1).completeInit();
        async.flushMicrotasks();
        expect(pool.failedFor(1).value, isFalse);
        expect(controllerOf(1).value.isPlaying, isTrue);

        async.elapse(const Duration(seconds: 10));
        expect(created, hasLength(3), reason: 'nothing left to retry');
      });
    });

    test('[OFF-3] retry() tries again at once', () {
      fakeAsync((async) {
        pool.update(plan(1, [1]));
        controllerOf(1).failInit();
        async.flushMicrotasks();

        pool.retry();
        expect(created, hasLength(2));
        controllerOf(1).completeInit();
        async.flushMicrotasks();
        expect(pool.failedFor(1).value, isFalse);

        async.elapse(const Duration(seconds: 3));
        expect(created, hasLength(2), reason: 'the timer was cancelled');
      });
    });

    test('[OFF-4] one episode failing leaves a playing one alone', () {
      fakeAsync((async) {
        pool.update(plan(1, [1, 2]));
        controllerOf(1).completeInit();
        async.flushMicrotasks();
        controllerOf(2).failInit();
        async.flushMicrotasks();

        expect(pool.failedFor(2).value, isTrue);
        expect(controllerOf(1).value.isPlaying, isTrue);
        expect(controllerOf(1).disposed, isFalse);

        async.elapse(const Duration(seconds: 3));
        expect(controllerOf(1).disposed, isFalse);
        expect(pool.controllerFor(1).value, same(controllerOf(1)));
      });
    });

    test(
      '[OFF-5] leaving the window stops the retries and clears the flag',
      () {
        fakeAsync((async) {
          pool.update(plan(1, [1, 2]));
          controllerOf(1).completeInit();
          async.flushMicrotasks();
          controllerOf(2).failInit();
          async.flushMicrotasks();

          pool.update(plan(5, [5]));
          expect(pool.failedFor(2).value, isFalse);
          final before = created.length;
          async.elapse(const Duration(seconds: 10));
          expect(
            created.skip(before).where((c) => c.source.toString() == 'v2'),
            isEmpty,
          );
        });
      },
    );
  });
}
