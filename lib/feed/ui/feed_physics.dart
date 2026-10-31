import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Paging for the feed, with an optional stop at [lockedPage] (PAY-3).
///
/// Paging: a critically damped spring settles in about 250 ms with no
/// overshoot, and a short flick is enough to turn the page.
///
/// The stop: past the locked page a drag works against an exponential
/// rubber band that can never show more than [give] of the next page, and a
/// release or fling always comes back to the locked page. Scrolling back is
/// not affected.
///
/// [lockedPage] is a listenable rather than a value because a Scrollable
/// keeps the physics object it was first given; the page itself changes
/// when an ad break before it is dropped, and goes away on unlock.
class LockedPagePhysics extends PageScrollPhysics {
  const LockedPagePhysics({required this.lockedPage, super.parent});

  final ValueListenable<int?> lockedPage;

  /// The most of the next page a drag can reveal, as a share of a page.
  static const double give = 0.06;

  @override
  LockedPagePhysics applyTo(ScrollPhysics? ancestor) =>
      LockedPagePhysics(lockedPage: lockedPage, parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 320);

  @override
  double get minFlingVelocity => 60;

  @override
  double get minFlingDistance => 12;

  /// Scroll offset of the locked page, or null when nothing is locked.
  double? _stopAt(ScrollMetrics m) => switch (lockedPage.value) {
    final page? => page * m.viewportDimension,
    null => null,
  };

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final stopAt = _stopAt(position);
    // Offsets are inverted: a forward drag is negative.
    final pull = -offset;
    if (stopAt == null || pull <= 0 || position.pixels + pull <= stopAt) {
      return super.applyPhysicsToUserOffset(position, offset);
    }
    // Free travel up to the stop. Beyond it the stretch s follows
    // s = cap * (1 - e^(-pull / cap)), so each extra pixel of pull moves the
    // page by the share of the give still unused.
    final cap = position.viewportDimension * give;
    final free = math.max<double>(0, stopAt - position.pixels);
    final unused = cap - math.max<double>(0, position.pixels - stopAt);
    final stretch = unused * (1 - math.exp(-(pull - free) / cap));
    return -(free + stretch);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final stopAt = _stopAt(position);
    if (stopAt != null && value > stopAt) {
      final ceiling = stopAt + position.viewportDimension * give;
      // The give is allowed even when the locked page is the last one,
      // which the parent would treat as out of range.
      if (value <= ceiling) return 0;
      // Refuse only movement beyond the ceiling and further forward; a feed
      // already past it (the lock arrived late) may still move back.
      final refused = value - math.max(ceiling, position.pixels);
      if (refused > 0) return refused;
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final stopAt = _stopAt(position);
    if (stopAt == null) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final past = position.pixels > stopAt;
    final target = math.min(_snapTarget(position, velocity, tolerance), stopAt);
    // From beyond the stop, forward momentum is dropped so the spring
    // heads straight back.
    final start = past ? math.min<double>(0, velocity) : velocity;

    if ((target - position.pixels).abs() < tolerance.distance &&
        start.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      start,
      tolerance: tolerance,
    );
  }

  double _snapTarget(
    ScrollMetrics position,
    double velocity,
    Tolerance tolerance,
  ) {
    final size = position.viewportDimension;
    var page = position.pixels / size;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return (page.roundToDouble() * size).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }
}
