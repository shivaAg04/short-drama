import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rume/ads/ad_config.dart';

// Google's published sample ids.
const _gamTestNetwork = '/21775744923/example/';
const _androidTestAppId = 'ca-app-pub-3940256099942544~3347511713';
const _iosTestAppId = 'ca-app-pub-3940256099942544~1458002511';

void main() {
  test('[AD-5] every break uses a GAM test ad unit', () {
    for (var n = 1; n <= 3; n++) {
      expect(AdConfig.unitFor('break:$n'), startsWith(_gamTestNetwork));
    }
  });

  test('[AD-5] both platforms declare only the sample app ids', () {
    final declared = {
      _androidTestAppId: 'android/app/src/main/AndroidManifest.xml',
      _iosTestAppId: 'ios/Runner/Info.plist',
    };
    for (final MapEntry(key: appId, value: path) in declared.entries) {
      final ids = RegExp(r'ca-app-pub-\d+~\d+')
          .allMatches(File(path).readAsStringSync())
          .map((m) => m[0])
          .toSet();
      expect(ids, {appId}, reason: path);
    }
  });
}
