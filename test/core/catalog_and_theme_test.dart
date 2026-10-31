import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rume/core/theme/app_colors.dart';
import 'package:rume/core/theme/app_theme.dart';
import 'package:rume/feed/data/episode_catalog.dart';
import 'package:rume/player/domain/scrub_frames.dart';

void main() {
  final episodes = EpisodeCatalog.episodes;

  test('[FEED-1] the catalogue is seven episodes, numbered 1 to 7', () {
    expect(episodes.map((e) => e.number), [1, 2, 3, 4, 5, 6, 7]);
  });

  test('[SCRUB-10] every episode streams over HTTPS from a host that can '
      'render scrub frames and posters', () {
    for (final e in episodes) {
      expect(Uri.parse(e.videoUrl).scheme, 'https');
      expect(ScrubFrames.urlAt(e.videoUrl, 0), isNotNull);
      expect(e.posterUrl, endsWith('.jpg'));
    }
  });

  test('the app is dark, on ink, in Inter, with brand-blue accents', () {
    final theme = AppTheme.dark;
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.ink);
    expect(theme.textTheme.titleMedium?.fontFamily, 'Inter');
    expect(theme.colorScheme.primary, AppColors.primaryLight);
  });
}
