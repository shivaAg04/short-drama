import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rume/core/theme/app_colors.dart';
import 'package:rume/engagement/ui/action_rail.dart';
import 'package:rume/feed/domain/episode.dart';
import 'package:rume/feed/domain/feed_entry.dart';
import 'package:rume/feed/state/feed_bloc.dart';
import 'package:rume/paywall/state/paywall_cubit.dart';
import 'package:rume/paywall/ui/paywall_overlay.dart';
import 'package:rume/player/domain/scrub_frames.dart';
import 'package:rume/player/state/video_pool.dart';
import 'package:rume/player/ui/episode_chip.dart';
import 'package:rume/player/ui/episode_gestures.dart';
import 'package:rume/player/ui/load_failed_card.dart';
import 'package:video_player/video_player.dart';

/// A page for one episode. The poster is drawn at once and the video fades
/// in on top when its controller is ready; for a locked episode no
/// controller exists, so the poster is all there is (PAY-1).
class EpisodePage extends StatefulWidget {
  const EpisodePage({required this.episode, required this.total, super.key});

  final Episode episode;
  final int total;

  @override
  State<EpisodePage> createState() => _EpisodePageState();
}

class _EpisodePageState extends State<EpisodePage> {
  // The rail's like icon: double-tap hearts fly into it.
  final GlobalKey<State<StatefulWidget>> _likeIcon = GlobalKey();

  Episode get episode => widget.episode;

  ImageProvider? _frameAt(int second) {
    final url = ScrubFrames.urlAt(episode.videoUrl, second);
    return url == null ? null : NetworkImage(url);
  }

  int get total => widget.total;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PaywallCubit, PaywallState, (bool, bool)>(
      selector: (s) =>
          (s.isLocked(episode.number), episode.number >= s.lockedEpisode),
      builder: (context, paywall) {
        final (locked, lockable) = paywall;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.ink),
            Poster(url: episode.posterUrl),
            if (!locked) _VideoOrPlaceholder(episode: episode.number),
            // Under the gestures layer, so it never dims the progress bar.
            const _Scrim(),
            if (!locked)
              ValueListenableBuilder<VideoPlayerController?>(
                valueListenable: context.read<VideoPool>().controllerFor(
                  episode.number,
                ),
                builder: (context, controller, _) => controller == null
                    ? const SizedBox.shrink()
                    : EpisodeGestures(
                        episode: episode.number,
                        controller: controller,
                        likeTarget: _likeIcon,
                        frameAt: _frameAt,
                      ),
              ),
            // Above the gestures so the description can take its own taps.
            _Caption(episode: episode, total: total),
            if (!locked)
              Positioned(
                right: 6,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 44),
                    child: ActionRail(episode: episode, likeKey: _likeIcon),
                  ),
                ),
              ),
            if (lockable) _PaywallLayer(episode: episode),
          ],
        );
      },
    );
  }
}

/// Feeds the overlay its inputs. Kept separate so a page change rebuilds
/// only this, never the video.
class _PaywallLayer extends StatelessWidget {
  const _PaywallLayer({required this.episode});

  final Episode episode;

  /// The locked clip, then the ones just before it, for the paywall's fan.
  List<String> _posters(BuildContext context) {
    final all = context.read<FeedBloc>().state.episodes;
    final others = all.where((e) => e.number != episode.number).toList()
      ..sort(
        (a, b) => (a.number - episode.number).abs().compareTo(
          (b.number - episode.number).abs(),
        ),
      );
    return [episode.posterUrl, for (final e in others.take(2)) e.posterUrl];
  }

  @override
  Widget build(BuildContext context) {
    final id = EpisodeEntry(episode).id;
    return BlocSelector<FeedBloc, FeedState, bool>(
      selector: (s) => s.focused?.id == id,
      builder: (context, focused) =>
          BlocSelector<PaywallCubit, PaywallState, (bool, bool)>(
            selector: (s) => (s.isLocked(episode.number), s.purchasing),
            builder: (context, paywall) => PaywallOverlay(
              episodeNumber: episode.number,
              locked: paywall.$1,
              purchasing: paywall.$2,
              focused: focused,
              onUnlock: context.read<PaywallCubit>().unlock,
              posters: _posters(context),
            ),
          ),
    );
  }
}

class Poster extends StatelessWidget {
  const Poster({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              child: child,
            ),
      errorBuilder: (context, error, stack) => const SizedBox.shrink(),
    );
  }
}

/// The video once it is ready; until then just the poster beneath, or the
/// error card if loading failed.
class _VideoOrPlaceholder extends StatelessWidget {
  const _VideoOrPlaceholder({required this.episode});

  final int episode;

  @override
  Widget build(BuildContext context) {
    final pool = context.read<VideoPool>();
    final controller = pool.controllerFor(episode);
    final failed = pool.failedFor(episode);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, failed]),
      builder: (context, _) {
        final ready = controller.value;
        if (ready != null) return _Video(controller: ready);
        if (failed.value) return LoadFailedCard(onRetry: pool.retry);
        return const SizedBox.shrink();
      },
    );
  }
}

/// The video over the poster. The fade-in plays only if the controller
/// becomes ready while the page is showing; a page built around an already
/// ready controller shows the video straight away.
class _Video extends StatefulWidget {
  const _Video({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.controller.value.size;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(widget.controller),
        ),
      ),
    );
  }
}

/// The episode chip, the series name and the description, shown from the
/// start (PLAY-11). Only the description takes taps; everything else lets
/// them through to the gestures below.
class _Caption extends StatelessWidget {
  const _Caption({required this.episode, required this.total});

  final Episode episode;
  final int total;

  // Clears the time label and progress bar beneath it.
  static const _aboveTimeline = 58.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 84, _aboveTimeline),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IgnorePointer(
                child: EpisodeChip(number: episode.number, total: total),
              ),
              if (episode.series.isNotEmpty) ...[
                const SizedBox(height: 12),
                IgnorePointer(child: SeriesLabel(name: episode.series)),
              ],
              if (episode.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                EpisodeDescription(text: episode.description),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Darkens the bottom of the episode so the caption and bar stay readable.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.5, 1],
            colors: [Color(0x00000000), Color(0xB3000000)],
          ),
        ),
      ),
    );
  }
}

/// The series' avatar, its initial on the brand gradient, and its name.
class SeriesLabel extends StatelessWidget {
  const SeriesLabel({required this.name, super.key});

  final String name;

  static const double height = 28;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: height,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                shadows: _shadow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 6)];

/// Two lines with an ellipsis; a tap opens it in full, growing upwards,
/// and another closes it (PLAY-13). A very long one scrolls rather than
/// covering the video.
class EpisodeDescription extends StatefulWidget {
  const EpisodeDescription({required this.text, super.key});

  final String text;

  static const collapsedLines = 2;
  static const style = TextStyle(
    color: Color(0xE6FFFFFF),
    fontSize: 13.5,
    height: 1.35,
    shadows: _shadow,
  );

  @override
  State<EpisodeDescription> createState() => _EpisodeDescriptionState();
}

class _EpisodeDescriptionState extends State<EpisodeDescription> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.text,
      style: EpisodeDescription.style,
      maxLines: _open ? null : EpisodeDescription.collapsedLines,
      overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _open = !_open),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomLeft,
        child: _open
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                ),
                child: SingleChildScrollView(child: text),
              )
            : text,
      ),
    );
  }
}
