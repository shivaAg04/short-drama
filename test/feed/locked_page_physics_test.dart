import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/feed/ui/feed_physics.dart';

const _viewport = 800.0;
const _lockedPage = 8;
const double _limit = _lockedPage * _viewport;

ScrollMetrics _at(double pixels, {int pages = 10}) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: (pages - 1) * _viewport,
  pixels: pixels,
  viewportDimension: _viewport,
  axisDirection: AxisDirection.down,
  devicePixelRatio: 1,
);

void main() {
  final lock = ValueNotifier<int?>(_lockedPage);
  final physics = LockedPagePhysics(lockedPage: lock);
  const maxGive = LockedPagePhysics.give * _viewport;

  setUp(() => lock.value = _lockedPage);

  test('[PAY-3] a drag past the lock meets heavy resistance', () {
    final moved = physics.applyPhysicsToUserOffset(_at(_limit), -100);
    expect(moved.abs(), lessThan(50));
  });

  test('[PAY-3] however far the drag, the next page shows less than 6%', () {
    var pixels = _limit - 50;
    for (var i = 0; i < 10; i++) {
      pixels -= physics.applyPhysicsToUserOffset(_at(pixels), -60);
    }
    expect(pixels, greaterThan(_limit));
    expect(pixels, lessThan(_limit + maxGive));
  });

  test('[PAY-3] up to the lock a drag moves freely', () {
    expect(physics.applyPhysicsToUserOffset(_at(_limit - 200), -100), -100);
  });

  test('[PAY-3] overscroll past the lock is capped at 6% of a page', () {
    const edge = _limit + maxGive;
    expect(physics.applyBoundaryConditions(_at(_limit), _limit + 20), 0);
    expect(
      physics.applyBoundaryConditions(_at(edge - 1), edge + 100),
      closeTo(100, 0.001),
    );
  });

  test('[PAY-3] the lock still gives a little at the very end of the feed', () {
    final atEnd = _at(_limit, pages: _lockedPage + 1);
    expect(physics.applyBoundaryConditions(atEnd, _limit + 10), 0);
  });

  test('[PAY-3] a hard fling towards the lock lands on the locked page', () {
    final sim = physics.createBallisticSimulation(_at(_limit - 300), 6000)!;
    expect(sim.x(3), closeTo(_limit, 1));
  });

  test('[PAY-3] released past the lock, the feed springs back to it', () {
    final sim = physics.createBallisticSimulation(_at(_limit + 30), 0)!;
    expect(sim.x(3), closeTo(_limit, 1));
  });

  test('[PAY-3] scrolling back is unaffected', () {
    expect(physics.applyPhysicsToUserOffset(_at(_limit), 100), 100);
    final sim = physics.createBallisticSimulation(_at(_limit - 300), -6000)!;
    expect(sim.x(3), closeTo(_limit - _viewport, 1));
  });

  test('[PAY-9] [PAY-8] the lock follows its page and lifts on unlock', () {
    lock.value = _lockedPage - 1;
    var sim = physics.createBallisticSimulation(_at(_limit - 300), 6000)!;
    expect(sim.x(3), closeTo(_limit - _viewport, 1));

    lock.value = null;
    sim = physics.createBallisticSimulation(_at(_limit - 300), 6000)!;
    expect(sim.x(3), closeTo(_limit, 1));
  });
}
