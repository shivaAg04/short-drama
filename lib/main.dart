// coverage:ignore-file
// The bootstrap: plugin start-up and system UI setup, run once on a device.
// Everything it builds is covered through FeedScreen.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:rume/core/theme/app_theme.dart';
import 'package:rume/feed/data/episode_catalog.dart';
import 'package:rume/feed/ui/feed_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Not awaited: the first ad slot is pages away, the first video is not.
  unawaited(MobileAds.instance.initialize());
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const RumeApp());
}

class RumeApp extends StatelessWidget {
  const RumeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alright',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: FeedScreen(episodes: EpisodeCatalog.episodes),
    );
  }
}
