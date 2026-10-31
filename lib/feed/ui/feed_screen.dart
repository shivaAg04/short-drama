import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rume/ads/ad_break_page.dart';
import 'package:rume/ads/ad_config.dart';
import 'package:rume/ads/break_ad_loader.dart';
import 'package:rume/engagement/data/share_service.dart';
import 'package:rume/engagement/state/engagement_cubit.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/domain/feed_entry.dart';
import 'package:rume/feed/state/feed_bloc.dart';
import 'package:rume/feed/ui/feed_physics.dart';
import 'package:rume/feed/ui/feed_top_bar.dart';
import 'package:rume/paywall/state/paywall_cubit.dart';
import 'package:rume/player/domain/playback_plan.dart';
import 'package:rume/player/state/video_pool.dart';
import 'package:rume/player/ui/episode_page.dart';
import 'package:rume/splash/brand_splash.dart';

/// Where the feed is put together: this widget creates the blocs, the video
/// pool and the ad loader, connects them, and disposes them. Everything
/// below it only reads state and sends events.
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    required this.episodes,
    this.pool,
    this.ads,
    this.splash = true,
    super.key,
  });

  final List<Episode> episodes;

  /// Shows the launch splash over the feed while it loads.
  final bool splash;

  /// Injected in tests; otherwise real ones are created and owned here.
  final VideoPool? pool;
  final BreakAdLoader? ads;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final FeedBloc _feed = FeedBloc(episodes: widget.episodes);
  late final PaywallCubit _paywall = PaywallCubit();
  late final EngagementCubit _engagement = EngagementCubit(
    episodes: widget.episodes,
  );
  late final VideoPool _pool = widget.pool ?? VideoPool();
  late final BreakAdLoader _ads = widget.ads ?? BreakAdLoader();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) => _pool.setHeld(held: s != AppLifecycleState.resumed),
    );
    _ads.onEmpty = (id) => _feed.add(AdBreakFailed(id));
    // The first episode buffers under the splash but doesn't play yet.
    if (widget.splash) _pool.setHeld(held: true, reason: _splashHold);
    _syncPool();
    _warmAds();
  }

  static const _splashHold = #splash;

  @override
  void dispose() {
    _lifecycle.dispose();
    _ads
      ..onEmpty = null
      ..dispose();
    _pool.dispose();
    unawaited(_feed.close());
    unawaited(_paywall.close());
    unawaited(_engagement.close());
    super.dispose();
  }

  void _syncPool() =>
      _pool.update(PlaybackPlan.from(_feed.state, _paywall.state));

  void _warmAds() => _ads.warm(_feed.state.breaksAhead(AdConfig.warmAhead));

  // Breaks whose ads have been handed back to the loader.
  Set<String> _discarded = const {};

  void _discardDropped(Set<String> dropped) {
    dropped.difference(_discarded).forEach(_ads.discard);
    _discarded = dropped;
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: _pool),
        RepositoryProvider.value(value: _ads),
        RepositoryProvider<ShareService>.value(value: const ShareService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _feed),
          BlocProvider.value(value: _paywall),
          BlocProvider.value(value: _engagement),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<FeedBloc, FeedState>(
              listenWhen: (a, b) =>
                  a.focusId != b.focusId || a.dropped != b.dropped,
              listener: (_, s) {
                _discardDropped(s.dropped);
                _syncPool();
                _warmAds();
              },
            ),
            BlocListener<PaywallCubit, PaywallState>(
              listenWhen: (a, b) => a.unlocked != b.unlocked,
              listener: (_, s) {
                if (s.unlocked) unawaited(HapticFeedback.mediumImpact());
                _syncPool();
              },
            ),
          ],
          child: Scaffold(
            body: widget.splash
                ? BrandSplash(
                    ready: _pool.controllerFor(widget.episodes.first.number),
                    onLeave: () =>
                        _pool.setHeld(held: false, reason: _splashHold),
                    child: const FeedTopBar(child: _FeedPager()),
                  )
                : const FeedTopBar(child: _FeedPager()),
          ),
        ),
      ),
    );
  }
}

class _FeedPager extends StatefulWidget {
  const _FeedPager();

