import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:rume/ads/ad_config.dart';

/// The ad shown in one ad break. Only [GamBreakAd] talks to the plugin;
/// everything else works against this interface and is tested with a fake.
abstract interface class BreakAd {
  Future<void> load();
  Future<void> dispose();
  Widget buildView();
}

typedef BreakAdMaker = BreakAd Function(
  String breakId, {
  required VoidCallback onFilled,
  required void Function(String why) onEmpty,
});

/// A GAM native ad, rendered by the full-screen layout registered in
/// MainActivity / AppDelegate under [AdConfig.factoryId].
final class GamBreakAd implements BreakAd {
  GamBreakAd(
    String breakId, {
    required VoidCallback onFilled,
    required void Function(String why) onEmpty,
  }) : _native = NativeAd.fromAdManagerRequest(
         adUnitId: AdConfig.unitFor(breakId),
         factoryId: AdConfig.factoryId,
         adManagerRequest: const AdManagerAdRequest(),
         nativeAdOptions: NativeAdOptions(
           mediaAspectRatio: MediaAspectRatio.portrait,
           // Video creatives start silent, matching an unfocused feed page.
           videoOptions: VideoOptions(startMuted: true),
         ),
         listener: NativeAdListener(
           onAdLoaded: (_) => onFilled(),
           onAdFailedToLoad: (_, error) =>
               onEmpty('${error.code}: ${error.message}'),
         ),
       );

  final NativeAd _native;

  @override
  Future<void> load() => _native.load();

  @override
  Future<void> dispose() => _native.dispose();

  @override
  Widget buildView() => AdWidget(ad: _native);
}
