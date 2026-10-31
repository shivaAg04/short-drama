import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The plugin's own channel: the only way to stand in for the native SDK.
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:rume/ads/ad_config.dart';
import 'package:rume/ads/break_ad.dart';

// The adapter's contract with the native SDK, checked on the platform
// channel: what it asks for, and what it does with the answers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = instanceManager.channel;
  late List<MethodCall> sent;
  late int loaded;
  late List<String> failures;

  setUp(() {
    sent = [];
    loaded = 0;
    failures = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent.add(call);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<GamBreakAd> loadAd() async {
    final ad = GamBreakAd(
      'break:1',
      onFilled: () => loaded++,
      onEmpty: failures.add,
    );
    await ad.load();
    return ad;
  }

  Map<dynamic, dynamic> loadRequest() =>
      sent.lastWhere((c) => c.method == 'loadNativeAd').arguments
          as Map<dynamic, dynamic>;

  // The native SDK reporting back, as it does on a device.
  Future<void> sdkSays(String event, [Map<String, Object?> extra = const {}]) {
    final call = MethodCall('onAdEvent', {
      'adId': loadRequest()['adId'],
      'eventName': event,
      ...extra,
    });
    return messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(call),
      (_) {},
    );
  }

  test('[AD-5] [AD-7] it requests the test unit, drawn by our full-screen '
      'layout, muted', () async {
    await loadAd();
    final request = loadRequest();
    expect(request['adUnitId'], AdConfig.unitFor('break:1'));
    expect(request['factoryId'], AdConfig.factoryId);
    final options = request['nativeAdOptions'] as NativeAdOptions;
    expect(options.videoOptions?.startMuted, isTrue);
  });

  test('[AD-1] a fill is reported as loaded', () async {
    await loadAd();
    await sdkSays('onAdLoaded');
    expect(loaded, 1);
    expect(failures, isEmpty);
  });

  test('[AD-3] no fill is reported with its code and message', () async {
    await loadAd();
    await sdkSays('onAdFailedToLoad', {
      'loadAdError': LoadAdError(
        3,
        'com.google.android.gms.ads',
        'No fill.',
        null,
      ),
    });
    expect(failures, ['3: No fill.']);
    expect(loaded, 0);
  });

  test('[AD-6] [AD-7] disposing releases the native ad; the view is the '
      "SDK's own widget", () async {
    final ad = await loadAd();
    expect(ad.buildView(), isA<AdWidget>());
    await ad.dispose();
    expect(sent.map((c) => c.method), contains('disposeAd'));
  });
}