  @override
  State<_FeedPager> createState() => _FeedPagerState();
}

class _FeedPagerState extends State<_FeedPager> {
  late final FeedBloc _feed = context.read<FeedBloc>();
  late final PaywallCubit _paywall = context.read<PaywallCubit>();
  late final PageController _pages = PageController()..addListener(_onMove);
  late final ValueNotifier<int?> _lockedPage = ValueNotifier(_lockPage());

  // The position whose scrolling state we report to the bloc.
  ScrollPosition? _watched;

  // Whether this gesture has already given its haptic tap against the lock.
  bool _bumped = false;

  @override
  void dispose() {
    _watched?.isScrollingNotifier.removeListener(_onScrollingChanged);
    _lockedPage.dispose();
    _pages.dispose();
    super.dispose();
  }

  int? _lockPage() => _paywall.state.unlocked
      ? null
      : _feed.state.pageOf(_paywall.state.lockedEpisode);

  void _watchPosition(Duration _) {
    if (!mounted || !_pages.hasClients) return;
    final position = _pages.position;
    if (identical(position, _watched)) return;
    _watched?.isScrollingNotifier.removeListener(_onScrollingChanged);
    _watched = position..isScrollingNotifier.addListener(_onScrollingChanged);
  }

  void _onScrollingChanged() {
    final active = _watched!.isScrollingNotifier.value;
    if (active) _bumped = false;
    _feed.add(FeedScrolling(active: active));
  }

  void _onMove() {
    final lock = _lockedPage.value;
    if (_bumped || lock == null) return;
    final p = _pages.position;
    if (p.pixels > lock * p.viewportDimension + 1) {
      _bumped = true;
      unawaited(HapticFeedback.lightImpact());
    }
  }

  /// Keeps the PageView on the focused entry. After a break behind the user
  /// is dropped, the entry's index is one lower: the controller jumps there
  /// before the next frame is drawn, so the content on screen never moves.
  void _seat(FeedState state) {
    if (!_pages.hasClients) return;
    final glide = state.glideTo;
    if (glide != null) {
      _pages.animateToPage(
        state.indexOf(glide),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else if (_pages.page?.round() != state.page) {
      _pages.jumpToPage(state.page);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_watchPosition);
    return MultiBlocListener(
      listeners: [
        BlocListener<FeedBloc, FeedState>(
          listenWhen: (a, b) => a.dropped != b.dropped,
          listener: (_, s) {
            _lockedPage.value = _lockPage();
            _seat(s);
          },
        ),
        BlocListener<FeedBloc, FeedState>(
          listenWhen: (a, b) => b.glideTo != null && a.glideTo != b.glideTo,
          listener: (_, s) => _seat(s),
        ),
        BlocListener<PaywallCubit, PaywallState>(
          listener: (_, _) => _lockedPage.value = _lockPage(),
        ),
      ],
      child: BlocBuilder<FeedBloc, FeedState>(
        buildWhen: (a, b) => a.dropped != b.dropped,
        builder: (context, state) {
          final entries = state.entries;
          final pageById = {for (final (i, e) in entries.indexed) e.id: i};
          return PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            // Snapping is done by LockedPagePhysics. PageView's built-in
            // snapping wraps the physics and would let a fling past the lock.
            pageSnapping: false,
            physics: LockedPagePhysics(
              lockedPage: _lockedPage,
              parent: const ClampingScrollPhysics(),
            ),
            // Builds the page after the visible one too, so it is already
            // laid out when a swipe begins.
            allowImplicitScrolling: true,
            itemCount: entries.length,
            findChildIndexCallback: (key) =>
                key is ValueKey<String> ? pageById[key.value] : null,
            onPageChanged: (page) {
              final lock = _lockedPage.value;
              if (lock == null || page <= lock) _feed.add(FeedFocused(page));
            },
            itemBuilder: (context, index) => switch (entries[index]) {
              final EpisodeEntry e => EpisodePage(
                key: ValueKey(e.id),
                episode: e.episode,
                total: state.episodes.length,
              ),
              final AdBreakEntry b => AdBreakPage(
                key: ValueKey(b.id),
                breakId: b.id,
              ),
            },
          );
        },
      ),
    );
  }
}
