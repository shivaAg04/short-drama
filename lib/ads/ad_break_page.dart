import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rume/ads/break_ad_loader.dart';
import 'package:rume/shared/brand_skeleton.dart';

/// The full-screen page for one ad break.
///
/// It has no episode gestures at all (AD-4): taps go to the native ad's own
/// view, and vertical drags go to the feed. While the ad is pending the
/// branded skeleton covers the page (AD-2); once filled, the ad is placed
/// underneath and the skeleton fades away above it. The native view itself
/// is never faded or transformed, which Android renders slowly and badly.
class AdBreakPage extends StatelessWidget {
  const AdBreakPage({required this.breakId, super.key});

  final String breakId;

  @override
  Widget build(BuildContext context) {
    final status = context.read<BreakAdLoader>().statusOf(breakId);
    return _StayAlive(
      child: ColoredBox(
        color: Colors.black,
        child: ValueListenableBuilder<BreakAdStatus>(
          valueListenable: status,
          builder: (context, status, _) {
            final ad = switch (status) {
              BreakAdFilled(:final ad) => ad,
              _ => null,
            };
            // An empty break is taken out of the feed by the bloc; until
            // then it keeps its skeleton rather than showing anything broken.
            return Stack(
              fit: StackFit.expand,
              children: [
                if (ad != null) ad.buildView(),
                _SkeletonCover(lifted: ad != null),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The skeleton over a break, fading out once [lifted] and then leaving the
/// tree. A break that was filled before its page was built starts lifted.
class _SkeletonCover extends StatefulWidget {
  const _SkeletonCover({required this.lifted});

  final bool lifted;

  @override
  State<_SkeletonCover> createState() => _SkeletonCoverState();
}

class _SkeletonCoverState extends State<_SkeletonCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shown = AnimationController(
    vsync: this,
    value: widget.lifted ? 0 : 1,
    duration: const Duration(milliseconds: 280),
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) {
    if (status.isDismissed) setState(() {});
  }

  @override
  void didUpdateWidget(_SkeletonCover old) {
    super.didUpdateWidget(old);
    if (widget.lifted && !old.lifted) {
      _shown.animateBack(0, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shown.isDismissed) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: widget.lifted,
      child: FadeTransition(opacity: _shown, child: const BrandSkeleton()),
    );
  }
}

/// Keeps a break's page, and the native view inside it, alive after it
/// scrolls out of the PageView's cache, so swiping back is instant.
class _StayAlive extends StatefulWidget {
  const _StayAlive({required this.child});

  final Widget child;

  @override
  State<_StayAlive> createState() => _StayAliveState();
}

class _StayAliveState extends State<_StayAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
